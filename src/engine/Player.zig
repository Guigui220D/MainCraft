//! Our own player (not other players)

const std = @import("std");
const coord = @import("coord");
const net = @import("net");
const Game = @import("Game.zig");
const blocks = @import("blocks");
const mc = @import("entities/movement_constants.zig");

const Player = @This();

// Made with the help of
// https://pixelbrush.dev/beta-wiki/entities/movement

// TODO for player movement:
// blocks pushing against instead of cancelling movement
// proper on ground detection

/// Reference to the game
game: *Game,
/// Health level
health: u8,
/// Current position of the player
pos: coord.Vec3f,
/// Velocity
vel: coord.Vec3f,
/// On ground flag
on_ground: bool,
/// Hitbox
hitbox: coord.HitboxAABB,
/// Last position sent to the server
last_pos: coord.Vec3f,
/// Forward movement potential
move_forward: f32,
/// Strafe movement potential
move_strafe: f32,
/// Head yaw in degrees (rotation along y axis)
yaw: f32,
/// Last yaw sent to the server
last_yaw: f32,
/// Head pitch in degrees(rotation up/down)
pitch: f32,
/// Last pitch sent to the server
last_pitch: f32,
/// Flags for the current walking direction
walking: packed struct {
    forward: bool,
    backward: bool,
    left: bool,
    right: bool,
},

pub fn init(game: *Game) Player {
    const ret: Player = .{
        .game = game,
        .health = 20,
        .pos = .{ .x = 0, .y = 0, .z = 0 },
        .vel = .{ .x = 0, .y = 0, .z = 0 },
        .on_ground = false,
        .hitbox = .{
            .a = .{ .x = -0.3, .y = 0, .z = -0.3 },
            .b = .{ .x = 0.3, .y = 1.8, .z = 0.3 },
        },
        .last_pos = .{ .x = 0, .y = 0, .z = 0 },
        .move_forward = 0,
        .move_strafe = 0,
        .yaw = 0,
        .last_yaw = 0,
        .pitch = 0,
        .last_pitch = 0,
        .walking = .{
            .forward = false,
            .backward = false,
            .left = false,
            .right = false,
        },
    };
    return ret;
}

pub fn setPosition(self: *Player, pos: coord.Vec3f) void {
    self.pos = pos;
}

pub fn setHeadAngle(self: *Player, yaw: f32, pitch: f32) void {
    self.yaw = yaw;
    self.pitch = pitch;
}

pub fn resetPosition(self: *Player, pos: coord.Vec3f) void {
    //self.last_pos = pos;
    self.pos = pos;
}

pub fn resetHeadAngle(self: *Player, yaw: f32, pitch: f32) void {
    //self.last_yaw = yaw;
    self.yaw = yaw;
    //self.last_pitch = pitch;
    self.pitch = pitch;
}

pub fn jump(self: *Player) void {
    if (!self.on_ground)
        return;
    //self.vspeed = jumping_acc;
    self.on_ground = false;
}

pub fn tick(self: *Player) void {
    // decay input axes
    self.move_forward *= mc.input_decay;
    self.move_strafe *= mc.input_decay;

    // apply keyboard controls
    self.applyKeyboardControls();

    const friction = mc.default_block_slipperiness * mc.horizontal_friction;
    const acceleration = 0.1 * mc.normal_friction_cubed / (friction * friction * friction);

    // TODO: sneaking
    // TODO: jumping
    // TODO: other scenarios

    self.applyInput(self.move_strafe, self.move_forward, acceleration);

    //self.move(self.vel);

    if (self.touchesTerrain()) { // Temporary
        self.vel.y = 0;
    } else {
        self.vel.y -= mc.gravity;
    }
    self.vel.y *= mc.vertical_friction;
    self.vel.x *= friction;
    self.vel.z *= friction;

    self.pos.x += self.vel.x;
    self.pos.y += self.vel.y;
    self.pos.z += self.vel.z;
}

/// consider keyboard input in
fn applyKeyboardControls(self: *Player) void {
    if (self.walking.forward) {
        self.walking.forward = false;
        self.move_forward = 1;
    }
    if (self.walking.backward) {
        self.walking.backward = false;
        self.move_forward = -1;
    }
    if (self.walking.left) {
        self.walking.left = false;
        self.move_strafe = 1;
    }
    if (self.walking.right) {
        self.walking.right = false;
        self.move_strafe = -1;
    }
}

/// Converts strafe/forward input into a velocity impulse along the entity's facing direction
fn applyInput(self: *Player, strafe: f32, forward: f32, accel: f32) void {
    var length = @sqrt(strafe * strafe + forward * forward);

    if (length < 0.1)
        return;

    if (length < 1.0)
        length = 1.0;

    const new_strafe = strafe / length;
    const new_forward = forward / length;
    const yaw = std.math.degreesToRadians(self.yaw);

    self.vel.x += (new_strafe * @cos(yaw) + new_forward * @sin(yaw)) * accel;
    self.vel.z += (-new_forward * @cos(yaw) + new_strafe * @sin(yaw)) * accel;
}

// Temporary: later, smarter things with how much of a movement should be cancelled and all
fn touchesTerrain(self: Player) bool {
    const hitbox = self.hitbox.offset(self.pos);
    var block_it = hitbox.getBlocks();
    while (block_it.next()) |block_pos| {
        const block_id = self.game.world.getBlockId(block_pos);
        const blocking = blocks.table[block_id].flags.hitbox;
        if (blocking)
            return true;
    }
    return false;
}

// Temporary: later, smarter things with how much of a movement should be cancelled and all
fn sideTouchesTerrain(self: Player, face: coord.Direction) bool {
    const hitbox = self.hitbox.offset(self.pos);
    var block_it = hitbox.getFaceBlocks(face);
    while (block_it.next()) |block_pos| {
        const block_id = self.game.world.getBlockId(block_pos);
        const blocking = blocks.table[block_id].flags.hitbox;
        if (blocking)
            return true;
    }
    return false;
}

pub fn makePositionPacket(self: *Player) net.server_bound.OutboundPacket {
    const did_move = (self.pos.x != self.last_pos.x) or (self.pos.y != self.last_pos.y) or (self.pos.y != self.last_pos.y);
    const did_turn = (self.pitch != self.last_pitch) or (self.yaw != self.last_yaw);

    defer {
        self.last_pos = self.pos;
        self.last_pitch = self.pitch;
        self.last_yaw = self.yaw;
    }

    if (did_move) {
        if (did_turn) {
            return .{ .player_look_move_13 = .{
                .x_position = self.pos.x,
                .y_position = self.pos.y,
                .y_center_position = self.pos.y + 1.0,
                .z_position = self.pos.z,
                .pitch = self.pitch,
                .yaw = self.yaw + 180.0,
                .on_ground = self.on_ground,
            } };
        } else {
            return .{ .player_position_11 = .{
                .x_position = self.pos.x,
                .y_position = self.pos.y,
                .y_center_position = self.pos.y + 1.0,
                .z_position = self.pos.z,
                .on_ground = self.on_ground,
            } };
        }
    } else {
        if (did_turn) {
            return .{ .player_look_12 = .{
                .pitch = self.pitch,
                .yaw = self.yaw + 180.0,
                .on_ground = self.on_ground,
            } };
        } else {
            return .{
                .on_ground_10 = .{
                    .on_ground = self.on_ground,
                },
            };
        }
    }
}

pub fn walkForwards(self: *Player) void {
    self.walking.forward = true;
}
pub fn walkLeft(self: *Player) void {
    self.walking.left = true;
}
pub fn walkBackwards(self: *Player) void {
    self.walking.backward = true;
}
pub fn walkRight(self: *Player) void {
    self.walking.right = true;
}

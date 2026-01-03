//! Our own player (not other players)

const std = @import("std");
const coord = @import("coord");
const net = @import("net");
const Game = @import("Game.zig");
const blocks = @import("blocks");

const Player = @This();

const player_speed = 4.317; // TODO: Check this value in the code

/// Reference to the game
game: *Game,
/// Current position of the player
pos: coord.Vec3f,
/// Hitbox
hitbox: coord.HitboxAABB,
/// Last position sent to the server
last_pos: coord.Vec3f,
/// Head yaw (rotation along y axis)
yaw: f32,
/// Last yaw sent to the server
last_yaw: f32,
/// Head pitch (rotation up/down)
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
    var ret: Player = undefined;
    ret.game = game;
    ret.pos = .{ .x = 0, .y = 0, .z = 0 };
    ret.hitbox = .{
        .a = .{ .x = -0.3, .y = 0, .z = -0.3 },
        .b = .{ .x = 0.3, .y = 1.8, .z = 0.3 },
    };
    ret.last_pos = .{ .x = 0, .y = 0, .z = 0 };
    ret.yaw = 0;
    ret.last_yaw = 0;
    ret.pitch = 0;
    ret.last_pitch = 0;
    ret.walking = .{
        .forward = false,
        .backward = false,
        .left = false,
        .right = false,
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
    self.last_pos = pos;
    self.pos = pos;
}

pub fn resetHeadAngle(self: *Player, yaw: f32, pitch: f32) void {
    self.last_yaw = yaw;
    self.yaw = yaw;
    self.last_pitch = pitch;
    self.pitch = pitch;
}

pub fn update(self: *Player, delta: f32) void {
    // Save movement in order to cancel it (temporary)
    var prev_pos = self.pos;

    // Normalize movement
    var mov_x_local: f32 = 0;
    var mov_z_local: f32 = 0;

    if (self.walking.forward)
        mov_x_local += 1;

    if (self.walking.backward)
        mov_x_local -= 1;

    if (self.walking.left)
        mov_z_local -= 1;

    if (self.walking.right)
        mov_z_local += 1;

    const norm = @sqrt(mov_x_local * mov_x_local + mov_z_local * mov_z_local);
    if (norm > 0.01) {
        mov_x_local /= norm;
        mov_z_local /= norm;

        // Apply movement
        self.pos.x += (@sin(-self.yaw) * mov_x_local + @cos(self.yaw) * mov_z_local) * delta * player_speed;
        self.pos.z -= (@cos(self.yaw) * mov_x_local - @sin(-self.yaw) * mov_z_local) * delta * player_speed;
    }

    self.walking.forward = false;
    self.walking.backward = false;
    self.walking.left = false;
    self.walking.right = false;

    if (self.touchesTerrain())
        self.pos = prev_pos;

    // Gravity (temporary, prototype)
    prev_pos = self.pos;
    self.pos.y -= delta;

    if (self.touchesTerrain())
        self.pos = prev_pos;
}

// Temporary: later, smarter things with how much of a movement should be cancelled and all
fn touchesTerrain(self: Player) bool {
    const hitbox = self.hitbox.offset(self.pos);
    var block_it = hitbox.getBlocks();
    while (block_it.next()) |block_pos| {
        const block_id = self.game.world.getBlockId(block_pos);
        const blocking = blocks.table[block_id].hitbox;
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

    // TODO: send actual on ground

    if (did_move) {
        if (did_turn) {
            return .{ .player_look_move_13 = .{
                .x_position = self.pos.x,
                .y_position = self.pos.y,
                .y_center_position = self.pos.y + 1.0,
                .z_position = self.pos.z,
                .pitch = self.pitch,
                .yaw = self.yaw,
                .on_ground = true,
            } };
        } else {
            return .{ .player_position_11 = .{
                .x_position = self.pos.x,
                .y_position = self.pos.y,
                .y_center_position = self.pos.y + 1.0,
                .z_position = self.pos.z,
                .on_ground = true,
            } };
        }
    } else {
        if (did_turn) {
            return .{ .player_look_12 = .{
                .pitch = self.pitch,
                .yaw = self.yaw,
                .on_ground = true,
            } };
        } else {
            return .{
                .on_ground_10 = .{
                    .on_ground = true,
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

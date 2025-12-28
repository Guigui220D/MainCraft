//! Our own player (not other players)

const std = @import("std");
const coord = @import("coord");

const Player = @This();

const player_speed = 4.317; // TODO: Check this value in the code

pos: coord.Vec3f,
yaw: f32,
pitch: f32,
walking: packed struct {
    forward: bool,
    backward: bool,
    left: bool,
    right: bool,
},

// Temporary
first_time: bool,

pub fn init() Player {
    var ret: Player = undefined;
    ret.first_time = true;
    ret.pos = .{ .x = 0, .y = 0, .z = 0 };
    ret.yaw = 0;
    ret.pitch = 0;
    ret.walking = .{
        .forward = false,
        .backward = false,
        .left = false,
        .right = false,
    };
    return ret;
}

pub fn setPosition(self: *Player, pos: coord.Vec3f) void {
    if (self.first_time) {
        self.pos = pos;
        // To test movement
        self.first_time = false;
    }
}

pub fn setHeadAngle(self: *Player, yaw: f32, pitch: f32) void {
    self.yaw = yaw;
    self.pitch = pitch;
}

pub fn update(self: *Player, delta: f32) void {
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

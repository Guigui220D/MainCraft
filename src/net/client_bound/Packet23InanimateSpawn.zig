//! Packet indicating an inanimate entity has spawned

const std = @import("std");
const net = @import("../net.zig");

entity_id: i32,
entity_type: u8,
x_position: i32,
y_position: i32,
z_position: i32,
projectile_sender: i32, // entity id
x_motion: i16,
y_motion: i16,
z_motion: i16,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    var ret = @This(){
        .entity_id = try stream.takeInt(i32, net.endianness),
        .entity_type = try stream.takeByte(),
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .projectile_sender = try stream.takeInt(i32, net.endianness),
        .x_motion = 0,
        .y_motion = 0,
        .z_motion = 0,
    };

    // Read motion only for projectiles
    if (ret.projectile_sender > 0) {
        ret.x_motion = try stream.takeInt(i16, net.endianness);
        ret.y_motion = try stream.takeInt(i16, net.endianness);
        ret.z_motion = try stream.takeInt(i16, net.endianness);
    }

    return ret;
}

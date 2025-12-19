//! Packet updating an entity's position teleporting it

const std = @import("std");
const net = @import("../net.zig");

entity_id: i32,
x_position: i32,
y_position: i32,
z_position: i32,
yaw: i8,
pitch: i8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .yaw = try stream.takeInt(i8, net.endianness),
        .pitch = try stream.takeInt(i8, net.endianness),
    };
}

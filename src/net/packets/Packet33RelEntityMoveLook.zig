//! Packet updating an entity's position and looking direction

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32,
x_position: i8,
y_position: i8,
z_position: i8,
yaw: i8,
pitch: i8,

// TODO: this is normally backed by packet30 entity, setting the rotating=true flag, should I do the same?

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .x_position = try stream.takeInt(i8, net.endianness),
        .y_position = try stream.takeInt(i8, net.endianness),
        .z_position = try stream.takeInt(i8, net.endianness),
        .yaw = try stream.takeInt(i8, net.endianness),
        .pitch = try stream.takeInt(i8, net.endianness),
    };
}

pub const tag = net.Packets.rel_entity_move_look_33;

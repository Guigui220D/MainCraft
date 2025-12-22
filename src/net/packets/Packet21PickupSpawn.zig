//! Packet to spawn loose item

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32,
x_position: i32,
y_position: i32,
z_position: i32,
rotation: i8,
pitch: i8,
roll: i8,
// TODO: item stack?
item_id: i16,
stack_size: i8,
item_dmg: i16,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Entity id
        .entity_id = try stream.takeInt(i32, net.endianness),
        .item_id = try stream.takeInt(i16, net.endianness),
        .stack_size = try stream.takeInt(i8, net.endianness),
        // Stack
        .item_dmg = try stream.takeInt(i16, net.endianness),
        // Position
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        // Rotation
        .rotation = try stream.takeInt(i8, net.endianness),
        .pitch = try stream.takeInt(i8, net.endianness),
        .roll = try stream.takeInt(i8, net.endianness),
    };
}

pub const tag = net.Packets.pickup_spawn_21;

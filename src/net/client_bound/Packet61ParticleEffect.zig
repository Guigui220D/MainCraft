//! Packet to play a particle effect such as breaking a block

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

effect_id: i32,
x_position: i32,
y_position: u8,
z_position: i32,
block_id: i32,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .effect_id = try stream.takeInt(i32, net.endianness),
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(u8, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .block_id = try stream.takeInt(i32, net.endianness),
    };
}

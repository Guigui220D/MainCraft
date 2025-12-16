//! Packet indicating where the player has (re)spawned

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

x_position: i32,
y_position: i32,
z_position: i32,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Read spawn coordinates
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
    };
}

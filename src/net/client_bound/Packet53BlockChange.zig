//! Packet notifying a block has changed

const std = @import("std");
const net = @import("../net.zig");

x_position: i32,
y_position: u8,
z_position: i32,
block_id: u8,
block_meta: u8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Read spawn coordinates
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(u8, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .block_id = try stream.takeInt(u8, net.endianness),
        .block_meta = try stream.takeInt(u8, net.endianness),
    };
}

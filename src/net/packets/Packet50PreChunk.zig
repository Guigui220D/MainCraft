//! Packet to prepare a chunk (before populating) or to delete it

const std = @import("std");
const net = @import("../net.zig");

x_position: i32,
z_position: i32,
mode: bool, // true to add, false to remove

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .x_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .mode = try stream.takeInt(i8, net.endianness) != 0,
    };
}

pub const tag = net.Packets.pre_chunk_50;

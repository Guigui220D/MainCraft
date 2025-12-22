//! Packet updating a statistics (?)

const std = @import("std");
const net = @import("../net.zig");

key: i32,
value: u8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .key = try stream.takeInt(i32, net.endianness),
        .value = try stream.takeByte(),
    };
}

pub const tag = net.Packets.statistic_200;

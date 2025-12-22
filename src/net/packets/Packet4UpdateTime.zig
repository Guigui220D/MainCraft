//! Packet to keep track of ingame time

const std = @import("std");
const net = @import("../net.zig");

time: i64,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Read time
        .time = try stream.takeInt(i64, net.endianness),
    };
}

pub const tag = net.Packets.update_time_4;

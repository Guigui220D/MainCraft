//! Packet updating the weather

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

// 1 is raining, 2 is not raining, anything more than that is some message (?)
value: i8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .value = try stream.takeInt(i8, net.endianness),
    };
}

pub const tag = net.Packets.weather_70;

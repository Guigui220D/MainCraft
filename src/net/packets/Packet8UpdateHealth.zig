//! Packet to update the player's health

const std = @import("std");
const net = @import("../net.zig");

health: u16,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Read time
        .health = try stream.takeInt(u16, net.endianness),
    };
}

pub const tag = net.Packets.update_health_8;

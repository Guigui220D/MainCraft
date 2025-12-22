//! Packet indicating if the player is on the ground

const std = @import("std");
const net = @import("../net.zig");

on_ground: bool,

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    try stream.writeByte(@intFromBool(self.on_ground));
}

pub const tag = net.Packets.on_ground_10;

//! Packet updating the player's head orientation

const std = @import("std");
const net = @import("../net.zig");

yaw: f32,
pitch: f32,
on_ground: bool,

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    try stream.writeInt(u32, @bitCast(self.yaw), net.endianness);
    try stream.writeInt(u32, @bitCast(self.pitch), net.endianness);
    try stream.writeByte(@intFromBool(self.on_ground));
}

pub const tag = net.Packets.player_look_12;

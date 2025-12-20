//! Packet to request handshake

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

username: []const u8,

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    // Username
    try string.checkUsername(self.username);
    try string.writeStringFast(stream, self.username);
}

pub const tag = net.Packets.handshake_2;

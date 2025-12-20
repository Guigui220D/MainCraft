//! Packet to request login

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

//protocol_version: i32, // Constant: defined in net
username: []const u8,
// map_seed: i64, // Unused for serverbound
// dimension: i8, // Unused for serverbound

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    // Protocol version
    try stream.writeInt(u32, net.protocol_version, net.endianness);
    // Username
    try string.writeStringFast(stream, self.username);
    // Map seed (unused)
    try stream.writeInt(i64, 0, net.endianness);
    // Dimension (unused)
    try stream.writeInt(i8, 0, net.endianness);
}

pub const tag = net.Packets.login_1;

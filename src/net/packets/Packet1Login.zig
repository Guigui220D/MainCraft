//! Login exchange packet

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32 = 0, // unused when serverbound
username: []const u8, // unused when clientbound
map_seed: i64 = 0, // unused when serverbound
dimension: i8 = 0, // unused when serverbound

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Entity ID
    const entity_id = try stream.takeInt(i32, net.endianness);
    // Unused string
    try string.discardString(stream, 16);
    // Map seed
    const map_seed = try stream.takeInt(i64, net.endianness);
    // Dimension
    const dimension = try stream.takeInt(i8, net.endianness);

    return .{
        .entity_id = entity_id,
        .username = "",
        .map_seed = map_seed,
        .dimension = dimension,
    };
}

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

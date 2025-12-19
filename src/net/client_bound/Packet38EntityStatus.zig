//! Packet updating an entity's status

const std = @import("std");
const net = @import("../net.zig");

entity_id: i32,
entity_status: u8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .entity_status = try stream.takeByte(),
    };
}

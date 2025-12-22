//! Packet destroying an entity

const std = @import("std");
const net = @import("../net.zig");

entity_id: i32,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
    };
}

pub const tag = net.Packets.destroy_entity_29;

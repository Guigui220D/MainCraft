//! Packet to indicate a player's held item

const std = @import("std");
const net = @import("../net.zig");

entity_id: i32,
slot: i16,
item_id: i16,
item_dmg: i16,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .slot = try stream.takeInt(i16, net.endianness),
        .item_id = try stream.takeInt(i16, net.endianness),
        .item_dmg = try stream.takeInt(i16, net.endianness),
    };
}

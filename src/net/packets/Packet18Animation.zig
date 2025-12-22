//! Packet notifying of an entity animation

const std = @import("std");
const net = @import("../net.zig");

entity_id: i32,
animation: u8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .animation = try stream.takeByte(),
    };
}

pub const tag = net.Packets.animation_18;

//! Packet indicating a loose item has been picked up

const std = @import("std");
const net = @import("../net.zig");

collected_ent_id: i32,
collector_ent_id: i32,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .collected_ent_id = try stream.takeInt(i32, net.endianness),
        .collector_ent_id = try stream.takeInt(i32, net.endianness),
    };
}

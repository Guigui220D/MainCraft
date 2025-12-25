//! Packet summoning a thunderbolt

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32,
is_thunder: bool,
position_x: i32,
position_y: i32,
position_z: i32,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .is_thunder = try stream.takeByte() != 0,
        .position_x = try stream.takeInt(i32, net.endianness),
        .position_y = try stream.takeInt(i32, net.endianness),
        .position_z = try stream.takeInt(i32, net.endianness),
    };
}

pub const tag = net.Packets.thunder_71;

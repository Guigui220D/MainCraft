//! Packet to update entity velocity

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32,
x_motion: i16,
y_motion: i16,
z_motion: i16,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Entity Id
        .entity_id = try stream.takeInt(i32, net.endianness),
        // Read motion
        .x_motion = try stream.takeInt(i16, net.endianness),
        .y_motion = try stream.takeInt(i16, net.endianness),
        .z_motion = try stream.takeInt(i16, net.endianness),
    };
}

pub const DonutPrint = .{};

//! Packet describing a player movement/position

const std = @import("std");
const net = @import("../net.zig");

// TODO The java code use a backing "packet flying". Should this be imitated?
x_position: f64,
y_position: f64,
z_position: f64,
y_center_position: f64,
yaw: f32,
pitch: f32,
on_ground: bool,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Ah yes, nice layout
        .x_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .y_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .y_center_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .z_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .yaw = @bitCast(try stream.takeInt(u32, net.endianness)),
        .pitch = @bitCast(try stream.takeInt(u32, net.endianness)),
        .on_ground = try stream.takeInt(i8, net.endianness) != 0,
    };
}

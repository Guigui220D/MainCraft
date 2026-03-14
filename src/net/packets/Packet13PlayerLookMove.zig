//! Packet describing a player movement/position

const std = @import("std");
const net = @import("../net.zig");

x_position: f64,
y_position: f64,
z_position: f64,
y_center_position: f64,
yaw: f32,
pitch: f32,
on_ground: bool,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .x_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .y_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .y_center_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .z_position = @bitCast(try stream.takeInt(u64, net.endianness)),
        .yaw = @bitCast(try stream.takeInt(u32, net.endianness)),
        .pitch = @bitCast(try stream.takeInt(u32, net.endianness)),
        .on_ground = try stream.takeInt(i8, net.endianness) != 0,
    };
}

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    try stream.writeInt(u64, @bitCast(self.x_position), net.endianness);
    try stream.writeInt(u64, @bitCast(self.y_position), net.endianness);
    try stream.writeInt(u64, @bitCast(self.y_center_position), net.endianness);
    try stream.writeInt(u64, @bitCast(self.z_position), net.endianness);
    try stream.writeInt(u32, @bitCast(self.yaw), net.endianness);
    try stream.writeInt(u32, @bitCast(self.pitch), net.endianness);
    try stream.writeByte(@intFromBool(self.on_ground));
}

pub const tag = net.Packets.player_look_move_13;

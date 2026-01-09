//! Packet spawning an entity

const std = @import("std");
const net = @import("../net.zig");
const WatchableObject = @import("engine").entities.WatchableObject;
const wo_reader = @import("../readers/watchable_objects.zig");

entity_id: i32,
entity_type: u8,
x_position: i32,
y_position: i32,
z_position: i32,
yaw: i8,
pitch: i8,
metadata: []WatchableObject,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .entity_type = try stream.takeByte(),
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .yaw = try stream.takeInt(i8, net.endianness),
        .pitch = try stream.takeInt(i8, net.endianness),
        .metadata = try wo_reader.read(alloc, stream),
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    WatchableObject.free(self.metadata, alloc);
}

pub const tag = net.Packets.mob_spawn_24;

//! Packet spawning an entity

const std = @import("std");
const net = @import("../net.zig");
const data_watcher = @import("data_watcher");
const wo_reader = @import("../readers/watchable_objects.zig");

entity_id: i32,
entity_type: i8,
x_position: i32,
y_position: i32,
z_position: i32,
yaw: i8,
pitch: i8,
metadata: []data_watcher.WatchableObject,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .entity_type = try stream.takeInt(i8, net.endianness),
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .yaw = try stream.takeInt(i8, net.endianness),
        .pitch = try stream.takeInt(i8, net.endianness),
        .metadata = try wo_reader.read(alloc, stream),
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    data_watcher.freeWatchableObjects(self.metadata, alloc);
}

pub const tag = net.Packets.mob_spawn_24;

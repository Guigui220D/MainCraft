//! Packet assigning metadata to an entity

const std = @import("std");
const net = @import("../net.zig");
const WatchableObject = @import("engine").entities.WatchableObject;
const wo_reader = @import("../readers/watchable_objects.zig");

entity_id: i32,
metadata: []WatchableObject,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        .entity_id = try stream.takeInt(i32, net.endianness),
        .metadata = try wo_reader.read(alloc, stream),
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    WatchableObject.free(self.metadata, alloc);
}

pub const tag = net.Packets.entity_metadata_40;

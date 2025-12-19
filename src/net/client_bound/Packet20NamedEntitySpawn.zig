//! Packet spawning a player
const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32,
name: []const u8,
x_position: i32,
y_position: i32,
z_position: i32,
rotation: i8,
pitch: i8,
current_item: i16,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    var ret: @This() = undefined;

    ret.entity_id = try stream.takeInt(i32, net.endianness);
    ret.name = try string.readString(stream, alloc, 16);
    errdefer alloc.free(ret.name);
    ret.x_position = try stream.takeInt(i32, net.endianness);
    ret.y_position = try stream.takeInt(i32, net.endianness);
    ret.z_position = try stream.takeInt(i32, net.endianness);
    ret.rotation = try stream.takeInt(i8, net.endianness);
    ret.pitch = try stream.takeInt(i8, net.endianness);
    ret.current_item = try stream.takeInt(i16, net.endianness);

    return ret;
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.name);
}

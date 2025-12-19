//! Packet containing block updates

const std = @import("std");
const net = @import("../net.zig");

x_position: i32,
z_position: i32,
size: u16,
coord_array: []i16,
block_ids: []u8,
block_metas: []u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    var ret = @This(){
        .x_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .size = try stream.takeInt(u16, net.endianness),
        .coord_array = undefined,
        .block_ids = undefined,
        .block_metas = undefined,
    };

    ret.coord_array = try stream.readSliceEndianAlloc(alloc, i16, ret.size, net.endianness);
    errdefer alloc.free(ret.coord_array);

    ret.block_ids = try stream.readAlloc(alloc, ret.size);
    errdefer alloc.free(ret.block_ids);

    ret.block_metas = try stream.readAlloc(alloc, ret.size);
    errdefer alloc.free(ret.block_metas);

    return ret;
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.coord_array);
    alloc.free(self.block_ids);
    alloc.free(self.block_metas);
}

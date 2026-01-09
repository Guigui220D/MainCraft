//! Packet containing a whole chunk or part of it

const std = @import("std");
const net = @import("../net.zig");

x_position: i32,
y_position: i16,
z_position: i32,
x_size: u8,
y_size: u8,
z_size: u8,
data: []u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Metadata
    var ret: @This() = .{
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i16, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .x_size = try stream.takeByte() + 1,
        .y_size = try stream.takeByte() + 1,
        .z_size = try stream.takeByte() + 1,

        .data = undefined,
    };

    // Data size isn't a separate field, it is with the data slice
    const data_size = try stream.takeInt(u32, net.endianness);
    var limited_reader_buf: [1024]u8 = undefined;
    var limited_reader = std.io.Reader.limited(stream, .limited(data_size), &limited_reader_buf);

    // Read chunk data using flate decompressor
    var decomp = std.compress.flate.Decompress.init(&limited_reader.interface, .zlib, &.{});
    ret.data = try decomp.reader.allocRemaining(alloc, .unlimited);
    errdefer alloc.free(ret.data);

    return ret;
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.data);
}

pub const tag = net.Packets.map_chunk_51;

//! Packet containing a whole chunk or part of it

const std = @import("std");
const net = @import("../net.zig");

x_position: i32,
y_position: i16,
z_position: i32,
x_size: u8,
y_size: u8,
z_size: u8,
chunk_size: u32,
chunk: []u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Metadata
    var ret: @This() = .{
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i16, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .x_size = try stream.takeInt(u8, net.endianness) + 1,
        .y_size = try stream.takeInt(u8, net.endianness) + 1,
        .z_size = try stream.takeInt(u8, net.endianness) + 1,
        .chunk_size = try stream.takeInt(u32, net.endianness),
        .chunk = undefined,
    };

    // Read chunk data
    // TODO: do I even need to buffer to read or can I stream it?
    const buf = try stream.readAlloc(alloc, @intCast(ret.chunk_size));
    defer alloc.free(buf);
    var buf_reader = std.Io.Reader.fixed(buf);

    // Init flate decompressor, and flush it all
    var decomp = std.compress.flate.Decompress.init(&buf_reader, .zlib, &.{});
    ret.chunk = try decomp.reader.allocRemaining(alloc, .unlimited); // TODO: surely there should be a limit? Figure out what should be the limit based on chunk sizes
    errdefer alloc.free(ret.chunk);

    return ret;
}

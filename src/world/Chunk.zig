//! A single chunk. Not the rendering data, only the contents

const std = @import("std");
const coord = @import("coord");

const Chunk = @This();

coords: coord.Chunk,
blocks: []const u8,

pub fn initEmpty(alloc: std.mem.Allocator, coords: coord.Chunk) !*Chunk {
    // Unimplemented
    const ret = try alloc.create(Chunk);
    errdefer alloc.destroy(ret);

    ret.* = .{
        .coords = coords,
        .blocks = undefined,
    };

    return ret;
}

pub fn destroyChunk(self: *Chunk, alloc: std.mem.Allocator) void {
    self.deinit(alloc);
    alloc.destroy(self);
}

pub fn deinit(_: Chunk, _: std.mem.Allocator) void {}

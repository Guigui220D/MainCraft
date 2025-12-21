//! A single chunk

const std = @import("std");
const coord = @import("coord");
const io = @import("io");

const Chunk = @This();

coords: coord.Chunk,
blocks: []const u8,
model: ?io.ChunkModel,

pub fn initEmpty(alloc: std.mem.Allocator, coords: coord.Chunk) !*Chunk {
    // Unimplemented
    const ret = try alloc.create(Chunk);
    errdefer alloc.destroy(ret);

    ret.* = .{
        .coords = coords,
        .blocks = undefined,
        .model = null,
    };

    return ret;
}

pub fn destroyChunk(self: *Chunk, alloc: std.mem.Allocator) void {
    self.deinit(alloc);
    alloc.destroy(self);
}

pub fn updateModel(self: *Chunk) !void {
    self.model = try io.ChunkModel.generateForChunk(self);
}

pub fn deinit(_: Chunk, _: std.mem.Allocator) void {}

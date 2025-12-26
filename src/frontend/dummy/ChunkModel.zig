//! A chunk's visual representation
//! This is specific to the IO and can be modified independently of the chunk's actual representation

const std = @import("std");
const coord = @import("coord");
const Chunk = @import("terrain").Chunk;

const ChunkModel = @This();

pub fn generateForChunk(_: std.mem.Allocator, _: Chunk) !ChunkModel {
    return .{};
}

pub fn deinit(_: ChunkModel, _: std.mem.Allocator) void {}

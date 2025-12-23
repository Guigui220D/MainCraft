//! A single chunk

const std = @import("std");
const coord = @import("coord");
const io = @import("io");

const Chunk = @This();

pub const width = 16;
pub const height = 256;

coords: coord.Chunk,
blocks: []u8,
model: ?io.ChunkModel,

pub fn initEmpty(alloc: std.mem.Allocator, coords: coord.Chunk) !*Chunk {
    // Unimplemented
    const ret = try alloc.create(Chunk);
    errdefer alloc.destroy(ret);

    ret.* = .{
        .coords = coords,
        .blocks = try alloc.alloc(u8, (height * width * width)),
        .model = null,
    };

    // Fill with zeros
    for (ret.blocks) |*bl| {
        bl.* = 0;
    }

    return ret;
}

// TODO: Understand better the memory layout of data, and also, is a chunk only 128 blocks high?
pub fn setChunkData(self: *Chunk, data: []const u8, x1: i32, y1: i32, z1: i32, x2: i32, y2: i32, z2: i32) []const u8 {
    var remaining = data;

    const dx = @abs(x2 - x1);
    const dy = @abs(y2 - y1);
    const dz = @abs(z2 - z1);

    // Copy each vertical slice
    var x = x1;
    while (x < x2) : (x += 1) {
        var z = z1;
        while (z < z2) : (z += 1) {
            const dest_offset: u32 = @bitCast(x << 11 | z << 7 | y1);
            @memcpy(self.blocks[dest_offset..(dest_offset + dy)], remaining[0..dy]);
            remaining = remaining[dy..];
        }
    }

    // Ignore remaining data (TODO: don't ignore metadata)
    const meta_len = (dx * dy * dz) / 2;
    remaining = remaining[(meta_len)..]; // meta
    remaining = remaining[(meta_len)..]; // blocklight
    remaining = remaining[(meta_len)..]; // skylight

    return remaining;
}

pub fn destroyChunk(self: *Chunk, alloc: std.mem.Allocator) void {
    self.deinit(alloc);
    if (self.model) |model|
        model.deinit(alloc);
    alloc.destroy(self);
}

pub fn updateModel(self: *Chunk, alloc: std.mem.Allocator) !void {
    if (self.model) |old_model|
        old_model.deinit(alloc);
    self.model = try io.ChunkModel.generateForChunk(alloc, self.*);
}

pub fn deinit(self: Chunk, alloc: std.mem.Allocator) void {
    alloc.free(self.blocks);
}

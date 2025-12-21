//! A collection of chunks

const std = @import("std");
const coord = @import("coord");

const World = @This();
const Chunk = @import("Chunk.zig");

// TODO: store by pointer or value? depends on what the hashmap does
const ChunkList = std.AutoHashMap(coord.Chunk, *Chunk);

alloc: std.mem.Allocator,
chunk_list: ChunkList,

pub fn init(alloc: std.mem.Allocator) !World {
    return .{
        .alloc = alloc,
        .chunk_list = .init(alloc),
    };
}

/// Gets a chunk reference from its coordinates
/// The chunk isn't guaranteed to be populated
/// or to even exist (in this case null is returned)
pub fn getChunk(self: *World, coords: coord.Chunk) ?*Chunk {
    return self.chunk_list.get(coords);
}

/// Prepare a chunk for population or remove it (for Packet50PreChunk)
pub fn doPreChunk(self: *World, coords: coord.Chunk, add: bool) !void {
    if (add) {
        // Add chunk
        if (!self.chunk_list.contains(coords)) {
            const new_chunk = try Chunk.initEmpty(self.alloc, coords);
            errdefer new_chunk.destroyChunk(self.alloc);
            try self.chunk_list.put(coords, new_chunk);
            // Temporary
            try new_chunk.updateModel();
        }
    } else {
        // Remove chunk
        self.removeChunk(coords);
    }
}

/// Removes and frees a chunk
fn removeChunk(self: *World, coords: coord.Chunk) void {
    if (self.chunk_list.fetchRemove(coords)) |kv| {
        kv.value.destroyChunk(self.alloc);
    }
}

pub fn deinit(self: *World) void {
    var it = self.chunk_list.iterator();
    // Destroy all contained chunks
    while (it.next()) |entry| {
        entry.value_ptr.*.destroyChunk(self.alloc);
    }
    self.chunk_list.deinit();
}

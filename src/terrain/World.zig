//! A collection of chunks

const std = @import("std");
const coord = @import("coord");
const net = @import("net");

const World = @This();
const Chunk = @import("Chunk.zig");

// TODO: store by pointer or value? depends on what the hashmap does
const ChunkList = std.AutoHashMap(coord.Chunk, *Chunk);

alloc: std.mem.Allocator,
chunk_list: ChunkList,
dirty_priority_counter: u64,

pub fn init(alloc: std.mem.Allocator) !World {
    return .{
        .alloc = alloc,
        .chunk_list = .init(alloc),
        .dirty_priority_counter = 1,
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
            try self.addChunk(coords);
        }
    } else {
        // Remove chunk
        self.removeChunk(coords);
    }
}

/// Take block data and apply it to chunks
pub fn doChunkMap(self: *World, x: i32, y: i16, z: i32, size_x: u8, size_y: u8, size_z: u8, data: []const u8) !void {
    // TODO: initialize chunks or not if they weren't added?

    // Tracking data left to read
    var remaining = data;

    const y1 = @max(0, y);
    const y2 = @min(128, y + size_y);

    // Find relevant chunk range
    const chunk_x1 = x >> 4;
    const chunk_z1 = z >> 4;
    const chunk_x2 = (x + size_x - 1) >> 4;
    const chunk_z2 = (z + size_z - 1) >> 4;

    // Iterate through relevant chunks
    var chunk_x = chunk_x1;
    while (chunk_x <= chunk_x2) : (chunk_x += 1) {
        // Clamped boundaries within chunk
        const x1 = @max(0, x - chunk_x * 16);
        const x2 = @min(x + size_x - chunk_x * 16, 16);

        var chunk_z = chunk_z1;
        while (chunk_z <= chunk_z2) : (chunk_z += 1) {
            // Clamped boundaries within chunk
            const z1 = @max(0, z - chunk_z * 16);
            const z2 = @min(z + size_z - chunk_z * 16, 16);

            const coords = coord.Chunk{ .x = chunk_x, .z = chunk_z };

            // Chunk must exist
            if (!self.chunk_list.contains(coords)) {
                try self.addChunk(coords);
                std.debug.print("Warning: Chunk didn't get prepared?\n", .{});
            }

            // Apply modifications to selected chunk
            const chunk = self.getChunk(coords).?;
            remaining = chunk.setChunkData(remaining, x1, y1, z1, x2, y2, z2);

            // Update own model
            chunk.markDirtiness(&self.dirty_priority_counter);
            // Update neighbors if needed
            if (x1 <= 0) {
                if (self.getChunk(.{ .x = chunk_x - 1, .z = chunk_z })) |neighbor|
                    neighbor.markDirtiness(&self.dirty_priority_counter);
            }
            if (x2 >= 15) {
                if (self.getChunk(.{ .x = chunk_x + 1, .z = chunk_z })) |neighbor|
                    neighbor.markDirtiness(&self.dirty_priority_counter);
            }

            if (z1 <= 0) {
                if (self.getChunk(.{ .x = chunk_x, .z = chunk_z - 1 })) |neighbor|
                    neighbor.markDirtiness(&self.dirty_priority_counter);
            }
            if (z2 >= 15) {
                if (self.getChunk(.{ .x = chunk_x, .z = chunk_z + 1 })) |neighbor|
                    neighbor.markDirtiness(&self.dirty_priority_counter);
            }
        }
    }
}

pub fn setBlockId(self: *World, pos: coord.Block, block_id: u8) !void {
    const chunk_pos = pos.getChunk();
    const chunk = self.getChunk(chunk_pos) orelse return error.ChunkNotLoaded;
    const pos_in_chunk = pos.getPosInChunk();

    std.debug.assert(pos_in_chunk.isWithinChunk());

    chunk.setBlockId(pos_in_chunk, block_id);

    // Update own model
    chunk.markDirtiness(&self.dirty_priority_counter);
    // Update neighbors if needed
    if (pos.x == 0) {
        if (self.getChunk(.{ .x = chunk_pos.x - 1, .z = chunk_pos.z })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    } else if (pos.x == 15) {
        if (self.getChunk(.{ .x = chunk_pos.x + 1, .z = chunk_pos.z })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    }

    if (pos.z == 0) {
        if (self.getChunk(.{ .x = chunk_pos.x, .z = chunk_pos.z - 1 })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    } else if (pos.z == 15) {
        if (self.getChunk(.{ .x = chunk_pos.x, .z = chunk_pos.z + 1 })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    }
}

/// Updates a single chunk's model if it is marked as dirty
/// Returns true if a model was updated
pub fn updateModel(self: *World) !bool {
    var it = self.chunk_list.iterator();
    var to_update: ?*Chunk = null;
    var dirtiest: u64 = 0;

    // TODO: does it make sense to not search through whole array? like how long is iterating
    // priority is only a heuristic, it doesn't matter *that* much
    // Find dirty chunk with highest priority
    while (it.next()) |entry| {
        const chunk = entry.value_ptr.*;
        // This intentionally doesn't include chunks whose dirtiness is 0
        if (chunk.model_dirty > dirtiest) {
            to_update = chunk;
            dirtiest = chunk.model_dirty;
        }
    }

    if (to_update) |chunk_to_update| {
        try chunk_to_update.updateModel(self.alloc);
        return true;
    } else {
        return false;
    }
}

/// Adds an empty chunk in the position(assumes it doesn't exist)
fn addChunk(self: *World, coords: coord.Chunk) !void {
    const new_chunk = try Chunk.initEmpty(self, self.alloc, coords);
    errdefer new_chunk.destroyChunk(self.alloc);
    try self.chunk_list.put(coords, new_chunk);
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

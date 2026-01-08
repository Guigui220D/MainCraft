//! A collection of chunks

const std = @import("std");
const coord = @import("coord");
const net = @import("net");

const Game = @import("engine").Game;
const World = @This();
const Chunk = @import("Chunk.zig");

// TODO: store by pointer or value? depends on what the hashmap does
const ChunkList = std.AutoHashMap(coord.Chunk, *Chunk);

game: *Game,
alloc: std.mem.Allocator,
chunk_list: ChunkList,
dirty_priority_counter: u64,
modeling_thread_pool: *std.Thread.Pool,
meshes_mutex: std.Thread.Mutex,

pub fn init(game: *Game, alloc: std.mem.Allocator) !World {
    var ret: World = .{
        .game = game,
        .alloc = alloc,
        .chunk_list = .init(alloc),
        .dirty_priority_counter = 1,
        .modeling_thread_pool = undefined,
        .meshes_mutex = .{},
    };

    ret.modeling_thread_pool = try alloc.create(std.Thread.Pool);
    errdefer alloc.destroy(ret.modeling_thread_pool);

    try ret.modeling_thread_pool.init(.{ .allocator = alloc, .n_jobs = 4 });
    errdefer ret.modeling_thread_pool.deinit();

    return ret;
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

            // Apply modifications to selected chunk
            const chunk = self.getChunk(coords) orelse return error.ChunkNotLoaded;
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

            // TODO: when doing multithreading : maybe add a mutex for dirtiness?
            // Because on one chunk map or multiblock change we might make dirtyness
            // several times, which may cause superfluous chunk remodeling
            // Also take in account order (so a mutex probably is good)
        }
    }
}

/// Change multiple blocks
pub fn doMultiBlockChange(self: *World, chunk_pos: coord.Chunk, coord_array: []i16, block_ids: []u8, block_metas: []u8) !void {
    // Apply modifications to selected chunk
    const chunk = self.getChunk(chunk_pos) orelse return error.ChunkNotLoaded;

    var north_dirty = false;
    var east_dirty = false;
    var south_dirty = false;
    var west_dirty = false;

    for (coord_array, block_ids, block_metas) |pos, block_id, block_meta| {
        const xyz = coord.Block{
            .x = pos >> 12 & 15,
            .y = pos & 255,
            .z = pos >> 8 & 15,
        };

        // Update neighbors if needed
        if (xyz.x == 0) {
            west_dirty = true;
        } else if (xyz.x == 15) {
            east_dirty = true;
        }

        if (xyz.z == 0) {
            north_dirty = true;
        } else if (xyz.z == 15) {
            south_dirty = true;
        }

        chunk.setBlockIdAndMetadata(xyz, block_id, @truncate(block_meta));
    }

    // Update own model
    chunk.markDirtiness(&self.dirty_priority_counter);

    // Update neighbors if needed
    if (west_dirty) {
        if (self.getChunk(.{ .x = chunk_pos.x - 1, .z = chunk_pos.z })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    }
    if (east_dirty) {
        if (self.getChunk(.{ .x = chunk_pos.x + 1, .z = chunk_pos.z })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    }
    if (north_dirty) {
        if (self.getChunk(.{ .x = chunk_pos.x, .z = chunk_pos.z - 1 })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    }
    if (south_dirty) {
        if (self.getChunk(.{ .x = chunk_pos.x, .z = chunk_pos.z + 1 })) |neighbor|
            neighbor.markDirtiness(&self.dirty_priority_counter);
    }
}

/// Set a block ID at coordinates, fails if the chunk isn't loaded
pub fn setBlockIdAndMetadata(self: *World, pos: coord.Block, block_id: u8, block_meta: u4) !void {
    const chunk_pos = pos.getChunk();
    const chunk = self.getChunk(chunk_pos) orelse return error.ChunkNotLoaded;
    const pos_in_chunk = pos.getPosInChunk();

    std.debug.assert(pos_in_chunk.isWithinChunk());

    chunk.setBlockIdAndMetadata(pos_in_chunk, block_id, block_meta);

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

// TODO: move elsewhere
const PendingModeling = struct {
    priority: usize,
    coords: coord.Chunk,
    request_time: i64,

    fn lessThan(context: void, a: PendingModeling, b: PendingModeling) bool {
        _ = context;
        return a.priority < b.priority;
    }
};

/// Updates a single chunk's model if it is marked as dirty
/// Returns true if a model was updated
pub fn updateModels(self: *World) !void {
    var it = self.chunk_list.iterator();

    var buf: [8]PendingModeling = undefined;
    var pending_arraylist = std.ArrayList(PendingModeling).initBuffer(&buf);

    const time = self.game.time.load(.unordered);

    // Find dirty chunks
    while (it.next()) |entry| {
        const chunk = entry.value_ptr.*;
        if (chunk.model_dirty > 0) {
            // Add chunks to model to list
            pending_arraylist.appendBounded(.{
                .coords = chunk.coords,
                .priority = chunk.model_dirty,
                .request_time = time,
            }) catch break;

            // Unset flag
            chunk.model_dirty = 0;
        }
    }

    // Sort list
    // TODO: check if the ordering is right (it seems spawn uses prepend and worker uses pop-first)
    std.sort.insertion(PendingModeling, pending_arraylist.items, {}, PendingModeling.lessThan);

    // Add tasks to pool
    for (pending_arraylist.items) |pending| {
        // Add to work queue
        if (self.getChunk(pending.coords)) |chunk|
            try self.modeling_thread_pool.spawn(Chunk.updateModel, .{ chunk, self.alloc });
    }

    // Call finalize on chunks that need it
    {
        self.meshes_mutex.lock();
        defer self.meshes_mutex.unlock();

        it = self.chunk_list.iterator();
        while (it.next()) |entry| {
            const chunk = entry.value_ptr.*;
            if (!chunk.model_finalized) {
                if (chunk.model) |*model| {
                    try model.finalize();
                }
                chunk.model_finalized = true;
            }
        }
    }
}

/// Gets a block id at coordinates, returns 0 if the chunk isn't loaded
pub fn getBlockId(self: *World, pos: coord.Block) u8 {
    const chunk_pos = pos.getChunk();
    const chunk = self.getChunk(chunk_pos) orelse return 0;
    const pos_in_chunk = pos.getPosInChunk();

    if (pos.y < 0 or pos.y >= 128)
        return 0;

    std.debug.assert(pos_in_chunk.isWithinChunk());
    return chunk.getBlockId(pos_in_chunk);
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
    self.modeling_thread_pool.deinit();
    self.alloc.destroy(self.modeling_thread_pool);

    var it = self.chunk_list.iterator();
    // Destroy all contained chunks
    while (it.next()) |entry| {
        entry.value_ptr.*.destroyChunk(self.alloc);
    }
    self.chunk_list.deinit();
}

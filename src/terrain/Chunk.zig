//! A single chunk

const std = @import("std");
const coord = @import("coord");
const io = @import("io");
const blocks = @import("blocks");
const tracy = @import("tracy");
const LightLevel = @import("light_level.zig").LightLevel;
const World = @import("World.zig");
const Context = @import("Context.zig");

const Chunk = @This();

pub const width = 16;
pub const height = 128;

pub const block_data_len = (height * width * width);

world: *World,
coords: coord.Chunk,
blocks_data: []u8,
metadata: []u8,
blocklight: []u8,
skylight: []u8,
model: ?io.ChunkModel,
/// ~~Flag~~ Value indicating if the model is up to date or not
/// Used to be a boolean, is now a value: 0 means not dirty, anything else means dirty
/// With the lowest value being the highest priority
model_dirty: u64,

pub fn initEmpty(world: *World, alloc: std.mem.Allocator, coords: coord.Chunk) !*Chunk {
    // Unimplemented
    const ret = try alloc.create(Chunk);
    errdefer alloc.destroy(ret);

    ret.* = .{
        .world = world,
        .coords = coords,
        .blocks_data = undefined,
        .metadata = undefined,
        .blocklight = undefined,
        .skylight = undefined,
        .model = null,
        .model_dirty = 0,
    };

    ret.blocks_data = try alloc.alloc(u8, block_data_len);
    errdefer alloc.free(ret.blocks_data);

    ret.metadata = try alloc.alloc(u8, block_data_len / 2);
    errdefer alloc.free(ret.metadata);

    ret.blocklight = try alloc.alloc(u8, block_data_len / 2);
    errdefer alloc.free(ret.blocklight);

    ret.skylight = try alloc.alloc(u8, block_data_len / 2);
    errdefer alloc.free(ret.skylight);

    // Fill with zeros
    for (0..block_data_len) |i| {
        ret.blocks_data[i] = 0;
        if (i < block_data_len / 2) {
            ret.metadata[i] = 0;
            ret.blocklight[i] = 0;
            ret.skylight[i] = 0;
        }
    }

    return ret;
}

// TODO: Understand better the memory layout of data, and also, is a chunk only 128 blocks high?
pub fn setChunkData(self: *Chunk, data: []const u8, x1: i32, y1: i32, z1: i32, x2: i32, y2: i32, z2: i32) []const u8 {
    var remaining = data;

    //const dx = @abs(x2 - x1);
    const dy = @abs(y2 - y1);
    //const dz = @abs(z2 - z1);

    // Block ids (Copy each vertical slice)
    var x = x1;
    while (x < x2) : (x += 1) {
        var z = z1;
        while (z < z2) : (z += 1) {
            const dest_offset: u32 = @bitCast(x << 11 | z << 7 | y1);
            @memcpy(self.blocks_data[dest_offset..(dest_offset + dy)], remaining[0..dy]);
            remaining = remaining[dy..];
        }
    }

    // Block metadata
    x = x1;
    while (x < x2) : (x += 1) {
        var z = z1;
        while (z < z2) : (z += 1) {
            const dest_offset: u32 = @as(u32, @bitCast(x << 11 | z << 7 | y1)) / 2;
            @memcpy(self.metadata[dest_offset..(dest_offset + (dy / 2))], remaining[0..(dy / 2)]);
            remaining = remaining[(dy / 2)..];
        }
    }

    // Block light
    x = x1;
    while (x < x2) : (x += 1) {
        var z = z1;
        while (z < z2) : (z += 1) {
            const dest_offset: u32 = @as(u32, @bitCast(x << 11 | z << 7 | y1)) / 2;
            @memcpy(self.blocklight[dest_offset..(dest_offset + (dy / 2))], remaining[0..(dy / 2)]);
            remaining = remaining[(dy / 2)..];
        }
    }

    // Sky light
    x = x1;
    while (x < x2) : (x += 1) {
        var z = z1;
        while (z < z2) : (z += 1) {
            const dest_offset: u32 = @as(u32, @bitCast(x << 11 | z << 7 | y1)) / 2;
            @memcpy(self.skylight[dest_offset..(dest_offset + (dy / 2))], remaining[0..(dy / 2)]);
            remaining = remaining[(dy / 2)..];
        }
    }

    return remaining;
}

pub fn destroyChunk(self: *Chunk, alloc: std.mem.Allocator) void {
    self.deinit(alloc);
    if (self.model) |model|
        model.deinit(alloc);
    alloc.destroy(self);
}

/// Sets the flag that the model must be updated
pub inline fn markDirtiness(self: *Chunk, counter: *usize) void {
    self.model_dirty = counter.*;
    counter.* +|= 1;
}

pub fn updateModel(self: *Chunk, alloc: std.mem.Allocator) !void {
    // TODO: only update one model per frame/tick to avoid spike lags
    if (self.model) |old_model|
        old_model.deinit(alloc);

    const zone = tracy.Zone.begin(.{
        .name = "Chunk meshing",
        .src = @src(),
        .color = .yellow,
    });
    defer zone.end();

    self.model = try io.ChunkModel.generateForChunk(alloc, self.*);
    self.model_dirty = 0;
}

pub fn deinit(self: Chunk, alloc: std.mem.Allocator) void {
    alloc.free(self.blocks_data);
    alloc.free(self.metadata);
    alloc.free(self.blocklight);
    alloc.free(self.skylight);
}

/// Get block id or 0 if the local coordinates are outside of the chunk
/// The position is within the chunk, not global coordinates
pub fn getBlockId(self: Chunk, pos: coord.Block) u8 {
    if (!pos.isWithinChunk())
        return 0;
    const index = indexFromCoord(pos);
    return self.blocks_data[index];
}

/// Get block id within the chunk, or from a neighbor chunk, transcending chunk boundaries
/// If the coordinates are for a neighbor that isn't loaded, this returns 0
/// The position is in the chunk's coordiante space within, not global coordinates
pub fn getBlockIdTranscend(self: Chunk, pos: coord.Block) u8 {
    if (pos.isWithinChunk()) {
        // Local block
        const index = indexFromCoord(pos);
        return self.blocks_data[index];
    } else {
        // Neighbor block
        // Relative chunk position
        const chunk_rel = pos.getChunk();
        // TODO: vector math helpers for concise code
        var other_chunk_pos = self.coords;
        other_chunk_pos.x += chunk_rel.x;
        other_chunk_pos.z += chunk_rel.z;

        if (self.world.getChunk(other_chunk_pos)) |other_chunk| {
            return other_chunk.getBlockId(pos.getPosInChunk());
        } else {
            // Neigbor not loaded
            return 0;
        }
    }
}

/// Set a block ID and metadat within the chunk
pub fn setBlockIdAndMetadata(self: *Chunk, pos: coord.Block, block_id: u8, block_meta: u4) void {
    std.debug.assert(pos.isWithinChunk());

    const index = indexFromCoord(pos);

    self.blocks_data[index] = block_id;

    var meta = self.metadata[index / 2];
    if (index % 2 == 0) {
        meta &= 0x0f;
        meta |= @as(u8, block_meta) << 4;
    } else {
        meta &= 0xf0;
        meta |= @as(u8, block_meta);
    }
    self.metadata[index / 2] = meta;
}

/// Get block lighting levels
pub fn getLight(self: Chunk, pos: coord.Block) LightLevel {
    if (!pos.isWithinChunk())
        return .{ .blocklight = 0, .skylight = 15 };

    const index = indexFromCoord(pos);
    const blocklight = self.blocklight[index / 2];
    const skylight = self.skylight[index / 2];
    if (index % 2 == 0) {
        return .{
            .blocklight = @intCast(blocklight & 0x0f),
            .skylight = @intCast(skylight & 0x0f),
        };
    } else {
        return .{
            .blocklight = @intCast((blocklight & 0xf0) >> 4),
            .skylight = @intCast((skylight & 0xf0) >> 4),
        };
    }
}

/// Get block lighting levels within the chunk, or from a neighbor chunk, transcending chunk boundaries
/// If the coordinates are for a neighbor that isn't loaded, this returns a default value
/// The position is in the chunk's coordiante space within, not global coordinates
pub fn getLightTranscend(self: Chunk, pos: coord.Block) LightLevel {
    if (pos.isWithinChunk()) {
        // Local block
        return self.getLight(pos);
    } else {
        // Neighbor block
        // Relative chunk position
        const chunk_rel = pos.getChunk();
        const other_chunk_pos = self.coords.add(chunk_rel);

        if (self.world.getChunk(other_chunk_pos)) |other_chunk| {
            return other_chunk.getLight(pos.getPosInChunk());
        } else {
            // Neigbor not loaded
            return .{ .blocklight = 0, .skylight = 15 };
        }
    }
}

/// Get block metadata
pub fn getBlockMeta(self: Chunk, pos: coord.Block) u4 {
    if (!pos.isWithinChunk())
        return 0;
    const index = indexFromCoord(pos);
    const val = self.metadata[index / 2];
    if (index % 2 == 0) {
        return @intCast(val & 0x0f);
    } else {
        return @intCast((val & 0xf0) >> 4);
    }
}

pub fn getContext(self: Chunk, pos: coord.Block) Context {
    const zone = tracy.Zone.begin(.{
        .name = "Get context",
        .src = @src(),
        .color = .dark_red,
    });
    defer zone.end();

    const block_n = blocks.table[getBlockIdTranscend(self, pos.neighbor(.north))];
    const block_e = blocks.table[getBlockIdTranscend(self, pos.neighbor(.east))];
    const block_s = blocks.table[getBlockIdTranscend(self, pos.neighbor(.south))];
    const block_w = blocks.table[getBlockIdTranscend(self, pos.neighbor(.west))];
    const block_u = blocks.table[getBlockId(self, pos.neighbor(.up))];
    const block_d = blocks.table[getBlockId(self, pos.neighbor(.down))];

    return .{
        .light_levels = .{
            .self = .{ .blocklight = 0, .skylight = 0 },
            .north = .{ .blocklight = 0, .skylight = 0 },
            .east = .{ .blocklight = 0, .skylight = 0 },
            .south = .{ .blocklight = 0, .skylight = 0 },
            .west = .{ .blocklight = 0, .skylight = 0 },
            .up = .{ .blocklight = 0, .skylight = 0 },
            .down = .{ .blocklight = 0, .skylight = 0 },
        },
        .occlusion = .{
            .north = block_n.isFull() and !block_n.flags.transparent,
            .east = block_e.isFull() and !block_e.flags.transparent,
            .south = block_s.isFull() and !block_s.flags.transparent,
            .west = block_w.isFull() and !block_w.flags.transparent,
            .up = block_u.isFull() and !block_u.flags.transparent,
            .down = block_d.isFull() and !block_d.flags.transparent,
        },
    };
}

/// Pass an index of the blocks array, get the corresponding block coords
pub inline fn coordFromIndex(index: usize) coord.Block {
    const i: i32 = @intCast(index);
    return .{
        .x = @divFloor(i, 128 * 16),
        .y = @mod(i, 128),
        .z = @mod(@divFloor(i, 128), 16),
    };
}

/// Pass a set of coordinates that is withing the chunk, get the offset of that block in the blocks array
pub inline fn indexFromCoord(coords: coord.Block) usize {
    std.debug.assert(coords.isWithinChunk());

    return @intCast(coords.y + coords.x * 128 * 16 + coords.z * 128);
}

test "coords from index from coords" {
    var rng = std.Random.DefaultPrng.init(@intCast(std.testing.random_seed));
    const random = rng.random();

    const in = coord.Block{
        .x = random.intRangeLessThan(i32, 0, 16),
        .y = random.intRangeLessThan(i32, 0, 128),
        .z = random.intRangeLessThan(i32, 0, 16),
    };

    const index = indexFromCoord(in);

    const out = coordFromIndex(index);

    try std.testing.expectEqualDeep(in, out);
}

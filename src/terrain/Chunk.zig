//! A single chunk

const std = @import("std");
const coord = @import("coord");
const io = @import("io");
const blocks = @import("blocks");
const tracy = @import("tracy");

const Chunk = @This();

pub const width = 16;
pub const height = 128;

pub const block_data_len = (height * width * width);

coords: coord.Chunk,
blocks_data: []u8,
model: ?io.ChunkModel,

pub fn initEmpty(alloc: std.mem.Allocator, coords: coord.Chunk) !*Chunk {
    // Unimplemented
    const ret = try alloc.create(Chunk);
    errdefer alloc.destroy(ret);

    ret.* = .{
        .coords = coords,
        .blocks_data = try alloc.alloc(u8, block_data_len),
        .model = null,
    };

    // Fill with zeros
    for (ret.blocks_data) |*bl| {
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
            @memcpy(self.blocks_data[dest_offset..(dest_offset + dy)], remaining[0..dy]);
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

    const zone = tracy.Zone.begin(.{
        .name = "Chunk meshing",
        .src = @src(),
        .color = .yellow,
    });
    defer zone.end();

    self.model = try io.ChunkModel.generateForChunk(alloc, self.*);
}

pub fn deinit(self: Chunk, alloc: std.mem.Allocator) void {
    alloc.free(self.blocks_data);
}

pub fn getBlockId(self: Chunk, pos: coord.Block) u8 {
    const zone = tracy.Zone.begin(.{
        .name = "Get block",
        .src = @src(),
        .color = .pink1,
    });
    defer zone.end();

    if (!pos.isWithinChunk())
        return 0;
    const index = indexFromCoord(pos);
    return self.blocks_data[index];
}

pub fn setBlockId(self: *Chunk, pos: coord.Block, block_id: u8) void {
    std.debug.assert(pos.isWithinChunk());

    const index = indexFromCoord(pos);
    self.blocks_data[index] = block_id;
}

pub fn getContext(self: Chunk, pos: coord.Block) blocks.Context {
    const zone = tracy.Zone.begin(.{
        .name = "Get context",
        .src = @src(),
        .color = .pink,
    });
    defer zone.end();

    return .{
        .north = !blocks.table[getBlockId(self, pos.neighbor(.north))].full_block,
        .east = !blocks.table[getBlockId(self, pos.neighbor(.east))].full_block,
        .south = !blocks.table[getBlockId(self, pos.neighbor(.south))].full_block,
        .west = !blocks.table[getBlockId(self, pos.neighbor(.west))].full_block,
        .up = !blocks.table[getBlockId(self, pos.neighbor(.up))].full_block,
        .down = !blocks.table[getBlockId(self, pos.neighbor(.down))].full_block,
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

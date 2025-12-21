//! A chunk's visual representation
//! This is specific to the IO and can be modified independently of the chunk's actual representation

const std = @import("std");
const rl = @import("raylib");
const coord = @import("coord");
const Chunk = @import("terrain").Chunk;

const ChunkModel = @This();

// TEMPORARY for debug
var col_rand: ?std.Random.DefaultPrng = null;
color: rl.Color,
// just a prototyping version where the chunk is just drawn block by block based on data
data: []const u8,

pub fn generateForChunk(alloc: std.mem.Allocator, chunk: *Chunk) !ChunkModel {
    if (col_rand == null) {
        col_rand = std.Random.DefaultPrng.init(42);
    }

    return .{
        .color = .fromInt(col_rand.?.random().int(u32) | 0xff),
        .data = try alloc.dupe(u8, chunk.blocks),
    };
}

pub fn draw(self: ChunkModel, pos: coord.Chunk) void {
    rl.drawCubeWires(.{ .x = @floatFromInt(pos.x * 16 + 8), .y = 128, .z = @floatFromInt(pos.z * 16 + 8) }, 16, 256, 16, .red);
    rl.drawPlane(.{ .x = @floatFromInt(pos.x * 16 + 8), .y = 0, .z = @floatFromInt(pos.z * 16 + 8) }, .{ .x = 16, .y = 16 }, self.color);

    // Draw cubes the wrong way
    for (self.data, 0..) |id, i| {
        const y: i32 = @intCast(i % 256);
        const x: i32 = @intCast(i / 256 % 16);
        const z: i32 = @intCast(i / (256 * 16));

        if (id == 0)
            continue;

        rl.drawCube(
            .{ .x = @as(f32, @floatFromInt(x + pos.x * 16)) + 0.5, .y = @as(f32, @floatFromInt(y)) + 0.5, .z = @as(f32, @floatFromInt(z + pos.z * 16)) + 0.5 },
            1,
            1,
            1,
            .init(id, id, id, 255),
        );
    }
}

pub fn deinit(self: ChunkModel, alloc: std.mem.Allocator) void {
    alloc.free(self.data);
}

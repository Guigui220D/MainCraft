//! A chunk's visual representation

const std = @import("std");
const rl = @import("raylib");
const coord = @import("coord");
const Chunk = @import("terrain").Chunk;

const ChunkModel = @This();

// TEMPORARY for debug
var col_rand: ?std.Random.DefaultPrng = null;
color: rl.Color,

pub fn generateForChunk(chunk: *Chunk) !ChunkModel {
    if (col_rand == null) {
        col_rand = std.Random.DefaultPrng.init(42);
    }

    _ = chunk;
    return .{
        .color = .fromInt(col_rand.?.random().int(u32) | 0xff),
    };
}

pub fn draw(self: ChunkModel, pos: coord.Chunk) void {
    rl.drawCubeWires(.{ .x = @floatFromInt(pos.x * 16 + 8), .y = 128, .z = @floatFromInt(pos.z * 16 + 8) }, 16, 256, 16, .red);
    rl.drawPlane(.{ .x = @floatFromInt(pos.x * 16 + 8), .y = 0, .z = @floatFromInt(pos.z * 16 + 8) }, .{ .x = 16, .y = 16 }, self.color);
}

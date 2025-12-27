//! 18 * 18 * 128 bitfield to cache what blocks are opaque or not

const std = @import("std");
const tracy = @import("tracy");
const coord = @import("coord");
const Context = @import("blocks").Context;

const OpacityCache = @This();

// Bit set means opaque block
bitfield: [18][18]u128,

pub fn isOpaque(self: OpacityCache, coords: coord.Block) bool {
    if (coords.y < 0)
        return true; // Avoids rendering bottom of bedrock
    if (coords.y > 128)
        return false;

    const bit_column = self.bitfield[@intCast(coords.x + 1)][@intCast(coords.z + 1)];
    const mask = @as(u128, 1) << @as(u7, @intCast(coords.y));

    return (bit_column & mask) != 0;
}

pub fn getContext(self: OpacityCache, coords: coord.Block) Context {
    std.debug.assert(coords.isWithinChunk());

    const zone = tracy.Zone.begin(.{
        .name = "Get context new",
        .src = @src(),
        .color = .pink,
    });
    defer zone.end();

    return .{
        .north = !isOpaque(self, coords.north()),
        .east = !isOpaque(self, coords.east()),
        .south = !isOpaque(self, coords.south()),
        .west = !isOpaque(self, coords.west()),
        .up = !isOpaque(self, coords.up()),
        .down = !isOpaque(self, coords.down()),
    };
}

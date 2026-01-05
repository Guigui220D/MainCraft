//! Helpers for terrain coloring

const std = @import("std");
const io = @import("io");

const blocks = @import("blocks.zig");
const Context = @import("terrain").Context;

/// The higher this is, the less impact light levels have on blocks
const lighting_adjustment = 3;

// TODO: based on biome
const grass_color: u32 = 0xff44bb44;
const foliage_color: u32 = 0xff449944;
const default_color: u32 = 0xffffffff;

/// Write the vertex colors depending on the context and block id
pub fn writeColors(arraylist: *std.ArrayList(u32), context: Context.Occlusion, vertex_count: usize, block_id: u8) void {
    switch (block_id) {
        // TODO: way to get block ids by names
        2 => { // Grass
            if (context.up) {
                arraylist.appendNTimesAssumeCapacity(default_color, vertex_count);
            } else {
                if (!context.north)
                    arraylist.appendNTimesAssumeCapacity(default_color, 4);
                if (!context.east)
                    arraylist.appendNTimesAssumeCapacity(default_color, 4);
                if (!context.south)
                    arraylist.appendNTimesAssumeCapacity(default_color, 4);
                if (!context.west)
                    arraylist.appendNTimesAssumeCapacity(default_color, 4);
                // up
                arraylist.appendNTimesAssumeCapacity(grass_color, 4);
                if (!context.down)
                    arraylist.appendNTimesAssumeCapacity(default_color, 4);
            }
        },
        18, 31 => { // Leaves, Tallgrass
            arraylist.appendNTimesAssumeCapacity(foliage_color, vertex_count);
        },
        else => arraylist.appendNTimesAssumeCapacity(default_color, vertex_count),
    }
}

/// Apply light level to color
pub fn adjustColors(colors: []u8, blocklight: u4, skylight: u4, _: Context) void {
    for (colors, 0..) |*col, i| {
        if (i % 4 == 3)
            continue;

        // TODO: consider each face

        const total_light = blocklight +| skylight +| lighting_adjustment;

        var temp: u32 = col.*;
        temp *= total_light;
        temp /= 15 + lighting_adjustment;
        col.* = @intCast(temp);
    }
}

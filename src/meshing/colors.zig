//! Helpers for terrain coloring

const std = @import("std");
const io = @import("io");
const tracy = @import("tracy");

const blocks = @import("blocks");
const Context = @import("terrain").Context;
const coord = @import("coord");

const meshing = @import("meshing.zig");

/// The higher this is, the less impact light levels have on blocks
const lighting_adjustment = 2;

// TODO: based on biome
const grass_color: u32 = 0xff44bb44;
const foliage_color: u32 = 0xff449944;
const default_color: u32 = 0xffffffff;

/// Write the vertex colors depending on the context and block id
pub fn writeColors(arraylist: *std.ArrayList(u32), context: Context.Occlusion, vertex_count: usize, block_id: u8) void {
    const zone = tracy.Zone.begin(.{
        .name = "Write colors",
        .src = @src(),
        .color = .green4,
    });
    defer zone.end();

    switch (block_id) {
        @intFromEnum(blocks.blocks_enum.grass) => {
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
        @intFromEnum(blocks.blocks_enum.leaves),
        @intFromEnum(blocks.blocks_enum.tallgrass),
        => {
            arraylist.appendNTimesAssumeCapacity(foliage_color, vertex_count);
        },
        else => arraylist.appendNTimesAssumeCapacity(default_color, vertex_count),
    }
}

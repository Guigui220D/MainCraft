//! Helpers for terrain UV related stuff

const std = @import("std");
const io = @import("io");

const blocks = @import("blocks.zig");
const Context = @import("context.zig").Context;

// The atlas has (atlas_size*atlas_size) textures
pub const atlas_size = 16;

/// Gets the texture coordinates for an ID of the terrain.png atlas
pub fn getTerrainUV(texture_id: u8, comptime reversed: bool) [8]f32 {
    const tx: f32 = @as(f32, @floatFromInt(texture_id % atlas_size));
    const ty: f32 = @as(f32, @floatFromInt(texture_id / atlas_size));
    const divide: f32 = if (io.properties.normalized_uvs) atlas_size else 1;

    if (reversed) {
        return [8]f32{
            (0.0 + tx) / divide, (1.0 + ty) / divide,
            (1.0 + tx) / divide, (1.0 + ty) / divide,
            (1.0 + tx) / divide, (0.0 + ty) / divide,
            (0.0 + tx) / divide, (0.0 + ty) / divide,
        };
    } else {
        return [8]f32{
            (1.0 + tx) / divide, (1.0 + ty) / divide,
            (0.0 + tx) / divide, (1.0 + ty) / divide,
            (0.0 + tx) / divide, (0.0 + ty) / divide,
            (1.0 + tx) / divide, (0.0 + ty) / divide,
        };
    }
}

pub const UvType = enum {
    basic, // Blocks with the same texture on each side
    barrel, // Blocks with a top, side, and bottom
    advanced, // Blocks with specific textures for each side
};

/// Write the right UV depending on the context and block id
/// Assumes there is enough space left in the arraylist ((6 or 3) * face_count) depending of if using 2 tris or 1 quad per face
pub fn writeUV(arraylist: *std.ArrayList(f32), context: Context, block_id: u8) void {
    const block = &blocks.table[block_id];
    switch (block.uv_type) {
        .basic => writeBasicUV(arraylist, context, block.tex_id),
        .barrel => writeBarrelUV(arraylist, context, block.tex_id, block.top_tex_id, block.bottom_tex_id),
        .advanced => writeAdvancedUV(arraylist, context, block.tex_id, block.east_tex_id, block.south_tex_id, block.west_tex_id, block.top_tex_id, block.bottom_tex_id),
    }
}

/// Write uv for the default basic scenario of blocks
fn writeBasicUV(arraylist: *std.ArrayList(f32), context: Context, tex_id: u8) void {
    const face_count = context.faceCount();
    const has_bottom = context.down;

    var tex_coords = getTerrainUV(tex_id, false);
    for (0..(face_count - @intFromBool(has_bottom))) |_| {
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }

    // Necessary otherwise you get a mirrored bottom face
    if (has_bottom) {
        tex_coords = getTerrainUV(tex_id, true);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
}

/// Write uv for barrel-like blocks
fn writeBarrelUV(arraylist: *std.ArrayList(f32), context: Context, side_tex_id: u8, top_tex_id: u8, bottom_tex_id: u8) void {
    const side_tex_coords = getTerrainUV(side_tex_id, false);

    if (context.north)
        arraylist.appendSliceAssumeCapacity(&side_tex_coords);
    if (context.east)
        arraylist.appendSliceAssumeCapacity(&side_tex_coords);
    if (context.south)
        arraylist.appendSliceAssumeCapacity(&side_tex_coords);
    if (context.west)
        arraylist.appendSliceAssumeCapacity(&side_tex_coords);
    if (context.up) {
        const top_tex_coords = getTerrainUV(top_tex_id, false);
        arraylist.appendSliceAssumeCapacity(&top_tex_coords);
    }
    if (context.down) {
        const bottom_tex_coords = getTerrainUV(bottom_tex_id, true);
        arraylist.appendSliceAssumeCapacity(&bottom_tex_coords);
    }
}

/// Write uv for barrel-like blocks
fn writeAdvancedUV(arraylist: *std.ArrayList(f32), context: Context, north_tex_id: u8, east_tex_id: u8, south_tex_id: u8, west_tex_id: u8, top_tex_id: u8, bottom_tex_id: u8) void {
    if (context.north) {
        const tex_coords = getTerrainUV(north_tex_id, false);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
    if (context.east) {
        const tex_coords = getTerrainUV(east_tex_id, false);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
    if (context.south) {
        const tex_coords = getTerrainUV(south_tex_id, false);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
    if (context.west) {
        const tex_coords = getTerrainUV(west_tex_id, false);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
    if (context.up) {
        const tex_coords = getTerrainUV(top_tex_id, false);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
    if (context.down) {
        const tex_coords = getTerrainUV(bottom_tex_id, true);
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
}

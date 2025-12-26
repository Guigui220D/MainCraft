//! Functions to generate block models

const std = @import("std");
const coord = @import("coord");
const io = @import("io");

const VertexIdT = io.properties.VertexIdT;

const uv = @import("uv.zig");
const Context = @import("context.zig").Context;

/// Enumeration of all block models
pub const BlockModel = enum {
    full,
    slab,
    plant,

    // and others...
};

/// Returns the number of vertices the block will use in that specific context
pub inline fn vertexCount(model: BlockModel, context: Context) usize {
    return faceCount(model, context) * 4;
}

/// Returns the number of faces the block will use in that specific context
pub inline fn faceCount(model: BlockModel, context: Context) usize {
    return switch (model) {
        .full => cubeFaceCount(context),
        .slab => slabFaceCount(context),
        .plant => plant_face_count,
    };
}

/// Writes the vertices of the selected model in the given context
/// The amount of vertices written is equal to the vertexCount() of the same model and context
/// Assumes there is enough space left in the arraylist
pub inline fn writeVertices(arraylist: *std.ArrayList(f32), model: BlockModel, coords: coord.Block, context: Context) void {
    const x = coords.x;
    const y = coords.y;
    const z = coords.z;
    switch (model) {
        .full => writeCubeVertices(arraylist, x, y, z, context),
        //.slab => writeSlabVertices(writer, x, y, z, context),
        .slab => unreachable,
        //.plant => writePlantVertices(writer, x, y, z),
        .plant => unreachable,
    }
}

/// Write vertex indices for faces to the arraylist
/// Assumes there is enough space left in the arraylist ((6 or 3) * face_count) depending of if using 2 tris or 1 quad per face
pub fn materializeFaces(arraylist: *std.ArrayList(VertexIdT), face_count: VertexIdT, index_offset: VertexIdT, comptime quad_mode: bool) void {
    // Check the vertex index type can fit that many
    std.debug.assert(index_offset < std.math.maxInt(VertexIdT) - (face_count * 4));

    var id_off = index_offset;
    if (quad_mode) {
        // Quads
        for (0..face_count) |_| {
            arraylist.appendSliceAssumeCapacity(&.{
                0 + id_off, 1 + id_off, 2 + id_off, 3 + id_off, // Untested
            });
            id_off += 4;
        }
    } else {
        // Tris
        for (0..face_count) |_| {
            arraylist.appendSliceAssumeCapacity(&.{
                0 + id_off, 2 + id_off, 1 + id_off,
                0 + id_off, 3 + id_off, 2 + id_off,
            });
            id_off += 4;
        }
    }
}

/// Write uv for the default basic scnario of blocks
/// Assumes there is enough space left in the arraylist ((6 or 3) * face_count) depending of if using 2 tris or 1 quad per face
pub fn writeDefaultUv(arraylist: *std.ArrayList(f32), face_count: usize, tex_id: u8) void {
    const tex_coords = uv.getTerrainUV(tex_id);
    for (0..face_count) |_| {
        arraylist.appendSliceAssumeCapacity(&tex_coords);
    }
}

fn cubeFaceCount(context: Context) usize {
    var ret: usize = 0;
    if (context.north)
        ret += 1;
    if (context.east)
        ret += 1;
    if (context.south)
        ret += 1;
    if (context.west)
        ret += 1;
    if (context.up)
        ret += 1;
    if (context.down)
        ret += 1;
    return ret;
}

fn writeCubeVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32, context: Context) void {
    const x1: f32 = @floatFromInt(x + 0);
    const x2: f32 = @floatFromInt(x + 1);
    const y1: f32 = @floatFromInt(y + 0);
    const y2: f32 = @floatFromInt(y + 1);
    const z1: f32 = @floatFromInt(z + 0);
    const z2: f32 = @floatFromInt(z + 1);
    if (context.north)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z1,
            x2, y1, z1,
            x2, y2, z1,
            x1, y2, z1,
        });
    if (context.east)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z1,
            x2, y1, z2,
            x2, y2, z2,
            x2, y2, z1,
        });
    if (context.south)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z2,
            x1, y1, z2,
            x1, y2, z2,
            x2, y2, z2,
        });
    if (context.west)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x1, y1, z1,
            x1, y2, z1,
            x1, y2, z2,
        });
    // TODO: check texture orientation for top/bottom textures
    if (context.up)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y2, z1,
            x2, y2, z1,
            x2, y2, z2,
            x1, y2, z2,
        });
    if (context.down)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z1,
            x1, y1, z2,
            x2, y1, z2,
            x2, y1, z1,
        });
}

fn slabFaceCount(context: Context) usize {
    // Top face always renders
    var ret: usize = 1;
    if (context.north)
        ret += 1;
    if (context.east)
        ret += 1;
    if (context.south)
        ret += 1;
    if (context.west)
        ret += 1;
    if (context.down)
        ret += 1;
    return ret;
}

const plant_face_count = 2;

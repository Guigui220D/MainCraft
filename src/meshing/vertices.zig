//! Functions to generate block models

const std = @import("std");
const coord = @import("coord");
const io = @import("io");
const tracy = @import("tracy");

const VertexIdT = io.properties.VertexIdT;

const uv = @import("uv.zig");
const Context = @import("terrain").Context;

const BlockModel = @import("blocks").BlockModel;

/// Returns the number of vertices the block will use in that specific context
pub inline fn vertexCount(model: BlockModel, context: Context.Occlusion) usize {
    return faceCount(model, context) * 4;
}

/// Returns the number of faces the block will use in that specific context
pub inline fn faceCount(model: BlockModel, context: Context.Occlusion) usize {
    return switch (model) {
        .full_basic, .full_barrel, .full_advanced => context.faceCount(),
        .slab => slabFaceCount(context),
        .plant => plant_face_count,
        .cactus => cactusFaceCount(context),
        .liquid_still => liquid_still_face_count,
        .snow_layer => slabFaceCount(context),
    };
}

/// Writes the vertices of the selected model in the given context
/// The amount of vertices written is equal to the vertexCount() of the same model and context
/// Assumes there is enough space left in the arraylist
pub inline fn writeVertices(arraylist: *std.ArrayList(f32), model: BlockModel, coords: coord.Block, context: Context.Occlusion) void {
    const zone = tracy.Zone.begin(.{
        .name = "Write vertices",
        .src = @src(),
        .color = .green1,
    });
    defer zone.end();

    const x = coords.x;
    const y = coords.y;
    const z = coords.z;
    switch (model) {
        .full_basic, .full_barrel, .full_advanced => writeCubeVertices(arraylist, x, y, z, context),
        .slab => writeSlabVertices(arraylist, x, y, z, context),
        .plant => writePlantVertices(arraylist, x, y, z),
        .cactus => writeCactusVertices(arraylist, x, y, z, context),
        .liquid_still => writeLiquidStillVertices(arraylist, x, y, z),
        .snow_layer => writeSnowVertices(arraylist, x, y, z, context),
    }
}

/// Write vertex indices for faces to the arraylist
/// Assumes there is enough space left in the arraylist ((6 or 3) * face_count) depending of if using 2 tris or 1 quad per face
pub fn materializeFaces(arraylist: *std.ArrayList(VertexIdT), face_count: VertexIdT, index_offset: VertexIdT, comptime quad_mode: bool) void {
    const zone = tracy.Zone.begin(.{
        .name = "Materialize faces",
        .src = @src(),
        .color = .green2,
    });
    defer zone.end();

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

fn writeCubeVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32, context: Context.Occlusion) void {
    const x1: f32 = @floatFromInt(x + 0);
    const x2: f32 = @floatFromInt(x + 1);
    const y1: f32 = @floatFromInt(y + 0);
    const y2: f32 = @floatFromInt(y + 1);
    const z1: f32 = @floatFromInt(z + 0);
    const z2: f32 = @floatFromInt(z + 1);
    if (!context.north)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z1,
            x2, y1, z1,
            x2, y2, z1,
            x1, y2, z1,
        });
    if (!context.east)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z1,
            x2, y1, z2,
            x2, y2, z2,
            x2, y2, z1,
        });
    if (!context.south)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z2,
            x1, y1, z2,
            x1, y2, z2,
            x2, y2, z2,
        });
    if (!context.west)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x1, y1, z1,
            x1, y2, z1,
            x1, y2, z2,
        });
    if (!context.up)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y2, z2,
            x1, y2, z2,
            x1, y2, z1,
            x2, y2, z1,
        });
    if (!context.down)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x2, y1, z2,
            x2, y1, z1,
            x1, y1, z1,
        });
}

fn writeSlabVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32, context: Context.Occlusion) void {
    const x1: f32 = @floatFromInt(x + 0);
    const x2: f32 = @floatFromInt(x + 1);
    const y1: f32 = @floatFromInt(y + 0);
    const y2: f32 = @as(f32, @floatFromInt(y)) + 0.5;
    const z1: f32 = @floatFromInt(z + 0);
    const z2: f32 = @floatFromInt(z + 1);
    if (!context.north)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z1,
            x2, y1, z1,
            x2, y2, z1,
            x1, y2, z1,
        });
    if (!context.east)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z1,
            x2, y1, z2,
            x2, y2, z2,
            x2, y2, z1,
        });
    if (!context.south)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z2,
            x1, y1, z2,
            x1, y2, z2,
            x2, y2, z2,
        });
    if (!context.west)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x1, y1, z1,
            x1, y2, z1,
            x1, y2, z2,
        });
    // if (!context.up)
    arraylist.appendSliceAssumeCapacity(&.{
        x2, y2, z2,
        x1, y2, z2,
        x1, y2, z1,
        x2, y2, z1,
    });
    if (!context.down)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x2, y1, z2,
            x2, y1, z1,
            x1, y1, z1,
        });
}

fn writePlantVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32) void {
    const x1: f32 = @as(f32, @floatFromInt(x)) + 1.0 - 0.853;
    const x2: f32 = @as(f32, @floatFromInt(x)) + 0.853;
    const y1: f32 = @floatFromInt(y + 0);
    const y2: f32 = @floatFromInt(y + 1);
    const z1: f32 = @as(f32, @floatFromInt(z)) + 1.0 - 0.853;
    const z2: f32 = @as(f32, @floatFromInt(z)) + 0.853;
    // Plant are two perpendicular two-faced squared
    arraylist.appendSliceAssumeCapacity(&.{
        // Plane 1 face 1
        x1, y1, z1,
        x2, y1, z2,
        x2, y2, z2,
        x1, y2, z1,
        // Plane 1 face 2
        x2, y1, z2,
        x1, y1, z1,
        x1, y2, z1,
        x2, y2, z2,
        // Plane 2 face 1
        x1, y1, z2,
        x2, y1, z1,
        x2, y2, z1,
        x1, y2, z2,
        // Plane 2 face 2
        x2, y1, z1,
        x1, y1, z2,
        x1, y2, z2,
        x2, y2, z1,
    });
}

fn writeCactusVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32, context: Context.Occlusion) void {
    const x1: f32 = @as(f32, @floatFromInt(x + 0));
    const x2: f32 = @as(f32, @floatFromInt(x + 1));
    const y1: f32 = @floatFromInt(y + 0);
    const y2: f32 = @floatFromInt(y + 1);
    const z1: f32 = @as(f32, @floatFromInt(z + 0));
    const z2: f32 = @as(f32, @floatFromInt(z + 1));
    const offset: f32 = (1.0 / 16.0);
    arraylist.appendSliceAssumeCapacity(&.{
        x1, y1, z1 + offset,
        x2, y1, z1 + offset,
        x2, y2, z1 + offset,
        x1, y2, z1 + offset,
    });
    arraylist.appendSliceAssumeCapacity(&.{
        x2 - offset, y1, z1,
        x2 - offset, y1, z2,
        x2 - offset, y2, z2,
        x2 - offset, y2, z1,
    });
    arraylist.appendSliceAssumeCapacity(&.{
        x2, y1, z2 - offset,
        x1, y1, z2 - offset,
        x1, y2, z2 - offset,
        x2, y2, z2 - offset,
    });
    arraylist.appendSliceAssumeCapacity(&.{
        x1 + offset, y1, z2,
        x1 + offset, y1, z1,
        x1 + offset, y2, z1,
        x1 + offset, y2, z2,
    });
    if (!context.up)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y2, z2,
            x1, y2, z2,
            x1, y2, z1,
            x2, y2, z1,
        });
    if (!context.down)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x2, y1, z2,
            x2, y1, z1,
            x1, y1, z1,
        });
}

fn writeLiquidStillVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32) void {
    const x1: f32 = @floatFromInt(x + 0);
    const x2: f32 = @floatFromInt(x + 1);
    const y1: f32 = @as(f32, @floatFromInt(y)) + (14.2 / 16.0);
    const z1: f32 = @floatFromInt(z + 0);
    const z2: f32 = @floatFromInt(z + 1);

    arraylist.appendSliceAssumeCapacity(&.{
        // Water surface face
        x1, y1, z1,
        x2, y1, z1,
        x2, y1, z2,
        x1, y1, z2,
    });
}

fn writeSnowVertices(arraylist: *std.ArrayList(f32), x: i32, y: i32, z: i32, context: Context.Occlusion) void {
    const x1: f32 = @floatFromInt(x + 0);
    const x2: f32 = @floatFromInt(x + 1);
    const y1: f32 = @floatFromInt(y + 0);
    const y2: f32 = @as(f32, @floatFromInt(y)) + (2.0 / 16.0);
    const z1: f32 = @floatFromInt(z + 0);
    const z2: f32 = @floatFromInt(z + 1);
    if (!context.north)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z1,
            x2, y1, z1,
            x2, y2, z1,
            x1, y2, z1,
        });
    if (!context.east)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z1,
            x2, y1, z2,
            x2, y2, z2,
            x2, y2, z1,
        });
    if (!context.south)
        arraylist.appendSliceAssumeCapacity(&.{
            x2, y1, z2,
            x1, y1, z2,
            x1, y2, z2,
            x2, y2, z2,
        });
    if (!context.west)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x1, y1, z1,
            x1, y2, z1,
            x1, y2, z2,
        });
    // if (!context.up)
    arraylist.appendSliceAssumeCapacity(&.{
        x2, y2, z2,
        x1, y2, z2,
        x1, y2, z1,
        x2, y2, z1,
    });
    if (!context.down)
        arraylist.appendSliceAssumeCapacity(&.{
            x1, y1, z2,
            x2, y1, z2,
            x2, y1, z1,
            x1, y1, z1,
        });
}

fn slabFaceCount(context: Context.Occlusion) usize {
    // Top face always renders
    var ret: usize = 1;
    if (!context.north)
        ret += 1;
    if (!context.east)
        ret += 1;
    if (!context.south)
        ret += 1;
    if (!context.west)
        ret += 1;
    if (!context.down)
        ret += 1;
    return ret;
}

fn cactusFaceCount(context: Context.Occlusion) usize {
    // Side faces always renders
    var ret: usize = 4;
    if (!context.up)
        ret += 1;
    if (!context.down)
        ret += 1;
    return ret;
}

const plant_face_count = 4;

const liquid_still_face_count = 1;

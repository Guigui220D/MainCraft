//! Helpers for terrain coloring

const std = @import("std");
const io = @import("io");
const tracy = @import("tracy");

const blocks = @import("blocks.zig");
const Context = @import("terrain").Context;
const coord = @import("coord");

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

/// Enable to replace lighting with face_dependant coloring
const debug_face_dir = false;

/// Apply light level to colors that already exist
/// The vertices are used to determine face orientation 3 vertices match 4 color bytes
pub fn adjustColors(colors: []u8, vertices: []const f32, context: Context) void {
    const zone = tracy.Zone.begin(.{
        .name = "Adjust colors",
        .src = @src(),
        .color = .green_yellow,
    });
    defer zone.end();

    // TODO: where to put those?
    const Vertex = coord.Vec3fs;

    const Face = packed struct {
        a: Vertex,
        b: Vertex,
        c: Vertex,
        _: Vertex,
    };

    const Color = packed struct(u32) {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    };

    const FaceColors = [4]Color;

    // Expect enough vertices for full 4 vertex faces
    std.debug.assert(vertices.len % (3 * 4) == 0);
    std.debug.assert(colors.len % 4 == 0);

    const faces: []const Face = @ptrCast(@alignCast(vertices));
    const faces_colors: []FaceColors = @ptrCast(@alignCast(colors));
    std.debug.assert(faces.len == faces_colors.len);

    for (faces, faces_colors) |face, *face_colors| {
        // TODO: only use local lighting for non full blocks?
        // Determine face orientation
        const vb = face.b.sub(face.a);
        const vc = face.c.sub(face.a);
        const cross = vc.cross(vb).normalize();
        const dir = cross.generalDirection();

        const light = context.getLight(dir);
        const blocklight = light.blocklight;
        const skylight = light.skylight;

        const total_light = blocklight +| skylight +| lighting_adjustment;

        for (face_colors) |*vertex_col| {
            // Apply color to RGB channels
            var temp: u32 = vertex_col.r;
            temp *= total_light;
            temp /= 15 + lighting_adjustment;
            vertex_col.r = @intCast(temp);

            temp = vertex_col.g;
            temp *= total_light;
            temp /= 15 + lighting_adjustment;
            vertex_col.g = @intCast(temp);

            temp = vertex_col.b;
            temp *= total_light;
            temp /= 15 + lighting_adjustment;
            vertex_col.b = @intCast(temp);

            // debug
            if (debug_face_dir) {
                vertex_col.r = 0;
                vertex_col.g = 0;
                vertex_col.b = 0;

                switch (dir) {
                    .down => {
                        // Cyan
                        vertex_col.g = 255;
                        vertex_col.b = 255;
                    },
                    .up => {
                        // Magenta
                        vertex_col.r = 255;
                        vertex_col.b = 255;
                    },
                    // Red
                    .north => vertex_col.r = 255,
                    // Green
                    .east => vertex_col.g = 255,
                    // Blue
                    .south => vertex_col.b = 255,
                    // Yellow
                    .west => {
                        vertex_col.r = 255;
                        vertex_col.g = 255;
                    },
                    // White
                    .self => {
                        vertex_col.r = 255;
                        vertex_col.g = 255;
                        vertex_col.b = 255;
                    },
                }
            }
        }
    }
}

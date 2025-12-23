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
mesh: *rl.Mesh,
dummy: rl.Model, // TODO: proper material

pub fn generateForChunk(alloc: std.mem.Allocator, chunk: Chunk) !ChunkModel {
    if (col_rand == null) {
        col_rand = std.Random.DefaultPrng.init(42);
    }

    var mesh = try alloc.create(rl.Mesh);
    errdefer alloc.destroy(mesh);
    mesh.* = try generateMeshForChunk(chunk);
    errdefer mesh.unload();
    rl.uploadMesh(mesh, false);

    const dummy = try rl.loadModel("res/test.glb");
    errdefer dummy.unload();

    return .{
        .color = .fromInt(col_rand.?.random().int(u32) | 0xff),
        .mesh = mesh,
        .dummy = dummy,
    };
}

pub fn draw(self: ChunkModel, pos: coord.Chunk) void {
    // Draw chunk bottom/bounds (debug)
    rl.drawCubeWires(.{ .x = @floatFromInt(pos.x * 16 + 8), .y = 128, .z = @floatFromInt(pos.z * 16 + 8) }, 16, 256, 16, .red);
    rl.drawPlane(.{ .x = @floatFromInt(pos.x * 16 + 8), .y = 0, .z = @floatFromInt(pos.z * 16 + 8) }, .{ .x = 16, .y = 16 }, self.color);

    //if (pos.x != 1 or pos.z != -6)
    //    return;

    // Draw chunk
    const transform: rl.Matrix = .translate(@as(f32, @floatFromInt(pos.x * 16)), 0, @as(f32, @floatFromInt(pos.z * 16)));
    rl.drawMesh(self.mesh.*, self.dummy.materials[0], transform);
}

pub fn deinit(self: ChunkModel, alloc: std.mem.Allocator) void {
    self.mesh.unload();
    alloc.destroy(self.mesh);
    self.dummy.unload();
}

/// Renders a chunk into a mesh
fn generateMeshForChunk(chunk: Chunk) !rl.Mesh {
    // Generate vertex matrix
    // TODO: do that comptime or only once
    var vertices: std.ArrayList(f32) = try .initCapacity(rl.mem, (17 * 17 * 129 * 3));
    errdefer vertices.deinit(rl.mem);

    {
        var x: usize = 0;
        while (x <= 16) : (x += 1) {
            var z: usize = 0;
            while (z <= 16) : (z += 1) {
                var y: usize = 0;
                while (y <= 128) : (y += 1) {
                    vertices.appendSliceAssumeCapacity(&.{
                        @floatFromInt(x),
                        @floatFromInt(y),
                        @floatFromInt(z),
                    });
                }
            }
        }
    }

    // Add cubes (TODO: cull hidden faces)
    var indices: std.ArrayList(c_ushort) = .{};
    errdefer indices.deinit(rl.mem);

    var normals: std.ArrayList(f32) = .{};
    errdefer normals.deinit(rl.mem);

    var colors: std.ArrayList(u8) = .{};
    errdefer colors.deinit(rl.mem);

    for (chunk.blocks, 0..) |id, i| {
        if (id == 0)
            continue;

        const y: i32 = @intCast(i % 128);
        const z: i32 = @intCast(i / 128 % 16);
        const x: i32 = @intCast(i / (128 * 16));
        const block = coord.Block{ .x = x, .y = y, .z = z };

        // For each face
        const top_face = getFaceVertices(block, .positive, .y);
        const bottom_face = getFaceVertices(block, .negative, .y);
        const east_face = getFaceVertices(block, .positive, .x);
        const west_face = getFaceVertices(block, .negative, .x);
        const south_face = getFaceVertices(block, .positive, .z);
        const north_face = getFaceVertices(block, .negative, .z);

        inline for (&.{ top_face, bottom_face, east_face, west_face, south_face, north_face }) |face| {
            // Add the two triangles
            try indices.appendSlice(rl.mem, &face);

            // TODO: correct normals
            try normals.appendSlice(rl.mem, &.{
                // Triangle 1
                0,
                1,
                0,
                // Triangle 2
                0,
                1,
                0,
            });

            // TODO: what's going on with colors?
            try colors.appendSlice(rl.mem, &.{ 255, 0, 0, 255 });
            try colors.appendSlice(rl.mem, &.{ 0, 255, 0, 255 });
            try colors.appendSlice(rl.mem, &.{ 0, 0, 255, 255 });
        }
    }

    const tri_count = indices.items.len / 3;
    const vert_count = vertices.items.len / 3;

    // Frankenstein mesh
    // TODO: proper errdefers
    return rl.Mesh{
        .animNormals = @ptrFromInt(0),
        .animVertices = @ptrFromInt(0),
        .boneCount = 0,
        .boneIds = @ptrFromInt(0),
        .boneMatrices = @ptrFromInt(0),
        .boneWeights = @ptrFromInt(0),
        .colors = @ptrCast(try colors.toOwnedSlice(rl.mem)),
        .indices = @ptrCast(try indices.toOwnedSlice(rl.mem)),
        .normals = @ptrCast(try normals.toOwnedSlice(rl.mem)),
        .tangents = @ptrFromInt(0),
        .texcoords = @ptrFromInt(0),
        .texcoords2 = @ptrFromInt(0),
        .triangleCount = @intCast(tri_count),
        .vaoId = 0,
        .vboId = @ptrFromInt(0),
        .vertexCount = @intCast(vert_count),
        .vertices = @ptrCast(try vertices.toOwnedSlice(rl.mem)),
    };
}

fn getFaceVertices(block: coord.Block, comptime direction: enum { negative, positive }, comptime axis: enum { x, y, z }) [6]c_ushort {
    const dir_bool = (direction == .positive);
    const v = switch (axis) {
        .x => [4]c_ushort{
            getVertexIndexFromBlockCoords(block, false, false, dir_bool),
            getVertexIndexFromBlockCoords(block, false, true, dir_bool),
            getVertexIndexFromBlockCoords(block, true, false, dir_bool),
            getVertexIndexFromBlockCoords(block, true, true, dir_bool),
        },
        .y => [4]c_ushort{
            getVertexIndexFromBlockCoords(block, dir_bool, false, false),
            getVertexIndexFromBlockCoords(block, dir_bool, false, true),
            getVertexIndexFromBlockCoords(block, dir_bool, true, false),
            getVertexIndexFromBlockCoords(block, dir_bool, true, true),
        },
        .z => [4]c_ushort{
            getVertexIndexFromBlockCoords(block, false, dir_bool, false),
            getVertexIndexFromBlockCoords(block, true, dir_bool, false),
            getVertexIndexFromBlockCoords(block, false, dir_bool, true),
            getVertexIndexFromBlockCoords(block, true, dir_bool, true),
        },
    };

    if (dir_bool) {
        return [6]c_ushort{ v[0], v[3], v[1], v[0], v[2], v[3] };
    } else {
        return [6]c_ushort{ v[0], v[1], v[3], v[0], v[3], v[2] };
    }
}

/// Calculate index of a vertex using the block coordinates and selecting the corner with the booleans
/// south: increasing in the z direction
/// east: increasing in the x direction
inline fn getVertexIndexFromBlockCoords(block: coord.Block, up: bool, south: bool, east: bool) c_ushort {
    std.debug.assert(block.isWithinChunk());

    var ret: c_ushort = 0;

    ret += @intCast((block.x + @intFromBool(east)) * 129 * 17);
    ret += @intCast((block.z + @intFromBool(south)) * 129);
    ret += @intCast((block.y + @intFromBool(up)));

    return ret;
}

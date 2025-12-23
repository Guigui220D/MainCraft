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
    var vertices: std.ArrayList(f32) = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
    errdefer vertices.deinit(rl.mem);

    var indices: std.ArrayList(c_ushort) = .{};
    errdefer indices.deinit(rl.mem);

    var colors: std.ArrayList(u32) = .{};
    errdefer colors.deinit(rl.mem);

    var id: c_ushort = 0;
    for (chunk.blocks, 0..) |block_id, i| {
        if (block_id == 0)
            continue;

        const y: i32 = @intCast(i % 128);
        const z: i32 = @intCast(i / 128 % 16);
        const x: i32 = @intCast(i / (128 * 16));

        // TODO: support for multiple meshes per chunk
        if (id > std.math.maxInt(c_ushort) - 8)
            break; // Can't fit more vertices

        // TODO: helper function for that
        // TODO: model per block id (reuse vertices where possible)
        vertices.appendSliceAssumeCapacity(&.{
            // 0
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z),
            // 1
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z + 1),
            // 2
            @floatFromInt(x + 1),
            @floatFromInt(y),
            @floatFromInt(z),
            // 3
            @floatFromInt(x + 1),
            @floatFromInt(y),
            @floatFromInt(z + 1),
            // 4
            @floatFromInt(x),
            @floatFromInt(y + 1),
            @floatFromInt(z),
            // 5
            @floatFromInt(x),
            @floatFromInt(y + 1),
            @floatFromInt(z + 1),
            // 6
            @floatFromInt(x + 1),
            @floatFromInt(y + 1),
            @floatFromInt(z),
            // 7
            @floatFromInt(x + 1),
            @floatFromInt(y + 1),
            @floatFromInt(z + 1),
        });

        // TODO: helper function for that
        try indices.appendSlice(rl.mem, &.{
            id + 0, id + 2, id + 3,
            id + 0, id + 3, id + 1,
            id + 1, id + 3, id + 7,
            id + 1, id + 7, id + 5,
            id + 0, id + 6, id + 2,
            id + 0, id + 4, id + 6,
            id + 0, id + 1, id + 5,
            id + 0, id + 5, id + 4,
            id + 4, id + 7, id + 6,
            id + 4, id + 5, id + 7,
            id + 2, id + 7, id + 3,
            id + 2, id + 6, id + 7,
        });

        try colors.append(rl.mem, 0xff000000);
        try colors.append(rl.mem, 0xff000099);
        try colors.append(rl.mem, 0xff009900);
        try colors.append(rl.mem, 0xff009999);
        try colors.append(rl.mem, 0xff990000);
        try colors.append(rl.mem, 0xff990099);
        try colors.append(rl.mem, 0xff999900);
        try colors.append(rl.mem, 0xff999999);

        id += 8;
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
        .normals = @ptrFromInt(0),
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

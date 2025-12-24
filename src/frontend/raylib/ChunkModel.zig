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
meshes: []rl.Mesh,
texture: rl.Texture, // TODO: this should be static
material: rl.Material, // TODO: this should be static

pub fn generateForChunk(alloc: std.mem.Allocator, chunk: Chunk) !ChunkModel {
    if (col_rand == null) {
        col_rand = std.Random.DefaultPrng.init(42);
    }

    // TODO: find out worst case to pre-alloc
    var meshes: std.ArrayList(rl.Mesh) = .{};
    errdefer {
        for (meshes.items) |mesh|
            mesh.unload();
        meshes.deinit(alloc);
    }

    try generateMeshesForChunk(chunk, alloc, &meshes);

    for (meshes.items) |*mesh|
        rl.uploadMesh(mesh, false);

    var texture = try rl.loadTexture("res/jar/minecraft/terrain.png");
    errdefer texture.unload();

    var material = try rl.loadMaterialDefault();
    errdefer material.unload();

    material.maps[0].texture = texture;

    return .{
        .color = .fromInt(col_rand.?.random().int(u32) | 0xff),
        .meshes = try meshes.toOwnedSlice(alloc),
        .texture = texture,
        .material = material,
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
    for (self.meshes) |mesh|
        rl.drawMesh(mesh, self.material, transform);
}

pub fn deinit(self: ChunkModel, alloc: std.mem.Allocator) void {
    for (self.meshes) |mesh|
        mesh.unload();
    alloc.free(self.meshes);
    self.material.unload();
    self.texture.unload();
}

/// Renders a chunk into a mesh
fn generateMeshesForChunk(chunk: Chunk, alloc: std.mem.Allocator, meshes: *std.ArrayList(rl.Mesh)) !void {
    // TODO: redo this whole thing: this is extremely ugly and WILL leak in case of error
    var vertices: std.ArrayList(f32) = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
    errdefer vertices.deinit(rl.mem);

    var indices: std.ArrayList(c_ushort) = .{};
    errdefer indices.deinit(rl.mem);

    var colors: std.ArrayList(u32) = .{};
    errdefer colors.deinit(rl.mem);

    var texcoords: std.ArrayList(f32) = .{};
    errdefer texcoords.deinit(rl.mem);

    var id: c_ushort = 0;
    for (chunk.blocks, 0..) |block_id, i| {
        if (block_id == 0)
            continue;

        const y: i32 = @intCast(i % 128);
        const z: i32 = @intCast(i / 128 % 16);
        const x: i32 = @intCast(i / (128 * 16));

        if (id > std.math.maxInt(c_ushort) - (8 * 3)) {
            // Can't fit more vertices
            id = 0;

            const tri_count = indices.items.len / 3;
            const vert_count = vertices.items.len / 3;

            if (tri_count > 0) {
                // Frankenstein mesh
                // TODO: proper errdefers
                try meshes.append(alloc, rl.Mesh{
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
                    .texcoords = @ptrCast(try texcoords.toOwnedSlice(rl.mem)),
                    .texcoords2 = @ptrFromInt(0),
                    .triangleCount = @intCast(tri_count),
                    .vaoId = 0,
                    .vboId = @ptrFromInt(0),
                    .vertexCount = @intCast(vert_count),
                    .vertices = @ptrCast(try vertices.toOwnedSlice(rl.mem)),
                });
            }

            vertices = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
            indices = .{};
            colors = .{};
            texcoords = .{};
        }

        // TODO: make sure the arrays are only exanded once, also maybe prealloc the max size when preparing a new mesh

        // TODO: helper function for that
        // TODO: model per block id (reuse vertices where possible)
        // TODO: cull faces
        vertices.appendSliceAssumeCapacity(&.{
            // Each point is shared by 3 faces, so duplicate the points
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
            // 0 + 8
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z),
            // 1 + 8
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z + 1),
            // 2 + 8
            @floatFromInt(x + 1),
            @floatFromInt(y),
            @floatFromInt(z),
            // 3 + 8
            @floatFromInt(x + 1),
            @floatFromInt(y),
            @floatFromInt(z + 1),
            // 4 + 8
            @floatFromInt(x),
            @floatFromInt(y + 1),
            @floatFromInt(z),
            // 5 + 8
            @floatFromInt(x),
            @floatFromInt(y + 1),
            @floatFromInt(z + 1),
            // 6
            @floatFromInt(x + 1),
            @floatFromInt(y + 1),
            @floatFromInt(z),
            // 7 + 8
            @floatFromInt(x + 1),
            @floatFromInt(y + 1),
            @floatFromInt(z + 1),
            // 0 + 16
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z),
            // 1 + 16
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z + 1),
            // 2 + 16
            @floatFromInt(x + 1),
            @floatFromInt(y),
            @floatFromInt(z),
            // 3 + 16
            @floatFromInt(x + 1),
            @floatFromInt(y),
            @floatFromInt(z + 1),
            // 4 + 16
            @floatFromInt(x),
            @floatFromInt(y + 1),
            @floatFromInt(z),
            // 5 + 16
            @floatFromInt(x),
            @floatFromInt(y + 1),
            @floatFromInt(z + 1),
            // 6 + 16
            @floatFromInt(x + 1),
            @floatFromInt(y + 1),
            @floatFromInt(z),
            // 7 + 16
            @floatFromInt(x + 1),
            @floatFromInt(y + 1),
            @floatFromInt(z + 1),
        });

        // TODO: helper function for that
        try indices.appendSlice(rl.mem, &.{
            //
            id + 0,      id + 2,      id + 3,
            id + 0,      id + 3,      id + 1,
            //
            id + 1 + 8,  id + 3 + 8,  id + 7 + 8,
            id + 1 + 8,  id + 7 + 8,  id + 5 + 8,
            //
            id + 0 + 8,  id + 6 + 8,  id + 2 + 8,
            id + 0 + 8,  id + 4 + 8,  id + 6 + 8,
            //
            id + 0 + 16, id + 1 + 16, id + 5 + 16,
            id + 0 + 16, id + 5 + 16, id + 4 + 16,
            //
            id + 4,      id + 7,      id + 6,
            id + 4,      id + 5,      id + 7,
            //
            id + 2,      id + 7,      id + 3,
            id + 2,      id + 6,      id + 7,
        });

        // Colors (later based on chunk lighting)
        try colors.appendNTimes(rl.mem, 0xffffffff, 8 * 3);

        // TODO: helper function for that
        const block_tex_id = 4;
        const tx: f32 = @as(f32, @floatFromInt(block_tex_id % 16)) / 16.0;
        const ty: f32 = @as(f32, @floatFromInt(block_tex_id / 16)) / 16.0;

        try texcoords.appendSlice(rl.mem, &.{
            0 + tx,          0 + ty,
            0 + tx,          1.0 / 16.0 + ty,
            1.0 / 16.0 + tx, 0 + ty,
            1.0 / 16.0 + tx, 1.0 / 16.0 + ty,

            1.0 / 16.0 + tx, 0 + ty,
            1.0 / 16.0 + tx, 1.0 / 16.0 + ty,
            0 + tx,          0 + ty,
            0 + tx,          1.0 / 16.0 + ty,
        });

        try texcoords.appendSlice(rl.mem, &.{
            0 + tx,          0 + ty,
            1.0 / 16.0 + tx, 0 + ty,
            0 + tx,          1.0 / 16.0 + ty,
            1.0 / 16.0 + tx, 1.0 / 16.0 + ty,

            1.0 / 16.0 + tx, 0 + ty,
            0 + tx,          0 + ty,
            1.0 / 16.0 + tx, 1.0 / 16.0 + ty,
            0 + tx,          1.0 / 16.0 + ty,
        });

        try texcoords.appendSlice(rl.mem, &.{
            0 + tx,          0 + ty,
            0 + tx,          1.0 / 16.0 + ty,
            1.0 / 16.0 + tx, 0 + ty,
            1.0 / 16.0 + tx, 1.0 / 16.0 + ty,

            1.0 / 16.0 + tx, 0 + ty,
            1.0 / 16.0 + tx, 1.0 / 16.0 + ty,
            0 + tx,          0 + ty,
            0 + tx,          1.0 / 16.0 + ty,
        });

        id += 8 * 3;
    }

    const tri_count = indices.items.len / 3;
    const vert_count = vertices.items.len / 3;

    if (tri_count > 0) {
        // Frankenstein mesh
        // TODO: proper errdefers
        try meshes.append(alloc, rl.Mesh{
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
            .texcoords = @ptrCast(try texcoords.toOwnedSlice(rl.mem)),
            .texcoords2 = @ptrFromInt(0),
            .triangleCount = @intCast(tri_count),
            .vaoId = 0,
            .vboId = @ptrFromInt(0),
            .vertexCount = @intCast(vert_count),
            .vertices = @ptrCast(try vertices.toOwnedSlice(rl.mem)),
        });
    }
}

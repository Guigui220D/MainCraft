//! A chunk's visual representation
//! This is specific to the IO and can be modified independently of the chunk's actual representation

const std = @import("std");
const rl = @import("raylib");
const coord = @import("coord");
const Chunk = @import("terrain").Chunk;
const blocks = @import("blocks").table;

const ChunkModel = @This();

// Material
var texture: rl.Texture = undefined;
var material: rl.Material = undefined;

meshes: []rl.Mesh,

/// Init the meshing system (static ressources)
pub fn initMesher() !void {
    // Load texture from jar
    texture = try rl.loadTexture("res/jar/minecraft/terrain.png");
    errdefer texture.unload();

    // Init material
    material = try rl.loadMaterialDefault();
    errdefer material.unload();
    material.maps[0].texture = texture;
}

/// Deinit the meshing system (static ressources)
pub fn deinitMesher() void {
    material.unload();
    texture.unload();
}

/// Prepare the ChunkModel for a chunk (part of the API)
pub fn generateForChunk(alloc: std.mem.Allocator, chunk: Chunk) !ChunkModel {
    const meshes = try generateMeshesForChunk(alloc, chunk);
    errdefer {
        for (meshes) |mesh|
            mesh.unload();
        alloc.free(meshes);
    }

    // Upload generated meshes
    for (meshes) |*mesh|
        rl.uploadMesh(mesh, false);

    return .{
        .meshes = meshes,
    };
}

pub fn draw(self: ChunkModel, pos: coord.Chunk) void {
    // Draw chunk
    const transform: rl.Matrix = .translate(@as(f32, @floatFromInt(pos.x * 16)), 0, @as(f32, @floatFromInt(pos.z * 16)));
    for (self.meshes) |mesh|
        rl.drawMesh(mesh, material, transform);
}

pub fn deinit(self: ChunkModel, alloc: std.mem.Allocator) void {
    for (self.meshes) |mesh|
        mesh.unload();
    alloc.free(self.meshes);
}

/// Renders a chunk into a mesh
fn generateMeshesForChunk(alloc: std.mem.Allocator, chunk: Chunk) ![]rl.Mesh {
    // Meshes arraylist
    // TODO: find out worst case to pre-alloc
    var meshes: std.ArrayList(rl.Mesh) = .{};
    errdefer {
        for (meshes.items) |mesh|
            mesh.unload();
        meshes.deinit(alloc);
    }

    // Remaining data
    var offset: usize = 0; // advanced by generateSingleMesh
    const data: []const u8 = chunk.blocks;

    // Generate meshes as long as needed
    while (offset < data.len) {
        const mesh = try generateSingleMesh(alloc, data, &offset);
        errdefer mesh.unload();

        try meshes.append(alloc, mesh);
    }

    return try meshes.toOwnedSlice(alloc);
}

fn generateSingleMesh(alloc: std.mem.Allocator, block_data: []const u8, offset: *usize) !rl.Mesh {
    // Slice of the remaining data
    const begin = offset.*;
    const remaining = block_data[begin..];

    // Dynamic arraylists used to alloc necessary memory for model data
    // TODO: put the transparent blocks in a distinct array
    var vertices: std.ArrayList(f32) = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
    errdefer vertices.deinit(rl.mem);
    // TODO: prealloc in a pessimistic way to avoid reallocations
    var indices: std.ArrayList(c_ushort) = .{};
    errdefer indices.deinit(rl.mem);

    var colors: std.ArrayList(u32) = .{};
    errdefer colors.deinit(rl.mem);

    var texcoords: std.ArrayList(f32) = .{};
    errdefer texcoords.deinit(rl.mem);

    // vertex indices used for the next model added
    var next_id: c_ushort = 0;

    // Iterate over as many blocks as possible
    for (remaining, begin..) |block_id, i| {
        offset.* = i + 1;

        if (block_id == 0)
            continue;

        const block = blocks[block_id];
        if (!block.full_block) // TODO: find solution for rendering transparent blocks
            continue;

        // Block coordinates
        const xyz = Chunk.coordFromIndex(i);

        // TODO: obtain programatically the needed amount of vertices (depending on the block and circumstances)
        const needed_vertices = 8 * 3;

        // Stop filling buffers: we can't use more vertex indices
        if (next_id > std.math.maxInt(c_ushort) - needed_vertices)
            break;

        // Add vertices
        // TODO: LESS VERTICES MEANS LESS MESHES TO UPLOAD
        try addProtoCubeVertices(&vertices, xyz.x, xyz.y, xyz.z);

        // Add triangles
        try addProtoCubeTris(&indices, next_id);

        // Colors (later based on chunk lighting)
        try colors.appendNTimes(rl.mem, 0xffffffff, 8 * 3);

        // Add UV
        const block_tex_id = block.tex_id;
        const tx: f32 = @as(f32, @floatFromInt(block_tex_id % 16)) / 16.0;
        const ty: f32 = @as(f32, @floatFromInt(block_tex_id / 16)) / 16.0;

        try addProtoCubeUV(&texcoords, tx, ty);

        // Count up the vertex indices
        next_id += needed_vertices;
    }

    // Count used tris and verts
    const tri_count = indices.items.len / 3;
    const vert_count = vertices.items.len / 3;

    // Own the slices
    const colors_data = try colors.toOwnedSlice(rl.mem);
    errdefer alloc.free(colors_data);

    const indices_data = try indices.toOwnedSlice(rl.mem);
    errdefer alloc.free(indices_data);

    const texcoords_data = try texcoords.toOwnedSlice(rl.mem);
    errdefer alloc.free(texcoords_data);

    const vertices_data = try vertices.toOwnedSlice(rl.mem);
    errdefer alloc.free(vertices_data);

    // Make up the mesh struct
    return rl.Mesh{
        .animNormals = @ptrFromInt(0),
        .animVertices = @ptrFromInt(0),
        .boneCount = 0,
        .boneIds = @ptrFromInt(0),
        .boneMatrices = @ptrFromInt(0),
        .boneWeights = @ptrFromInt(0),
        .colors = @ptrCast(colors_data),
        .indices = @ptrCast(indices_data),
        .normals = @ptrFromInt(0),
        .tangents = @ptrFromInt(0),
        .texcoords = @ptrCast(texcoords_data),
        .texcoords2 = @ptrFromInt(0),
        .triangleCount = @intCast(tri_count),
        .vaoId = 0,
        .vboId = @ptrFromInt(0),
        .vertexCount = @intCast(vert_count),
        .vertices = @ptrCast(vertices_data),
    };
}

/// Prototype helper to make cube triangles just for readability but this will disappear
fn addProtoCubeTris(tris: *std.ArrayList(c_ushort), id: c_ushort) !void {
    // TODO: rethink meshing
    try tris.appendSlice(rl.mem, &.{
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
}

/// Prototype helper to map cube triangles UVs just for readability but this will disappear
fn addProtoCubeUV(uv: *std.ArrayList(f32), tx: f32, ty: f32) !void {
    // TODO: rethink meshing
    try uv.appendSlice(rl.mem, &.{
        0 + tx,          0 + ty,
        0 + tx,          1.0 / 16.0 + ty,
        1.0 / 16.0 + tx, 0 + ty,
        1.0 / 16.0 + tx, 1.0 / 16.0 + ty,

        1.0 / 16.0 + tx, 0 + ty,
        1.0 / 16.0 + tx, 1.0 / 16.0 + ty,
        0 + tx,          0 + ty,
        0 + tx,          1.0 / 16.0 + ty,

        0 + tx,          0 + ty,
        1.0 / 16.0 + tx, 0 + ty,
        0 + tx,          1.0 / 16.0 + ty,
        1.0 / 16.0 + tx, 1.0 / 16.0 + ty,

        1.0 / 16.0 + tx, 0 + ty,
        0 + tx,          0 + ty,
        1.0 / 16.0 + tx, 1.0 / 16.0 + ty,
        0 + tx,          1.0 / 16.0 + ty,

        0 + tx,          0 + ty,
        0 + tx,          1.0 / 16.0 + ty,
        1.0 / 16.0 + tx, 0 + ty,
        1.0 / 16.0 + tx, 1.0 / 16.0 + ty,

        1.0 / 16.0 + tx, 0 + ty,
        1.0 / 16.0 + tx, 1.0 / 16.0 + ty,
        0 + tx,          0 + ty,
        0 + tx,          1.0 / 16.0 + ty,
    });
}

fn addProtoCubeVertices(vertices: *std.ArrayList(f32), x: i32, y: i32, z: i32) !void {
    // TODO: cull faces
    // TODO: rethink meshing: model per block id (reuse vertices where possible)
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
}

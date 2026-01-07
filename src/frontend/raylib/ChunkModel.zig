//! A chunk's visual representation
//! This is specific to the IO and can be modified independently of the chunk's actual representation

const std = @import("std");
const rl = @import("raylib");
const coord = @import("coord");
const terrain = @import("terrain");
const Chunk = terrain.Chunk;
const Context = terrain.Context;
const blocks = @import("blocks");
const tracy = @import("tracy");
const meshing = @import("meshing");

const ChunkModel = @This();

// TODO: make the meshes on a separate thread

// Material
// TODO: ressource manager
var texture: rl.Texture = undefined;
var material: rl.Material = undefined;
var shader_transparency: rl.Shader = undefined;
var material_transparency: rl.Material = undefined;

meshes: []rl.Mesh,
transparent_meshes: []rl.Mesh,

/// Init the meshing system (static ressources)
pub fn initMesher() !void {
    // Load texture from jar
    texture = try rl.loadTexture("res/jar/minecraft/terrain.png");
    errdefer texture.unload();

    // Init materials
    material = try rl.loadMaterialDefault();
    errdefer material.unload();
    material.maps[0].texture = texture;

    shader_transparency = try rl.loadShader(null, "res/shaders/chunk_transparent.fs");
    errdefer shader_transparency.unload();

    material_transparency = try rl.loadMaterialDefault();
    errdefer material_transparency.unload();
    material_transparency.maps[0].texture = texture;
    material_transparency.shader = shader_transparency;
}

/// Deinit the meshing system (static ressources)
pub fn deinitMesher() void {
    material.unload();
    material_transparency.unload();
    texture.unload();
}

/// Prepare the ChunkModel for a chunk (part of the API)
pub fn generateForChunk(alloc: std.mem.Allocator, chunk: Chunk) !ChunkModel {
    const meshes, const transparent_meshes = try generateMeshesForChunk(alloc, chunk);
    errdefer {
        for (meshes) |mesh|
            mesh.unload();
        alloc.free(meshes);

        for (transparent_meshes) |mesh|
            mesh.unload();
        alloc.free(transparent_meshes);
    }

    // Upload generated meshes
    for (meshes) |*mesh|
        rl.uploadMesh(mesh, false);

    for (transparent_meshes) |*mesh|
        rl.uploadMesh(mesh, false);

    return .{
        .meshes = meshes,
        .transparent_meshes = transparent_meshes,
    };
}

pub fn draw(self: ChunkModel, pos: coord.Chunk) void {
    // Draw chunk
    const transform: rl.Matrix = .translate(@as(f32, @floatFromInt(pos.x * 16)), 0, @as(f32, @floatFromInt(pos.z * 16)));
    for (self.meshes) |mesh|
        rl.drawMesh(mesh, material, transform);
}

pub fn drawTransparentLayer(self: ChunkModel, pos: coord.Chunk) void {
    // Draw chunk
    const transform: rl.Matrix = .translate(@as(f32, @floatFromInt(pos.x * 16)), 0, @as(f32, @floatFromInt(pos.z * 16)));
    for (self.transparent_meshes) |mesh|
        rl.drawMesh(mesh, material_transparency, transform);
}

pub fn deinit(self: ChunkModel, alloc: std.mem.Allocator) void {
    for (self.meshes) |mesh|
        mesh.unload();
    for (self.transparent_meshes) |mesh|
        mesh.unload();
    alloc.free(self.meshes);
    alloc.free(self.transparent_meshes);
}

/// Renders a chunk into a mesh
fn generateMeshesForChunk(alloc: std.mem.Allocator, chunk: Chunk) !struct { []rl.Mesh, []rl.Mesh } {
    // Meshes arraylist
    var meshes: std.ArrayList(rl.Mesh) = .{};
    var transparent_meshes: std.ArrayList(rl.Mesh) = .{};
    errdefer {
        for (meshes.items) |mesh|
            mesh.unload();
        meshes.deinit(alloc);

        for (transparent_meshes.items) |mesh|
            mesh.unload();
        transparent_meshes.deinit(alloc);
    }

    // Remaining data
    var offset: usize = 0; // advanced by generateSingleMesh

    // SOLID MESHES

    // Generate meshes as long as needed
    while (offset < Chunk.block_data_len) {
        const mesh = try generateSingleMesh(alloc, chunk, &offset, false) orelse continue;
        errdefer mesh.unload();

        try meshes.append(alloc, mesh);
    }

    offset = 0;

    // TRANSPARENT MESHES

    // Generate meshes as long as needed
    while (offset < Chunk.block_data_len) {
        const mesh = try generateSingleMesh(alloc, chunk, &offset, true) orelse continue;
        errdefer mesh.unload();

        try transparent_meshes.append(alloc, mesh);
    }

    // Owned arrays
    const owned_meshes = try meshes.toOwnedSlice(alloc);
    errdefer alloc.free(owned_meshes);

    const owned_transparent_meshes = try transparent_meshes.toOwnedSlice(alloc);
    errdefer alloc.free(owned_transparent_meshes);

    return .{
        owned_meshes,
        owned_transparent_meshes,
    };
}

// TODO: two passes aren't necessary, can collect both meshes in one go
fn generateSingleMesh(alloc: std.mem.Allocator, chunk: Chunk, offset: *usize, transparent: bool) !?rl.Mesh {
    const zone = tracy.Zone.begin(.{
        .name = "Chunk meshing (rl)",
        .src = @src(),
        .color = .orange,
    });
    defer zone.end();

    // Slice of the remaining data
    const begin = offset.*;
    const remaining = chunk.blocks_data[begin..];

    // Dynamic arraylists used to alloc necessary memory for model data
    var vertices: std.ArrayList(f32) = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
    defer vertices.deinit(rl.mem);
    // TODO: prealloc in a pessimistic way to avoid reallocations
    var indices: std.ArrayList(c_ushort) = .{};
    defer indices.deinit(rl.mem);

    var colors: std.ArrayList(u32) = .{};
    defer colors.deinit(rl.mem);

    var texcoords: std.ArrayList(f32) = .{};
    defer texcoords.deinit(rl.mem);

    // vertex indices used for the next model added
    var next_id: c_ushort = 0;

    // Iterate over as many blocks as possible
    for (remaining, begin..) |block_id, i| {
        offset.* = i + 1;

        if (block_id == 0)
            continue;

        const block = blocks.table[block_id];
        if (block.flags.transparent != transparent)
            continue;

        // Block coordinates
        const xyz = Chunk.coordFromIndex(i);

        const context: Context = chunk.getContext(xyz);
        const face_count: c_ushort = @intCast(meshing.vertices.faceCount(block.flags.model, context.occlusion));
        if (face_count == 0)
            continue;

        const metadata = chunk.getBlockMeta(xyz);
        _ = metadata;

        const vertex_count: c_ushort = face_count * 4;

        // Stop filling buffers: we can't use more vertex indices
        if (next_id > std.math.maxInt(c_ushort) - vertex_count)
            break;

        // Resize buffers to fit if needed
        {
            const realloc_zone = tracy.Zone.begin(.{
                .name = "Realloc vertices",
                .src = @src(),
                .color = .indian_red,
            });
            defer realloc_zone.end();

            try vertices.ensureUnusedCapacity(rl.mem, vertex_count);
            try indices.ensureUnusedCapacity(rl.mem, face_count * 6);
            try colors.ensureUnusedCapacity(rl.mem, vertex_count);
            try texcoords.ensureUnusedCapacity(rl.mem, vertex_count * 2);
        }

        // Write mesh data for block
        {
            const write_zone = tracy.Zone.begin(.{
                .name = "Write block mesh",
                .src = @src(),
                .color = .red,
            });
            defer write_zone.end();

            // Add vertices
            meshing.vertices.writeVertices(&vertices, block.flags.model, xyz, context.occlusion);

            // Add triangles
            meshing.vertices.materializeFaces(&indices, face_count, next_id, false);

            // Colors (later based on chunk lighting)
            meshing.colors.writeColors(&colors, context.occlusion, vertex_count, block_id);
            meshing.colors.adjustColors(
                @ptrCast(colors.items[(colors.items.len - vertex_count)..]),
                vertices.items[(vertices.items.len - (vertex_count * 3))..],
                context,
            );

            // Add UV
            meshing.uv.writeUV(&texcoords, context.occlusion, block_id);
        }

        // Count up the vertex indices
        next_id += vertex_count;
    }

    // Count used tris and verts
    const tri_count = indices.items.len / 3;
    const vert_count = vertices.items.len / 3;

    // We don't want to generate an empty mesh
    if (vert_count == 0)
        return null;

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

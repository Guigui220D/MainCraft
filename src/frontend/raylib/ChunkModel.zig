//! A chunk's visual representation
//! This is specific to the IO and can be modified independently of the chunk's actual representation

const std = @import("std");
const rl = @import("raylib");
const coord = @import("coord");
const Chunk = @import("terrain").Chunk;
const blocks = @import("blocks");
const tracy = @import("tracy");

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

    // Generate meshes as long as needed
    while (offset < Chunk.block_data_len) {
        const mesh = try generateSingleMesh(alloc, chunk, &offset);
        errdefer mesh.unload();

        try meshes.append(alloc, mesh);
    }

    return try meshes.toOwnedSlice(alloc);
}

fn generateSingleMesh(alloc: std.mem.Allocator, chunk: Chunk, offset: *usize) !rl.Mesh {
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

        const block_zone = tracy.Zone.begin(.{
            .name = "Single block meshing (rl)",
            .src = @src(),
            .color = .orange_red,
        });
        defer block_zone.end();

        const block = blocks.table[block_id];
        // TODO: find solution for rendering transparent blocks

        // Block coordinates
        const xyz = Chunk.coordFromIndex(i);

        const context: blocks.Context = chunk.getContext(xyz);
        const face_count: c_ushort = @intCast(blocks.models.faceCount(block.block_model, context));
        if (face_count == 0)
            continue;

        const vertex_count: c_ushort = face_count * 4;

        // Stop filling buffers: we can't use more vertex indices
        if (next_id > std.math.maxInt(c_ushort) - vertex_count)
            break;

        const writemesh_zone = tracy.Zone.begin(.{
            .name = "Write block mesh",
            .src = @src(),
            .color = .orange_red1,
        });
        defer writemesh_zone.end();

        // Add vertices
        blocks.models.writeVertices(&vertices, block.block_model, xyz, context);

        // Add triangles
        try indices.ensureUnusedCapacity(rl.mem, face_count * 6); // TODO: more elegant way to get these numbers
        blocks.models.materializeFaces(&indices, face_count, next_id, false);

        // Colors (later based on chunk lighting)
        try colors.appendNTimes(rl.mem, 0xffffffff, vertex_count);

        // Add UV
        try texcoords.ensureUnusedCapacity(rl.mem, vertex_count * 2);
        blocks.uv.writeUV(&texcoords, context, block_id);

        // Count up the vertex indices
        next_id += vertex_count;
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

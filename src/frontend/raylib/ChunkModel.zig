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
const properties = @import("properties.zig");

const ChunkModel = @This();

// TODO: make the meshes on a separate thread

model: rl.Model,
bl_tex: rl.Texture,
sl_tex: rl.Texture,

/// Prepare the ChunkModel for a chunk (part of the API)
pub fn generateForChunk(alloc: std.mem.Allocator, chunk: Chunk) !ChunkModel {
    // Get meshes
    const opaque_meshes, const transparent_meshes = try generateMeshesForChunk(alloc, chunk);
    defer alloc.free(opaque_meshes);
    defer alloc.free(transparent_meshes);

    errdefer {
        for (opaque_meshes) |mesh|
            mesh.unload();
        for (transparent_meshes) |mesh|
            mesh.unload();
    }

    // Put all meshes in one array (order matters)
    const total_meshes = opaque_meshes.len + transparent_meshes.len;
    var all_meshes = try std.ArrayList(rl.Mesh).initCapacity(rl.mem, total_meshes);
    errdefer all_meshes.deinit(rl.mem);
    all_meshes.appendSliceAssumeCapacity(opaque_meshes);
    all_meshes.appendSliceAssumeCapacity(transparent_meshes);
    const meshes = try all_meshes.toOwnedSlice(rl.mem);
    errdefer rl.mem.free(meshes);

    // Upload all meshes
    for (meshes) |*mesh|
        rl.uploadMesh(mesh, false);

    // Generate light textures (prototype)
    const bl_tex = try generateLightTexture(chunk.blocklight);
    errdefer bl_tex.unload();

    const sl_tex = try generateLightTexture(chunk.skylight);
    errdefer sl_tex.unload();

    // Mesh materials
    const mesh_materials = try rl.mem.dupe(c_int, &.{0});
    errdefer rl.mem.free(mesh_materials);

    const materials = try rl.mem.dupe(rl.Material, &.{undefined});
    errdefer rl.mem.free(materials);

    const model = rl.Model{
        .bindPose = @ptrFromInt(0),
        .boneCount = 0,
        .bones = @ptrFromInt(0),
        .materialCount = 1,
        .materials = @ptrCast(materials),
        .meshCount = @intCast(total_meshes),
        .meshes = @ptrCast(meshes),
        .meshMaterial = @ptrCast(mesh_materials),
        .transform = .identity(),
    };
    errdefer model.unload();

    return .{
        .model = model,
        .bl_tex = bl_tex,
        .sl_tex = sl_tex,
    };
}

pub fn draw(self: ChunkModel, pos: coord.Chunk, material: *const rl.Material) void {
    self.model.materials[0] = material.*;
    self.model.materials[0].maps[1].texture = self.bl_tex;
    self.model.materials[0].maps[2].texture = self.sl_tex;

    // Draw chunk
    rl.drawModel(
        self.model,
        .{ .x = @as(f32, @floatFromInt(pos.x * 16)), .y = 0, .z = @as(f32, @floatFromInt(pos.z * 16)) },
        1.0,
        .white,
    );
}

/// Renders a chunk into a mesh
fn generateMeshesForChunk(alloc: std.mem.Allocator, chunk: Chunk) !struct { []rl.Mesh, []rl.Mesh } {
    var meshes = try MeshBuilder.init(alloc);
    errdefer meshes.deinit();

    var meshes_t = try MeshBuilder.init(alloc);
    errdefer meshes_t.deinit();

    for (chunk.blocks_data, 0..) |block_id, i| {
        // Ignore air
        if (block_id == 0)
            continue;

        const block = blocks.table[block_id];

        // Select mesh builder based on transparency
        const mesh_builder = if (block.flags.transparent) &meshes_t else &meshes;

        // Block coordinates
        const xyz = Chunk.coordFromIndex(i);

        // Get general block information
        const context: Context = chunk.getContext(xyz);
        const face_count: c_ushort = @intCast(meshing.vertices.faceCount(block.flags.model, context.occlusion));
        // Ignore blocks that are fully occulted
        if (face_count == 0)
            continue;

        const metadata = chunk.getBlockMeta(xyz);
        _ = metadata;

        const vertex_count: c_ushort = face_count * 4;

        // Stop filling buffers: we can't use more vertex indices
        if (mesh_builder.next_id > std.math.maxInt(c_ushort) - vertex_count) {
            // Flush current mesh builder and
            try mesh_builder.flush();
        }

        // Resize buffers to fit if needed
        {
            const realloc_zone = tracy.Zone.begin(.{
                .name = "Realloc vertices",
                .src = @src(),
                .color = .indian_red,
            });
            defer realloc_zone.end();

            try mesh_builder.vertices.ensureUnusedCapacity(rl.mem, vertex_count * 3);
            try mesh_builder.indices.ensureUnusedCapacity(rl.mem, face_count * 6);
            try mesh_builder.colors.ensureUnusedCapacity(rl.mem, vertex_count);
            try mesh_builder.texcoords.ensureUnusedCapacity(rl.mem, vertex_count * 2);
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
            meshing.vertices.writeVertices(&mesh_builder.vertices, block.flags.model, xyz, context.occlusion);

            // Add triangles
            meshing.vertices.materializeFaces(&mesh_builder.indices, face_count, mesh_builder.next_id, false);

            // Add normals
            meshing.vertices.writeNormals(&mesh_builder.normals, mesh_builder.vertices.items[(mesh_builder.vertices.items.len - (vertex_count * 3))..], block.isFull(), xyz);

            // Colors (later based on chunk lighting)
            meshing.colors.writeColors(&mesh_builder.colors, context.occlusion, vertex_count, block_id);

            // Add UV
            meshing.uv.writeUV(&mesh_builder.texcoords, context.occlusion, block_id);
        }

        // Count up the vertex indices
        mesh_builder.next_id += vertex_count;
    }

    return .{
        try meshes.getMeshesAndDeinit(),
        try meshes_t.getMeshesAndDeinit(),
    };
}

/// Gets a 1D texture from the light data, to send as uniform
fn generateLightTexture(lightdata: []const u8) !rl.Texture {
    std.debug.assert(lightdata.len == 16384);

    var image = rl.Image{
        .data = @ptrCast(try rl.mem.dupe(u8, lightdata)),
        .format = .uncompressed_r32,
        .width = 4096,
        .height = 1,
        .mipmaps = 1,
    };
    defer image.unload();

    const ptr = @as([*]u8, @ptrCast(image.data));
    const data = ptr[0..16384];

    @memcpy(data, lightdata);
    //for (data) |*val| {
    //    val.* = 0xF0;
    //}

    return try image.toTexture();
}

/// Struct holding arraylists for a mesh that is being built
const MeshBuilder = struct {
    alloc: std.mem.Allocator,
    built_meshes: std.ArrayList(rl.Mesh),
    vertices: std.ArrayList(f32),
    indices: std.ArrayList(properties.VertexIdT),
    normals: std.ArrayList(f32),
    colors: std.ArrayList(u32),
    texcoords: std.ArrayList(f32),
    next_id: c_ushort,

    /// Inits a mesh builder and preallocates buffers in pessimistic way
    pub fn init(alloc: std.mem.Allocator) !MeshBuilder {
        var ret: MeshBuilder = undefined;

        ret.alloc = alloc;

        // Prealloc pessemistically
        ret.vertices = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
        errdefer ret.vertices.deinit(rl.mem);

        ret.indices = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) + 1));
        errdefer ret.indices.deinit(rl.mem);

        ret.normals = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 3 + 1));
        errdefer ret.normals.deinit(rl.mem);

        ret.colors = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 4 + 1));
        errdefer ret.colors.deinit(rl.mem);

        ret.texcoords = try .initCapacity(rl.mem, (std.math.maxInt(c_ushort) * 2 + 1));
        errdefer ret.texcoords.deinit(rl.mem);

        ret.built_meshes = try .initCapacity(alloc, 2);
        errdefer ret.built_meshes.deinit(alloc);

        ret.next_id = 0;

        return ret;
    }

    /// Adds a new mesh by owning the buffers
    /// Doesn't add anything if the buffers have no meaningful data
    /// Buffers are then ready for a new mesh
    pub fn flush(self: *MeshBuilder) !void {
        // TODO: this is a bit flimsy when it comes to errdefers
        // Count used tris and verts
        const tri_count = self.indices.items.len / 3;
        const vert_count = self.vertices.items.len / 3;

        // We don't want to generate an empty mesh
        if (vert_count == 0) {
            return;
        }

        // Make up the mesh struct
        const new_mesh = blk: {
            // Own the slices
            const vertices_data = try self.vertices.toOwnedSlice(rl.mem);
            errdefer rl.mem.free(vertices_data);

            const indices_data = try self.indices.toOwnedSlice(rl.mem);
            errdefer rl.mem.free(indices_data);

            const normals_data = try self.normals.toOwnedSlice(rl.mem);
            errdefer rl.mem.free(normals_data);

            const colors_data = try self.colors.toOwnedSlice(rl.mem);
            errdefer rl.mem.free(colors_data);

            const texcoords_data = try self.texcoords.toOwnedSlice(rl.mem);
            errdefer rl.mem.free(texcoords_data);

            break :blk rl.Mesh{
                .animNormals = @ptrFromInt(0),
                .animVertices = @ptrFromInt(0),
                .boneCount = 0,
                .boneIds = @ptrFromInt(0),
                .boneMatrices = @ptrFromInt(0),
                .boneWeights = @ptrFromInt(0),
                .colors = @ptrCast(colors_data),
                .indices = @ptrCast(indices_data),
                .normals = @ptrCast(normals_data),
                .tangents = @ptrFromInt(0),
                .texcoords = @ptrCast(texcoords_data),
                .texcoords2 = @ptrFromInt(0),
                .triangleCount = @intCast(tri_count),
                .vaoId = 0,
                .vboId = @ptrFromInt(0),
                .vertexCount = @intCast(vert_count),
                .vertices = @ptrCast(vertices_data),
            };
        };
        errdefer new_mesh.unload();

        // Reset the slices
        self.vertices = .{};
        self.indices = .{};
        self.normals = .{};
        self.colors = .{};
        self.texcoords = .{};
        self.next_id = 0;

        // Add the new mesh
        try self.built_meshes.append(self.alloc, new_mesh);
    }

    /// Gets the meshes and deinits the mesh builder
    /// No need to call deinit after
    pub fn getMeshesAndDeinit(self: *MeshBuilder) ![]rl.Mesh {
        try self.flush();
        return self.built_meshes.toOwnedSlice(self.alloc);
    }

    /// Not needed after getMeshesAndDeinit
    pub fn deinit(self: *MeshBuilder) void {
        self.built_meshes.deinit(self.alloc);
        self.vertices.deinit(self.alloc);
        self.indices.deinit(self.alloc);
        self.normals.deinit(self.alloc);
        self.colors.deinit(self.alloc);
        self.texcoords.deinit(self.alloc);
    }
};

pub fn deinit(self: ChunkModel, _: std.mem.Allocator) void {
    self.model.materials[0] = rl.loadMaterialDefault() catch undefined;
    self.model.unload();
    self.bl_tex.unload();
    self.sl_tex.unload();
}

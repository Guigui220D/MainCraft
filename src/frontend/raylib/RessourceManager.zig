//! Ressource manager for the raylib frontend

const std = @import("std");
const rl = @import("raylib");

const RessourceManager = @This();

/// Allocator
alloc: std.mem.Allocator,
/// Loaded textures
textures: std.StringHashMap(*rl.Texture),
/// Loaded models
models: std.StringHashMap(*rl.Model),
/// Loaded models
shaders: std.StringHashMap(*rl.Shader),
/// Loaded materials
materials: std.StringHashMap(*rl.Material),

/// Initializes the ressource manager (doesn't load ressources)
pub fn init(alloc: std.mem.Allocator) !RessourceManager {
    return .{
        .alloc = alloc,
        .textures = .init(alloc),
        .models = .init(alloc),
        .shaders = .init(alloc),
        .materials = .init(alloc),
    };
}

/// Loads all raylib ressources
pub fn loadAll(self: *RessourceManager) !void {
    // Textures
    try self.loadTexture("res/jar/minecraft/terrain.png");

    // Models
    try self.loadModel("res/kenney/character-a.glb");
    try self.loadModel("res/compass.glb");

    // Shaders
    try self.loadShader("chunk", null, "res/shaders/chunk.fs");

    // Materials
    try self.makeMaterial("chunk", "terrain.png", "chunk");
}

/// Unloads all raylib ressources
pub fn unloadAll(self: *RessourceManager) void {
    var tex_it = self.textures.iterator();
    while (tex_it.next()) |tex| {
        // TODO: why can't I unload?
        // yeah let the os take care of that
        //tex.value_ptr.*.unload();
        self.alloc.destroy(tex.value_ptr.*);
    }

    var mod_it = self.models.iterator();
    while (mod_it.next()) |mod| {
        //mod.value_ptr.*.unload();
        self.alloc.destroy(mod.value_ptr.*);
    }

    var sh_it = self.shaders.iterator();
    while (sh_it.next()) |sh| {
        //sh.value_ptr.*.unload();
        self.alloc.destroy(sh.value_ptr.*);
    }

    var mat_it = self.materials.iterator();
    while (mat_it.next()) |mat| {
        //mat.value_ptr.*.unload();
        self.alloc.destroy(mat.value_ptr.*);
    }
}

/// Loads a texture using its path
/// The name it will be referred to as is the file name from the path
fn loadTexture(self: *RessourceManager, path: [:0]const u8) !void {
    const name = std.fs.path.basename(path);

    var new_tex = try self.alloc.create(rl.Texture);
    errdefer self.alloc.destroy(new_tex);

    new_tex.* = try rl.loadTexture(path);
    errdefer new_tex.unload();

    try self.textures.put(name, new_tex);

    std.log.debug("Loaded texture {s}", .{name});
}

/// Loads a model using its path
/// The name it will be referred to as is the file name from the path
fn loadModel(self: *RessourceManager, path: [:0]const u8) !void {
    const name = std.fs.path.basename(path);

    var new_mod = try self.alloc.create(rl.Model);
    errdefer self.alloc.destroy(new_mod);

    new_mod.* = try rl.loadModel(path);
    errdefer new_mod.unload();

    try self.models.put(name, new_mod);

    std.log.debug("Loaded model {s}", .{name});
}

/// Loads a shader using its path
/// The name it will be referred to as is the file name from the path of the vertex shader (or the fragment shader)
fn loadShader(self: *RessourceManager, name: []const u8, path_vs: ?[:0]const u8, path_fs: ?[:0]const u8) !void {
    var new_sh = try self.alloc.create(rl.Shader);
    errdefer self.alloc.destroy(new_sh);

    new_sh.* = try rl.loadShader(path_vs, path_fs);
    errdefer new_sh.unload();

    try self.shaders.put(name, new_sh);

    std.log.debug("Loaded shader {s}", .{name});
}

/// Makes a material using a texture and a shader
fn makeMaterial(self: *RessourceManager, name: []const u8, texture_name: ?[:0]const u8, shader_name: ?[:0]const u8) !void {
    var new_mat = try self.alloc.create(rl.Material);
    errdefer self.alloc.destroy(new_mat);

    new_mat.* = try rl.loadMaterialDefault();
    errdefer new_mat.unload();

    if (texture_name) |tex_name| {
        new_mat.maps[0].texture = self.textures.get(tex_name).?.*;
    }

    if (shader_name) |sh_name| {
        new_mat.shader = self.shaders.get(sh_name).?.*;
    }

    try self.materials.put(name, new_mat);

    std.log.debug("Loaded material {s}", .{name});
}

/// Deinits the ressource manager (doesn't unload ressources)
pub fn deinit(self: *RessourceManager) void {
    self.textures.deinit();
    self.models.deinit();
    self.shaders.deinit();
    self.materials.deinit();
}

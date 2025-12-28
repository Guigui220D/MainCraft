//! The game window

const std = @import("std");
const rl = @import("raylib");

const coord = @import("coord");
const terrain = @import("terrain");
const entities = @import("entities");

const ChunkModel = @import("ChunkModel.zig");

const GameWindow = @This();

const screenWidth = 800;
const screenHeight = 450;

// Debug compass
// TODO: ressource manager
var compass: rl.Model = undefined;

camera: rl.Camera,
cube_position: rl.Vector3,
player_position: rl.Vector3,
first_player_pos: bool = true,
focused: bool = true,
f3_enabled: bool = false,
f3_buf: [512]u8 = undefined,
f3_str: [:0]const u8 = undefined,
wiremesh: bool = false,

pub fn init(alloc: std.mem.Allocator) !GameWindow {
    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(screenWidth, screenHeight, "MainCraft");
    errdefer rl.closeWindow();

    rl.disableCursor();
    rl.setTargetFPS(60);
    rl.setExitKey(.f1);

    if (getSplashTitle(alloc) catch null) |ti| {
        rl.setWindowTitle(ti);
        alloc.free(ti);
    }

    //rl.setTraceLogLevel(.warning);

    try ChunkModel.initMesher();
    errdefer ChunkModel.deinitMesher();

    compass = try rl.loadModel("res/compass.glb");
    errdefer compass.unload();

    return .{
        .camera = rl.Camera{
            .position = .init(0, 120, 0),
            .target = .init(10, 120, 0),
            .up = .init(0, 1, 0),
            .fovy = 60,
            .projection = .perspective,
        },
        .cube_position = .init(0, 0, 0),
        .player_position = undefined,
    };
}

pub fn hasClosed(_: GameWindow) bool {
    return rl.windowShouldClose();
}

pub fn update(self: *GameWindow) !void {
    if (rl.isMouseButtonPressed(.left)) {
        rl.disableCursor();
        self.focused = true;
    }

    if (!self.focused)
        return;

    if (rl.isKeyPressed(.escape) and self.focused) {
        rl.enableCursor();
        self.focused = false;
    }

    if (rl.isKeyPressed(.f3)) {
        self.f3_enabled = !self.f3_enabled;
    }

    if (rl.isKeyPressed(.f4)) {
        self.wiremesh = !self.wiremesh;
    }

    if (self.focused)
        self.camera.update(.free);

    if (self.f3_enabled) {
        const pos = self.camera.position;
        // TODO: coords function for that
        var pos_block: coord.Block = .{ .x = @intFromFloat(pos.x), .y = @intFromFloat(pos.y), .z = @intFromFloat(pos.z) };
        if (pos.x < 0)
            pos_block.x -= 1;
        if (pos.y < 0)
            pos_block.y -= 1;
        if (pos.z < 0)
            pos_block.z -= 1;
        const pos_chunk = pos_block.getChunk();
        const pos_in_chunk = pos_block.getPosInChunk();
        self.f3_str = try std.fmt.bufPrintZ(&self.f3_buf, "pos: {}\nblock: {}\nchunk: {}\nin chunk: {}\nfocused: {}", .{
            pos,
            pos_block,
            pos_chunk,
            pos_in_chunk,
            self.focused,
        });
    }
}

pub fn beginDraw(_: GameWindow) void {
    rl.beginDrawing();
    defer rl.clearBackground(.white);
}

pub fn drawWorld(self: GameWindow, world: terrain.World, entity_manager: entities.EntityManager) void {
    self.camera.begin();

    // Draw world
    if (self.wiremesh)
        rl.gl.rlEnableWireMode();

    var chunk_it = world.chunk_list.iterator();
    while (chunk_it.next()) |entry| {
        const chunk = entry.value_ptr.*;
        const chunk_pos = entry.key_ptr.*;
        if (self.f3_enabled) {
            // Draw chunk bottom/bounds (debug)
            rl.drawCubeWires(.{ .x = @floatFromInt(chunk_pos.x * 16 + 8), .y = 64, .z = @floatFromInt(chunk_pos.z * 16 + 8) }, 16, 128, 16, .red);
            rl.drawPlane(.{ .x = @floatFromInt(chunk_pos.x * 16 + 8), .y = 0, .z = @floatFromInt(chunk_pos.z * 16 + 8) }, .{ .x = 16, .y = 16 }, .magenta);
        }
        // Draw the solid part of the chunk
        if (chunk.model) |model| {
            model.draw(entry.key_ptr.*);
        }
    }

    // Draw the transparent part of chunks
    chunk_it = world.chunk_list.iterator();
    while (chunk_it.next()) |entry| {
        if (entry.value_ptr.*.model) |model| {
            model.drawTransparentLayer(entry.key_ptr.*);
        }
    }

    if (self.wiremesh)
        rl.gl.rlDisableWireMode();

    // Draw ourself
    rl.drawCube(self.player_position, 0.6, 1.8, 0.6, .dark_purple);

    // Draw entities
    var it = entity_manager.entities.iterator();
    while (it.next()) |entry| {
        const entity = entry.value_ptr.*;
        entity.draw();
    }

    // Draw 3d debug info
    if (self.f3_enabled) {
        const camdir = self.camera.target.subtract(self.camera.position).normalize();
        const sidedir = camdir.crossProduct(self.camera.up).normalize();
        const pos = self.camera.position.add(camdir.scale(0.1)).add(sidedir.scale(0.0));
        rl.drawModel(compass, pos, 0.005, .white);
    }

    self.camera.end();
}

pub fn drawGui(self: GameWindow) void {
    if (self.f3_enabled)
        rl.drawText(self.f3_str, 10, 10, 20, .black);
}

pub fn endDraw(_: GameWindow) void {
    rl.endDrawing();
}

pub fn deinit(_: GameWindow) void {
    compass.unload();
    ChunkModel.deinitMesher();
    rl.closeWindow();
}

pub fn setPlayerMarker(self: *GameWindow, pos: coord.Vec3f) void {
    self.player_position = .{ .x = @floatCast(pos.x), .y = @floatCast(pos.y), .z = @floatCast(pos.z) };
    // Set camera for the first time
    if (self.first_player_pos) {
        self.first_player_pos = false;
        self.camera.position = self.player_position;
    }
}

/// Silly thing to get a random splash screen line from the original minecraft
fn getSplashTitle(alloc: std.mem.Allocator) ![:0]const u8 {
    var splashes_file = try std.fs.cwd().openFile("res/jar/minecraft/title/splashes.txt", .{});
    defer splashes_file.close();

    var reader = splashes_file.reader(&.{});
    const lines = try reader.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(lines);

    const line_count = std.mem.count(u8, lines, "\n");

    var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
    const random = rng.random();

    const chosen_line = random.intRangeLessThan(usize, 0, line_count);
    var i: usize = 0;

    var line_it = std.mem.TokenIterator(u8, .scalar){ .buffer = lines, .delimiter = '\n', .index = 0 };
    while (line_it.next()) |line| {
        if (i == chosen_line) {
            return alloc.dupeZ(u8, line[0 .. line.len - 1]);
        }

        i += 1;
    }

    unreachable;
}

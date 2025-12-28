//! The game window

const std = @import("std");
const rl = @import("raylib");

const engine = @import("engine");
const coord = @import("coord");
const terrain = @import("terrain");
const entities = @import("entities");

const vec = @import("vec.zig");
const ChunkModel = @import("ChunkModel.zig");

const GameWindow = @This();

const screenWidth = 800;
const screenHeight = 450;

// Debug compass
// TODO: ressource manager
var compass: rl.Model = undefined;

camera: rl.Camera,
cam_rot: rl.Vector2,
cube_position: rl.Vector3,
first_player_pos: bool = true,
focused: bool = true,
f3_enabled: bool = false,
f3_buf: [512]u8 = undefined,
f3_str: [:0]const u8 = undefined,
freecam: bool = false,
wiremesh: bool = false,
game: ?*engine.Game = null,

pub fn init(_: std.mem.Allocator) !GameWindow {
    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(screenWidth, screenHeight, "Maincraft by Guigui220D");
    errdefer rl.closeWindow();

    rl.disableCursor();
    rl.setTargetFPS(60);
    rl.setExitKey(.f1);

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
        .cam_rot = .zero(),
    };
}

pub fn hasClosed(_: GameWindow) bool {
    return rl.windowShouldClose();
}

pub fn update(self: *GameWindow, delta: f32) !void {
    if (self.game == null)
        return;

    const game = self.game.?;

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

    if (rl.isKeyPressed(.tab)) {
        self.freecam = !self.freecam;
    }

    if (self.focused) {
        // Update camera
        if (self.freecam) {
            self.camera.update(.free);
        } else {
            // Take mouse movement in account
            self.cam_rot = self.cam_rot.add(rl.getMouseDelta().scale(delta * 10.0));
            // Clamp vertical rotation
            if (self.cam_rot.y > 89.9)
                self.cam_rot.y = 89.9;
            if (self.cam_rot.y < -89.9)
                self.cam_rot.y = -89.9;
            // Modulo the horizontal rotation
            while (self.cam_rot.x >= 360.0)
                self.cam_rot.x -= 360.0;
            while (self.cam_rot.x < 0)
                self.cam_rot.x += 360.0;

            const cam_rel_pos = rl.Vector3.init(0, 0, -1.0)
                .rotateByAxisAngle(.{ .x = 1.0, .y = 0.0, .z = 0.0 }, std.math.degreesToRadians(-self.cam_rot.y))
                .rotateByAxisAngle(.{ .x = 0.0, .y = 1.0, .z = 0.0 }, std.math.degreesToRadians(-self.cam_rot.x));

            self.camera.position = vec.coordToRlVec(game.player.pos);
            self.camera.target = self.camera.position.add(cam_rel_pos.scale(1.0));
        }
    }

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

pub fn enterGame(self: *GameWindow, game: *engine.Game) void {
    std.debug.print("Game started!\n", .{});
    self.game = game;
}

pub fn exitGame(self: *GameWindow) void {
    std.debug.print("Game stopped!\n", .{});
    self.game = null;
}

pub fn beginDraw(_: GameWindow) void {
    rl.beginDrawing();
    defer rl.clearBackground(.white);
}

pub fn drawWorld(self: GameWindow) void {
    if (self.game == null)
        return;

    const game = self.game.?;

    self.camera.begin();

    // Draw world
    if (self.wiremesh)
        rl.gl.rlEnableWireMode();

    var chunk_it = game.world.chunk_list.iterator();
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
    chunk_it = game.world.chunk_list.iterator();
    while (chunk_it.next()) |entry| {
        if (entry.value_ptr.*.model) |model| {
            model.drawTransparentLayer(entry.key_ptr.*);
        }
    }

    if (self.wiremesh)
        rl.gl.rlDisableWireMode();

    // Draw ourself
    rl.drawCube(vec.coordToRlVec(game.player.pos), 0.6, 1.8, 0.6, .dark_purple);

    // Draw entities
    var it = game.entities.entities.iterator();
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
    if (self.game == null) {
        rl.drawText("No game!", 10, 10, 20, .black);
        return;
    }

    if (self.freecam)
        rl.drawCircle(10, 10, 5, .red);

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

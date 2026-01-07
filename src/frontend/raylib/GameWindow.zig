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
cam_rel_pos: rl.Vector3,
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

    rl.setTraceLogLevel(.warning);

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
        .cam_rel_pos = .zero(),
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

    if (rl.isKeyPressed(.escape) and self.focused) {
        rl.enableCursor();
        self.focused = false;
    }

    if (rl.isKeyPressed(.f3) and self.focused) {
        self.f3_enabled = !self.f3_enabled;
    }

    if (rl.isKeyPressed(.f4) and self.focused) {
        self.wiremesh = !self.wiremesh;
    }

    if (rl.isKeyPressed(.tab) and self.focused) {
        self.freecam = !self.freecam;
    }

    if (self.focused) {
        if (self.freecam) {
            // Freecam mode
            self.camera.update(.free);
        } else {
            // Look around code
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

            const pitch = std.math.degreesToRadians(-self.cam_rot.y);
            const yaw = std.math.degreesToRadians(-self.cam_rot.x);

            self.cam_rel_pos = rl.Vector3.init(0, 0, -1.0)
                .rotateByAxisAngle(.{ .x = 1.0, .y = 0.0, .z = 0.0 }, pitch)
                .rotateByAxisAngle(.{ .x = 0.0, .y = 1.0, .z = 0.0 }, yaw);

            game.player.setHeadAngle(self.cam_rot.x, self.cam_rot.y);

            // Player movement
            if (rl.isKeyDown(.w)) {
                game.player.walkForwards();
            }
            if (rl.isKeyDown(.a)) {
                game.player.walkLeft();
            }
            if (rl.isKeyDown(.s)) {
                game.player.walkBackwards();
            }
            if (rl.isKeyDown(.d)) {
                game.player.walkRight();
            }
            if (rl.isKeyDown(.space))
                game.player.jump();
        }
    }

    // Update camera position
    if (!self.freecam) {
        // TODO: give the player a cam pos function (for head bobbing and whatnot)
        self.camera.position = vec.coordToRlVec(game.player.pos).add(.{ .x = 0, .y = 1.5, .z = 0 });
        self.camera.target = self.camera.position.add(self.cam_rel_pos.scale(1.0));
    }

    if (self.f3_enabled) {
        const cam_pos = self.camera.position;
        const pos = game.player.pos;
        const pos_block = pos.getBlock();
        const pos_chunk = pos_block.getChunk();
        const pos_in_chunk = pos_block.getPosInChunk();
        self.f3_str = try std.fmt.bufPrintZ(&self.f3_buf, "camera: {}\nplayer: {}\nblock: {}\nchunk: {}\nin chunk: {}\nfocused: {}", .{
            cam_pos,
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

    {
        game.world.meshes_mutex.lock();
        defer game.world.meshes_mutex.unlock();

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
            if (chunk.model_finalized) {
                if (chunk.model) |model| {
                    model.draw(entry.key_ptr.*);
                }
            }
        }

        // Draw the transparent part of chunks
        chunk_it = game.world.chunk_list.iterator();
        while (chunk_it.next()) |entry| {
            if (entry.value_ptr.*.model_finalized) {
                if (entry.value_ptr.*.model) |model| {
                    model.drawTransparentLayer(entry.key_ptr.*);
                }
            }
        }
    }

    if (self.wiremesh)
        rl.gl.rlDisableWireMode();

    // Draw ourself
    {
        const box = game.player.hitbox;
        const size = box.size();
        rl.drawCubeWires(
            vec.coordToRlVec(game.player.pos).add(.{ .x = 0, .y = @floatCast(size.y / 2.0), .z = 0 }),
            @floatCast(size.x),
            @floatCast(size.y),
            @floatCast(size.z),
            .dark_purple,
        );
    }

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

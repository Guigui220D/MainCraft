//! The game window

const std = @import("std");
const rl = @import("raylib");

const engine = @import("engine");
const coord = @import("coord");
const terrain = @import("terrain");
const entities = @import("entities");
const RessourceManager = @import("RessourceManager.zig");
const vec = @import("vec.zig");
const ChunkModel = @import("ChunkModel.zig");
const blocks = @import("blocks");

const GameWindow = @This();

const screenWidth = 800;
const screenHeight = 450;

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
ressource_manager: RessourceManager,
chunk_mat: *const rl.Material,
compass: *const rl.Model,
selected_block: ?coord.Block = null,
window_size: rl.Vector2,

pub fn init(alloc: std.mem.Allocator) !GameWindow {
    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(screenWidth, screenHeight, "Maincraft by Guigui220D");
    errdefer rl.closeWindow();

    rl.disableCursor();
    rl.setTargetFPS(60);
    rl.setExitKey(.f1);

    rl.setTraceLogLevel(.warning);

    var res_mana = try RessourceManager.init(alloc);
    errdefer res_mana.deinit();
    errdefer res_mana.unloadAll();
    try res_mana.loadAll();

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
        .ressource_manager = res_mana,
        .chunk_mat = res_mana.materials.get("chunk").?,
        .compass = res_mana.models.get("compass.glb").?,
        .window_size = .{ .x = @floatFromInt(rl.getScreenWidth()), .y = @floatFromInt(rl.getScreenHeight()) },
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

    if (rl.isWindowResized())
        self.window_size = .{ .x = @floatFromInt(rl.getScreenWidth()), .y = @floatFromInt(rl.getScreenHeight()) };

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

            // TODO: move that piece of code to player
            {
                var block_it = coord.raycast.sendRay(vec.rlVecToCoord(self.camera.position), vec.rlVecToCoord(self.cam_rel_pos), 4.5);
                const selected_block = while (block_it.next()) |block_info| {
                    const block_pos, _ = block_info;
                    if (game.world.getBlockId(block_pos) != 0)
                        break block_pos;
                } else null;

                self.selected_block = selected_block;
            }
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
        const time = game.time.load(.unordered);
        const block_id = if (self.selected_block) |selected| game.world.getBlockId(selected) else 0;
        self.f3_str = try std.fmt.bufPrintZ(&self.f3_buf, "camera: {}\nplayer: {}\nblock: {}\nchunk: {}\nin chunk: {}\nfocused: {}\ntime: {}\nblock aimed at: {?}\nblock id: {} {s}", .{
            cam_pos,
            pos,
            pos_block,
            pos_chunk,
            pos_in_chunk,
            self.focused,
            time,
            self.selected_block,
            block_id,
            blocks.table[block_id].name,
        });
    }
}

pub fn enterGame(self: *GameWindow, game: *engine.Game) void {
    std.log.info("Game started!", .{});
    self.game = game;
}

pub fn exitGame(self: *GameWindow) void {
    std.log.info("Game stopped!", .{});
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
            model.draw(entry.key_ptr.*, self.chunk_mat);
        }
    }

    // Draw the transparent part of chunks
    chunk_it = game.world.chunk_list.iterator();
    while (chunk_it.next()) |entry| {
        if (entry.value_ptr.*.model) |model| {
            model.drawTransparentLayer(entry.key_ptr.*, self.chunk_mat);
        }
    }

    if (self.wiremesh)
        rl.gl.rlDisableWireMode();

    // Draw ourself
    if (self.f3_enabled) {
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

    // Draw block selector/damage
    if (self.selected_block) |selected|
        rl.drawCubeWires(vec.coordToRlVec(selected.toVec3(f64)).add(.{ .x = 0.51, .y = 0.51, .z = 0.51 }), 1.05, 1.05, 1.05, .black);

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
        rl.drawModel(self.compass.*, pos, 0.005, .white);
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

    rl.drawCircleLinesV(self.window_size.scale(0.5), 5, .black);
}

pub fn endDraw(_: GameWindow) void {
    rl.endDrawing();
}

pub fn deinit(self: *GameWindow) void {
    rl.closeWindow();
    self.ressource_manager.unloadAll();
    self.ressource_manager.deinit();
}

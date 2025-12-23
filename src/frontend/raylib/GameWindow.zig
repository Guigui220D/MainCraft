//! The game window

const std = @import("std");
const rl = @import("raylib");

const coord = @import("coord");
const terrain = @import("terrain");

const GameWindow = @This();

const screenWidth = 800;
const screenHeight = 450;

camera: rl.Camera,
cube_position: rl.Vector3,
player_position: rl.Vector3,
first_player_pos: bool = true,
focused: bool = true,

pub fn init() !GameWindow {
    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(screenWidth, screenHeight, "Maincraft - Zig Minecraft client by Guigui220D - b1.7.3");
    errdefer rl.closeWindow();

    rl.disableCursor();
    rl.setTargetFPS(60);
    rl.setExitKey(.f1);

    rl.setTraceLogLevel(.warning);

    return .{
        .camera = rl.Camera{
            .position = .init(0, 120, 0),
            .target = .init(10, 120, 0),
            .up = .init(0, 1, 0),
            .fovy = 45,
            .projection = .perspective,
        },
        .cube_position = .init(0, 0, 0),
        .player_position = undefined,
    };
}

pub fn hasClosed(_: GameWindow) bool {
    return rl.windowShouldClose();
}

pub fn update(self: *GameWindow) void {
    if (rl.isKeyPressed(.escape) and self.focused) {
        rl.enableCursor();
        self.focused = false;
    }
    if (rl.isMouseButtonPressed(.left)) {
        rl.disableCursor();
        self.focused = true;
    }

    if (self.focused)
        self.camera.update(.free);
}

pub fn beginDraw(self: GameWindow) void {
    rl.beginDrawing();
    defer rl.clearBackground(.white);

    self.camera.begin();
}

pub fn drawWorld(self: GameWindow, world: terrain.World) void {
    var chunk_it = world.chunk_list.iterator();
    while (chunk_it.next()) |entry| {
        if (entry.value_ptr.*.model) |model| {
            model.draw(entry.key_ptr.*);
        }
    }

    rl.drawSphere(self.player_position, 0.4, .dark_purple);
}

pub fn endDraw(self: GameWindow) void {
    self.camera.end();
    rl.endDrawing();
}

pub fn deinit(_: GameWindow) void {
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

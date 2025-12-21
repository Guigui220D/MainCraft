//! The game window

const std = @import("std");
const rl = @import("raylib");

const terrain = @import("terrain");

const GameWindow = @This();

const screenWidth = 800;
const screenHeight = 450;

camera: rl.Camera,
cube_position: rl.Vector3,

pub fn init() !GameWindow {
    rl.initWindow(screenWidth, screenHeight, "Maincraft - Zig Minecraft client by Guigui220D - b1.7.3");
    errdefer rl.closeWindow();

    rl.disableCursor();
    rl.setTargetFPS(60);

    return .{
        .camera = rl.Camera{
            .position = .init(0, 120, 0),
            .target = .init(10, 120, 0),
            .up = .init(0, 1, 0),
            .fovy = 45,
            .projection = .perspective,
        },
        .cube_position = .init(0, 0, 0),
    };
}

pub fn hasClosed(_: GameWindow) bool {
    return rl.windowShouldClose();
}

pub fn update(self: *GameWindow) void {
    self.camera.update(.free);
}

pub fn beginDraw(self: GameWindow) void {
    rl.beginDrawing();
    defer rl.clearBackground(.white);
    rl.drawText("Hello from Maincraft", 190, 200, 20, .light_gray);

    self.camera.begin();
}

pub fn drawWorld(self: GameWindow, world: terrain.World) void {
    _ = self;
    var chunk_it = world.chunk_list.iterator();
    while (chunk_it.next()) |entry| {
        if (entry.value_ptr.*.model) |model| {
            model.draw(entry.key_ptr.*);
        }
    }
}

pub fn endDraw(self: GameWindow) void {
    self.camera.end();
    rl.endDrawing();
}

pub fn deinit(_: GameWindow) void {
    rl.closeWindow();
}

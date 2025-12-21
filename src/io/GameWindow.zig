//! The game window

const std = @import("std");
const rl = @import("raylib");

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
            .position = .init(10, 10, 10),
            .target = .init(0, 0, 0),
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

pub fn draw(self: GameWindow) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.white);

    {
        self.camera.begin();
        defer self.camera.end();

        rl.drawCube(self.cube_position, 2, 2, 2, .red);
        rl.drawCubeWires(self.cube_position, 2, 2, 2, .maroon);

        rl.drawGrid(10, 1);
    }

    rl.drawText("Hello from Maincraft", 190, 200, 20, .light_gray);
}

pub fn deinit(_: GameWindow) void {
    rl.closeWindow();
}

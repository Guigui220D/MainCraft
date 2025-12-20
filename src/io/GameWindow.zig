//! The game window

const std = @import("std");
const rl = @import("raylib");

const GameWindow = @This();

const screenWidth = 800;
const screenHeight = 450;

pub fn init() !GameWindow {
    rl.initWindow(screenWidth, screenHeight, "Maincraft - Zig Minecraft client by Guigui220D - b1.7.3");
    errdefer rl.closeWindow();

    return .{};
}

pub fn hasClosed(_: GameWindow) bool {
    return rl.windowShouldClose();
}

pub fn draw(_: GameWindow) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.white);

    rl.drawText("Hello from Maincraft", 190, 200, 20, .light_gray);
}

pub fn deinit(_: GameWindow) void {
    rl.closeWindow();
}

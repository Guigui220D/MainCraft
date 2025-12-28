//! The game window

const std = @import("std");
const rl = @import("raylib");

const engine = @import("engine");
const coord = @import("coord");
const terrain = @import("terrain");
const entities = @import("entities");

const GameWindow = @This();

pub fn init(_: std.mem.Allocator) !GameWindow {
    return .{};
}

pub fn hasClosed(_: GameWindow) bool {
    return false;
}

pub fn update(_: *GameWindow, _: f32) !void {
    // Slow down to reach 60 fps
    std.Thread.sleep(16000000);
}

pub fn enterGame(_: *GameWindow, _: *engine.Game) void {
    std.debug.print("Game started!\n", .{});
}

pub fn exitGame(_: *GameWindow) void {
    std.debug.print("Game stopped!\n", .{});
}

pub fn beginDraw(_: GameWindow) void {}

pub fn drawWorld(_: GameWindow, _: terrain.World, _: entities.EntityManager) void {}

pub fn drawGui(_: GameWindow) void {}

pub fn endDraw(_: GameWindow) void {}

pub fn deinit(_: GameWindow) void {}

//! The game window

const std = @import("std");
const rl = @import("raylib");

const coord = @import("coord");
const terrain = @import("terrain");

const GameWindow = @This();

pub fn init(_: std.mem.Allocator) !GameWindow {
    std.Thread.sleep(2000000000);
    return .{};
}

pub fn hasClosed(_: GameWindow) bool {
    return false;
}

pub fn update(_: *GameWindow) !void {
    // Slow down to reach 60 fps
    std.Thread.sleep(16000000);
}

pub fn beginDraw(_: GameWindow) void {}

pub fn drawWorld(_: GameWindow, _: terrain.World) void {}

pub fn drawGui(_: GameWindow) void {}

pub fn endDraw(_: GameWindow) void {}

pub fn deinit(_: GameWindow) void {}

pub fn setPlayerMarker(_: *GameWindow, _: coord.Vec3f) void {}

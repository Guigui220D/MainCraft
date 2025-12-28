//! Entry point of the frontend

const std = @import("std");
const engine = @import("engine");

const GameWindow = @import("GameWindow.zig");

/// Entry point of the frontend
pub fn main(default_alloc: std.mem.Allocator) !void {
    const alloc = default_alloc;

    var window: GameWindow = try .init(alloc);
    defer window.deinit();

    var client: engine.Client = undefined;

    try client.init(alloc, &window, "localhost", 25565);
    defer client.deinit();

    window.enterGame(&client.game);
    defer window.exitGame();

    while (try client.update()) {}
}

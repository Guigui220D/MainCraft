//! Entry point of the frontend

const std = @import("std");
const rl = @import("raylib");
const engine = @import("engine");
const tracy = @import("tracy");

const GameWindow = @import("GameWindow.zig");

/// Entry point of the frontend
pub fn main(default_alloc: std.mem.Allocator) !void {
    const alloc = default_alloc;

    var window: GameWindow = try .init(alloc);
    defer window.deinit();

    var client: engine.Client = undefined;

    std.log.info("Connecting...", .{});
    client.init(alloc, &window, "localhost", 25565) catch |e| {
        if (e == error.CouldNotConnect) {
            std.log.err("Could not connect to server!", .{});
            return;
        } else {
            return e;
        }
    };
    defer client.deinit();
    std.log.debug("Client started", .{});

    window.enterGame(&client.game);
    defer window.exitGame();

    // TODO: make menus
    while (!window.hasClosed()) {
        const dt = rl.getFrameTime();

        if (!try client.update(dt))
            break;

        // TODO: who should call that?
        try window.update(dt);
        {
            const zone = tracy.Zone.begin(.{
                .name = "Game draw",
                .src = @src(),
                .color = .red1,
            });
            defer zone.end();
            window.beginDraw();
            window.drawWorld();
            window.drawGui();
        }
        window.endDraw();
    }
}

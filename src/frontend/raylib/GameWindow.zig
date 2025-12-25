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

// TODO: add debug compass

pub fn init(alloc: std.mem.Allocator) !GameWindow {
    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(screenWidth, screenHeight, "MainCraft");
    errdefer rl.closeWindow();

    rl.disableCursor();
    rl.setTargetFPS(60);
    rl.setExitKey(.f1);

    if (getSplashTitle(alloc) catch null) |ti| {
        rl.setWindowTitle(ti);
        alloc.free(ti);
    }

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

/// Silly thing to get a random splash screen line from the original minecraft
fn getSplashTitle(alloc: std.mem.Allocator) ![:0]const u8 {
    var splashes_file = try std.fs.cwd().openFile("res/jar/minecraft/title/splashes.txt", .{});
    defer splashes_file.close();

    var reader = splashes_file.reader(&.{});
    const lines = try reader.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(lines);

    const line_count = std.mem.count(u8, lines, "\n");

    var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
    const random = rng.random();

    const chosen_line = random.intRangeLessThan(usize, 0, line_count);
    var i: usize = 0;

    var line_it = std.mem.TokenIterator(u8, .scalar){ .buffer = lines, .delimiter = '\n', .index = 0 };
    while (line_it.next()) |line| {
        if (i == chosen_line) {
            return alloc.dupeZ(u8, line[0 .. line.len - 1]);
        }

        i += 1;
    }

    unreachable;
}

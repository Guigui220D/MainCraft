//! Main structure containing the state of the game

const std = @import("std");
const net = @import("net");
const io = @import("io");
const tracy = @import("tracy");

const Entities = @import("entities").EntityManager;
const World = @import("terrain").World;
const Client = @import("Client.zig");
const Game = @This();

const Player = @import("Player.zig");

/// Allocator
alloc: std.mem.Allocator,

/// Reference to the client class
client: *Client,

/// Reference to the window (TODO: does that make sense?)
window: *io.GameWindow,

/// Timestamp of last time we did a game tick
last_tick: i64,

// Game data
/// World
world: World,
/// Entities
entities: Entities,
/// Player
player: Player,

/// Inits a game state
pub fn init(game: *Game, alloc: std.mem.Allocator, client: *Client, window: *io.GameWindow) !void {
    // References to components
    game.alloc = alloc;
    game.client = client;
    game.window = window;

    // General variables
    game.last_tick = 0;

    // Game state components
    game.world = try World.init(alloc);
    errdefer game.world.deinit();

    game.entities = try Entities.init(alloc);
    errdefer game.entities.deinit();

    game.player = .init(game);
}

/// Deinits the game state
pub fn deinit(self: *Game) void {
    self.world.deinit();
    self.entities.deinit();
}

// Update game engine
pub fn update(self: *Game, delta: f32) !void {
    const zone = tracy.Zone.begin(.{
        .name = "Game update",
        .src = @src(),
        .color = .blue2,
    });
    defer zone.end();

    _ = try self.world.updateModels();

    self.player.update(delta);
    _ = try self.maybeTick();
}

/// Run engine tick if enough time has passed
fn maybeTick(self: *Game) !bool {
    const do_tick = self.shouldTick();
    if (do_tick)
        try self.tick();
    return do_tick;
}

/// Run engine tick
fn tick(self: *Game) !void {
    const zone = tracy.Zone.begin(.{
        .name = "Game tick",
        .src = @src(),
        .color = .blue3,
    });
    defer zone.end();

    if (self.client.is_connected) {
        const position_packet = self.player.makePositionPacket();
        self.client.enqueuePacket(position_packet);
    }
}

/// Accept a packet a take it into consideration in the game state
/// Does not own the packet
pub fn handlePacket(self: *Game, packet: net.InboundPacket) !void {
    switch (packet) {
        .chat_3 => |chat| {
            std.debug.print("\"{s}\"\n", .{chat.message});
        },
        .update_time_4 => |time| {
            _ = time;
            // TODO: handle time
        },
        .player_look_move_13 => |plm| {
            self.player.resetPosition(.{
                .x = plm.x_position,
                .y = plm.y_position,
                .z = plm.z_position,
            });
            self.player.resetHeadAngle(plm.yaw, plm.pitch);
        },
        .animation_18 => |anim| {
            self.entities.get(anim.entity_id).?.startAnimation(anim.animation);
        },
        .named_entity_spawn_20 => |sp| {
            try self.entities.addOtherPlayer(
                sp.entity_id,
                .fromIntsDiv32(sp.x_position, sp.y_position, sp.z_position),
                sp.name,
            );
        },
        .pickup_spawn_21 => |sp| {
            try self.entities.addEntity(
                sp.entity_id,
                .fromIntsDiv32(sp.x_position, sp.y_position, sp.z_position),
                .item,
            );
        },
        .inanimate_spawn_23 => |_| {
            // TODO: "vehicle" (inanimate) entities
            //try self.entities.addEntity(
            //    sp.entity_id,
            //    .fromIntsDiv32(sp.x_position, sp.y_position, sp.z_position),
            //    @enumFromInt(sp.entity_type),
            //);
        },
        .mob_spawn_24 => |sp| {
            self.entities.addEntity(
                sp.entity_id,
                .fromIntsDiv32(sp.x_position, sp.y_position, sp.z_position),
                //@enumFromInt(sp.entity_type),
                .pig, // Before I fix it
            ) catch |e| {
                std.debug.print("Couldn't add entity {}, error {}\n", .{ sp.entity_id, e });
            };
        },
        .destroy_entity_29 => |stroy| {
            try self.entities.removeEntity(stroy.entity_id);
        },
        .rel_entity_move_31 => |move| {
            // TODO: no need to crash when the entity is not found
            self.entities.get(move.entity_id).?.move(
                .fromIntsDiv32(move.x_position, move.y_position, move.z_position),
            );
        },
        .rel_entity_move_look_33 => |move| {
            self.entities.get(move.entity_id).?.move(
                .fromIntsDiv32(move.x_position, move.y_position, move.z_position),
            );
        },
        .entity_teleport_34 => |tp| {
            self.entities.get(tp.entity_id).?.setPosition(
                .fromIntsDiv32(tp.x_position, tp.y_position, tp.z_position),
            );
        },
        .pre_chunk_50 => |pc| {
            try self.world.doPreChunk(.{ .x = pc.x_position, .z = pc.z_position }, pc.mode);
        },
        .map_chunk_51 => |mc| {
            try self.world.doChunkMap(
                mc.x_position,
                mc.y_position,
                mc.z_position,
                mc.x_size,
                mc.y_size,
                mc.z_size,
                mc.data,
            );
        },
        .multi_block_change_52 => |mbc| {
            try self.world.doMultiBlockChange(
                .{ .x = mbc.x_position, .z = mbc.z_position },
                mbc.coord_array,
                mbc.block_ids,
                mbc.block_metas,
            );
        },
        .block_change_53 => |bc| {
            try self.world.setBlockIdAndMetadata(
                .{ .x = bc.x_position, .y = bc.y_position, .z = bc.z_position },
                bc.block_id,
                @truncate(bc.block_meta),
            );
        },
        inline else => |pack| {
            if (!@hasDecl(@TypeOf(pack), "do_not_print"))
                std.debug.print("{any}\n", .{packet});
        },
    }
}

/// Returns true when enough time has passed and game should tick
fn shouldTick(self: *Game) bool {
    if (std.time.milliTimestamp() - self.last_tick >= 50) {
        self.last_tick = std.time.milliTimestamp();
        return true;
    } else {
        return false;
    }
}

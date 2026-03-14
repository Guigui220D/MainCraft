//! Main structure containing the state of the game

const std = @import("std");
const net = @import("net");
const io = @import("io");
const tracy = @import("tracy");

const Entities = @import("entities.zig").EntityManager;
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
/// Time
time: std.atomic.Value(i64),
/// Server time: when the server gives us a time that is < than our own time, store it in server time to catch up
server_time: i64,

/// Inits a game state
pub fn init(game: *Game, alloc: std.mem.Allocator, client: *Client, window: *io.GameWindow) !void {
    // References to components
    game.alloc = alloc;
    game.client = client;
    game.window = window;

    // General variables
    game.last_tick = 0;
    game.time = .init(0);
    game.server_time = 0;

    // Game state components
    game.world = try World.init(alloc);
    errdefer game.world.deinit();

    game.entities = try Entities.init(alloc, game);
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

    _ = try self.world.updateModel();

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

    // Increment time
    {
        const time = self.time.load(.unordered);
        if (self.server_time != 0) {
            self.server_time += 1;
            if (self.server_time >= time) {
                self.server_time = 0;
            }
        } else {
            self.time.store(time + 1, .unordered);
        }
    }

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
            std.log.info("Chat: \"{s}\"", .{chat.message});
        },
        .update_time_4 => |time| {
            const current_time = self.time.load(.unordered);
            if (current_time > time.time) {
                // We are too early
                self.server_time = time.time;
                std.log.debug("Clock too early!", .{});
            } else {
                // We are on time or late
                self.time.store(time.time, .unordered);
            }
        },
        .player_look_move_13 => |plm| {
            std.log.warn("Player rollback! Possibily illegal movement", .{});
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
                std.log.err("Couldn't add entity {}, error {}", .{ sp.entity_id, e });
            };
        },
        .destroy_entity_29 => |stroy| {
            try self.entities.removeEntity(stroy.entity_id);
        },
        .rel_entity_move_31 => |move| {
            if (self.entities.get(move.entity_id)) |entity| {
                entity.move(
                    .fromIntsDiv32(move.x_position, move.y_position, move.z_position),
                );
            }
        },
        .rel_entity_move_look_33 => |move| {
            if (self.entities.get(move.entity_id)) |entity| {
                entity.move(
                    .fromIntsDiv32(move.x_position, move.y_position, move.z_position),
                );
            }
        },
        .entity_teleport_34 => |tp| {
            if (self.entities.get(tp.entity_id)) |entity| {
                entity.move(
                    .fromIntsDiv32(tp.x_position, tp.y_position, tp.z_position),
                );
            }
        },
        .pre_chunk_50 => |pc| {
            try self.world.doPreChunk(.{ .x = pc.x_position, .z = pc.z_position }, pc.mode);
        },
        .map_chunk_51 => |mc| {
            self.world.doChunkMap(
                mc.x_position,
                mc.y_position,
                mc.z_position,
                mc.x_size,
                mc.y_size,
                mc.z_size,
                mc.data,
            ) catch |e| {
                std.log.err("Couldn't do chunk map near x:{}, z:{}, error {}", .{ mc.x_position, mc.z_position, e });
            };
        },
        .multi_block_change_52 => |mbc| {
            self.world.doMultiBlockChange(
                .{ .x = mbc.x_position, .z = mbc.z_position },
                mbc.coord_array,
                mbc.block_ids,
                mbc.block_metas,
            ) catch |e| {
                std.log.err("Edit chunk at x:{}, z:{}, error {}", .{ mbc.x_position, mbc.z_position, e });
            };
        },
        .block_change_53 => |bc| {
            self.world.setBlockIdAndMetadata(
                .{ .x = bc.x_position, .y = bc.y_position, .z = bc.z_position },
                bc.block_id,
                @truncate(bc.block_meta),
            ) catch |e| {
                std.log.err("Couldn't set block at x:{}, z:{}, error {}", .{ bc.x_position, bc.z_position, e });
            };
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

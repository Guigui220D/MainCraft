//! Main structure containing the state of the game

const std = @import("std");
const net = @import("net");
const io = @import("io");

const Entities = @import("entities").EntityManager;
const World = @import("terrain").World;

const Client = @import("Client.zig");
const Game = @This();

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
/// Temporary
last_plm: net.server_bound.Packet13PlayerLookMove,

/// Inits a game state
pub fn init(alloc: std.mem.Allocator, client: *Client, window: *io.GameWindow) !Game {
    var ret: Game = undefined;

    // References to components
    ret.alloc = alloc;
    ret.client = client;
    ret.window = window;

    // General variables
    ret.last_tick = 0;

    // Game state components
    ret.world = try World.init(alloc);
    errdefer ret.world.deinit();

    ret.entities = try Entities.init(alloc);
    errdefer ret.entities.deinit();

    return ret;
}

/// Deinits the game state
pub fn deinit(self: *Game) void {
    self.world.deinit();
    self.entities.deinit();
}

/// Run engine tick if enough time has passed
pub fn maybeTick(self: *Game) !bool {
    const do_tick = self.shouldTick();
    if (do_tick)
        try self.tick();
    return do_tick;
}
/// Run engine tick
fn tick(self: *Game) !void {
    if (self.client.is_connected) {
        // Temporary thing so server considers us alive (TODO: actual physics)
        self.last_plm.y_position -= 0.1;
        self.last_plm.y_center_position -= 0.1;
        if (self.last_plm.y_center_position < self.last_plm.y_position) {
            const swap = self.last_plm.y_center_position;
            self.last_plm.y_center_position = self.last_plm.y_position;
            self.last_plm.y_position = swap;
        }
        self.client.enqueuePacket(self.last_plm);
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
            self.last_plm = plm;
            self.window.setPlayerMarker(.{ .x = plm.x_position, .y = plm.y_position, .z = plm.z_position });
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
            try self.entities.addEntity(
                sp.entity_id,
                .fromIntsDiv32(sp.x_position, sp.y_position, sp.z_position),
                @enumFromInt(sp.entity_type),
            );
        },
        .destroy_entity_29 => |stroy| {
            try self.entities.removeEntity(stroy.entity_id);
        },
        .rel_entity_move_31 => |move| {
            // TODO: no need to crash when the entity is not found
            try self.entities.moveEntity(
                move.entity_id,
                .fromIntsDiv32(move.x_position, move.y_position, move.z_position),
            );
        },
        .rel_entity_move_look_33 => |move| {
            try self.entities.moveEntity(
                move.entity_id,
                .fromIntsDiv32(move.x_position, move.y_position, move.z_position),
            );
        },
        .entity_teleport_34 => |tp| {
            try self.entities.setEntityPosition(
                tp.entity_id,
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
        .block_change_53 => |bc| {
            std.debug.print("Set Block\n", .{});
            try self.world.setBlockId(
                .{ .x = bc.x_position, .y = bc.y_position, .z = bc.z_position },
                bc.block_id,
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

//! List of entity instances that exist in the world

pub const std = @import("std");
const coord = @import("coord");

const Game = @import("../Game.zig");

const Entity = @import("Entity.zig");

const EntityManager = @This();

game: *Game,
entities: std.AutoArrayHashMap(i32, *Entity),
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator, game: *Game) !EntityManager {
    return .{
        .game = game,
        .alloc = alloc,
        .entities = .init(alloc),
    };
}

pub fn deinit(self: *EntityManager) void {
    var it = self.entities.iterator();

    while (it.next()) |ent| {
        self.alloc.destroy(ent.value_ptr.*);
    }

    self.entities.deinit();
}

pub fn addEntity(self: *EntityManager, id: i32, pos: coord.Vec3f, ent_type: Entity.Type) !void {
    const new_ent = try self.alloc.create(Entity);
    errdefer self.alloc.destroy(new_ent);

    new_ent.* = .{
        .id = id,
        .pos = pos,
        .data = .initData(ent_type),
        .entity_model = try .initForEntity(self.alloc, new_ent, self.game.window),
    };
    errdefer new_ent.entity_model.deinit(self.alloc);

    if (self.entities.contains(id))
        return error.EntityAlreadyExists;

    try self.entities.put(id, new_ent);

    std.log.debug("Added {} entity {} at {any}", .{ ent_type, id, pos });
}

pub fn addOtherPlayer(self: *EntityManager, id: i32, pos: coord.Vec3f, name: []const u8) !void {
    const new_ent = try self.alloc.create(Entity);
    errdefer self.alloc.destroy(new_ent);

    // TODO: own name (dupe it)
    new_ent.* = .{
        .id = id,
        .pos = pos,
        .data = .{ .player = .{ .username = name } },
        .entity_model = try .initForEntity(self.alloc, new_ent, self.game.window),
    };
    errdefer new_ent.entity_model.deinit(self.alloc);

    if (self.entities.contains(id))
        return error.EntityAlreadyExists;

    try self.entities.put(id, new_ent);

    std.log.debug("Added player {} named \"{s}\" at {any}", .{ id, name, pos });
}

pub fn removeEntity(self: *EntityManager, id: i32) !void {
    const kv = self.entities.fetchSwapRemove(id) orelse {
        std.log.err("Couldn't remove entity {} (doesn't exist)", .{id});
        return;
    };

    self.alloc.destroy(kv.value);

    std.log.debug("Removed entity {}", .{id});
}

pub fn get(self: *EntityManager, entity_id: i32) ?*Entity {
    return self.entities.get(entity_id);
}

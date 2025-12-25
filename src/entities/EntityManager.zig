//! List of entity instances that exist in the world

pub const std = @import("std");
const coord = @import("coord");

const Entity = @import("Entity.zig");

const EntityManager = @This();

entities: std.AutoArrayHashMap(i32, *Entity),
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator) !EntityManager {
    return .{
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

    new_ent.* = .{ .pos = pos, .ent_type = ent_type };

    if (self.entities.contains(id))
        return error.EntityAlreadyExists;

    try self.entities.put(id, new_ent);

    std.debug.print("Added {} entity {} at {any}\n", .{ ent_type, id, pos });
}

pub fn removeEntity(self: *EntityManager, id: i32) !void {
    const kv = self.entities.fetchSwapRemove(id) orelse {
        std.debug.print("Couldn't remove entity {} (doesn't exist)\n", .{id});
        return;
    };

    self.alloc.destroy(kv.value);

    std.debug.print("Removed entity {}\n", .{id});
}

// Temporary: prototyping
pub fn setEntityPosition(self: *EntityManager, id: i32, pos: coord.Vec3f) !void {
    const entity = self.entities.get(id) orelse return error.EntityNotFound;
    entity.pos = pos;
}

// Temporary: prototyping
pub fn moveEntity(self: *EntityManager, id: i32, mov: coord.Vec3f) !void {
    const entity = self.entities.get(id) orelse return error.EntityNotFound;
    entity.pos = .{
        .x = entity.pos.x + mov.x,
        .y = entity.pos.y + mov.y,
        .z = entity.pos.z + mov.z,
    };
}

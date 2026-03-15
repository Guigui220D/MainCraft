//! An entity's visual representation
//! This is specific to the IO and can be modified independently of the entity's actual representation

const std = @import("std");
const coord = @import("coord");
const Entity = @import("engine").entities.Entity;
const GameWindow = @import("GameWindow.zig");
const DrawContext = @import("DrawContext.zig");

const EntityModel = @This();

entity: *Entity,

pub fn initForEntity(_: std.mem.Allocator, entity: *Entity, _: *GameWindow) !EntityModel {
    return .{
        .entity = entity,
    };
}

pub fn draw(_: Entity, _: DrawContext) void {}

pub fn startAnimation(_: *EntityModel, _: u8) void {
    //std.debug.print("Entity {}: animation {}\n", .{ self.entity.id, anim });
}

pub fn deinit(_: EntityModel, _: std.mem.Allocator) void {}

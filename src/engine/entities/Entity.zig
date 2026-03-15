//! Entity

const std = @import("std");
const io = @import("io");
const coord = @import("coord");
const DrawContext = io.DrawContext;

const Entity = @This();

pub const Type = @import("entity_types.zig").EntityType;

id: i32,
pos: coord.Vec3f,
data: Data,
entity_model: io.EntityModel,

// Temporary: prototyping
pub fn setPosition(self: *Entity, pos: coord.Vec3f) void {
    self.pos = pos;
}

// Temporary: prototyping
pub fn move(self: *Entity, mov: coord.Vec3f) void {
    self.pos.x += mov.x;
    self.pos.y += mov.y;
    self.pos.z += mov.z;
}

pub fn startAnimation(self: *Entity, animation: u8) void {
    self.entity_model.startAnimation(animation);
}

pub fn draw(self: Entity, context: DrawContext) void {
    self.entity_model.draw(context);
}

pub const Data = union(Type) {
    pub fn initData(entity_type: Type) Data {
        return switch (entity_type) {
            .item => .{ .item = undefined },
            .painting => .{ .painting = undefined },
            .arrow => .{ .arrow = undefined },
            .snowball => .{ .snowball = undefined },
            .primed_tnt => .{ .primed_tnt = undefined },
            .falling_sand => .{ .falling_sand = undefined },
            .minecart => .{ .minecart = undefined },
            .boat => .{ .boat = undefined },
            .mob => .{ .mob = undefined },
            .monster => .{ .monster = undefined },
            .creeper => .{ .creeper = undefined },
            .skeleton => .{ .skeleton = undefined },
            .giant => .{ .giant = undefined },
            .zombie => .{ .zombie = undefined },
            .slime => .{ .slime = undefined },
            .ghast => .{ .ghast = undefined },
            .pig_zombie => .{ .pig_zombie = undefined },
            .pig => .{ .pig = undefined },
            .sheep => .{ .sheep = undefined },
            .cow => .{ .cow = undefined },
            .chicken => .{ .chicken = undefined },
            .squid => .{ .squid = undefined },
            .wolf => .{ .wolf = undefined },
            .player => .{ .player = undefined },
            _ => {
                std.log.err("Unexpected entity type: {}", .{entity_type});
                // unreachable
                return .{ .pig = undefined }; // Temporary placeholder to avoid crashing
            },
        };
    }

    item: void,
    painting: void,
    arrow: void,
    snowball: void,
    primed_tnt: void,
    falling_sand: void,
    minecart: void,
    boat: void,
    mob: void,
    monster: void,
    creeper: void,
    skeleton: void,
    giant: void,
    zombie: void,
    slime: void,
    ghast: void,
    pig_zombie: void,
    pig: void,
    sheep: void,
    cow: void,
    chicken: void,
    squid: void,
    wolf: void,
    player: @import("entities/OtherPlayer.zig"),
};

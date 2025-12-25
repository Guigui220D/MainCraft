//! Entity

const std = @import("std");
const coord = @import("coord");

pub const Type = @import("entity_types.zig").EntityType;

pos: coord.Vec3f,
data: Data,

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
                std.debug.print("Unexpected entity type: {}\n", .{entity_type});
                return undefined;
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

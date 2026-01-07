//! List of all existing blocks

const std = @import("std");

pub const Block = @import("Block.zig");
pub const BlockModel = Block.BlockModel;

fn texpos(x: comptime_int, y: comptime_int) comptime_int {
    return y * 16 + x;
}

/// Generate the blocks enum at compile time
pub const blocks_enum = blk: {
    @setEvalBranchQuota(5000);
    var fields_ret: []const std.builtin.Type.EnumField = &.{};

    for (table, 0..) |block_def, i| {
        const name = (block_def.name ++ &[_]u8{0})[0..block_def.name.len :0];
        // Block doesn't exist
        if (name.len == 0)
            continue;

        // Check that we didn't already add that name
        if (for (fields_ret) |existing_field| {
            if (std.mem.eql(u8, existing_field.name, name))
                break true;
        } else false)
            continue;

        // Add to the fields
        fields_ret = fields_ret ++ &[_]std.builtin.Type.EnumField{.{
            .name = name,
            .value = i,
        }};
    }

    // Reify
    const enum_ret: std.builtin.Type.Enum = .{
        .decls = &.{},
        .fields = fields_ret,
        .is_exhaustive = false,
        .tag_type = u8,
    };
    break :blk @Type(.{ .@"enum" = enum_ret });
};

/// Table of all block types
pub const table = [256]Block{
    // 0
    .{ .name = "air", .flags = .{ .hitbox = false, .transparent = true } },
    .{ .name = "stone", .tex_id = 1 },
    .{ .name = "grass", .tex_id = 3, .top_tex_id = 0, .bottom_tex_id = 2, .flags = .{ .model = .full_barrel } },
    .{ .name = "dirt", .tex_id = 2 },
    .{ .name = "cobblestone", .tex_id = texpos(0, 1) },
    .{ .name = "wood", .tex_id = 4 },
    .{ .name = "sapling", .tex_id = 15, .flags = .{ .transparent = true, .hitbox = false } },
    .{ .name = "bedrock", .tex_id = texpos(1, 1) },
    .{ .name = "water", .tex_id = texpos(15, 12), .flags = .{ .transparent = true, .hitbox = false } },
    .{ .name = "water", .tex_id = texpos(15, 12), .flags = .{ .model = .liquid_still, .transparent = true, .hitbox = false } },
    .{ .name = "lava", .tex_id = texpos(15, 14), .flags = .{ .hitbox = false } },
    .{ .name = "lava", .tex_id = texpos(15, 14), .flags = .{ .model = .liquid_still, .hitbox = false } },
    .{ .name = "sand", .tex_id = texpos(2, 1) },
    .{ .name = "gravel", .tex_id = texpos(3, 1) },
    .{ .name = "oreGold", .tex_id = texpos(0, 2) },
    .{ .name = "oreIron", .tex_id = texpos(1, 2) },
    // 16
    .{ .name = "oreCoal", .tex_id = texpos(2, 2) },
    .{ .name = "log", .tex_id = texpos(4, 1), .top_tex_id = texpos(5, 1), .bottom_tex_id = texpos(5, 1), .flags = .{ .model = .full_barrel } },
    .{ .name = "leaves", .tex_id = texpos(4, 3), .flags = .{ .transparent = true } },
    .{},
    .{ .name = "glass", .tex_id = texpos(1, 3), .flags = .{ .transparent = true } },
    .{ .name = "oreLapis", .tex_id = texpos(0, 10) },
    .{},
    .{},
    .{ .name = "sandStone", .tex_id = texpos(0, 12), .top_tex_id = texpos(0, 11), .bottom_tex_id = texpos(0, 13), .flags = .{ .model = .full_barrel } },
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{ .name = "tallgrass", .tex_id = texpos(7, 2), .flags = .{ .model = .plant, .transparent = true, .hitbox = false } },
    // 32
    .{ .name = "deadbush", .tex_id = texpos(7, 3), .flags = .{ .model = .plant, .transparent = true, .hitbox = false } },
    .{},
    .{},
    .{},
    .{},
    .{ .name = "flower", .tex_id = 13, .flags = .{ .model = .plant, .transparent = true, .hitbox = false } },
    .{ .name = "rose", .tex_id = 12, .flags = .{ .model = .plant, .transparent = true, .hitbox = false } },
    .{ .name = "mushroom", .tex_id = texpos(13, 1), .flags = .{ .model = .plant, .transparent = true, .hitbox = false } },
    .{ .name = "mushroom", .tex_id = texpos(12, 1), .flags = .{ .model = .plant, .transparent = true, .hitbox = false } },
    .{},
    .{},
    .{},
    .{ .name = "step", .tex_id = 5, .top_tex_id = 6, .bottom_tex_id = 6, .flags = .{ .model = .slab } },
    .{},
    .{},
    .{},
    // 48
    .{ .name = "stoneMoss", .tex_id = texpos(4, 2) },
    .{ .name = "obsidian", .tex_id = texpos(5, 2) },
    .{},
    .{},
    .{ .name = "mobSpawner", .tex_id = texpos(1, 4), .flags = .{ .transparent = true } },
    .{},
    .{},
    .{},
    .{ .name = "oreDiamond", .tex_id = texpos(2, 3) },
    .{},
    .{ .name = "workbench", .tex_id = texpos(12, 3), .east_tex_id = texpos(11, 3), .south_tex_id = texpos(11, 3), .west_tex_id = texpos(12, 3), .top_tex_id = texpos(11, 2), .bottom_tex_id = 4, .flags = .{ .model = .full_advanced } },
    .{},
    .{},
    .{},
    .{},
    .{},
    // 64
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{ .name = "oreRedstone", .tex_id = texpos(3, 3) },
    .{ .name = "oreRedstone", .tex_id = texpos(3, 3) },
    .{},
    .{},
    .{},
    .{},
    .{},
    // 80
    .{},
    .{ .name = "cactus", .tex_id = texpos(6, 4), .top_tex_id = texpos(5, 4), .bottom_tex_id = texpos(7, 4), .flags = .{ .model = .cactus, .transparent = true } },
    .{ .name = "clay", .tex_id = texpos(8, 4) },
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 96
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 112
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 128
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 144
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 160
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 176
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 192
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 208
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 224
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 240
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    .{},
    // 256
};

test "block tests" {
    try std.testing.expect(table[@intFromEnum(blocks_enum.stone)].isFull());
    try std.testing.expect(!table[@intFromEnum(blocks_enum.air)].isFull());
    try std.testing.expect(!table[@intFromEnum(blocks_enum.glass)].isFull());
    try std.testing.expect(!table[@intFromEnum(blocks_enum.step)].isFull());
}

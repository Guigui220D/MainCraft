const Block = @import("vectors.zig").Block;

pub const Direction = enum {
    north, // -Z
    east, // +X
    south, // +Z
    west, // -X
    up, // +Y
    down, // -Y
    self, // same

    pub inline fn asRelativeBlock(self: Direction) Block {
        return switch (self) {
            .north => .{ .x = 0, .y = 0, .z = -1 },
            .east => .{ .x = 1, .y = 0, .z = 0 },
            .south => .{ .x = 0, .y = 0, .z = 1 },
            .west => .{ .x = -1, .y = 0, .z = 0 },
            .up => .{ .x = 0, .y = 1, .z = 0 },
            .down => .{ .x = 0, .y = -1, .z = 0 },
            .self => .{ .x = 0, .y = 0, .z = 0 },
        };
    }
};

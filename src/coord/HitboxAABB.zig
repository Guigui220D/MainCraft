//! Axis Aligned Boundary Box struct

const std = @import("std");

const vec = @import("vectors.zig");
const Vec3f = vec.Vec3f;
const Block = vec.Block;

const HitboxAABB = @This();

a: Vec3f,
b: Vec3f,

/// Change the xyz coordinates of both corners so that
/// a.x <= b.x, a.y <= b.y, a.z <= b.z
pub fn reorder(self: HitboxAABB) HitboxAABB {
    var ret = self;
    var swap: f64 = undefined;

    // Swap X if needed
    if (ret.a.x > ret.b.x) {
        swap = ret.a.x;
        ret.a.x = ret.b.x;
        ret.b.x = swap;
    }

    // Swap Y if needed
    if (ret.a.y > ret.b.y) {
        swap = ret.a.y;
        ret.a.y = ret.b.y;
        ret.b.y = swap;
    }

    // Swap Z if needed
    if (ret.a.z > ret.b.z) {
        swap = ret.a.z;
        ret.a.z = ret.b.z;
        ret.b.z = swap;
    }

    return ret;
}

/// Returns the xyz size of the hitbox
pub fn size(self: HitboxAABB) Vec3f {
    return .{
        .x = @abs(self.b.x - self.a.x),
        .y = @abs(self.b.y - self.a.y),
        .z = @abs(self.b.z - self.a.z),
    };
}

/// Iterator structure to iterate over blocks in a volume
pub const BlockIterator = struct {
    a: Block, // must be < b
    b: Block,
    current: Block,

    pub fn next(self: *BlockIterator) ?Block {
        const ret = self.current;

        if (ret.y > self.b.y)
            return null;

        // Move current for next call
        self.current.x += 1;
        if (self.current.x > self.b.x) {
            self.current.x = self.a.x;
            self.current.z += 1;
            if (self.current.z > self.b.z) {
                self.current.z = self.a.z;
                self.current.y += 1;
            }
        }

        return ret;
    }
};

/// Returns an iterator to take into consideration every block touched by the hitbox
pub fn getBlocks(self: HitboxAABB) BlockIterator {
    const ordered = self.reorder();
    const a = ordered.a.getBlock();
    const b = ordered.b.getBlock();

    return .{
        .a = a,
        .b = b,
        .current = a,
    };
}

test "Hitbox blocks iteration" {
    const hitbox = HitboxAABB{
        .a = .{ .x = 0.6, .y = -6.5, .z = 4.1 },
        .b = .{ .x = 1.2, .y = -5.2, .z = 2.7 },
    };

    var iterator = hitbox.getBlocks();

    try std.testing.expectEqual(Block{ .x = 0, .y = -7, .z = 2 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 1, .y = -7, .z = 2 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 0, .y = -7, .z = 3 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 1, .y = -7, .z = 3 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 0, .y = -7, .z = 4 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 1, .y = -7, .z = 4 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 0, .y = -6, .z = 2 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 1, .y = -6, .z = 2 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 0, .y = -6, .z = 3 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 1, .y = -6, .z = 3 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 0, .y = -6, .z = 4 }, iterator.next());
    try std.testing.expectEqual(Block{ .x = 1, .y = -6, .z = 4 }, iterator.next());

    try std.testing.expectEqual(null, iterator.next());
}

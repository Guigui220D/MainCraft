//! Helper structure for raycasting through blocks

const std = @import("std");
const Direction = @import("direction.zig").Direction;
const vectors = @import("vectors.zig");
const Vec3f = vectors.Vec3f;
const Block = vectors.Block;

/// Iterator to iterate over blocks covered by a ray
pub const RaycastIterator = struct {
    /// Where the ray starts (must not be 0!)
    start: Vec3f,
    /// Where the ray is going relative to the start point
    direction: Vec3f,
    /// Distance limit where next stops yielding
    distance_limit: ?f64,

    // Internal state for DDA algorithm
    current_block: Block,
    step: Block,
    t_max: Vec3f,
    t_delta: Vec3f,
    distance_traveled: f64,
    first_iteration: bool,

    /// Returns the next block hit by the ray and the face from which it was hit
    pub fn next(self: *RaycastIterator) ?struct { Block, Direction } {
        // On first iteration, return the starting block
        if (self.first_iteration) {
            self.first_iteration = false;
            return .{ self.current_block, .north }; // arbitrary face for first block
        }

        // Find which axis we cross first
        var face: Direction = undefined;
        var min_t: f64 = undefined;

        if (self.t_max.x < self.t_max.y) {
            if (self.t_max.x < self.t_max.z) {
                min_t = self.t_max.x;
                self.t_max.x += self.t_delta.x;
                self.current_block.x += self.step.x;
                face = if (self.step.x > 0) Direction.west else Direction.east;
            } else {
                min_t = self.t_max.z;
                self.t_max.z += self.t_delta.z;
                self.current_block.z += self.step.z;
                face = if (self.step.z > 0) Direction.south else Direction.north;
            }
        } else {
            if (self.t_max.y < self.t_max.z) {
                min_t = self.t_max.y;
                self.t_max.y += self.t_delta.y;
                self.current_block.y += self.step.y;
                face = if (self.step.y > 0) Direction.down else Direction.up;
            } else {
                min_t = self.t_max.z;
                self.t_max.z += self.t_delta.z;
                self.current_block.z += self.step.z;
                face = if (self.step.z > 0) Direction.south else Direction.north;
            }
        }

        self.distance_traveled = min_t;

        // Check distance limit
        if (self.distance_limit) |limit| {
            if (self.distance_traveled >= limit) {
                return null;
            }
        }

        return .{ self.current_block, face };
    }
};

/// Returns a raycasting iterator
pub fn sendRay(start: Vec3f, dir: Vec3f, limit: f64) RaycastIterator {
    std.debug.assert(dir.x != 0 or dir.y != 0 or dir.z != 0);

    // Get starting block
    const current_block = Block{
        .x = @as(i32, @intFromFloat(@floor(start.x))),
        .y = @as(i32, @intFromFloat(@floor(start.y))),
        .z = @as(i32, @intFromFloat(@floor(start.z))),
    };

    // Determine step direction for each axis
    const step = Block{
        .x = if (dir.x >= 0) @as(i32, 1) else @as(i32, -1),
        .y = if (dir.y >= 0) @as(i32, 1) else @as(i32, -1),
        .z = if (dir.z >= 0) @as(i32, 1) else @as(i32, -1),
    };

    // Calculate t_delta (distance to traverse one block along ray for each axis)
    const t_delta = Vec3f{
        .x = if (dir.x != 0) @abs(1.0 / dir.x) else std.math.inf(f64),
        .y = if (dir.y != 0) @abs(1.0 / dir.y) else std.math.inf(f64),
        .z = if (dir.z != 0) @abs(1.0 / dir.z) else std.math.inf(f64),
    };

    // Calculate t_max (distance to next block boundary for each axis)
    var t_max: Vec3f = undefined;

    if (dir.x != 0) {
        const next_boundary = if (dir.x > 0)
            @ceil(start.x)
        else
            @floor(start.x);
        t_max.x = (next_boundary - start.x) / dir.x;
    } else {
        t_max.x = std.math.inf(f64);
    }

    if (dir.y != 0) {
        const next_boundary = if (dir.y > 0)
            @ceil(start.y)
        else
            @floor(start.y);
        t_max.y = (next_boundary - start.y) / dir.y;
    } else {
        t_max.y = std.math.inf(f64);
    }

    if (dir.z != 0) {
        const next_boundary = if (dir.z > 0)
            @ceil(start.z)
        else
            @floor(start.z);
        t_max.z = (next_boundary - start.z) / dir.z;
    } else {
        t_max.z = std.math.inf(f64);
    }

    return .{
        .start = start,
        .direction = dir,
        .distance_limit = limit,
        .current_block = current_block,
        .step = step,
        .t_max = t_max,
        .t_delta = t_delta,
        .distance_traveled = 0.0,
        .first_iteration = true,
    };
}

test "raycast along positive X axis" {
    const start = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 };
    const dir = Vec3f{ .x = 1.0, .y = 0.0, .z = 0.0 };
    var iter = sendRay(start, dir, 5.0);

    // First block: starting position
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 0, .y = 0, .z = 0 }, result[0]);
    } else {
        try std.testing.expect(false);
    }

    // Second block: X = 1
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 1, .y = 0, .z = 0 }, result[0]);
        try std.testing.expectEqual(Direction.west, result[1]);
    } else {
        try std.testing.expect(false);
    }

    // Third block: X = 2
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 2, .y = 0, .z = 0 }, result[0]);
        try std.testing.expectEqual(Direction.west, result[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "along negative X axis" {
    const start = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 };
    const dir = Vec3f{ .x = -1.0, .y = 0.0, .z = 0.0 };
    var iter = sendRay(start, dir, 3.0);

    // First block: starting position
    _ = iter.next();

    // Second block: X = -1
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = -1, .y = 0, .z = 0 }, result[0]);
        try std.testing.expectEqual(Direction.east, result[1]);
    } else {
        try std.testing.expect(false);
    }

    // Third block: X = -2
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = -2, .y = 0, .z = 0 }, result[0]);
        try std.testing.expectEqual(Direction.east, result[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "along positive Y axis" {
    const start = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 };
    const dir = Vec3f{ .x = 0.0, .y = 1.0, .z = 0.0 };
    var iter = sendRay(start, dir, 3.0);

    // First block
    _ = iter.next();

    // Second block: Y = 1
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 0, .y = 1, .z = 0 }, result[0]);
        try std.testing.expectEqual(Direction.down, result[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "along negative Y axis" {
    const start = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 };
    const dir = Vec3f{ .x = 0.0, .y = -1.0, .z = 0.0 };
    var iter = sendRay(start, dir, 3.0);

    // First block
    _ = iter.next();

    // Second block: Y = -1
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 0, .y = -1, .z = 0 }, result[0]);
        try std.testing.expectEqual(Direction.up, result[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "along positive Z axis" {
    const start = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 };
    const dir = Vec3f{ .x = 0.0, .y = 0.0, .z = 1.0 };
    var iter = sendRay(start, dir, 3.0);

    // First block
    _ = iter.next();

    // Second block: Z = 1
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 0, .y = 0, .z = 1 }, result[0]);
        try std.testing.expectEqual(Direction.south, result[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "along negative Z axis" {
    const start = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 };
    const dir = Vec3f{ .x = 0.0, .y = 0.0, .z = -1.0 };
    var iter = sendRay(start, dir, 3.0);

    // First block
    _ = iter.next();

    // Second block: Z = -1
    if (iter.next()) |result| {
        try std.testing.expectEqual(Block{ .x = 0, .y = 0, .z = -1 }, result[0]);
        try std.testing.expectEqual(Direction.north, result[1]);
    } else {
        try std.testing.expect(false);
    }
}

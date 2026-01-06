//! 2D and 3D vector structs

const std = @import("std");

const Direction = @import("direction.zig").Direction;

/// Coordinates of a chunk
pub const Chunk = struct {
    x: i32 = 0,
    z: i32 = 0,
};

/// Global or local (within chunk) block coordinates
pub const Block = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,

    /// Adds two vectors
    pub inline fn add(a: Block, b: Block) Block {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    /// Get the chunk coordinates from the global block coordinates
    pub inline fn getChunk(self: Block) Chunk {
        return .{
            .x = @divFloor(self.x, 16),
            .z = @divFloor(self.z, 16),
        };
    }

    /// Get the local coordinates within the chunk from the global block coordinates
    pub inline fn getPosInChunk(self: Block) Block {
        return .{
            .x = @mod(self.x, 16),
            .y = self.y,
            .z = @mod(self.z, 16),
        };
    }

    /// If this coordinates as local coords is within chunk boundaries
    pub inline fn isWithinChunk(self: Block) bool {
        if (self.x < 0 or self.y < 0 or self.z < 0)
            return false;
        if (self.x >= 16 or self.y >= 128 or self.z >= 16)
            return false;
        return true;
    }

    /// Check if a local block coordinate is at the border of a chunk
    pub inline fn isAtChunkBorder(self: Block) bool {
        return (self.x == 0 or self.z == 0 or self.x == 15 or self.z == 15);
    }

    /// Returns the coordinates of a neighbor block
    pub inline fn neighbor(self: Block, dir: Direction) Block {
        return self.add(Direction.asRelativeBlock(dir));
    }
};

/// Double float vectors used by entities for instance
pub const Vec3f = Vec3(f64);
/// Single float vectors used by vertices for instance
pub const Vec3fs = Vec3(f32);

/// Generic float vector type
pub fn Vec3(Float: type) type {
    return packed struct {
        const Vec = @This();

        x: Float,
        y: Float,
        z: Float,

        /// Gets a position from integers the way it is encoded in some packets
        pub inline fn fromIntsDiv32(x: i32, y: i32, z: i32) Vec {
            return .{
                .x = @as(Float, @floatFromInt(x)) / 32.0,
                .y = @as(Float, @floatFromInt(y)) / 32.0,
                .z = @as(Float, @floatFromInt(z)) / 32.0,
            };
        }

        /// Gets the block that vector is in
        pub inline fn getBlock(pos: Vec) Block {
            var block: Block = .{ .x = @intFromFloat(pos.x), .y = @intFromFloat(pos.y), .z = @intFromFloat(pos.z) };
            if (pos.x < 0)
                block.x -= 1;
            if (pos.y < 0)
                block.y -= 1;
            if (pos.z < 0)
                block.z -= 1;
            return block;
        }

        /// Adds two vectors
        pub inline fn add(a: Vec, b: Vec) Vec {
            return .{
                .x = a.x + b.x,
                .y = a.y + b.y,
                .z = a.z + b.z,
            };
        }

        /// Substract a vector from an other
        pub inline fn sub(a: Vec, b: Vec) Vec {
            return .{
                .x = a.x - b.x,
                .y = a.y - b.y,
                .z = a.z - b.z,
            };
        }

        /// Cross product
        pub inline fn cross(a: Vec, b: Vec) Vec {
            return .{
                .x = a.y * b.z - a.z * b.y,
                .y = a.z * b.x - a.x * b.z,
                .z = a.x * b.y - a.y * b.x,
            };
        }

        /// Length of the vector
        pub inline fn length(a: Vec) Float {
            return @sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
        }

        /// Normalize the vector (make its length 1)
        pub inline fn normalize(a: Vec) Vec {
            const len = a.length();
            if (len == 0)
                return a;

            return .{
                .x = a.x / len,
                .y = a.y / len,
                .z = a.z / len,
            };
        }

        /// Gives a general direction corresponding to the vector
        /// This is for very basic cases and doesn't do any fancy maths
        pub fn generalDirection(a: Vec) Direction {
            if (a.x > 0.9)
                return .east;
            if (a.x < -0.9)
                return .west;
            if (a.y > 0.9)
                return .up;
            if (a.y < -0.9)
                return .down;
            if (a.z > 0.9)
                return .south;
            if (a.z < -0.9)
                return .north;
            return .self;
        }
    };
}

test "Block from Vec3f" {
    const a = Vec3f{ .x = 0.1, .y = 1, .z = 2.1 };
    const b = Vec3f{ .x = -0.1, .y = -1, .z = -2.1 };

    try std.testing.expectEqual(Block{ .x = 0, .y = 1, .z = 2 }, a.getBlock());
    try std.testing.expectEqual(Block{ .x = -1, .y = -2, .z = -3 }, b.getBlock());
}

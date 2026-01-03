//! 2D and 3D vector structs

const std = @import("std");

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

    pub inline fn getChunk(self: Block) Chunk {
        return .{
            .x = @divFloor(self.x, 16),
            .z = @divFloor(self.z, 16),
        };
    }

    pub inline fn getPosInChunk(self: Block) Block {
        return .{
            .x = @mod(self.x, 16),
            .y = self.y,
            .z = @mod(self.z, 16),
        };
    }

    pub inline fn isWithinChunk(self: Block) bool {
        if (self.x < 0 or self.y < 0 or self.z < 0)
            return false;
        if (self.x >= 16 or self.y >= 128 or self.z >= 16)
            return false;
        return true;
    }

    pub inline fn north(self: Block) Block {
        return .{ .x = self.x, .y = self.y, .z = self.z - 1 };
    }

    pub inline fn east(self: Block) Block {
        return .{ .x = self.x + 1, .y = self.y, .z = self.z };
    }

    pub inline fn south(self: Block) Block {
        return .{ .x = self.x, .y = self.y, .z = self.z + 1 };
    }

    pub inline fn west(self: Block) Block {
        return .{ .x = self.x - 1, .y = self.y, .z = self.z };
    }

    pub inline fn up(self: Block) Block {
        return .{ .x = self.x, .y = self.y + 1, .z = self.z };
    }

    pub inline fn down(self: Block) Block {
        return .{ .x = self.x, .y = self.y - 1, .z = self.z };
    }
};

/// Float 3D vector for entity positions
pub const Vec3f = struct {
    x: f64,
    y: f64,
    z: f64,

    /// Gets a position from integers the way it is encoded in some packets
    pub inline fn fromIntsDiv32(x: i32, y: i32, z: i32) Vec3f {
        return .{
            .x = @as(f64, @floatFromInt(x)) / 32.0,
            .y = @as(f64, @floatFromInt(y)) / 32.0,
            .z = @as(f64, @floatFromInt(z)) / 32.0,
        };
    }

    /// Gets the block that vec3f is in
    pub inline fn getBlock(pos: Vec3f) Block {
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
    pub inline fn add(a: Vec3f, b: Vec3f) Vec3f {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }
};

test "Block from Vec3f" {
    const a = Vec3f{ .x = 0.1, .y = 1, .z = 2.1 };
    const b = Vec3f{ .x = -0.1, .y = -1, .z = -2.1 };

    try std.testing.expectEqual(Block{ .x = 0, .y = 1, .z = 2 }, a.getBlock());
    try std.testing.expectEqual(Block{ .x = -1, .y = -2, .z = -3 }, b.getBlock());
}

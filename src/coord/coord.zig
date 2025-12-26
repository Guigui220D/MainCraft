pub const Chunk = struct {
    x: i32 = 0,
    z: i32 = 0,
};

pub const Block = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,

    pub fn getChunk(self: Block) Chunk {
        return .{
            .x = self.x >> 4,
            .z = self.z >> 4,
        };
    }

    pub fn isWithinChunk(self: Block) bool {
        if (self.x < 0 or self.y < 0 or self.z < 0)
            return false;
        if (self.x >= 16 or self.y >= 128 or self.z >= 16)
            return false;
        return true;
    }

    pub fn north(self: Block) Block {
        return .{ .x = self.x, .y = self.y, .z = self.z - 1 };
    }

    pub fn east(self: Block) Block {
        return .{ .x = self.x + 1, .y = self.y, .z = self.z };
    }

    pub fn south(self: Block) Block {
        return .{ .x = self.x, .y = self.y, .z = self.z + 1 };
    }

    pub fn west(self: Block) Block {
        return .{ .x = self.x - 1, .y = self.y, .z = self.z };
    }

    pub fn up(self: Block) Block {
        return .{ .x = self.x, .y = self.y + 1, .z = self.z };
    }

    pub fn down(self: Block) Block {
        return .{ .x = self.x, .y = self.y - 1, .z = self.z };
    }
};

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
};

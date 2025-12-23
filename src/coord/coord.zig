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
};

pub const Vec3f = struct {
    x: f64,
    y: f64,
    z: f64,
};

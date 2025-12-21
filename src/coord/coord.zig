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
};

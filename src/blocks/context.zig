//! Context data passed when generating block models

// TODO: expand context concept to other relevant things like fences, water?

/// Bitfield indicating which edge faces of a block should be rendered
pub const Context = packed struct {
    /// North (-Z) faces should be rendered
    north: bool = true,
    /// East (+X) faces should be rendered
    east: bool = true,
    /// South (+Z) faces should be rendered
    south: bool = true,
    /// West (-X) faces should be rendered
    west: bool = true,
    /// Top (+Y) faces should be rendered
    up: bool = true,
    /// Bottom (-Y) faces should be rendered
    down: bool = true,

    pub fn faceCount(self: Context) u8 {
        var ret: u8 = 0;
        if (self.north)
            ret += 1;
        if (self.east)
            ret += 1;
        if (self.south)
            ret += 1;
        if (self.west)
            ret += 1;
        if (self.up)
            ret += 1;
        if (self.down)
            ret += 1;
        return ret;
    }
};

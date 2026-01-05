//! Context data passed when generating block models

const LightLevel = @import("light_level.zig").LightLevel;

/// Occlusion
occlusion: Occlusion,
/// Surrounding light levels
light_levels: LightLevels,

/// Light levels of the surrounding blocks
pub const LightLevels = packed struct {
    /// Light level of the selected block
    self: LightLevel,
    /// Light level of the north face
    north: LightLevel,
    /// Light level of the east face
    east: LightLevel,
    /// Light level of the south face
    south: LightLevel,
    /// Light level of the west face
    west: LightLevel,
    /// Light level of the up face
    up: LightLevel,
    /// Light level of the down face
    down: LightLevel,
};

/// Bitfield indicating which edge faces of a block are occluded and should not be rendered
pub const Occlusion = packed struct {
    /// North (-Z) faces should not be rendered
    north: bool,
    /// East (+X) faces should not be rendered
    east: bool,
    /// South (+Z) faces should not be rendered
    south: bool,
    /// West (-X) faces should not be rendered
    west: bool,
    /// Top (+Y) faces should not be rendered
    up: bool,
    /// Bottom (-Y) faces should not be rendered
    down: bool,

    /// Returns how many faces are not occluded
    pub fn faceCount(self: Occlusion) u8 {
        var ret: u8 = 0;
        if (!self.north)
            ret += 1;
        if (!self.east)
            ret += 1;
        if (!self.south)
            ret += 1;
        if (!self.west)
            ret += 1;
        if (!self.up)
            ret += 1;
        if (!self.down)
            ret += 1;
        return ret;
    }
};

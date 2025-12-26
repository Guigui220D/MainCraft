//! Context data passed when generating block models

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
};

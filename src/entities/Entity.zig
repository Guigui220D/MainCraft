//! Entity

const coord = @import("coord");

// Temporary
pub const Type = enum(u8) {
    inanimate,
    mob,
    item,
    player
};

pos: coord.Vec3f,
ent_type: Type,

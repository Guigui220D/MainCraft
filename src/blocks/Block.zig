//! Struct describing a single block type

const no_tex = 253;

pub const Block = @This();

/// Main texture ID
tex_id: u8 = no_tex, // North
// Optional: only when the uv type is not basic
/// Bottom texture ID
bottom_tex_id: u8 = no_tex,
/// Top texture ID
top_tex_id: u8 = no_tex,
/// East texture ID
east_tex_id: u8 = no_tex,
/// South texture ID
south_tex_id: u8 = no_tex,
/// West texture ID
west_tex_id: u8 = no_tex,
/// Block name for debugging
name: []const u8 = "",
/// Model related flags
flags: Flags = .{},

// TODO: direction-based opacity: example: slab occults face below but not others

/// Returns true if the block is a full opaque block
pub inline fn isFull(self: Block) bool {
    return switch (self.flags.model) {
        .full_basic, .full_barrel, .full_advanced => !self.flags.transparent,
        else => false,
    };
}

/// Enumeration of all block models and their uv variants
pub const BlockModel = enum(u4) {
    full_basic, // Cube with same texture on each faces
    full_barrel, // Cube with side texture, top and bottom
    full_advanced, // Cube with texture for each face
    slab,
    plant,
    liquid_still,
    // and others...
};

/// Packed bitfield for model related flags (for compation)
pub const Flags = packed struct(u8) {
    /// Model and UV used
    model: BlockModel = .full_basic,
    /// Texture has transparent parts (should be rendered on a different layer)
    transparent: bool = false,
    /// Can be walked through
    hitbox: bool = true, // Later: enum

    /// Unused padding
    unused: u2 = 0,
};

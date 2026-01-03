//! Struct describing a single block type

const UvType = @import("uv.zig").UvType;
const BlockModel = @import("block_models.zig").BlockModel;

const no_tex = 253;

// TODO: bitfield to compact some flags

tex_id: u8 = no_tex, // North
// Optional: only when the uv type is not basic
bottom_tex_id: u8 = no_tex,
top_tex_id: u8 = no_tex,
east_tex_id: u8 = no_tex,
south_tex_id: u8 = no_tex,
west_tex_id: u8 = no_tex,
name: []const u8 = "",
// Texture has transparent parts
transparent: bool = false,
// Hides blocks
full_block: bool = true,
// Model used
block_model: BlockModel = .full,
// UV mapping method
uv_type: UvType = .basic,
hitbox: bool = true, // Later: enum

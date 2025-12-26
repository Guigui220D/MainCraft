//! Struct describing a single block type

const UvType = @import("uv.zig").UvType;
const BlockModel = @import("block_models.zig").BlockModel;

const no_tex = 253;

tex_id: u8 = no_tex, // North
// Optional: only when the uv type is not basic
bottom_tex_id: u8 = no_tex,
top_tex_id: u8 = no_tex,
east_tex_id: u8 = no_tex,
south_tex_id: u8 = no_tex,
west_tex_id: u8 = no_tex,
name: []const u8 = "error",
full_block: bool = true,
block_mode: BlockModel = .full,
uv_type: UvType = .basic,

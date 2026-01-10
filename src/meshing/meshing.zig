//! Root of the meshing modules, for methods related to generating models of blocks

const coord = @import("coord");

pub const vertices = @import("vertices.zig");
pub const uv = @import("uv.zig");
pub const colors = @import("colors.zig");

pub const Vertex = coord.Vec3fs;

pub const Face = packed struct {
    a: Vertex,
    b: Vertex,
    c: Vertex,
    _: Vertex,
};

pub const Color = packed struct(u32) {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

//! Root of the coords module

const std = @import("std");

pub const HitboxAABB = @import("HitboxAABB.zig");
pub const vec = @import("vectors.zig");
pub const Block = vec.Block;
pub const Chunk = vec.Chunk;
pub const Vec3f = vec.Vec3f;

test "coord tests" {
    std.testing.refAllDecls(@import("vectors.zig"));
    std.testing.refAllDecls(@import("HitboxAABB.zig"));
}

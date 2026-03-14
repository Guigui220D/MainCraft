//! Root of the coords module

const std = @import("std");

pub const HitboxAABB = @import("HitboxAABB.zig");
pub const vec = @import("vectors.zig");
pub const Block = vec.Block;
pub const Chunk = vec.Chunk;
pub const Vec3f = vec.Vec3f;
pub const Direction = @import("direction.zig").Direction;
pub const Vec3fs = vec.Vec3fs;
pub const raycast = @import("raycast.zig");

test "coord tests" {
    std.testing.refAllDecls(vec);
    std.testing.refAllDecls(HitboxAABB);
    std.testing.refAllDecls(raycast);
}

//! Root of the terrain submodule

const std = @import("std");

pub const Chunk = @import("Chunk.zig");
pub const World = @import("World.zig");

test "terrain tests" {
    std.testing.refAllDecls(Chunk);
    std.testing.refAllDecls(World);
}

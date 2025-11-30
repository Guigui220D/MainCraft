//! Root of the NBT module

const std = @import("std");

pub const TagId = @import("tags/tag_id.zig").TagId;
pub const tags = @import("tags/tags.zig");
pub const decoder = @import("decoder.zig");

pub const nbt_endianness = std.builtin.Endian.big;

/// Describes a full NBT tree, with managed memory
pub const Tree = struct {
    /// The arena to help freeing the allocated memory
    arena: std.heap.ArenaAllocator,
    /// The compound representing the stored values
    compound: tags.Compound,

    /// Inits an empty NBT tree
    pub fn init(alloc: std.mem.Allocator) !Tree {
        var ret: Tree = undefined;

        // Init arena
        ret.arena = .init(alloc);
        errdefer ret.arena.deinit();
        const arena_alloc = ret.arena.allocator();

        // Init empty compound
        ret.compound = try arena_alloc.create(tags.CompoundHashMap);
        ret.compound.* = .init(arena_alloc);

        return ret;
    }

    /// Decodes from an raw NBT byte stream
    pub fn decode(data: *std.io.Reader, alloc: std.mem.Allocator) !Tree {
        var ret: Tree = undefined;

        // Init arena
        ret.arena = .init(alloc);
        errdefer ret.arena.deinit();
        const arena_alloc = ret.arena.allocator();

        // Decode into a new compound
        ret.compound = try decoder.decodeCompound(data, arena_alloc, true);

        return ret;
    }

    /// Frees ressources taken by this NBT tree
    pub fn deinit(self: Tree) void {
        // Much simpler thanks to the arena
        self.arena.deinit();
    }
};

test "nbt tests" {
    std.testing.refAllDecls(@import("tests/nbt_tests.zig"));
}

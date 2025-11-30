const std = @import("std");

pub const TagId = @import("tags/tag_id.zig").TagId;
pub const tags = @import("tags/tags.zig");
pub const nbt_endianness = std.builtin.Endian.big;
pub const decoder = @import("decoder.zig");

test "nbt tests" {
    std.testing.refAllDecls(@import("tests/nbt_tests.zig"));
}

//! Tests file for the NBT library module

const std = @import("std");
const nbt = @import("../nbt.zig");

test "empty nbt tree" {
    const alloc = std.testing.allocator;

    const nbt_root = try nbt.Tree.init(alloc);
    defer nbt_root.deinit();
}

test "loading and freeing level.nbt" {
    const alloc = std.testing.allocator;

    const file = try std.fs.cwd().openFile("test_data/level.nbt", .{ .mode = .read_only });
    defer file.close();

    var buf: [1024]u8 = undefined;

    var reader_file = file.reader(&buf);
    const reader = &reader_file.interface;

    const nbt_root = try nbt.Tree.decode(reader, alloc);
    defer nbt_root.deinit();
}

//! Tests file for the NBT library module

const std = @import("std");
const nbt = @import("../nbt.zig");

test "empty nbt tree" {
    const alloc = std.testing.allocator;

    const nbt_root = try nbt.Tree.init(alloc);
    defer nbt_root.deinit();
}

test "loading decompressed level.bin embed" {
    const alloc = std.testing.allocator;

    // Read data
    const file = @embedFile("data/level.bin");
    var reader = std.Io.Reader.fixed(file);

    // Decode and then free
    const nbt_root = try nbt.Tree.decode(&reader, alloc);
    defer nbt_root.deinit();

    //std.debug.print("{f}\n", .{nbt_root});
}

test "loading decompressed level.bin" {
    const alloc = std.testing.allocator;

    const file = try std.fs.cwd().openFile("src/nbt/tests/data/level.bin", .{ .mode = .read_only });
    defer file.close();

    var buf: [1024]u8 = undefined;

    var reader_file = file.reader(&buf);
    const reader = &reader_file.interface;

    const nbt_root = try nbt.Tree.decode(reader, alloc);
    defer nbt_root.deinit();

    //std.debug.print("{f}\n", .{nbt_root});
}

test "loading compressed level.dat" {
    const alloc = std.testing.allocator;

    // Read data
    const file = @embedFile("data/level.dat");
    var reader = std.Io.Reader.fixed(file);

    // Decode and then free
    const nbt_root = try nbt.Tree.decodeCompressed(&reader, alloc);
    defer nbt_root.deinit();

    //std.debug.print("{f}\n", .{nbt_root});
}

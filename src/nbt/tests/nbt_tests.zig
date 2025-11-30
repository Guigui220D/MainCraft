const std = @import("std");
const nbt = @import("../nbt.zig");

test "loading and freeing level.nbt" {
    const alloc = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile("test_data/level.nbt", .{ .mode = .read_only });
    defer file.close();

    var buf: [1024]u8 = undefined;

    var reader_file = file.reader(&buf);
    const reader = &reader_file.interface;

    const nbt_root = try nbt.decoder.decodeNbtRoot(reader, alloc);
    defer nbt.decoder.freeNbt(nbt_root, alloc);
}

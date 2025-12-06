//! Tests file for the NBT library module

const std = @import("std");
const nbt = @import("../nbt.zig");

test "empty nbt tree" {
    const alloc = std.testing.allocator;

    const nbt_root = try nbt.Tree.init(alloc);
    defer nbt_root.deinit();
}

test "decode hello_world.nbt" {
    // Read uncompressed hello_world.nbt
    const alloc = std.testing.allocator;

    // Read data
    const file = @embedFile("data/hello_world.nbt");
    var reader = std.Io.Reader.fixed(file);

    // Decode and then free
    const nbt_root = try nbt.Tree.decode(&reader, alloc);
    defer nbt_root.deinit();

    // Compare with expected: TODO

    //std.debug.print("{f}\n", .{nbt_root});
}

test "decode bigtest.nbt" {
    // Read compressed bigtest.nbt
    const alloc = std.testing.allocator;

    // Read data
    const file = @embedFile("data/bigtest.nbt");
    var reader = std.Io.Reader.fixed(file);

    // Decode and then free
    const nbt_root = try nbt.Tree.decodeCompressed(&reader, alloc);
    defer nbt_root.deinit();

    // Compare with expected

    // Find "root" (level) compound
    const level = nbt_root.compound.hashmap.get("Level").?;
    const level_compound = level.payload.tag_compound.hashmap;
    try std.testing.expectEqual(11, level_compound.count());

    { // Check byteArray
        const byte_array = level_compound.get("byteArrayTest (the first 1000 values of (n*n*255+n*7)%100, starting with n=0 (0, 62, 34, 16, 8, ...))").?.payload.tag_byte_array;
        for (byte_array, 0..) |byte, n| {
            // Do the maths
            const expected = (n * n * 255 + n * 7) % 100;
            const expected_byte: i8 = @intCast(expected);
            try std.testing.expectEqual(expected_byte, byte);
        }
    }

    { // Numbers
        const byte = level_compound.get("byteTest").?.payload.tag_byte;
        try std.testing.expectEqual(@as(i8, 127), byte);

        const short = level_compound.get("shortTest").?.payload.tag_short;
        try std.testing.expectEqual(@as(i16, 32767), short);

        const int = level_compound.get("intTest").?.payload.tag_int;
        try std.testing.expectEqual(@as(i32, 2147483647), int);

        const long = level_compound.get("longTest").?.payload.tag_long;
        try std.testing.expectEqual(@as(i64, 9223372036854775807), long);

        const float = level_compound.get("floatTest").?.payload.tag_float;
        try std.testing.expectApproxEqAbs(@as(f32, 0.4982315), float, 0.01);

        const double = level_compound.get("doubleTest").?.payload.tag_double;
        try std.testing.expectApproxEqAbs(@as(f64, 0.493128713218231), double, 0.0001);
    }

    { // String
        const string = level_compound.get("stringTest").?.payload.tag_string;
        try std.testing.expectEqualStrings("HELLO WORLD THIS IS A TEST STRING ÅÄÖ!", string);
    }

    { // Lists
        const list_compound = level_compound.get("listTest (compound)").?.payload.tag_list;
        const list_long = level_compound.get("listTest (long)").?.payload.tag_list;

        // Check lengths
        try std.testing.expectEqual(@as(usize, 2), list_compound.tag_compound.len);
        try std.testing.expectEqual(@as(usize, 5), list_long.tag_long.len);

        // Test longs
        const expected_long = [_]i64{ 11, 12, 13, 14, 15 };
        try std.testing.expectEqualSlices(i64, &expected_long, list_long.tag_long);

        // Test compounds
        const comp0 = list_compound.tag_compound[0];
        const comp1 = list_compound.tag_compound[1];

        try std.testing.expectEqual(@as(usize, 2), comp0.hashmap.count());
        try std.testing.expectEqual(@as(usize, 2), comp1.hashmap.count());

        try std.testing.expectEqualStrings("Compound tag #0", comp0.hashmap.get("name").?.payload.tag_string);
        try std.testing.expectEqual(@as(i64, 1264099775885), comp0.hashmap.get("created-on").?.payload.tag_long);

        try std.testing.expectEqualStrings("Compound tag #1", comp1.hashmap.get("name").?.payload.tag_string);
        try std.testing.expectEqual(@as(i64, 1264099775885), comp1.hashmap.get("created-on").?.payload.tag_long);
    }

    { // Nested compounds
        const nested_compound = level_compound.get("nested compound test").?.payload.tag_compound;

        // Check length
        try std.testing.expectEqual(@as(usize, 2), nested_compound.hashmap.count());

        // Test contents
        const egg = nested_compound.hashmap.get("egg").?.payload.tag_compound;
        const ham = nested_compound.hashmap.get("ham").?.payload.tag_compound;

        try std.testing.expectEqualStrings("Eggbert", egg.hashmap.get("name").?.payload.tag_string);
        try std.testing.expectEqual(@as(f32, 0.5), egg.hashmap.get("value").?.payload.tag_float);

        try std.testing.expectEqualStrings("Hampus", ham.hashmap.get("name").?.payload.tag_string);
        try std.testing.expectEqual(@as(f32, 0.75), ham.hashmap.get("value").?.payload.tag_float);
    }
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

//! Writing and reading VarInt for packets

const std = @import("std");

/// Reads a 32 bits signed integer with variable length encoding
/// Pass a pointer to a usize in bytes_read to return the number of bytes the varInt took
fn readVarInt(data: *std.Io.Reader, bytes_read: ?*usize) !i32 {
    var num_read: u5 = 0;
    var result: i32 = 0;

    // Read until there is not end marking bit
    while (true) {
        // Reads byte
        const byte: u8 = try data.takeByte();
        const value: i32 = byte & 0b01111111;

        // Update result
        result |= (value << (7 * num_read));

        // Count read bytes
        num_read += 1;

        // Break when seeing end bit
        if (byte & 0b10000000 == 0)
            break;

        if (num_read >= 5) {
            // Var Ints are never longer than 5 bytes
            return error.VarIntTooBig;
        }
    }

    if (bytes_read) |read_ptr|
        read_ptr.* = num_read;
    return result;
}

/// Reads a 64 bits signed integer with variable length encoding
fn readVarLong(data: *std.Io.Reader, bytes_read: ?*usize) !i64 {
    var num_read: u6 = 0;
    var result: i64 = 0;

    // Read until there is not end marking bit
    while (true) {
        // Reads byte
        const byte: u8 = try data.takeByte();
        const value: i64 = byte & 0b01111111;

        // Update result
        result |= (value << (7 * num_read));

        // Count read bytes
        num_read += 1;

        // Break when seeing end bit
        if (byte & 0b10000000 == 0)
            break;

        if (num_read >= 10) {
            // Var Ints are never longer than 5 bytes
            return error.VarIntTooBig;
        }
    }

    if (bytes_read) |read_ptr|
        read_ptr.* = num_read;
    return result;
}

test "Sample VarInts" {
    // From file:///home/guide/wiki.vg/Protocol.html#VarInt_and_VarLong
    {
        const data = &[_]u8{0x00};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 0), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{0x01};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 1), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{0x02};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 2), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{0x7f};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 127), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0x80, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 128), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 255), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0xff, 0xff, 0xff, 0x07 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, 2147483647), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0xff, 0xff, 0xff, 0x0f };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, -1), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x08 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i32, -2147483648), readVarInt(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        // A VarInt is never longer than 5 bytes
        const data = &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x08 };
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectError(error.VarIntTooBig, readVarInt(&reader, null));
    }
    {
        const data = &[_]u8{ 0x80, 0x80, 0x80 };
        // Incomplete data
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectError(error.EndOfStream, readVarInt(&reader, null));
    }
}

test "Sample VarLongs" {
    // From file:///home/guide/wiki.vg/Protocol.html#VarInt_and_VarLong
    {
        const data = &[_]u8{0x00};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 0), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{0x01};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 1), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{0x02};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 2), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{0x7f};
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 127), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0x80, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 128), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 255), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0xff, 0xff, 0xff, 0x07 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 2147483647), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, 9223372036854775807), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, -1), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0xf8, 0xff, 0xff, 0xff, 0xff, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, -2147483648), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        const data = &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01 };
        var bytes_read: usize = 0;
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectEqual(@as(i64, -9223372036854775808), readVarLong(&reader, &bytes_read));
        try std.testing.expectEqual(data.len, bytes_read);
    }
    {
        // A VarInt is never longer than 10 bytes
        const data = &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x08 };
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectError(error.VarIntTooBig, readVarLong(&reader, null));
    }
    {
        const data = &[_]u8{ 0x80, 0x80, 0x80 };
        // Incomplete data
        var reader = std.Io.Reader.fixed(data);
        try std.testing.expectError(error.EndOfStream, readVarLong(&reader, null));
    }
}

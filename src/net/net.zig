//! Root of the net module
//! To read packets from a TCP stream

const std = @import("std");

/// Reads a 32 bits signed integer with variable length encoding
fn readVarInt(data: *std.Io.Reader) !i32 {
    var num_read: u5 = 0;
    var result: i32 = 0;

    // Read until there is not end marking bit
    while (true) {
        // Reads byte
        const byte: u8 = try data.takeByte();
        const value: i32 = byte & 0b01111111;

        // Update result
        result |= (value << (7 * num_read));

        // Break when seeing end bit
        if (byte & 0b10000000 == 0)
            break;

        // Count read bytes
        num_read += 1;
        if (num_read >= 5) {
            // Var Ints are never longer than 5 bytes
            return error.VarIntTooBig;
        }
    }

    return result;
}

/// Reads a 64 bits signed integer with variable length encoding
fn readVarLong(data: *std.Io.Reader) !i64 {
    var num_read: u6 = 0;
    var result: i64 = 0;

    // Read until there is not end marking bit
    while (true) {
        // Reads byte
        const byte: u8 = try data.takeByte();
        const value: i64 = byte & 0b01111111;

        // Update result
        result |= (value << (7 * num_read));

        // Break when seeing end bit
        if (byte & 0b10000000 == 0)
            break;

        // Count read bytes
        num_read += 1;
        if (num_read >= 10) {
            // Var Ints are never longer than 5 bytes
            return error.VarIntTooBig;
        }
    }

    return result;
}

test "Sample VarInts" {
    // From file:///home/guide/wiki.vg/Protocol.html#VarInt_and_VarLong
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x00});
        try std.testing.expectEqual(@as(i32, 0), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x01});
        try std.testing.expectEqual(@as(i32, 1), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x02});
        try std.testing.expectEqual(@as(i32, 2), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x7f});
        try std.testing.expectEqual(@as(i32, 127), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x01 });
        try std.testing.expectEqual(@as(i32, 128), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0x01 });
        try std.testing.expectEqual(@as(i32, 255), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0xff, 0xff, 0xff, 0x07 });
        try std.testing.expectEqual(@as(i32, 2147483647), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0xff, 0xff, 0xff, 0x0f });
        try std.testing.expectEqual(@as(i32, -1), readVarInt(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x08 });
        try std.testing.expectEqual(@as(i32, -2147483648), readVarInt(&reader));
    }
    {
        // A VarInt is never longer than 5 bytes
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x08 });
        try std.testing.expectError(error.VarIntTooBig, readVarInt(&reader));
    }
    {
        // Incomplete data
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80 });
        try std.testing.expectError(error.EndOfStream, readVarLong(&reader));
    }
}

test "Sample VarLongs" {
    // From file:///home/guide/wiki.vg/Protocol.html#VarInt_and_VarLong
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x00});
        try std.testing.expectEqual(@as(i64, 0), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x01});
        try std.testing.expectEqual(@as(i64, 1), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x02});
        try std.testing.expectEqual(@as(i64, 2), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{0x7f});
        try std.testing.expectEqual(@as(i64, 127), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x01 });
        try std.testing.expectEqual(@as(i64, 128), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0x01 });
        try std.testing.expectEqual(@as(i64, 255), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0xff, 0xff, 0xff, 0x07 });
        try std.testing.expectEqual(@as(i64, 2147483647), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f });
        try std.testing.expectEqual(@as(i64, 9223372036854775807), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01 });
        try std.testing.expectEqual(@as(i64, -1), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0xf8, 0xff, 0xff, 0xff, 0xff, 0x01 });
        try std.testing.expectEqual(@as(i64, -2147483648), readVarLong(&reader));
    }
    {
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01 });
        try std.testing.expectEqual(@as(i64, -9223372036854775808), readVarLong(&reader));
    }
    {
        // A VarInt is never longer than 10 bytes
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x08 });
        try std.testing.expectError(error.VarIntTooBig, readVarLong(&reader));
    }
    {
        // Incomplete data
        var reader = std.Io.Reader.fixed(&[_]u8{ 0x80, 0x80, 0x80 });
        try std.testing.expectError(error.EndOfStream, readVarLong(&reader));
    }
}

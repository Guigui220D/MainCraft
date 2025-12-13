//! Root of the net module
//! To read packets from a TCP stream

const std = @import("std");
const client_bound = @import("client_bound.zig");
const server_bound = @import("server_bound.zig");

var compression_enabled: bool = false;

/// Reads a packet from the TCP stream
/// compression_enabled dictates if the packet is read as compressed or not
fn readPacket(data: *std.Io.Reader, alloc: std.mem.Allocator) !void {
    if (compression_enabled) {
        readCompressedPacket(data, alloc);
    } else {
        readUncompressedPacket(data, alloc);
    }
}

/// Reads a uncompressed packet from the TCP stream
pub fn readUncompressedPacket(data: *std.Io.Reader, alloc: std.mem.Allocator) !void {
    // TODO: that doesn't seem right! for instance handshake doesn't have that format
    // Read length and packet id
    var bytes_read: usize = undefined;
    const packet_length = try readVarInt(data, null);
    const packet_id = try readVarInt(data, &bytes_read);

    // Remaining length to parse
    const payload_length = (std.math.cast(usize, packet_length) orelse return error.InvalidPacketLength) - bytes_read;
    if (payload_length == 0)
        return;

    // Read whole packet from stream (TODO: that's not good! bad performance, might not be possible for big packets)
    const buf = try data.readAlloc(alloc, payload_length);
    errdefer alloc.free(buf);

    std.debug.print("Size: {}\n", .{buf.len});
    std.debug.print("Id: {}\n", .{packet_id});
    std.debug.print("Packet: {any}\n", .{buf});

    // TODO: do what with packet
    alloc.free(buf);
}

/// Reads a compressed packet from the TCP stream
fn readCompressedPacket(data: *std.Io.Reader, alloc: std.mem.Allocator) !void {
    // Read length and packet id
    const packet_length = try readVarInt(data, null);

    // Allocate buffer for decompress
    // TODO: understand what that is all about
    const decomp_buf = try alloc.alloc(u8, std.compress.flate.max_window_len);
    defer alloc.free(decomp_buf);

    // Init decompress
    var decomp = std.compress.flate.Decompress.init(data, .zlib, decomp_buf);
    const dec_reader = &decomp.reader;

    // Read packet ID
    // Read length and packet id
    var bytes_read: usize = undefined;
    const packet_id = try readVarInt(dec_reader, &bytes_read);

    // Remaining length to parse
    const payload_length = (std.math.cast(usize, packet_length) orelse return error.InvalidPacketLength) - bytes_read;
    if (payload_length == 0)
        return;

    // Read whole packet from stream (TODO: that's not good! bad performance, might not be possible for big packets)
    const buf = try data.readAlloc(alloc, payload_length);
    errdefer alloc.free(buf);

    // TODO: do what with packet
    alloc.free(buf);
    _ = packet_id;
}

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

    if (bytes_read) |read_ptr|
        read_ptr.* = num_read;
    return result;
}

/// TEMPORARY (TODO where to put functions like this?)
pub fn handshake(stream: *std.Io.Writer) !void {
    const packet = server_bound.Packet2Handshake{ .username = "MainCraft1" };
    try packet.send(stream);
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

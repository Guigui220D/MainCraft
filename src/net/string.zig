//! Writing and reading UTF-16 with sizes

const std = @import("std");
const net = @import("net.zig");

/// Reads a string from the stream (length + utf16 bytes) into a utf8 string
/// Caller owns the string (free with alloc)
pub fn readString(stream: *std.Io.Reader, alloc: std.mem.Allocator) ![]const u8 {
    // Read length
    const length = try stream.takeInt(u16, net.endianness);

    // Read string in utf16 form into buffer
    const utf16 = try stream.readSliceEndianAlloc(alloc, u16, length, net.endianness);
    defer alloc.free(utf16);

    // Convert to utf8
    const utf8 = try std.unicode.utf16LeToUtf8Alloc(alloc, utf16);
    errdefer alloc.free(utf8);

    return utf8;
}

/// Writes a string to the stream (length + utf16 bytes) from an ascii string
/// This version assumes the input string is ascii to simplify conversion to utf16
pub fn writeStringFast(stream: *std.Io.Writer, ascii: []const u8) !void {
    // Write length
    try stream.writeInt(u16, @intCast(ascii.len), net.endianness);
    // Write each byte converted to u16
    for (ascii) |char| {
        try stream.writeInt(u16, @intCast(char), net.endianness);
    }
}

// TODO: writeString for full unicode support

// TODO: writeString and writeStringFast tests

test "KiwiPamplemousse" {
    // Taken from a network capture
    const bytes = [_]u8{ 0x00, 0x10, 0x00, 0x4b, 0x00, 0x69, 0x00, 0x77, 0x00, 0x69, 0x00, 0x50, 0x00, 0x61, 0x00, 0x6d, 0x00, 0x70, 0x00, 0x6c, 0x00, 0x65, 0x00, 0x6d, 0x00, 0x6f, 0x00, 0x75, 0x00, 0x73, 0x00, 0x73, 0x00, 0x65 };
    var reader = std.Io.Reader.fixed(&bytes);

    const string = try readString(&reader, std.testing.allocator);
    defer std.testing.allocator.free(string);

    try std.testing.expectEqualStrings("KiwiPamplemousse", string);
}

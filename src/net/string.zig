//! Writing and reading UTF-16 with sizes

const std = @import("std");
const net = @import("net.zig");

/// Reads a string from the stream (length + utf16 bytes) into a utf8 string
/// Caller owns the string (free with alloc)
pub fn readString(stream: *std.Io.Reader, alloc: std.mem.Allocator, max_length: u16) ![]const u8 {
    // Read length
    const length = try stream.takeInt(u16, net.endianness);
    if (length > max_length)
        return error.StringTooLong;

    // Read string in utf16 form into buffer
    const utf16 = try stream.readSliceEndianAlloc(alloc, u16, length, net.endianness);
    defer alloc.free(utf16);

    // Convert to utf8
    const utf8 = try std.unicode.utf16LeToUtf8Alloc(alloc, utf16);
    errdefer alloc.free(utf8);

    return utf8;
}

/// Discards a string (length + utf16 bytes)
/// Used when a string field is unused or useless
pub fn discardString(stream: *std.Io.Reader, max_length: u16) !void {
    // Read length
    const length = try stream.takeInt(u16, net.endianness);
    if (length > max_length)
        return error.StringTooLong;
    // Toss string bytes
    stream.toss(@sizeOf(u16) * length);
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

/// Writes a string to the stream (length + utf16 bytes) from an utf-8 string
/// Uses an allocator for
pub fn writeString(stream: *std.Io.Writer, string: []const u8) !void {
    // Write length
    const length = try std.unicode.calcUtf16LeLen(string);
    try stream.writeInt(u16, @intCast(length), net.endianness);

    // Iterate over codepoints to write them as utf16
    // (the std doesn't have a way to do that??)
    var view = try std.unicode.Utf8View.init(string);
    var it = view.iterator();
    while (it.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            try stream.writeInt(u16, @intCast(codepoint), net.endianness);
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
            try stream.writeInt(u16, high, net.endianness);
            try stream.writeInt(u16, low, net.endianness);
        }
    }
}

/// Tries to encode and decode the string and compares it with the original
/// Pass is_ascii = true to use the writeStringFast implementation
fn encodeDecodeTest(string: []const u8, comptime is_ascii: bool) !void {
    const alloc = std.testing.allocator;

    // Use a fixed writer to store temporarily
    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    // Write the string
    if (is_ascii) {
        try writeStringFast(&writer, string);
    } else {
        try writeString(&writer, string);
    }

    // TODO: is this the right way to access the fixed writer string?
    var reader = std.Io.Reader.fixed(buf[0..writer.end]);
    // Read back
    const result = try readString(&reader, alloc, 128);
    defer alloc.free(result);

    // Compare results
    try std.testing.expectEqualStrings(string, result);
}

/// Checks if a username is valid (returns an error otherwise)
pub fn checkUsername(name: []const u8) !void {
    // Check Name Len
    if (name.len < 3)
        return error.UsernameTooShort;
    if (name.len > 16)
        return error.UsernameTooLong;
    // Check name characters
    for (name) |char| {
        switch (char) {
            'a'...'z' => continue,
            'A'...'Z' => continue,
            '0'...'9' => continue,
            '_' => continue,
            else => return error.InvalidUsernameCharacter,
        }
    }
}

test "encode and decode ascii" {
    try encodeDecodeTest("hello this is a test!", true);
    try encodeDecodeTest("", true);
    try encodeDecodeTest("The quick brown fox jumped over the lazy dog", true);
    try encodeDecodeTest("123! 456? 789 :)\n", true);
}

test "encode and decode utf8" {
    try encodeDecodeTest("Keyboard ⌨️ emoji", false);
    try encodeDecodeTest("", false);
    try encodeDecodeTest("è_é", false);
    try encodeDecodeTest("♡〜٩( ˃▿˂ )۶〜♡\n", false);
}

test "KiwiPamplemousse" {
    // Taken from a network capture
    const bytes = [_]u8{ 0x00, 0x10, 0x00, 0x4b, 0x00, 0x69, 0x00, 0x77, 0x00, 0x69, 0x00, 0x50, 0x00, 0x61, 0x00, 0x6d, 0x00, 0x70, 0x00, 0x6c, 0x00, 0x65, 0x00, 0x6d, 0x00, 0x6f, 0x00, 0x75, 0x00, 0x73, 0x00, 0x73, 0x00, 0x65, undefined, undefined, undefined };
    var reader = std.Io.Reader.fixed(&bytes);

    const string = try readString(&reader, std.testing.allocator, 100);
    defer std.testing.allocator.free(string);

    try std.testing.expectEqualStrings("KiwiPamplemousse", string);
}

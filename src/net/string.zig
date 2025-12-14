//! Writing and reading UTF-16 with sizes

const std = @import("std");

/// Reads a string from the stream (length + utf16 bytes) into a utf8 string
/// Caller owns the string (free with alloc)
pub fn readString(stream: *std.Io.Reader, alloc: std.mem.Allocator) ![]const u8 {
    // Read length
    const length = try stream.takeInt(u16, .big);

    // Read string in utf16 form into buffer
    const utf16 = try stream.readSliceEndianAlloc(alloc, u16, length, .big);
    defer alloc.free(utf16);

    // Convert to utf8
    const utf8 = try std.unicode.utf16LeToUtf8Alloc(alloc, utf16);
    errdefer alloc.free(utf8);

    return utf8;
}

// TODO: writeString and writeStringFast (for ascii)

test "KiwiPamplemousse" {
    // Taken from a network capture
    const bytes = [_]u8{ 0x00, 0x10, 0x00, 0x4b, 0x00, 0x69, 0x00, 0x77, 0x00, 0x69, 0x00, 0x50, 0x00, 0x61, 0x00, 0x6d, 0x00, 0x70, 0x00, 0x6c, 0x00, 0x65, 0x00, 0x6d, 0x00, 0x6f, 0x00, 0x75, 0x00, 0x73, 0x00, 0x73, 0x00, 0x65 };
    var reader = std.Io.Reader.fixed(&bytes);

    const string = try readString(&reader, std.testing.allocator);
    defer std.testing.allocator.free(string);

    try std.testing.expectEqualStrings("KiwiPamplemousse", string);
}

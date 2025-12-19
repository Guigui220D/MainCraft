//! Packet for a chat message

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

message: []const u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Get message
    const message = try string.readString(stream, alloc, 119);
    errdefer alloc.free(message);

    return .{
        .message = message,
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.message);
}

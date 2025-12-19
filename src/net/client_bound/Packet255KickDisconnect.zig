//! Packet for server to kick the client

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

reason: []const u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Get reason
    const reason = try string.readString(stream, alloc, 100);
    errdefer alloc.free(reason);

    return .{
        .reason = reason,
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.reason);
}

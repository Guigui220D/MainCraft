//! Handshake packet indicating offline or online server

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

username: []const u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Get username
    const name = try string.readString(stream, alloc, 32);
    errdefer alloc.free(name);

    return .{
        // TODO: get if server is online or offline
        .username = name,
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.username);
}

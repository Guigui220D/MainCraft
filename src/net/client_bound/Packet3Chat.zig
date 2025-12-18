//! Packet for a chat message

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

message: []const u8,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    return .{
        // Reason
        .message = try string.readString(stream, alloc, 119),
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.message);
}

//! Handshake exchange packet

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

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    // Username
    try string.checkUsername(self.username);
    try string.writeStringFast(stream, self.username);
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.username);
}

pub const tag = net.Packets.handshake_2;

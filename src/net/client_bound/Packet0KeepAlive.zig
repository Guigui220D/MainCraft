//! Packet to indicate that the server is still on the line

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

pub fn receive(_: std.mem.Allocator, _: *std.Io.Reader) !@This() {
    return .{};
}

//! Packet to prevent false timeout

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

pub fn receive(_: std.mem.Allocator, _: *std.Io.Reader) !@This() {
    return .{};
}

pub fn send(_: @This(), _: *std.Io.Writer) !void {}

pub const tag = net.Packets.keep_alive_0;

//! Dummy packet

const std = @import("std");
const net = @import("../net.zig");

pub fn send(_: @This(), _: *std.Io.Writer) !void {}

pub const tag = net.Packets.keep_alive_0;

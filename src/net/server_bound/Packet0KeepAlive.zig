//! Dummy packet

const std = @import("std");
const net = @import("../net.zig");

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    _ = self;
    // Packet ID
    try stream.writeByte(0x00);

    // TODO: should this be done here?
    try stream.flush();
}

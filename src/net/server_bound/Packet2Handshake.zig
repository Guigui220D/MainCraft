//! Packet to request handshake

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

username: []const u8,

pub fn send(self: @This(), stream: *std.Io.Writer) !void {
    // Check beforehand
    try string.checkUsername(self.username);

    // Packet ID
    try stream.writeByte(0x02);
    // Username
    try string.writeStringFast(stream, self.username);

    // TODO: should this be done here?
    try stream.flush();
}

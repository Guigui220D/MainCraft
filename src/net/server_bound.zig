//! All serverbound packets and methods to write them

const std = @import("std");
const net = @import("net.zig");
const string = @import("string.zig");

// TODO: merge clientbound and serverbound packets when they are the same
pub const Packet1Login = struct {
    //protocol_version: i32, // Constant: defined in net
    username: []const u8,
    // map_seed: i64, // Unused for serverbound
    // dimension: i8, // Unused for serverbound

    pub fn send(self: @This(), stream: *std.Io.Writer) !void {
        // Packet ID
        try stream.writeByte(0x01);
        // Protocol version
        try stream.writeInt(u32, net.protocol_version, net.endianness);
        // Username
        try string.writeStringFast(stream, self.username);
        // Map seed (unused)
        try stream.writeInt(i64, 0, net.endianness);
        // Dimension (unused)
        try stream.writeInt(i8, 0, net.endianness);

        // TODO: should this be done here?
        try stream.flush();
    }
};

// TODO: merge clientbound and serverbound packets when they are the same
pub const Packet2Handshake = struct {
    username: []const u8,

    pub fn send(self: @This(), stream: *std.Io.Writer) !void {
        // Check beforehand
        try checkUsername(self.username);

        // Packet ID
        try stream.writeByte(0x02);
        // Username
        try string.writeStringFast(stream, self.username);

        // TODO: should this be done here?
        try stream.flush();
    }

    fn checkUsername(name: []const u8) !void {
        // Check Name Len
        if (name.len < 3)
            return error.UsernameTooShort;
        if (name.len > 16)
            return error.UsernameTooLong;
        // Check name characters
        for (name) |char| {
            switch (char) {
                'a'...'z' => continue,
                'A'...'Z' => continue,
                '0'...'9' => continue,
                '_' => continue,
                else => return error.InvalidUsernameCharacter,
            }
        }
    }
};

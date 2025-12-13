const std = @import("std");
const net = @import("net.zig");

pub const Packet2Handshake = struct {
    username: []const u8,

    pub fn send(self: Packet2Handshake, stream: *std.Io.Writer) !void {
        // Check beforehand
        try checkUsername(self.username);

        // TODO: varInt serialization (with comptime version)
        try stream.writeByte(0x02);
        try stream.writeInt(u16, @intCast(self.username.len), .big);
        for (self.username) |char| {
            try stream.writeInt(u16, @intCast(char), .big);
        }

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

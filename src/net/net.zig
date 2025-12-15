//! Root of the net module
//! To read packets from a TCP stream

const std = @import("std");
const client_bound = @import("client_bound.zig");
const server_bound = @import("server_bound.zig");

pub const Packets = @import("packets.zig").Packets;
pub const InboundPacket = client_bound.InboundPacket;

pub const endianness = std.builtin.Endian.big;
pub const protocol_version = 14;

/// Takes in a new packet from the data stream
pub fn readPacket(alloc: std.mem.Allocator, data: *std.Io.Reader) !InboundPacket {
    const packet_id = try data.takeEnum(Packets, endianness);

    // inline switching on else to get the right packet class
    switch (packet_id) {
        inline else => |id| {
            // id is comptime here (because of inline) but packet_id isn't
            const field = std.meta.fields(InboundPacket)[@intFromEnum(id)];

            const packet = field.type.receive(alloc, data) catch |err| {
                std.debug.print("Error when interpreting packet {}\n", .{id});
                return err;
            };

            return @unionInit(InboundPacket, field.name, packet);
        },
    }
}

/// TEMPORARY (TODO where to put functions like this?)
pub fn handshake(stream: *std.Io.Writer) !void {
    const packet = server_bound.Packet2Handshake{ .username = "MainCraft1" };
    try packet.send(stream);
}

/// TEMPORARY (TODO where to put functions like this?)
pub fn login(stream: *std.Io.Writer) !void {
    const packet = server_bound.Packet1Login{ .username = "MainCraft1" };
    try packet.send(stream);
}

test "net tests" {
    std.testing.refAllDecls(@import("var_int.zig"));
    std.testing.refAllDecls(@import("string.zig"));
}

//! Root of the net module
//! To read packets from a TCP stream

const std = @import("std");

pub const client_bound = @import("client_bound.zig");
pub const server_bound = @import("server_bound.zig");

pub const Packets = @import("packets.zig").Packets;
pub const InboundPacket = client_bound.InboundPacket;
pub const OutboundPacket = server_bound.OutboundPacket;

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
                std.log.err("Error when interpreting packet {}", .{id});
                return err;
            };

            return @unionInit(InboundPacket, field.name, packet);
        },
    }
}

test "net tests" {
    std.testing.refAllDecls(@import("string.zig"));
}

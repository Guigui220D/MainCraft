//! All clientbound packets and methods to read them

const std = @import("std");
const net = @import("net.zig");
const string = @import("string.zig");

pub const BadPacket = struct {
    pub fn receive(_: *std.Io.Reader) !@This() {
        return error.BadPacket;
    }
};

pub const Packet0KeepAlive = struct {
    pub fn receive(_: *std.Io.Reader) !@This() {
        return .{};
    }
};

// Despite having the same name as the serverbound packet
// And the same field types, they are used differently
// TODO: should I name it differently?
pub const Packet1Login = struct {
    entity_id: i32,
    //username: []const u8, // Unused serverbound
    map_seed: i64,
    dimension: i8,

    pub fn receive(stream: *std.Io.Reader) !@This() {
        // TEMPORARY (TODO)
        var buf: [128]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const alloc = fba.allocator();

        const entity_id = try stream.takeInt(i32, net.endianness);
        _ = try string.readString(stream, alloc);
        const map_seed = try stream.takeInt(i64, net.endianness);
        const dimension = try stream.takeInt(i8, net.endianness);

        std.debug.print("Entity id: {}\nMap seed: {x}\nDimension: {}\n", .{ entity_id, map_seed, dimension });

        return .{
            .entity_id = entity_id,
            .map_seed = map_seed,
            .dimension = dimension,
        };
    }
};

pub const Packet2Handshake = struct {
    username: []const u8,

    pub fn receive(stream: *std.Io.Reader) !@This() {
        // TEMPORARY (TODO)
        var buf: [128]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const alloc = fba.allocator();
        const name = try string.readString(stream, alloc);
        std.debug.print("Handshake: \"{s}\"\n", .{name});
        return undefined;
    }
};

// List of all packet classes to retrieve them via a comptime ID (grouped by 16)
pub const packet_by_id = [256]type{
    // 0
    Packet0KeepAlive,
    Packet1Login,
    Packet2Handshake,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 16
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 32
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 48
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 64
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 80
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 96
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 112
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 128
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 144
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 160
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 176
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 192
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 208
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 224
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 240
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    BadPacket,
    // 256
};

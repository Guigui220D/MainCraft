//! Packet to validate login

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

// Despite having the same name as the serverbound packet
// And the same field types, they are used differently
// TODO: should I name it differently?

entity_id: i32,
//username: []const u8, // Unused serverbound
map_seed: i64,
dimension: i8,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    // Entity ID
    const entity_id = try stream.takeInt(i32, net.endianness);
    // Unused string
    try string.discardString(stream, 16);
    // Map seed
    const map_seed = try stream.takeInt(i64, net.endianness);
    // Dimension
    const dimension = try stream.takeInt(i8, net.endianness);

    return .{
        .entity_id = entity_id,
        .map_seed = map_seed,
        .dimension = dimension,
    };
}

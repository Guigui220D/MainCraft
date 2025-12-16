//! Packet spawning an entity

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");

entity_id: i32,
entity_type: i8,
x_position: i32,
y_position: i32,
z_position: i32,
yaw: i8,
pitch: i8,

and_more: void,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    const ret = @This(){
        .entity_id = try stream.takeInt(i32, net.endianness),
        .entity_type = try stream.takeInt(i8, net.endianness),
        .x_position = try stream.takeInt(i32, net.endianness),
        .y_position = try stream.takeInt(i32, net.endianness),
        .z_position = try stream.takeInt(i32, net.endianness),
        .yaw = try stream.takeInt(i8, net.endianness),
        .pitch = try stream.takeInt(i8, net.endianness),
        .and_more = {}, // placeholder
    };

    // TODO: keep data for real
    // TEMPORARY

    while (true) {
        const byte = try stream.takeInt(u8, net.endianness);

        // 127 is the end marker
        if (byte == 127)
            break;

        const b = (byte & 224) >> 5;
        switch (b) {
            0 => {
                const n = try stream.takeInt(i8, net.endianness);
                _ = n; //std.debug.print("Byte: {}\n", .{n});
            },
            1 => {
                const n = try stream.takeInt(i16, net.endianness);
                _ = n; // std.debug.print("Short: {}\n", .{n});
            },
            2 => {
                const n = try stream.takeInt(i32, net.endianness);
                _ = n; //std.debug.print("Int: {}\n", .{n});
            },
            3 => {
                const n: f32 = @bitCast(try stream.takeInt(i32, net.endianness));
                _ = n; //std.debug.print("Float: {}\n", .{n});
            },
            4 => {
                const str = try string.readString(stream, alloc, 64);
                defer alloc.free(str);
                //std.debug.print("String: {s}\n", .{str});
            },
            5 => {
                const item_id = try stream.takeInt(i16, net.endianness);
                const stack_size = try stream.takeInt(i8, net.endianness);
                const item_dmg = try stream.takeInt(i16, net.endianness);
                _ = item_id;
                _ = stack_size;
                _ = item_dmg;
                //std.debug.print("Item: {},{},{}\n", .{ item_id, stack_size, item_dmg });
            },
            6 => {
                const x = try stream.takeInt(i32, net.endianness);
                const y = try stream.takeInt(i32, net.endianness);
                const z = try stream.takeInt(i32, net.endianness);
                _ = x;
                _ = y;
                _ = z;
                //std.debug.print("Coords: {},{},{}\n", .{ x, y, z });
            },
            else => std.debug.print("Unexpected byte {}\n", .{b}),
        }
    }

    return ret;
}

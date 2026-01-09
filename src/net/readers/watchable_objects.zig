//! Reader for watchable objects

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");
const item_stack = @import("item_stack.zig");
const WatchableObject = @import("entities").WatchableObject;

/// Interpret array of watchable objects from the stream
/// Caller owns the list and contained strings
pub fn read(alloc: std.mem.Allocator, stream: *std.Io.Reader) ![]WatchableObject {
    var list: std.ArrayList(WatchableObject) = .{};
    errdefer {
        // Free strings
        for (list.items) |wo| {
            if (wo.payload == .string) {
                alloc.free(wo.payload.string);
            }
        }
        // Free list
        list.deinit(alloc);
    }

    while (true) {
        const byte = try stream.takeByte();

        // 127 is the end marker
        if (byte == 127)
            break;

        const b = (byte & 224) >> 5;
        const k = (byte & 31);

        var to_add: WatchableObject = undefined;
        to_add.key = k;

        // Interpret payload
        to_add.payload = switch (b) {
            0 => .{ .byte = try stream.takeInt(i8, net.endianness) },
            1 => .{ .short = try stream.takeInt(i16, net.endianness) },
            2 => .{ .int = try stream.takeInt(i32, net.endianness) },
            3 => .{ .float = @bitCast(try stream.takeInt(i32, net.endianness)) },
            4 => .{ .string = try string.readString(stream, alloc, 64) },
            5 => .{ .item_stack = try item_stack.read(stream, .full) },
            6 => .{ .coordinates = .{
                .x = try stream.takeInt(i32, net.endianness),
                .y = try stream.takeInt(i32, net.endianness),
                .z = try stream.takeInt(i32, net.endianness),
            } },
            else => {
                std.debug.print("Unexpected byte {}\n", .{b});
                unreachable;
            },
        };

        // Add to array
        try list.append(alloc, to_add);
    }

    return try list.toOwnedSlice(alloc);
}

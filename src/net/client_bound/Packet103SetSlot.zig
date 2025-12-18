//! Packet updating an inventory slot

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");
const ItemStack = @import("inventory").ItemStack;
const is_reader = @import("readers/item_stack.zig");

window_id: i8,
item_slot: i16,
item_stack: ItemStack,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    const window_id = try stream.takeInt(i8, net.endianness);
    const item_slot = try stream.takeInt(i16, net.endianness);

    // Read item stack
    const stack: ItemStack = try is_reader.read(stream, .compact);

    return .{
        .item_slot = item_slot,
        .item_stack = stack,
        .window_id = window_id,
    };
}

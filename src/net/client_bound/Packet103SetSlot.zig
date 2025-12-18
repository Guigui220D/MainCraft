//! Packet updating an inventory slot

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");
const ItemStack = @import("inventory").ItemStack;

window_id: i8,
item_slot: i16,
item_stack: ItemStack,

pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    const window_id = try stream.takeInt(i8, net.endianness);
    const item_slot = try stream.takeInt(i16, net.endianness);

    // Read item stack
    const item_id = try stream.takeInt(i16, net.endianness);

    var stack: ItemStack = .{};
    if (item_id >= 0) {
        stack.item_id = @intCast(item_id);
        stack.size = try stream.takeInt(u8, net.endianness);
        stack.item_dmg = try stream.takeInt(u16, net.endianness);
    }

    return .{
        .item_slot = item_slot,
        .item_stack = stack,
        .window_id = window_id,
    };
}

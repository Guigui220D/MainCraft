//! Packet describing an inventory

const std = @import("std");
const net = @import("../net.zig");
const string = @import("../string.zig");
const ItemStack = @import("inventory").ItemStack;
const is_reader = @import("../readers/item_stack.zig");

window_id: i8,
item_stacks: []const ItemStack,

pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
    const window_id = try stream.takeInt(i8, net.endianness);
    const item_count = @max(try stream.takeInt(i16, net.endianness), 0);

    const stacks = try alloc.alloc(ItemStack, @intCast(item_count));
    errdefer alloc.free(stacks);

    // Read each stack
    for (stacks) |*stack| {
        stack.* = try is_reader.read(stream, .compact);
    }

    return .{
        .window_id = window_id,
        .item_stacks = stacks,
    };
}

pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
    alloc.free(self.item_stacks);
}

pub const tag = net.Packets.window_items_104;

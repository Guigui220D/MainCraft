//! Reimplementation of DataWatcher.java

const std = @import("std");
const coord = @import("coord");
const ItemStack = @import("inventory").ItemStack;

const WatchableObject = @This();

key: u8,
payload: union(enum) {
    byte: i8,
    short: i16,
    int: i32,
    float: f32,
    string: []const u8,
    item_stack: ItemStack,
    coordinates: coord.Block,
},

/// Free a slice of watchable objects the right way
pub fn free(wos: []const WatchableObject, alloc: std.mem.Allocator) void {
    // Free strings
    for (wos) |wo| {
        if (wo.payload == .string) {
            alloc.free(wo.payload.string);
        }
    }
    // Free list
    alloc.free(wos);
}

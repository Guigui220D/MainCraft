//! Reimplementation of DataWatcher.java

const std = @import("std");
const ItemStack = @import("inventory").ItemStack;

pub const WatchableObject = struct {
    key: u8,
    payload: union(enum) {
        byte: i8,
        short: i16,
        int: i32,
        float: f32,
        string: []const u8,
        item_stack: ItemStack,
        coordinates: struct {
            // TODO: make module for coordinates
            x: i32,
            y: i32,
            z: i32,
        },
    },
};

// Free a slice of watchable objects the right way
pub fn freeWatchableObjects(wos: []const WatchableObject, alloc: std.mem.Allocator) void {
    // Free strings
    for (wos) |wo| {
        if (wo.payload == .string) {
            alloc.free(wo.payload.string);
        }
    }
    // Free list
    alloc.free(wos);
}

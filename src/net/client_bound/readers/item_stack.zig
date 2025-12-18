//! Reader for item stacks

const std = @import("std");
const net = @import("../../net.zig");
const ItemStack = @import("inventory").ItemStack;

pub const ReadMode = enum {
    full,
    compact,
};

/// Read an ItemStack from a reader stream
/// .compact mode only reads the rest of the item if the id is defined (used by some packets)
/// .full reads the whole item (used by data_watcher for instance)
pub fn read(reader: *std.Io.Reader, comptime read_mode: ReadMode) !ItemStack {
    if (read_mode == .compact) {
        var ret: ItemStack = .{};

        const item_id = try reader.takeInt(i16, net.endianness);
        if (item_id >= 0) {
            // Only read item when id is non zero
            ret.item_id = @intCast(item_id);
            ret.size = try reader.takeInt(u8, net.endianness);
            ret.item_dmg = try reader.takeInt(u16, net.endianness);
        }

        return ret;
    } else {
        return .{
            .item_id = @intCast(try reader.takeInt(i16, net.endianness)),
            .size = try reader.takeInt(u8, net.endianness),
            .item_dmg = try reader.takeInt(u16, net.endianness),
        };
    }
}

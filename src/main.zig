const std = @import("std");
const server = @import("server.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

    try server.run(alloc);
}

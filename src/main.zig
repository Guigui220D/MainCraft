const std = @import("std");
const io = @import("io");
const network = @import("network");

pub const tracy_impl = @import("tracy_impl");

pub const tracy = @import("tracy");
pub const tracy_options: tracy.Options = .{
    .on_demand = false,
    .no_broadcast = false,
    .only_localhost = true,
    .only_ipv4 = false,
    .delayed_init = false,
    .manual_lifetime = false,
    .verbose = false,
    .data_port = null,
    .broadcast_port = null,
    .default_callstack_depth = 0,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.log.debug("Loading network", .{});
    try network.init();
    defer network.deinit();
    std.log.debug("Network ready", .{});

    std.log.info("Running frontend \"{s}\"", .{io.frontend_name});
    try io.main(alloc);
    std.log.info("Game stopped", .{});
}

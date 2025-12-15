const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const network_dep = b.dependency("network", .{});
    const spsc_queue_dep = b.dependency("spsc_queue", .{});

    // Internal modules
    const nbt_mod = b.addModule("nbt", .{
        .root_source_file = b.path("src/nbt/nbt.zig"),
        .target = target,
    });

    const net_mod = b.addModule("net", .{
        .root_source_file = b.path("src/net/net.zig"),
        .target = target,
    });

    // Client executable
    const exe = b.addExecutable(.{
        .name = "maincraft",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nbt", .module = nbt_mod },
                .{ .name = "net", .module = net_mod },
                .{ .name = "network", .module = network_dep.module("network") },
                .{ .name = "spsc_queue", .module = spsc_queue_dep.module("spsc_queue") },
            },
        }),
    });

    b.installArtifact(exe);

    // STEPS

    // Run step and command
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Module tests
    const nbt_mod_tests = b.addTest(.{
        .root_module = nbt_mod,
    });
    const run_nbt_tests = b.addRunArtifact(nbt_mod_tests);

    const net_mod_tests = b.addTest(.{
        .root_module = net_mod,
    });
    const run_net_tests = b.addRunArtifact(net_mod_tests);

    // Client tests
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // All tests step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_nbt_tests.step);
    test_step.dependOn(&run_net_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const network_dep = b.dependency("network", .{});
    const spsc_queue_dep = b.dependency("spsc_queue", .{});
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    // Internal modules
    const nbt_mod = b.addModule("nbt", .{
        .root_source_file = b.path("src/nbt/nbt.zig"),
        .target = target,
    });

    const inv_mod = b.addModule("inventory", .{
        .root_source_file = b.path("src/inventory/inventory.zig"),
        .target = target,
    });

    const coord_mod = b.addModule("coord", .{
        .root_source_file = b.path("src/coord/coord.zig"),
        .target = target,
    });

    const dw_mod = b.addModule("data_watcher", .{
        .root_source_file = b.path("src/data_watcher/data_watcher.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "inventory", .module = inv_mod },
        },
    });

    const terrain_mod = b.addModule("terrain", .{
        .root_source_file = b.path("src/terrain/terrain.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "coord", .module = coord_mod },
        },
    });

    const io_mod = b.addModule("io", .{
        .root_source_file = b.path("src/io/io.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "raylib", .module = raylib_dep.module("raylib") },
            .{ .name = "raygui", .module = raylib_dep.module("raygui") },
            .{ .name = "terrain", .module = terrain_mod },
            .{ .name = "coord", .module = coord_mod },
        },
    });
    io_mod.linkLibrary(raylib_dep.artifact("raylib"));

    terrain_mod.addImport("io", io_mod);

    const net_mod = b.addModule("net", .{
        .root_source_file = b.path("src/net/net.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "data_watcher", .module = dw_mod },
            .{ .name = "inventory", .module = inv_mod },
        },
    });

    // Client executable
    const exe = b.addExecutable(.{
        .name = "maincraft",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // Internal
                .{ .name = "nbt", .module = nbt_mod },
                .{ .name = "net", .module = net_mod },
                .{ .name = "data_watcher", .module = dw_mod },
                .{ .name = "inventory", .module = inv_mod },
                .{ .name = "io", .module = io_mod },
                .{ .name = "coord", .module = coord_mod },
                .{ .name = "terrain", .module = terrain_mod },
                // Dependencies
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

    const inv_mod_tests = b.addTest(.{
        .root_module = inv_mod,
    });
    const run_inv_tests = b.addRunArtifact(inv_mod_tests);

    const dw_mod_tests = b.addTest(.{
        .root_module = dw_mod,
    });
    const run_dw_tests = b.addRunArtifact(dw_mod_tests);

    const io_mod_tests = b.addTest(.{
        .root_module = io_mod,
    });
    const run_io_tests = b.addRunArtifact(io_mod_tests);

    const coord_mod_tests = b.addTest(.{
        .root_module = coord_mod,
    });
    const run_coord_tests = b.addRunArtifact(coord_mod_tests);

    const terrain_mod_tests = b.addTest(.{
        .root_module = terrain_mod,
    });
    const run_terrain_tests = b.addRunArtifact(terrain_mod_tests);

    // Client tests
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // All tests step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_nbt_tests.step);
    test_step.dependOn(&run_net_tests.step);
    test_step.dependOn(&run_inv_tests.step);
    test_step.dependOn(&run_dw_tests.step);
    test_step.dependOn(&run_io_tests.step);
    test_step.dependOn(&run_coord_tests.step);
    test_step.dependOn(&run_terrain_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Individual test steps
    b.step("test_nbt", "Run NBT module tests").dependOn(&run_nbt_tests.step);
    b.step("test_net", "Run net module tests").dependOn(&run_net_tests.step);
    b.step("test_inv", "Run inventory module tests").dependOn(&run_inv_tests.step);
    b.step("test_dw", "Run data watcher module tests").dependOn(&run_nbt_tests.step);
    b.step("test_io", "Run game i/o module tests").dependOn(&run_nbt_tests.step);
    b.step("test_coord", "Run coordinates module tests").dependOn(&run_nbt_tests.step);
    b.step("test_terrain", "Run terrain module tests").dependOn(&run_nbt_tests.step);
    b.step("test_exe", "Run NBT module tests").dependOn(&run_exe_tests.step);
}

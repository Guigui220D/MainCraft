const std = @import("std");

pub const Frontend = enum {
    dummy,
    raylib,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tracy_enabled = b.option(
        bool,
        "tracy",
        "Build with Tracy support.",
    ) orelse false;

    const frontend = b.option(
        Frontend,
        "frontend",
        "Select the frontend",
    ) orelse .raylib;

    // Dependencies
    const network_dep = b.dependency("network", .{});
    const spsc_queue_dep = b.dependency("spsc_queue", .{});
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const tracy_dep = b.dependency("tracy", .{
        .target = target,
        .optimize = optimize,
    });

    const tracy_impl_mod = if (tracy_enabled) tracy_dep.module("tracy_impl_enabled") else tracy_dep.module("tracy_impl_disabled");

    // Internal modules
    const inv_mod = b.addModule("inventory", .{
        .root_source_file = b.path("src/inventory/inventory.zig"),
        .target = target,
    });

    const coord_mod = b.addModule("coord", .{
        .root_source_file = b.path("src/coord/coord.zig"),
        .target = target,
    });

    const terrain_mod = b.addModule("terrain", .{
        .root_source_file = b.path("src/terrain/terrain.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "coord", .module = coord_mod },
            .{ .name = "tracy", .module = tracy_dep.module("tracy") },
        },
    });

    const blocks_mod = b.addModule("blocks", .{
        .root_source_file = b.path("src/blocks/blocks.zig"),
        .target = target,
    });
    terrain_mod.addImport("blocks", blocks_mod);

    const meshing_mod = b.addModule("meshing", .{
        .root_source_file = b.path("src/meshing/meshing.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "blocks", .module = blocks_mod },
            .{ .name = "coord", .module = coord_mod },
            .{ .name = "terrain", .module = terrain_mod },
            .{ .name = "tracy", .module = tracy_dep.module("tracy") },
        },
    });

    const entities_mod = b.addModule("entities", .{
        .root_source_file = b.path("src/entities/entities.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "coord", .module = coord_mod },
            .{ .name = "inventory", .module = inv_mod },
        },
    });

    const raylib_io_mod = b.addModule("io", .{
        .root_source_file = b.path("src/frontend/raylib/io.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "raylib", .module = raylib_dep.module("raylib") },
            .{ .name = "raygui", .module = raylib_dep.module("raygui") },
        },
    });
    raylib_io_mod.linkLibrary(raylib_dep.artifact("raylib"));

    const dummy_io_mod = b.addModule("io", .{
        .root_source_file = b.path("src/frontend/dummy/io.zig"),
        .target = target,
    });

    const io_mod = switch (frontend) {
        .dummy => dummy_io_mod,
        .raylib => raylib_io_mod,
    };
    io_mod.addImport("terrain", terrain_mod);
    io_mod.addImport("entities", entities_mod);
    io_mod.addImport("coord", coord_mod);
    io_mod.addImport("blocks", blocks_mod);
    io_mod.addImport("meshing", meshing_mod);
    io_mod.addImport("tracy", tracy_dep.module("tracy"));
    terrain_mod.addImport("io", io_mod);
    meshing_mod.addImport("io", io_mod);
    entities_mod.addImport("io", io_mod);

    const net_mod = b.addModule("net", .{
        .root_source_file = b.path("src/net/net.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "inventory", .module = inv_mod },
        },
    });
    net_mod.addImport("entities", entities_mod);

    const engine_mod = b.addModule("engine", .{
        .root_source_file = b.path("src/engine/engine.zig"),
        .target = target,
        .imports = &.{
            // Internal
            .{ .name = "net", .module = net_mod },
            .{ .name = "inventory", .module = inv_mod },
            .{ .name = "io", .module = io_mod },
            .{ .name = "coord", .module = coord_mod },
            .{ .name = "terrain", .module = terrain_mod },
            .{ .name = "blocks", .module = blocks_mod },
            .{ .name = "entities", .module = entities_mod },
            // Dependencies
            .{ .name = "network", .module = network_dep.module("network") },
            .{ .name = "spsc_queue", .module = spsc_queue_dep.module("spsc_queue") },
            .{ .name = "tracy", .module = tracy_dep.module("tracy") },
        },
    });

    io_mod.addImport("engine", engine_mod);

    // Client executable
    const exe = b.addExecutable(.{
        .name = "maincraft",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // Internal
                .{ .name = "io", .module = io_mod },
                // Dependencies
                .{ .name = "network", .module = network_dep.module("network") },
                .{ .name = "tracy", .module = tracy_dep.module("tracy") },
            },
        }),
    });

    exe.root_module.addImport("tracy_impl", tracy_impl_mod);

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
    const net_mod_tests = b.addTest(.{
        .root_module = net_mod,
    });
    const run_net_tests = b.addRunArtifact(net_mod_tests);

    const inv_mod_tests = b.addTest(.{
        .root_module = inv_mod,
    });
    const run_inv_tests = b.addRunArtifact(inv_mod_tests);

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

    const blocks_mod_tests = b.addTest(.{
        .root_module = blocks_mod,
    });
    const run_blocks_tests = b.addRunArtifact(blocks_mod_tests);

    const meshing_mod_tests = b.addTest(.{
        .root_module = meshing_mod,
    });
    const run_meshing_tests = b.addRunArtifact(meshing_mod_tests);

    const entities_mod_tests = b.addTest(.{
        .root_module = entities_mod,
    });
    const run_entities_tests = b.addRunArtifact(entities_mod_tests);

    const engine_mod_tests = b.addTest(.{
        .root_module = engine_mod,
    });
    const run_engine_tests = b.addRunArtifact(engine_mod_tests);

    // Client tests
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // All tests step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_net_tests.step);
    test_step.dependOn(&run_inv_tests.step);
    test_step.dependOn(&run_io_tests.step);
    test_step.dependOn(&run_coord_tests.step);
    test_step.dependOn(&run_terrain_tests.step);
    test_step.dependOn(&run_blocks_tests.step);
    test_step.dependOn(&run_meshing_tests.step);
    test_step.dependOn(&run_entities_tests.step);
    test_step.dependOn(&run_engine_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Individual test steps
    b.step("test_net", "Run net module tests").dependOn(&run_net_tests.step);
    b.step("test_inv", "Run inventory module tests").dependOn(&run_inv_tests.step);
    b.step("test_io", "Run game i/o module tests").dependOn(&run_io_tests.step);
    b.step("test_coord", "Run coordinates module tests").dependOn(&run_coord_tests.step);
    b.step("test_terrain", "Run terrain module tests").dependOn(&run_terrain_tests.step);
    b.step("test_blocks", "Run blocks module tests").dependOn(&run_blocks_tests.step);
    b.step("test_meshing", "Run meshing module tests").dependOn(&run_meshing_tests.step);
    b.step("test_entities", "Run entities module tests").dependOn(&run_entities_tests.step);
    b.step("test_engine", "Run engine tests").dependOn(&run_engine_tests.step);
    b.step("test_exe", "Run NBT module tests").dependOn(&run_exe_tests.step);
}

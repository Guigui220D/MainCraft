const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // MODULES

    // Nbt library
    const nbt_mod = b.addModule("nbt", .{
        .root_source_file = b.path("src/nbt/nbt.zig"),
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
    const run_mod_tests = b.addRunArtifact(nbt_mod_tests);

    // Client tests
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // All tests step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // Library Module
    // ========================================================================
    const mod = b.addModule("openpricing", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // ========================================================================
    // Shared Library for FFI
    // ========================================================================
    const shared_lib = b.addLibrary(.{
        .name = "openpricing",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ffi/bindings.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "openpricing", .module = mod },
            },
        }),
    });

    shared_lib.linkLibC();
    b.installArtifact(shared_lib);

    // ========================================================================
    // CLI Executable
    // ========================================================================
    const exe = b.addExecutable(.{
        .name = "openpricing-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "openpricing", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    // ========================================================================
    // Run Step
    // ========================================================================
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the CLI application");
    run_step.dependOn(&run_cmd.step);

    // ========================================================================
    // Tests
    // ========================================================================
    const lib_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);
}

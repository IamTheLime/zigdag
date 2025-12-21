const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library Module
    const mod = b.addModule("openpricing", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // JSON to Zig Code Generation
    // Converts pricing_model.json into generated_nodes.zig at build time
    const codegen_exe = b.addExecutable(.{
        .name = "json_to_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/json_to_zig.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });

    const codegen_run = b.addRunArtifact(codegen_exe);
    codegen_run.addFileArg(b.path("models/pricing_model.json"));
    const generated_file = codegen_run.addOutputFileArg("generated_nodes.zig");

    const generated_mod = b.addModule("generated_nodes", .{
        .root_source_file = generated_file,
        .target = target,
        .imports = &.{
            .{ .name = "openpricing", .module = mod },
        },
    });

    // CLI Executable
    const exe = b.addExecutable(.{
        .name = "openpricing-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "openpricing", .module = mod },
                .{ .name = "generated_nodes", .module = generated_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // Run Step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the CLI application");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    // Check Step (for ZLS)
    const exe_check = b.addExecutable(.{
        .name = "openpricing-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "openpricing", .module = mod },
                .{ .name = "generated_nodes", .module = generated_mod },
            },
        }),
    });

    const test_check = b.addTest(.{
        .root_module = mod,
    });

    const check = b.step("check", "Check if openpricing compiles");
    check.dependOn(&exe_check.step);
    check.dependOn(&test_check.step);
}

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
    // JSON to Zig Code Generation (Compile-Time Magic!)
    // ========================================================================
    // This step converts pricing_model.json into generated_nodes.zig
    // The generated code becomes compile-time constants, enabling:
    // - Zero runtime parsing
    // - Zero runtime validation
    // - Fully inlined execution
    // - Stack-allocated node arrays

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

    // Create a module for the generated nodes
    const generated_mod = b.addModule("generated_nodes", .{
        .root_source_file = generated_file,
        .target = target,
        .imports = &.{
            .{ .name = "openpricing", .module = mod },
        },
    });

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
                .{ .name = "generated_nodes", .module = generated_mod },
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
    // Compile-Time JSON Example (DISABLED - not possible in current Zig)
    // ========================================================================
    // Note: True compile-time JSON parsing with allocations is not supported
    // in Zig. Use the code generation approach instead (json_to_zig.zig).
    // const json_comptime_example = b.addExecutable(.{
    //     .name = "json_comptime_example",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("examples/json_comptime_example.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //         .imports = &.{
    //             .{ .name = "openpricing", .module = mod },
    //         },
    //     }),
    // });

    // b.installArtifact(json_comptime_example);

    // const run_json_comptime = b.addRunArtifact(json_comptime_example);
    // run_json_comptime.step.dependOn(b.getInstallStep());

    // const run_json_comptime_step = b.step("run-json-comptime", "Run the compile-time JSON example");
    // run_json_comptime_step.dependOn(&run_json_comptime.step);

    // ========================================================================
    // Tests
    // ========================================================================
    const lib_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    // ========================================================================
    // ZLS Check Step (enables Build-On-Save in ZLS)
    // ========================================================================
    // This creates check artifacts without installing them, allowing ZLS
    // to provide real-time diagnostics as you type.

    // Check the main library module
    const lib_check = b.addLibrary(.{
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
    lib_check.linkLibC();

    // Check the CLI executable (needs generated nodes)
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

    // Check tests
    const test_check = b.addTest(.{
        .root_module = mod,
    });

    // Register the check step that ZLS will use
    const check = b.step("check", "Check if openpricing compiles");
    check.dependOn(&lib_check.step);
    check.dependOn(&exe_check.step);
    check.dependOn(&test_check.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library Module
    const mod = b.addModule("zigdag", .{
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
            .{ .name = "zigdag", .module = mod },
        },
    });

    // Shared Library (for FFI from Python/Node.js/etc)
    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigdag", .module = mod },
            .{ .name = "generated_nodes", .module = generated_mod },
        },
    });

    const lib = b.addLibrary(.{
        .name = "zigdag",
        .root_module = lib_module,
        .linkage = .dynamic, // Shared library
    });

    b.installArtifact(lib);

    // Benchmark Executable
    const benchmark_module = b.createModule(.{
        .root_source_file = b.path("benchmark/benchmark.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigdag", .module = mod },
            .{ .name = "generated_nodes", .module = generated_mod },
        },
    });

    const benchmark_exe = b.addExecutable(.{
        .name = "zigdag-benchmark",
        .root_module = benchmark_module,
    });

    b.installArtifact(benchmark_exe);

    // Run Step (runs benchmark)
    const run_cmd = b.addRunArtifact(benchmark_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the benchmark");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    // =========================================================================
    // Python Package Generation
    // =========================================================================
    // Builds a complete Python package with the native library and type stubs
    //
    // Usage:
    //   zig build python-package                     # Build for current platform
    //   zig build python-package -Dtarget=aarch64-macos  # Cross-compile for macOS ARM
    //   zig build python-package -Dtarget=x86_64-macos   # Cross-compile for macOS Intel
    //   zig build python-package -Dtarget=aarch64-linux  # Cross-compile for Linux ARM
    // =========================================================================

    const python_package_step = b.step("python-package", "Generate Python package with native library");

    // Determine library suffix based on target
    const target_info = target.result;
    const lib_suffix: []const u8 = if (target_info.os.tag == .macos) "dylib" else "so";

    // Python package generator executable (runs on host)
    const pygen_exe = b.addExecutable(.{
        .name = "gen_python_package",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gen_python_package.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });

    // The Python generator reads the model name from JSON and creates the package directory
    const pygen_run = b.addRunArtifact(pygen_exe);
    pygen_run.addFileArg(b.path("models/pricing_model.json"));

    // Output base directory: zig-out/python-dist/
    // The generator will create <base>/<package_name>/ based on the JSON
    const pkg_base_dir = b.fmt("{s}/python-dist", .{b.install_path});
    pygen_run.addArg(pkg_base_dir);
    pygen_run.addArg(lib_suffix);

    // The Python generator depends on the codegen step (to validate the model)
    pygen_run.step.dependOn(&codegen_run.step);

    // Create install step for the library into the Python package
    // Note: We need to copy the library after the package dir is created
    // For now, we'll use a fixed name that matches what's in the model
    const lib_install = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "python-dist/zigdag" } },
    });

    // Python package step depends on both the library and the Python files
    python_package_step.dependOn(&pygen_run.step);
    python_package_step.dependOn(&lib_install.step);

    // =========================================================================
    // Cross-compilation convenience targets
    // =========================================================================

    // Add convenience steps for common cross-compilation targets
    addCrossCompileStep(b, "python-package-linux-x64", "x86_64-linux", mod);
    addCrossCompileStep(b, "python-package-linux-arm64", "aarch64-linux", mod);
    addCrossCompileStep(b, "python-package-macos-x64", "x86_64-macos", mod);
    addCrossCompileStep(b, "python-package-macos-arm64", "aarch64-macos", mod);

    // Check Step (for ZLS)
    const lib_check_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigdag", .module = mod },
            .{ .name = "generated_nodes", .module = generated_mod },
        },
    });

    const lib_check = b.addLibrary(.{
        .name = "zigdag",
        .root_module = lib_check_module,
        .linkage = .dynamic,
    });

    const benchmark_check_module = b.createModule(.{
        .root_source_file = b.path("benchmark/benchmark.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigdag", .module = mod },
            .{ .name = "generated_nodes", .module = generated_mod },
        },
    });

    const benchmark_check = b.addExecutable(.{
        .name = "zigdag-benchmark",
        .root_module = benchmark_check_module,
    });

    const test_check = b.addTest(.{
        .root_module = mod,
    });

    const check = b.step("check", "Check if zigdag compiles");
    check.dependOn(&lib_check.step);
    check.dependOn(&benchmark_check.step);
    check.dependOn(&test_check.step);
}

fn addCrossCompileStep(
    b: *std.Build,
    step_name: []const u8,
    target_str: []const u8,
    zigdag_mod: *std.Build.Module,
) void {
    const cross_target = std.Target.Query.parse(.{ .arch_os_abi = target_str }) catch unreachable;
    const resolved_target = b.resolveTargetQuery(cross_target);

    const target_info = resolved_target.result;
    const lib_suffix: []const u8 = if (target_info.os.tag == .macos) "dylib" else "so";

    // Regenerate generated_nodes for this target
    const codegen_exe = b.addExecutable(.{
        .name = "json_to_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/json_to_zig.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });

    const codegen_run = b.addRunArtifact(codegen_exe);
    codegen_run.addFileArg(b.path("models/pricing_model.json"));
    const generated_file = codegen_run.addOutputFileArg("generated_nodes.zig");

    const generated_mod = b.addModule(b.fmt("generated_nodes_{s}", .{target_str}), .{
        .root_source_file = generated_file,
        .target = resolved_target,
        .imports = &.{
            .{ .name = "zigdag", .module = zigdag_mod },
        },
    });

    // Build library for the target
    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = resolved_target,
        .optimize = .ReleaseFast,
        .imports = &.{
            .{ .name = "zigdag", .module = zigdag_mod },
            .{ .name = "generated_nodes", .module = generated_mod },
        },
    });

    const lib = b.addLibrary(.{
        .name = "zigdag",
        .root_module = lib_module,
        .linkage = .dynamic,
    });

    // Python package generator
    const pygen_exe = b.addExecutable(.{
        .name = b.fmt("gen_python_package_{s}", .{target_str}),
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gen_python_package.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });

    const pkg_base_dir = b.fmt("python-dist-{s}", .{target_str});

    const pygen_run = b.addRunArtifact(pygen_exe);
    pygen_run.addFileArg(b.path("models/pricing_model.json"));
    pygen_run.addArg(b.fmt("{s}/{s}", .{ b.install_path, pkg_base_dir }));
    pygen_run.addArg(lib_suffix);

    const lib_install = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("{s}/zigdag", .{pkg_base_dir}) } },
    });

    const step = b.step(step_name, b.fmt("Build Python package for {s}", .{target_str}));
    step.dependOn(&pygen_run.step);
    step.dependOn(&lib_install.step);
}

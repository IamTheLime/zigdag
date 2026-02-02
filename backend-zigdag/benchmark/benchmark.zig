const std = @import("std");
const zigdag = @import("zigdag");
const generated = @import("generated_nodes");

// ============================================================================
// BENCHMARK - Tests the compile-time pricing model with hardcoded inputs
// ============================================================================
// This benchmark demonstrates and tests the pricing engine with default values
// The actual library (main.zig) will expose FFI functions for Python/other languages

const PRICING_NODES = generated.nodes;

// Create the executor type based on the compile-time generated nodes
const PRICING_EXECUTOR = zigdag.ComptimeExecutorFromNodes(PRICING_NODES);

/// Benchmark entry point - demonstrates the compile-time pricing model
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize executor - everything is on the stack!
    var executor = PRICING_EXECUTOR.init();

    // Execute pricing calculation
    std.debug.print("\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("  ZigDag - Compile-Time Engine\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Pricing Model Information:\n", .{});
    std.debug.print("  - JSON parsed at: COMPILE TIME\n", .{});
    std.debug.print("  - Graph validated at: COMPILE TIME\n", .{});
    std.debug.print("  - Nodes in model: {d}\n", .{PRICING_NODES.len});
    std.debug.print("  - Node storage: STACK (no heap!)\n", .{});
    std.debug.print("  - Execution: FULLY INLINED\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Compile-Time Node Information:\n", .{});
    inline for (PRICING_NODES) |node| {
        std.debug.print("  [{s}] {s}\n", .{ @tagName(node.operation), node.metadata.name });
        std.debug.print("      Description: {s}\n", .{node.metadata.description});
        switch (node.operation) {
            .constant_input_num => |op| {
                std.debug.print("      Value: {d}\n", .{op.value});
            },
            .dynamic_input_num => |op| {
                if (op.allowed_values.len > 0) {
                    std.debug.print("      Allowed values: ", .{});
                    inline for (op.allowed_values, 0..) |val, i| {
                        if (i > 0) std.debug.print(", ", .{});
                        std.debug.print("{d}", .{val});
                    }
                    std.debug.print("\n", .{});
                }
            },
            .dynamic_input_str => |op| {
                if (op.allowed_values != null and op.allowed_values.?.len > 0) {
                    std.debug.print("      Allowed values: ", .{});
                    inline for (op.allowed_values, 0..) |val, i| {
                        if (i > 0) std.debug.print(", ", .{});
                        std.debug.print("{d}", .{val});
                    }
                    std.debug.print("\n", .{});
                }
            },
            else => {},
        }
        const deps = comptime zigdag.comptime_parser.getDependencies(node.operation);
        if (comptime deps.len > 0) {
            std.debug.print("      Inputs: ", .{});
            inline for (deps, 0..) |input, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{input});
            }
            std.debug.print("\n", .{});
        }
    }
    std.debug.print("\n", .{});
    std.debug.print("Running example calculation...\n", .{});

    // Set input values - this is the ONLY runtime operation besides the math!
    // All dynamic numeric inputs are set to 100.0 for testing
    inline for (PRICING_NODES) |node| {
        switch (node.operation) {
            .dynamic_input_num => {
                std.debug.print("  Setting {s} = 100.0\n", .{node.metadata.name});
                try executor.setInputNum(node.node_id, 100.0);
            },
            .dynamic_input_str => {
                std.debug.print("  Setting {s} = 'tiago'\n", .{node.metadata.name});
                try executor.setInputStr(node.node_id, "tiago");
            },
            else => {},
        }
    }

    // Single test execution to show result
    const test_result = try executor.getOutput();
    std.debug.print("  Result: ${d:.2}\n", .{test_result});
    std.debug.print("\n", .{});

    // Benchmark: Run 1 million iterations
    std.debug.print("Running benchmark (1,000,000 iterations)...\n", .{});
    const iterations: usize = 1_000_000;

    var timer = try std.time.Timer.start();
    var i: usize = 0;
    var total: f64 = 0.0;

    while (i < iterations) : (i += 1) {
        const result = try executor.getOutput();
        total += result; // Prevent optimization from removing the calculation
    }

    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const elapsed_s = elapsed_ms / 1000.0;
    const per_iteration_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const iterations_per_sec = @as(f64, @floatFromInt(iterations)) / elapsed_s;

    std.debug.print("\nSingle-Item Benchmark Results:\n", .{});
    std.debug.print("  Total time: {d:.2}ms ({d:.4}s)\n", .{ elapsed_ms, elapsed_s });
    std.debug.print("  Per iteration: {d:.2}ns\n", .{per_iteration_ns});
    std.debug.print("  Throughput: {d:.0} calculations/sec\n", .{iterations_per_sec});
    std.debug.print("  Verification sum: ${d:.2}\n", .{total});
    std.debug.print("\n", .{});

    // Batch Benchmark
    std.debug.print("Running batch benchmark (10,000 batches × 100 items = 1M)...\n", .{});

    // Get list of dynamic inputs at compile time
    const dynamic_inputs = comptime blk: {
        var inputs: []const []const u8 = &.{};
        for (PRICING_NODES) |node| {
            if (node.operation == .dynamic_input_num or node.operation == .dynamic_input_str) {
                inputs = inputs ++ &[_][]const u8{node.node_id};
            }
        }
        break :blk inputs;
    };

    const batch_size: usize = 100;
    const num_batches: usize = 10_000;
    const total_batch_items = batch_size * num_batches;

    // Prepare batch input data
    const batch_inputs = try allocator.alloc(f64, batch_size * dynamic_inputs.len);
    defer allocator.free(batch_inputs);
    const batch_results = try allocator.alloc(f64, batch_size);
    defer allocator.free(batch_results);

    // Fill with test values
    for (batch_inputs) |*val| {
        val.* = 100.0;
    }

    var batch_executor = PRICING_EXECUTOR.init();
    timer.reset();
    var batch_idx: usize = 0;
    var batch_total: f64 = 0.0;

    while (batch_idx < num_batches) : (batch_idx += 1) {
        // Process batch
        var row: usize = 0;
        while (row < batch_size) : (row += 1) {
            // Set inputs for this row
            inline for (dynamic_inputs, 0..) |node_id, input_idx| {
                const node_op = comptime blk: {
                    for (PRICING_NODES) |node| {
                        if (std.mem.eql(u8, node.node_id, node_id)) {
                            break :blk node.operation;
                        }
                    }
                    unreachable;
                };

                if (node_op == .dynamic_input_num) {
                    const value = batch_inputs[row * dynamic_inputs.len + input_idx];
                    try batch_executor.setInputNum(node_id, value);
                } else {
                    try batch_executor.setInputStr(node_id, "tiago");
                }
            }

            // Calculate result
            batch_results[row] = try batch_executor.getOutput();
            batch_total += batch_results[row];
        }
    }

    const batch_elapsed_ns = timer.read();
    const batch_elapsed_ms = @as(f64, @floatFromInt(batch_elapsed_ns)) / 1_000_000.0;
    const batch_elapsed_s = batch_elapsed_ms / 1000.0;
    const batch_per_item_ns = @as(f64, @floatFromInt(batch_elapsed_ns)) / @as(f64, @floatFromInt(total_batch_items));
    const batch_items_per_sec = @as(f64, @floatFromInt(total_batch_items)) / batch_elapsed_s;

    std.debug.print("\nBatch Benchmark Results:\n", .{});
    std.debug.print("  Total time: {d:.2}ms ({d:.4}s)\n", .{ batch_elapsed_ms, batch_elapsed_s });
    std.debug.print("  Per item: {d:.2}ns\n", .{batch_per_item_ns});
    std.debug.print("  Throughput: {d:.0} calculations/sec\n", .{batch_items_per_sec});
    std.debug.print("  Verification sum: ${d:.2}\n", .{batch_total});
    std.debug.print("\n", .{});

    std.debug.print("Performance Characteristics:\n", .{});
    std.debug.print("  - JSON parsing: ZERO (done at compile time)\n", .{});
    std.debug.print("  - Graph validation: ZERO (done at compile time)\n", .{});
    std.debug.print("  - Memory allocation: Minimal (just input hashmap)\n", .{});
    std.debug.print("  - Execution: Pure computation (fully inlined)\n", .{});
    std.debug.print("  - Node values: Stack-allocated array\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Code Generation:\n", .{});
    std.debug.print("  The execute() function is completely inlined.\n", .{});
    std.debug.print("  At runtime, this is just a few arithmetic operations!\n", .{});
    std.debug.print("  No loops, no conditionals, no overhead.\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Workflow:\n", .{});
    std.debug.print("  1. Design model in frontend (React Flow UI)\n", .{});
    std.debug.print("  2. Export JSON to models/dag_model.json\n", .{});
    std.debug.print("  3. Rebuild - nodes auto-generated at compile time!\n", .{});
    std.debug.print("  4. New model is baked into the binary\n", .{});
    std.debug.print("  5. Use from Python with ctypes/cffi\n", .{});
    std.debug.print("  6. Enjoy ZERO-OVERHEAD pricing calculations!\n", .{});
    std.debug.print("\n", .{});
}

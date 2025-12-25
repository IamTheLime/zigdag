const std = @import("std");
const openpricing = @import("openpricing");
const generated = @import("generated_nodes");

// ============================================================================
// GENERATED PRICING NODES - Auto-generated from models/pricing_model.json
// ============================================================================
// These nodes are generated at build time by tools/json_to_zig.zig
// Workflow:
// 1. Design your pricing model in the frontend (React Flow UI)
// 2. Export to JSON and save to models/pricing_model.json
// 3. Build the project - nodes are auto-generated and compiled in!
// 4. The pricing model is now baked into your binary at compile time!

const PRICING_NODES = generated.nodes;

// Create the executor type based on the compile-time generated nodes
const PRICING_EXECUTOR = openpricing.ComptimeExecutorFromNodes(PRICING_NODES);

/// Main entry point - demonstrates the compile-time pricing model
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize executor - everything is on the stack!
    var executor = PRICING_EXECUTOR.init();
    _ = allocator; // No longer needed

    // Execute pricing calculation
    std.debug.print("\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("  OpenPricing - Compile-Time Engine\n", .{});
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
            else => {},
        }
        const deps = comptime openpricing.comptime_parser.getDependencies(node.operation);
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
        if (node.operation == .dynamic_input_num) {
            std.debug.print("  Setting {s} = 100.0\n", .{node.metadata.name});
            try executor.setInput(node.node_id, 100.0);
        }
        // Conditional value inputs are also set to 100.0 for testing
        // (In production, these would be computed from the conditional_values map)
        if (node.operation == .conditional_value_input) {
            std.debug.print("  Setting {s} = 100.0 (test default)\n", .{node.metadata.name});
            try executor.setInput(node.node_id, 100.0);
        }
    }

    // Execute - this is pure computation, fully inlined by the compiler!
    // The last node in the array is always the output (should be a funnel node)
    const output_node = PRICING_NODES[PRICING_NODES.len - 1];
    const result = try executor.getOutput(output_node.node_id);

    std.debug.print("  {s}: ${d:.2}\n", .{ output_node.metadata.name, result });
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
    std.debug.print("  2. Export JSON to models/pricing_model.json\n", .{});
    std.debug.print("  3. Rebuild - nodes auto-generated at compile time!\n", .{});
    std.debug.print("  4. New model is baked into the binary\n", .{});
    std.debug.print("  5. Use from Python with ctypes/cffi\n", .{});
    std.debug.print("  6. Enjoy ZERO-OVERHEAD pricing calculations!\n", .{});
    std.debug.print("\n", .{});
}

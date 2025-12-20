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

const PricingNodes = generated.nodes;

// Create the executor type based on the compile-time generated nodes
const PricingExecutor = openpricing.ComptimeExecutorFromNodes(PricingNodes);

/// Main entry point - demonstrates the compile-time pricing model
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize executor - only allocates the input hash map, everything else is on the stack!
    var executor = PricingExecutor.init(allocator);
    defer executor.deinit();

    // Execute pricing calculation
    std.debug.print("\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("  OpenPricing - Compile-Time Engine\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Pricing Model Information:\n", .{});
    std.debug.print("  - JSON parsed at: COMPILE TIME\n", .{});
    std.debug.print("  - Graph validated at: COMPILE TIME\n", .{});
    std.debug.print("  - Nodes in model: {d}\n", .{PricingNodes.len});
    std.debug.print("  - Node storage: STACK (no heap!)\n", .{});
    std.debug.print("  - Execution: FULLY INLINED\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Compile-Time Node Information:\n", .{});
    inline for (PricingNodes) |node| {
        std.debug.print("  [{s}] {s}\n", .{ @tagName(node.operation), node.name });
        std.debug.print("      Description: {s}\n", .{node.description});
        if (node.operation == .constant) {
            std.debug.print("      Value: {d}\n", .{node.constant_value});
        }
        if (node.inputs.len > 0) {
            std.debug.print("      Inputs: ", .{});
            inline for (node.inputs, 0..) |input, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{input});
            }
            std.debug.print("\n", .{});
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("Running example calculation...\n", .{});

    // Set input values - this is the ONLY runtime operation besides the math!
    // The example sets all input nodes to demonstrate the model
    inline for (PricingNodes) |node| {
        if (node.operation == .input) {
            std.debug.print("  Setting {s} = 100.0\n", .{node.name});
            try executor.setInput(node.id, 100.0);
        }
    }

    // Execute - this is pure computation, fully inlined by the compiler!
    // Use the last node as output (typically the final result)
    const output_node = PricingNodes[PricingNodes.len - 1];
    const result = try executor.execute(output_node.id);

    std.debug.print("  {s}: ${d:.2}\n", .{ output_node.name, result });
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

//! Example: Parse JSON pricing models at compile-time
//!
//! This example shows how to use @embedFile to load JSON pricing models
//! at compile-time, eliminating the need for:
//! - Runtime JSON parsing
//! - Build-time code generation
//! - Heap allocations
//!
//! Your JSON files remain the source of truth for both frontend and backend!

const std = @import("std");
const openpricing = @import("openpricing");

// Method 1: Embed and parse JSON at compile-time
// The JSON file is read at compile-time and converted to a static node array
const pricing_model_from_json = openpricing.parseComptimeJSON(
    @embedFile("test_pricing.json"),
);

pub fn main() !void {
    std.debug.print("=== Compile-Time JSON Parsing Example ===\n\n", .{});

    // Show that the model was parsed at compile-time
    std.debug.print("Loaded pricing model from JSON at compile-time!\n", .{});
    std.debug.print("Number of nodes: {d}\n", .{pricing_model_from_json.len});
    std.debug.print("All nodes are static and live in .rodata section\n\n", .{});

    // List all nodes
    std.debug.print("Nodes in the model:\n", .{});
    inline for (pricing_model_from_json, 0..) |node, i| {
        std.debug.print("  [{d}] {s} ({s})\n", .{ i, node.name, @tagName(node.operation) });
        std.debug.print("      ID: {s}\n", .{node.id});
        std.debug.print("      Description: {s}\n", .{node.description});
        if (node.inputs.len > 0) {
            std.debug.print("      Inputs: ", .{});
            inline for (node.inputs, 0..) |input, j| {
                if (j > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{input});
            }
            std.debug.print("\n", .{});
        }
        if (node.constant_value != 0.0) {
            std.debug.print("      Constant: {d}\n", .{node.constant_value});
        }
        std.debug.print("\n", .{});
    }

    // Create an executor from the compile-time parsed JSON
    std.debug.print("Creating executor from JSON model...\n", .{});
    const PricingExecutor = openpricing.ComptimeExecutorFromNodes(pricing_model_from_json);
    var executor = PricingExecutor{};

    // Run a calculation
    std.debug.print("\nRunning pricing calculation:\n", .{});
    std.debug.print("  Base Price: $100.00\n", .{});
    std.debug.print("  Quantity: 5\n", .{});

    try executor.setInput("base_price", 100.0);
    try executor.setInput("quantity", 5.0);

    // Get intermediate values
    const subtotal = try executor.getOutput("subtotal");
    const discount_amount = try executor.getOutput("discount_amount");
    const after_discount = try executor.getOutput("after_discount");
    const tax_amount = try executor.getOutput("tax_amount");
    const final_total = try executor.getOutput("final_total");

    std.debug.print("\nCalculation breakdown:\n", .{});
    std.debug.print("  Subtotal: ${d:.2}\n", .{subtotal});
    std.debug.print("  Discount (10%%): -${d:.2}\n", .{discount_amount});
    std.debug.print("  After Discount: ${d:.2}\n", .{after_discount});
    std.debug.print("  Tax (8%%): +${d:.2}\n", .{tax_amount});
    std.debug.print("  Final Total: ${d:.2}\n", .{final_total});

    std.debug.print("\n=== Benefits of Compile-Time JSON Parsing ===\n", .{});
    std.debug.print("✓ JSON files remain source of truth\n", .{});
    std.debug.print("✓ Frontend and backend share same JSON models\n", .{});
    std.debug.print("✓ No build-time code generation step\n", .{});
    std.debug.print("✓ No runtime JSON parsing\n", .{});
    std.debug.print("✓ No heap allocations\n", .{});
    std.debug.print("✓ All data in .rodata (read-only)\n", .{});
    std.debug.print("✓ Compile-time validation of JSON structure\n", .{});
    std.debug.print("✓ Type errors caught at compile-time\n", .{});
    std.debug.print("✓ Single command: `zig build`\n", .{});

    std.debug.print("\n=== Workflow ===\n", .{});
    std.debug.print("1. Edit JSON file: models/pricing_model.json\n", .{});
    std.debug.print("2. Run: zig build\n", .{});
    std.debug.print("3. Done! JSON is parsed at compile-time\n", .{});
}

//! Example: Using the compile-time builder to define pricing models
//!
//! This example shows how to define pricing models directly in Zig
//! without any JSON files or code generation steps.
//!
//! Run with: zig build run-comptime-example

const std = @import("std");
const openpricing = @import("openpricing");

// Import the pre-defined pricing models
const pricing_models = @import("../src/pricing_models.zig");

pub fn main() !void {
    std.debug.print("=== OpenPricing Compile-Time Builder Example ===\n\n", .{});

    // Example 1: Using a pre-defined model
    std.debug.print("Example 1: Simple Pricing Model\n", .{});
    std.debug.print("Model has {d} nodes, all defined at compile-time!\n", .{pricing_models.simple_pricing.len});
    std.debug.print("Node structure lives in .rodata (read-only data section)\n\n", .{});

    // List all nodes in the simple pricing model
    inline for (pricing_models.simple_pricing, 0..) |node, i| {
        std.debug.print("  [{d}] {s}: {s} (operation: {s})\n", .{
            i,
            node.name,
            node.description,
            @tagName(node.operation),
        });
    }
    std.debug.print("\n", .{});

    // Example 2: Create a ComptimeExecutor from the model
    std.debug.print("Example 2: Creating a ComptimeExecutor\n", .{});
    const PricingExecutor = openpricing.ComptimeExecutorFromNodes(pricing_models.simple_pricing);

    var executor = PricingExecutor{};

    // Set input values
    try executor.setInput("base_price", 100.0);
    try executor.setInput("quantity", 5.0);

    // Execute the pricing calculation
    const final_price = try executor.getOutput("final_total");

    std.debug.print("Inputs:\n", .{});
    std.debug.print("  Base Price: $100.00\n", .{});
    std.debug.print("  Quantity: 5\n", .{});
    std.debug.print("\nCalculation:\n", .{});
    std.debug.print("  Subtotal: $500.00\n", .{});
    std.debug.print("  Discount (10%): -$50.00\n", .{});
    std.debug.print("  After Discount: $450.00\n", .{});
    std.debug.print("  Tax (8%): +$36.00\n", .{});
    std.debug.print("  Final Total: ${d:.2}\n\n", .{final_price});

    // Example 3: Define a custom model inline
    std.debug.print("Example 3: Inline Model Definition\n", .{});

    const builder = openpricing.comptime_builder;
    const custom_model = builder.comptimeModel(&.{
        builder.input("hourly_rate", "Hourly Rate", "Rate per hour"),
        builder.input("hours_worked", "Hours Worked", "Total hours"),
        builder.multiply("gross_pay", "Gross Pay", "Hours × Rate", &.{ "hourly_rate", "hours_worked" }),
        builder.constant("tax_rate", "Tax Rate", "Income tax 20%", 0.20),
        builder.multiply("tax_amount", "Tax Amount", "Tax to withhold", &.{ "gross_pay", "tax_rate" }),
        builder.subtract("net_pay", "Net Pay", "Take-home pay", &.{ "gross_pay", "tax_amount" }),
    });

    const PayrollExecutor = openpricing.ComptimeExecutorFromNodes(custom_model);
    var payroll = PayrollExecutor{};

    try payroll.setInput("hourly_rate", 50.0);
    try payroll.setInput("hours_worked", 40.0);

    const net_pay = try payroll.getOutput("net_pay");

    std.debug.print("Payroll Calculation:\n", .{});
    std.debug.print("  Rate: $50/hour\n", .{});
    std.debug.print("  Hours: 40\n", .{});
    std.debug.print("  Gross Pay: $2000.00\n", .{});
    std.debug.print("  Tax (20%%): -$400.00\n", .{});
    std.debug.print("  Net Pay: ${d:.2}\n\n", .{net_pay});

    // Example 4: Subscription pricing model
    std.debug.print("Example 4: Subscription Pricing\n", .{});
    std.debug.print("Model: {s}\n", .{"subscription_pricing"});
    std.debug.print("Nodes: {d}\n", .{pricing_models.subscription_pricing.len});

    const SubExecutor = openpricing.ComptimeExecutorFromNodes(pricing_models.subscription_pricing);
    var sub_executor = SubExecutor{};

    try sub_executor.setInput("api_calls", 5000.0);
    try sub_executor.setInput("storage_gb", 25.0);

    const monthly_bill = try sub_executor.getOutput("monthly_total");

    std.debug.print("Usage:\n", .{});
    std.debug.print("  API Calls: 5,000 (1,000 free, 4,000 billable)\n", .{});
    std.debug.print("  Storage: 25 GB (10 GB free, 15 GB billable)\n", .{});
    std.debug.print("  Base Fee: $29.99\n", .{});
    std.debug.print("  API Charges: $4.00\n", .{});
    std.debug.print("  Storage Charges: $1.50\n", .{});
    std.debug.print("  Monthly Total: ${d:.2}\n\n", .{monthly_bill});

    std.debug.print("=== Benefits of Compile-Time Models ===\n", .{});
    std.debug.print("✓ No JSON parsing at runtime\n", .{});
    std.debug.print("✓ No heap allocations needed\n", .{});
    std.debug.print("✓ Type-safe at compile time\n", .{});
    std.debug.print("✓ Zero-cost abstractions\n", .{});
    std.debug.print("✓ All data in .rodata section\n", .{});
    std.debug.print("✓ Perfect for embedded systems\n", .{});
}

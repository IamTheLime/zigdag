const std = @import("std");
const testing = std.testing;
const openpricing = @import("openpricing");
const builder = openpricing.comptime_builder;

test "comptime builder - simple model" {
    const model = builder.comptimeModel(&.{
        builder.input("a", "A", "Input A"),
        builder.input("b", "B", "Input B"),
        builder.add("result", "Result", "A + B", &.{ "a", "b" }),
    });

    try testing.expectEqual(3, model.len);
    try testing.expectEqualStrings("a", model[0].id);
    try testing.expectEqualStrings("b", model[1].id);
    try testing.expectEqualStrings("result", model[2].id);
}

test "comptime builder - execution" {
    const model = builder.comptimeModel(&.{
        builder.input("base_price", "Base Price", "Product base price"),
        builder.input("quantity", "Quantity", "Number of items"),
        builder.multiply("total", "Total", "Price × Quantity", &.{ "base_price", "quantity" }),
    });

    const Executor = openpricing.ComptimeExecutorFromNodes(model);
    var exec = Executor{};

    try exec.setInput("base_price", 100.0);
    try exec.setInput("quantity", 5.0);

    const result = try exec.getOutput("total");
    try testing.expectEqual(500.0, result);
}

test "comptime builder - complex calculation" {
    const model = builder.comptimeModel(&.{
        builder.input("base_price", "Base Price", "Product base price"),
        builder.input("quantity", "Quantity", "Number of items"),
        builder.multiply("subtotal", "Subtotal", "Price × Quantity", &.{ "base_price", "quantity" }),
        builder.constant("discount_rate", "Discount Rate", "10% discount", 0.1),
        builder.multiply("discount_amount", "Discount Amount", "Discount dollars", &.{ "subtotal", "discount_rate" }),
        builder.subtract("after_discount", "After Discount", "After discount", &.{ "subtotal", "discount_amount" }),
        builder.constant("tax_rate", "Tax Rate", "8% tax", 0.08),
        builder.multiply("tax_amount", "Tax Amount", "Tax dollars", &.{ "after_discount", "tax_rate" }),
        builder.add("final_total", "Final Total", "Total with tax", &.{ "after_discount", "tax_amount" }),
    });

    const Executor = openpricing.ComptimeExecutorFromNodes(model);
    var exec = Executor{};

    try exec.setInput("base_price", 100.0);
    try exec.setInput("quantity", 5.0);

    const final_total = try exec.getOutput("final_total");

    // Expected: 500 * 0.9 = 450, then 450 * 1.08 = 486
    try testing.expectApproxEqRel(486.0, final_total, 0.001);
}

test "comptime builder - weighted sum" {
    const model = builder.comptimeModel(&.{
        builder.input("a", "A", "Input A"),
        builder.input("b", "B", "Input B"),
        builder.input("c", "C", "Input C"),
        builder.weightedSum("result", "Result", "Weighted sum", &.{ "a", "b", "c" }, &.{ 0.5, 0.3, 0.2 }),
    });

    const Executor = openpricing.ComptimeExecutorFromNodes(model);
    var exec = Executor{};

    try exec.setInput("a", 100.0);
    try exec.setInput("b", 50.0);
    try exec.setInput("c", 20.0);

    const result = try exec.getOutput("result");

    // Expected: 100*0.5 + 50*0.3 + 20*0.2 = 50 + 15 + 4 = 69
    try testing.expectApproxEqRel(69.0, result, 0.001);
}

test "comptime builder - math operations" {
    const model = builder.comptimeModel(&.{
        builder.constant("four", "Four", "Number 4", 4.0),
        builder.sqrt("two", "Two", "Square root of 4", "four"),
        builder.power("sixteen", "Sixteen", "2^4", &.{ "two", "four" }),
        builder.log("result", "Result", "ln(16)", "sixteen"),
    });

    const Executor = openpricing.ComptimeExecutorFromNodes(model);
    var exec = Executor{};

    const result = try exec.getOutput("result");

    // Expected: ln(16) ≈ 2.7726
    try testing.expectApproxEqRel(2.7726, result, 0.01);
}

test "comptime builder - min/max" {
    const model = builder.comptimeModel(&.{
        builder.constant("a", "A", "Value 10", 10.0),
        builder.constant("b", "B", "Value 20", 20.0),
        builder.constant("c", "C", "Value 15", 15.0),
        builder.max("maximum", "Maximum", "Max of a,b,c", &.{ "a", "b", "c" }),
        builder.min("minimum", "Minimum", "Min of a,b,c", &.{ "a", "b", "c" }),
    });

    const Executor = openpricing.ComptimeExecutorFromNodes(model);
    var exec = Executor{};

    const max_result = try exec.getOutput("maximum");
    const min_result = try exec.getOutput("minimum");

    try testing.expectEqual(20.0, max_result);
    try testing.expectEqual(10.0, min_result);
}

test "comptime builder - using pre-defined models" {
    const pricing_models = @import("../src/pricing_models.zig");

    // Test that the model is valid
    try testing.expect(pricing_models.simple_pricing.len > 0);

    // Test that we can create an executor from it
    const Executor = openpricing.ComptimeExecutorFromNodes(pricing_models.simple_pricing);
    var exec = Executor{};

    try exec.setInput("base_price", 100.0);
    try exec.setInput("quantity", 5.0);

    const result = try exec.getOutput("final_total");

    // Should calculate correctly
    try testing.expect(result > 0.0);
}

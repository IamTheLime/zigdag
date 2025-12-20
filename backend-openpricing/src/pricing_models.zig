//! Compile-time pricing model definitions
//!
//! This file contains pricing models defined directly in Zig at compile-time.
//! No JSON parsing, no build-time code generation - just pure compile-time evaluation.
//! All data structures live in the .rodata section and are completely stack-based.

const openpricing = @import("openpricing");
const builder = openpricing.comptime_builder;

/// Simple pricing model: Base Price × Quantity with discount and tax
/// This replaces the pricing_model.json file
pub const simple_pricing = builder.comptimeModel(&.{
    builder.input("base_price", "Base Price", "Product base price"),
    builder.input("quantity", "Quantity", "Number of items"),
    builder.multiply("subtotal", "Subtotal", "Price × Quantity", &.{ "base_price", "quantity" }),
    builder.constant("discount_rate", "Discount Rate", "10% discount", 0.1),
    builder.multiply("discount_amount", "Discount Amount", "Discount in dollars", &.{ "subtotal", "discount_rate" }),
    builder.subtract("after_discount", "After Discount", "Price after discount", &.{ "subtotal", "discount_amount" }),
    builder.constant("tax_rate", "Tax Rate", "8% sales tax", 0.08),
    builder.multiply("tax_amount", "Tax Amount", "Tax in dollars", &.{ "after_discount", "tax_rate" }),
    builder.add("final_total", "Final Total", "Total price with tax", &.{ "after_discount", "tax_amount" }),
});

/// Tiered pricing model with volume discounts
/// Example: Different pricing based on quantity thresholds
pub const tiered_pricing = builder.comptimeModel(&.{
    builder.input("base_price", "Base Price", "Base unit price"),
    builder.input("quantity", "Quantity", "Number of units"),

    // Tier thresholds
    builder.constant("tier1_threshold", "Tier 1 Threshold", "First tier at 10 units", 10.0),
    builder.constant("tier2_threshold", "Tier 2 Threshold", "Second tier at 50 units", 50.0),

    // Discount rates for each tier
    builder.constant("tier0_rate", "Tier 0 Rate", "No discount", 1.0),
    builder.constant("tier1_rate", "Tier 1 Rate", "5% discount", 0.95),
    builder.constant("tier2_rate", "Tier 2 Rate", "10% discount", 0.90),

    // Calculate effective rate based on quantity (simplified - real version would use conditionals)
    // For demonstration, we'll use a weighted approach
    builder.multiply("base_total", "Base Total", "Quantity × Base Price", &.{ "base_price", "quantity" }),
    builder.multiply("discounted_total", "Discounted Total", "Total with volume discount", &.{ "base_total", "tier1_rate" }),
});

/// Subscription pricing with usage-based charges
pub const subscription_pricing = builder.comptimeModel(&.{
    // Base subscription fee
    builder.constant("base_subscription", "Base Subscription", "Monthly base fee", 29.99),

    // Usage inputs
    builder.input("api_calls", "API Calls", "Number of API calls this month"),
    builder.input("storage_gb", "Storage (GB)", "Storage used in gigabytes"),

    // Per-unit pricing
    builder.constant("price_per_call", "Price per Call", "$0.001 per API call", 0.001),
    builder.constant("price_per_gb", "Price per GB", "$0.10 per GB", 0.10),

    // Free tier allowances
    builder.constant("free_calls", "Free API Calls", "1000 free calls included", 1000.0),
    builder.constant("free_storage", "Free Storage", "10 GB included", 10.0),

    // Calculate overage
    builder.subtract("excess_calls", "Excess Calls", "Calls beyond free tier", &.{ "api_calls", "free_calls" }),
    builder.subtract("excess_storage", "Excess Storage", "Storage beyond free tier", &.{ "storage_gb", "free_storage" }),

    // Clamp to 0 (can't have negative usage)
    builder.max("billable_calls", "Billable Calls", "Calls to charge for", &.{ "excess_calls", "zero" }),
    builder.max("billable_storage", "Billable Storage", "Storage to charge for", &.{ "excess_storage", "zero" }),

    // Helper constant
    builder.constant("zero", "Zero", "Zero constant", 0.0),

    // Calculate usage charges
    builder.multiply("calls_charge", "API Calls Charge", "Cost for API calls", &.{ "billable_calls", "price_per_call" }),
    builder.multiply("storage_charge", "Storage Charge", "Cost for storage", &.{ "billable_storage", "price_per_gb" }),

    // Total
    builder.add("usage_total", "Usage Total", "Total usage charges", &.{ "calls_charge", "storage_charge" }),
    builder.add("monthly_total", "Monthly Total", "Total monthly bill", &.{ "base_subscription", "usage_total" }),
});

/// Complex pricing with weighted factors
pub const weighted_pricing = builder.comptimeModel(&.{
    builder.input("base_price", "Base Price", "Starting price"),
    builder.input("market_factor", "Market Factor", "Market conditions multiplier"),
    builder.input("customer_score", "Customer Score", "Customer loyalty score"),
    builder.input("urgency", "Urgency", "Urgency factor (0-1)"),

    // Use weighted sum to combine factors
    builder.weightedSum(
        "price_adjustment",
        "Price Adjustment",
        "Weighted combination of factors",
        &.{ "market_factor", "customer_score", "urgency" },
        &.{ 0.5, 0.3, 0.2 }, // Weights: 50% market, 30% customer, 20% urgency
    ),

    builder.multiply("adjusted_price", "Adjusted Price", "Price after adjustments", &.{ "base_price", "price_adjustment" }),
});

/// Mathematical pricing example using advanced operations
pub const math_pricing = builder.comptimeModel(&.{
    builder.input("base_value", "Base Value", "Starting value"),

    // Exponential growth
    builder.constant("growth_rate", "Growth Rate", "e^x growth", 1.5),
    builder.power("exponential_value", "Exponential Value", "Base^growth", &.{ "base_value", "growth_rate" }),

    // Logarithmic dampening
    builder.log("log_dampener", "Log Dampener", "Log of exponential", &.{"exponential_value"}),

    // Trigonometric adjustment (for cyclical pricing)
    builder.multiply("scaled_input", "Scaled Input", "Scale for trig", &.{ "base_value", "pi_over_6" }),
    builder.constant("pi_over_6", "Pi/6", "30 degrees in radians", 0.5236),
    builder.sin("sine_adjustment", "Sine Adjustment", "Cyclical component", &.{"scaled_input"}),

    // Combine
    builder.add("trig_adjusted", "Trig Adjusted", "With sine component", &.{ "log_dampener", "sine_adjustment" }),
    builder.abs("final_positive", "Final Positive", "Ensure positive value", &.{"trig_adjusted"}),
});

/// Example of using min/max for boundary constraints
pub const constrained_pricing = builder.comptimeModel(&.{
    builder.input("calculated_price", "Calculated Price", "Initial calculated price"),

    // Set price floor and ceiling
    builder.constant("min_price", "Minimum Price", "Price floor", 9.99),
    builder.constant("max_price", "Maximum Price", "Price ceiling", 999.99),

    // Clamp the price
    builder.clamp("final_price", "Final Price", "Price within bounds", &.{ "calculated_price", "min_price", "max_price" }),
});

# Compile-Time Builder API

The compile-time builder provides a clean, type-safe way to define pricing models directly in Zig without JSON files or code generation.

## Why Use the Compile-Time Builder?

### Before (JSON + Code Generation)
```
JSON file → json_to_zig tool → Generated .zig file → Compile
```

**Problems:**
- Multi-step build process
- JSON parsing required
- Separate tool to maintain
- Build-time dependencies

### After (Pure Compile-Time)
```
.zig file → Compile
```

**Benefits:**
- ✅ **Single-step compilation** - no build tools needed
- ✅ **Type-safe** - catch errors at compile time
- ✅ **Zero runtime cost** - all data in .rodata section
- ✅ **No heap allocations** - everything on the stack
- ✅ **Better IDE support** - full autocomplete and type checking
- ✅ **Cleaner code** - readable, maintainable pricing models

## Quick Start

### 1. Import the Builder

```zig
const openpricing = @import("openpricing");
const builder = openpricing.comptime_builder;
```

### 2. Define Your Pricing Model

```zig
const my_pricing_model = builder.comptimeModel(&.{
    builder.input("base_price", "Base Price", "Product base price"),
    builder.input("quantity", "Quantity", "Number of items"),
    builder.multiply("total", "Total", "Base × Quantity", &.{"base_price", "quantity"}),
});
```

### 3. Create an Executor

```zig
const PricingExecutor = openpricing.ComptimeExecutorFromNodes(my_pricing_model);
var executor = PricingExecutor{};
```

### 4. Use It

```zig
try executor.setInput("base_price", 100.0);
try executor.setInput("quantity", 5.0);
const result = try executor.getOutput("total"); // 500.0
```

## API Reference

### Basic Operations

#### Input Nodes
```zig
builder.input(id, name, description)
```
Defines a runtime input value.

#### Constant Nodes
```zig
builder.constant(id, name, description, value)
```
Defines a compile-time constant value.

### Arithmetic Operations

#### Addition
```zig
builder.add(id, name, description, &.{input1, input2, ...})
```
Sums multiple inputs.

#### Subtraction
```zig
builder.subtract(id, name, description, &.{minuend, subtrahend})
```
Subtracts second input from first.

#### Multiplication
```zig
builder.multiply(id, name, description, &.{input1, input2, ...})
```
Multiplies inputs together.

#### Division
```zig
builder.divide(id, name, description, &.{dividend, divisor})
```
Divides first input by second.

#### Power
```zig
builder.power(id, name, description, &.{base, exponent})
```
Raises base to exponent power.

#### Modulo
```zig
builder.modulo(id, name, description, &.{dividend, divisor})
```
Computes remainder of division.

### Mathematical Functions

#### Unary Operations
```zig
builder.negate(id, name, description, input)  // -x
builder.abs(id, name, description, input)     // |x|
builder.sqrt(id, name, description, input)    // √x
builder.exp(id, name, description, input)     // e^x
builder.log(id, name, description, input)     // ln(x)
builder.sin(id, name, description, input)     // sin(x)
builder.cos(id, name, description, input)     // cos(x)
```

### Comparison Operations

#### Max
```zig
builder.max(id, name, description, &.{input1, input2, ...})
```
Returns the maximum value.

#### Min
```zig
builder.min(id, name, description, &.{input1, input2, ...})
```
Returns the minimum value.

#### Clamp
```zig
builder.clamp(id, name, description, &.{value, min, max})
```
Restricts value to [min, max] range.

### Advanced Operations

#### Weighted Sum
```zig
builder.weightedSum(
    id, 
    name, 
    description, 
    &.{input1, input2, input3},
    &.{weight1, weight2, weight3}
)
```
Computes: input1×weight1 + input2×weight2 + input3×weight3

## Complete Examples

### Example 1: Simple E-commerce Pricing

```zig
const simple_pricing = builder.comptimeModel(&.{
    // Inputs
    builder.input("base_price", "Base Price", "Product base price"),
    builder.input("quantity", "Quantity", "Number of items"),
    
    // Calculate subtotal
    builder.multiply("subtotal", "Subtotal", "Price × Quantity", 
        &.{"base_price", "quantity"}),
    
    // Apply discount
    builder.constant("discount_rate", "Discount Rate", "10% off", 0.1),
    builder.multiply("discount_amount", "Discount Amount", "Discount in dollars",
        &.{"subtotal", "discount_rate"}),
    builder.subtract("after_discount", "After Discount", "Price after discount",
        &.{"subtotal", "discount_amount"}),
    
    // Add tax
    builder.constant("tax_rate", "Tax Rate", "8% sales tax", 0.08),
    builder.multiply("tax_amount", "Tax Amount", "Tax in dollars",
        &.{"after_discount", "tax_rate"}),
    
    // Final total
    builder.add("final_total", "Final Total", "Total with tax",
        &.{"after_discount", "tax_amount"}),
});
```

### Example 2: Subscription with Usage Tiers

```zig
const subscription_model = builder.comptimeModel(&.{
    // Base fee
    builder.constant("base_fee", "Base Fee", "Monthly subscription", 29.99),
    
    // Usage inputs
    builder.input("api_calls", "API Calls", "Number of API calls"),
    builder.input("storage_gb", "Storage GB", "Storage used"),
    
    // Free tier allowances
    builder.constant("free_calls", "Free Calls", "Included calls", 1000.0),
    builder.constant("free_storage", "Free Storage", "Included GB", 10.0),
    
    // Calculate overage
    builder.subtract("excess_calls", "Excess Calls", "Billable calls",
        &.{"api_calls", "free_calls"}),
    builder.subtract("excess_storage", "Excess Storage", "Billable GB",
        &.{"storage_gb", "free_storage"}),
    
    // Clamp to zero (can't have negative overage)
    builder.constant("zero", "Zero", "Zero constant", 0.0),
    builder.max("billable_calls", "Billable Calls", "Calls to charge",
        &.{"excess_calls", "zero"}),
    builder.max("billable_storage", "Billable Storage", "Storage to charge",
        &.{"excess_storage", "zero"}),
    
    // Per-unit pricing
    builder.constant("price_per_call", "Price per Call", "$0.001/call", 0.001),
    builder.constant("price_per_gb", "Price per GB", "$0.10/GB", 0.10),
    
    // Calculate charges
    builder.multiply("call_charges", "Call Charges", "API call fees",
        &.{"billable_calls", "price_per_call"}),
    builder.multiply("storage_charges", "Storage Charges", "Storage fees",
        &.{"billable_storage", "price_per_gb"}),
    
    // Total
    builder.add("usage_charges", "Usage Charges", "Total usage fees",
        &.{"call_charges", "storage_charges"}),
    builder.add("monthly_total", "Monthly Total", "Total bill",
        &.{"base_fee", "usage_charges"}),
});
```

### Example 3: Dynamic Pricing with Weighted Factors

```zig
const dynamic_pricing = builder.comptimeModel(&.{
    // Base price
    builder.input("base_price", "Base Price", "Starting price"),
    
    // Market factors
    builder.input("demand_factor", "Demand Factor", "Current demand (0-2)"),
    builder.input("competitor_factor", "Competitor Factor", "Market competition (0-2)"),
    builder.input("inventory_factor", "Inventory Factor", "Stock level (0-2)"),
    
    // Weighted combination (50% demand, 30% competition, 20% inventory)
    builder.weightedSum(
        "price_multiplier",
        "Price Multiplier",
        "Combined market factors",
        &.{"demand_factor", "competitor_factor", "inventory_factor"},
        &.{0.5, 0.3, 0.2}
    ),
    
    // Apply multiplier
    builder.multiply("dynamic_price", "Dynamic Price", "Market-adjusted price",
        &.{"base_price", "price_multiplier"}),
    
    // Set price bounds
    builder.constant("min_price", "Min Price", "Price floor", 9.99),
    builder.constant("max_price", "Max Price", "Price ceiling", 999.99),
    
    // Clamp to valid range
    builder.clamp("final_price", "Final Price", "Bounded price",
        &.{"dynamic_price", "min_price", "max_price"}),
});
```

### Example 4: Mathematical Pricing (Advanced)

```zig
const exponential_pricing = builder.comptimeModel(&.{
    builder.input("base_value", "Base Value", "Initial value"),
    
    // Exponential growth: base^1.5
    builder.constant("growth_rate", "Growth Rate", "Exponent", 1.5),
    builder.power("grown_value", "Grown Value", "Exponential growth",
        &.{"base_value", "growth_rate"}),
    
    // Logarithmic dampening
    builder.log("dampened_value", "Dampened Value", "Log adjustment",
        &.{"grown_value"}),
    
    // Cyclical adjustment using sine
    builder.input("time_factor", "Time Factor", "Time-based input (0-2π)"),
    builder.sin("cyclical", "Cyclical", "Sine wave component",
        &.{"time_factor"}),
    
    // Combine components
    builder.add("combined", "Combined", "Sum of components",
        &.{"dampened_value", "cyclical"}),
    
    // Ensure positive
    builder.abs("final_price", "Final Price", "Absolute value",
        &.{"combined"}),
});
```

## Comparison with JSON Approach

### Old Way (JSON)
```json
{
  "nodes": [
    {
      "id": "base_price",
      "operation": "input",
      "inputs": [],
      "weights": [],
      "constant_value": 0.0,
      "metadata": {
        "name": "Base Price",
        "description": "Product base price"
      }
    },
    {
      "id": "quantity",
      "operation": "input",
      "inputs": [],
      "weights": [],
      "constant_value": 0.0,
      "metadata": {
        "name": "Quantity",
        "description": "Number of items"
      }
    }
  ]
}
```

Then run: `zig run tools/json_to_zig.zig -- models/pricing.json src/generated.zig`

### New Way (Compile-Time)
```zig
const model = builder.comptimeModel(&.{
    builder.input("base_price", "Base Price", "Product base price"),
    builder.input("quantity", "Quantity", "Number of items"),
});
```

No build step required! Just import and use.

## Migration Guide

If you're currently using JSON models, here's how to migrate:

### Step 1: Create a new .zig file
```zig
// src/my_pricing_models.zig
const openpricing = @import("openpricing");
const builder = openpricing.comptime_builder;

pub const my_model = builder.comptimeModel(&.{
    // Your nodes here
});
```

### Step 2: Convert each JSON node

**JSON:**
```json
{
  "id": "subtotal",
  "operation": "multiply",
  "inputs": ["base_price", "quantity"],
  "metadata": {
    "name": "Subtotal",
    "description": "Price × Quantity"
  }
}
```

**Zig:**
```zig
builder.multiply("subtotal", "Subtotal", "Price × Quantity", 
    &.{"base_price", "quantity"}),
```

### Step 3: Update your build
Remove the JSON → Zig generation step from your build process.

### Step 4: Use the new model
```zig
const models = @import("my_pricing_models.zig");
const Executor = openpricing.ComptimeExecutorFromNodes(models.my_model);
```

## Best Practices

### 1. Organize Models in Modules
```zig
// src/pricing_models/ecommerce.zig
pub const simple = builder.comptimeModel(&.{ ... });
pub const tiered = builder.comptimeModel(&.{ ... });

// src/pricing_models/subscription.zig
pub const basic = builder.comptimeModel(&.{ ... });
pub const premium = builder.comptimeModel(&.{ ... });
```

### 2. Use Descriptive Names
```zig
// Good
builder.multiply("total_with_tax", "Total with Tax", "Final amount including tax", ...)

// Less clear
builder.multiply("t", "T", "t", ...)
```

### 3. Comment Complex Logic
```zig
// Calculate tiered discount based on volume
// 0-10 units: no discount
// 11-50 units: 5% discount
// 51+ units: 10% discount
builder.weightedSum("discount_rate", "Discount Rate", "Volume-based discount", ...),
```

### 4. Keep Models Focused
Each model should represent a single pricing strategy. Don't try to handle all cases in one model.

### 5. Test Your Models
```zig
test "simple pricing model calculation" {
    const Executor = openpricing.ComptimeExecutorFromNodes(simple_pricing);
    var exec = Executor{};
    
    try exec.setInput("base_price", 100.0);
    try exec.setInput("quantity", 5.0);
    
    const result = try exec.getOutput("final_total");
    try std.testing.expectApprox(486.0, result, 0.01);
}
```

## Performance Characteristics

- **Compile-time cost**: Models are evaluated once at compile time
- **Binary size**: Models live in .rodata section (read-only data)
- **Runtime cost**: Zero overhead - same as hand-written code
- **Memory**: Stack-only, no heap allocations
- **Type safety**: All errors caught at compile time

## Limitations

1. All node IDs and relationships must be known at compile time
2. Cannot dynamically add/remove nodes at runtime
3. Array sizes are fixed at compile time

For dynamic models, use the runtime JSON parser instead.

## See Also

- [COMPILE_TIME_APPROACH.md](./COMPILE_TIME_APPROACH.md) - Technical details
- [examples/comptime_example.zig](./examples/comptime_example.zig) - Working examples
- [src/pricing_models.zig](./src/pricing_models.zig) - Pre-built models

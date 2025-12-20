# Compile-Time JSON Parsing

This guide shows how to use JSON files as your pricing model source while leveraging Zig's compile-time features to eliminate runtime overhead.

## The Problem

You want to:
1. ✅ Use JSON as the source of truth (shared with frontend)
2. ✅ Avoid multi-step build processes
3. ✅ Eliminate runtime JSON parsing
4. ✅ Keep everything on the stack (no heap allocations)

## The Solution: `@embedFile` + Compile-Time Parsing

Zig can **read and parse JSON files at compile-time** using `@embedFile` and `parseComptimeJSON`. This gives you:

```
JSON file → @embedFile → Compile-time parse → Static .rodata → Zero runtime cost
```

## Quick Start

### 1. Create Your JSON Model

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
    },
    {
      "id": "total",
      "operation": "multiply",
      "inputs": ["base_price", "quantity"],
      "weights": [],
      "constant_value": 0.0,
      "metadata": {
        "name": "Total",
        "description": "Final total"
      }
    }
  ]
}
```

### 2. Load and Parse at Compile-Time

```zig
const openpricing = @import("openpricing");

// This happens at COMPILE-TIME, not runtime!
const pricing_nodes = openpricing.parseComptimeJSON(
    @embedFile("path/to/your/model.json")
);

// Create an executor from the parsed nodes
const PricingExecutor = openpricing.ComptimeExecutorFromNodes(pricing_nodes);
```

### 3. Use It

```zig
pub fn main() !void {
    var executor = PricingExecutor{};
    
    try executor.setInput("base_price", 100.0);
    try executor.setInput("quantity", 5.0);
    
    const total = try executor.getOutput("total"); // 500.0
    std.debug.print("Total: ${d:.2}\n", .{total});
}
```

### 4. Build

```bash
zig build
```

That's it! No separate build steps, no code generation tools.

## Comparison with Previous Approach

### Before: Multi-Step Process

```bash
# Step 1: Generate Zig code from JSON
zig run tools/json_to_zig.zig -- models/pricing.json src/generated_nodes.zig

# Step 2: Compile
zig build
```

**Problems:**
- Two-step build process
- Need to maintain json_to_zig tool
- Generated files in source tree
- Easy to forget regeneration step

### After: Single-Step Compile-Time

```bash
# Just build!
zig build
```

**Benefits:**
- ✅ One command
- ✅ No tool maintenance
- ✅ No generated files
- ✅ JSON parsed at compile-time
- ✅ Compile errors if JSON is invalid

## How It Works

### 1. `@embedFile` (Zig Built-in)

```zig
const json_content = @embedFile("models/pricing.json");
// json_content is a []const u8 available at COMPILE-TIME
```

The `@embedFile` builtin reads the file during compilation and makes its contents available as a compile-time string constant.

### 2. `parseComptimeJSON` (OpenPricing Function)

```zig
pub fn parseComptimeJSON(comptime json_content: []const u8) []const ComptimeNode {
    // Parse JSON at compile-time
    // Return static array of nodes
}
```

This function:
- Runs entirely at compile-time (marked with `comptime`)
- Uses Zig's compile-time JSON parser
- Produces a static array that lives in `.rodata`
- No runtime cost whatsoever

### 3. Memory Layout

```
Runtime Heap:     (empty - no allocations!)
Runtime Stack:    Just your executor state
.rodata Section:  All node definitions (immutable)
.text Section:    Optimized execution code
```

## Complete Example

```zig
const std = @import("std");
const openpricing = @import("openpricing");

// Parse JSON at compile-time - happens during compilation!
const my_pricing = openpricing.parseComptimeJSON(
    @embedFile("../models/my_pricing.json")
);

pub fn main() !void {
    // Create executor - all types known at compile-time
    const Executor = openpricing.ComptimeExecutorFromNodes(my_pricing);
    var executor = Executor{};
    
    // Set inputs
    try executor.setInput("product_price", 99.99);
    try executor.setInput("quantity", 3);
    try executor.setInput("tax_rate", 0.08);
    
    // Calculate - pure stack operations, no allocations
    const total = try executor.getOutput("final_total");
    
    std.debug.print("Total: ${d:.2}\n", .{total});
}
```

## Integration with Frontend

Since your JSON files remain the source of truth, your frontend can use the same files:

### Frontend (TypeScript/React)

```typescript
import pricingModel from './models/pricing_model.json';

// Use the model in your UI
const graph = new PricingGraph(pricingModel);
```

### Backend (Zig)

```zig
const pricing_model = openpricing.parseComptimeJSON(
    @embedFile("../models/pricing_model.json")
);
```

**Same JSON file, used by both!**

## File Organization

```
your-project/
├── models/
│   ├── pricing_model.json          ← Source of truth
│   ├── tiered_pricing.json         ← Another model
│   └── subscription_pricing.json   ← Yet another model
├── backend/
│   └── src/
│       └── main.zig                ← Uses @embedFile
└── frontend/
    └── src/
        └── App.tsx                 ← Imports JSON
```

## Advanced Usage

### Multiple Models

```zig
const simple_pricing = openpricing.parseComptimeJSON(
    @embedFile("../models/simple.json")
);

const complex_pricing = openpricing.parseComptimeJSON(
    @embedFile("../models/complex.json")
);

const tiered_pricing = openpricing.parseComptimeJSON(
    @embedFile("../models/tiered.json")
);

// Use whichever model you need
const Executor = openpricing.ComptimeExecutorFromNodes(simple_pricing);
```

### Conditional Compilation

```zig
const pricing_model = if (builtin.mode == .Debug)
    openpricing.parseComptimeJSON(@embedFile("../models/test_pricing.json"))
else
    openpricing.parseComptimeJSON(@embedFile("../models/prod_pricing.json"));
```

### Compile-Time Validation

```zig
const pricing = openpricing.parseComptimeJSON(
    @embedFile("../models/pricing.json")
);

// This runs at compile-time and will fail the build if node doesn't exist!
comptime {
    _ = openpricing.comptime_parser.getNodeIndex(pricing, "final_total");
}
```

## Error Handling

If your JSON is invalid, you get **compile-time errors**:

### Invalid JSON Syntax

```
error: Failed to parse JSON at compile-time. Check JSON syntax.
```

### Missing Required Fields

```
error: Node missing 'operation' field
```

### Invalid Operation Type

```
error: Unknown operation: "invalid_op"
```

These errors happen **during compilation**, not at runtime!

## Performance Characteristics

| Aspect | Runtime JSON | Generated Code | Compile-Time JSON |
|--------|-------------|----------------|-------------------|
| Parse Time | ~1ms at startup | 0 (pre-generated) | 0 (compile-time) |
| Memory | Heap allocation | .rodata | .rodata |
| Build Steps | 1 | 2 | 1 |
| Flexibility | Dynamic | Static | Static |
| Type Safety | Runtime | Compile-time | Compile-time |
| Source of Truth | JSON | JSON → .zig | JSON |

## When to Use Each Approach

### Use Compile-Time JSON (`parseComptimeJSON`) When:

- ✅ You want JSON as source of truth
- ✅ Models are known at compile-time
- ✅ You want single-step builds
- ✅ You need maximum performance
- ✅ You want compile-time validation
- ✅ Frontend and backend share models

### Use Zig Builder (`comptimeModel`) When:

- ✅ You prefer Zig over JSON
- ✅ You don't need frontend integration
- ✅ You want IDE autocomplete for models
- ✅ Models are simple and don't change often

### Use Runtime JSON (`parser.GraphParser`) When:

- ✅ Models are loaded from database
- ✅ Models change without recompilation
- ✅ Users create custom models
- ✅ You need true dynamic behavior

## Migration Guide

### From `json_to_zig` Tool

**Before:**
```bash
# build.zig
const run_json_to_zig = b.addRunArtifact(json_to_zig);
run_json_to_zig.addArg("models/pricing.json");
run_json_to_zig.addArg("src/generated_nodes.zig");

// In your code
const generated = @import("generated_nodes.zig");
const pricing_nodes = generated.nodes;
```

**After:**
```zig
// Just use @embedFile directly in your code
const pricing_nodes = openpricing.parseComptimeJSON(
    @embedFile("../models/pricing.json")
);
```

Remove the build step, delete `json_to_zig` tool, delete generated files.

## Best Practices

### 1. Keep JSON Files in a Shared Directory

```
project/
├── shared-models/
│   └── pricing_model.json  ← Both backend and frontend use this
├── backend/
└── frontend/
```

### 2. Version Your JSON Schema

```json
{
  "version": "1.0",
  "nodes": [ ... ]
}
```

### 3. Validate at Compile-Time

```zig
comptime {
    // Ensure required nodes exist
    _ = openpricing.comptime_parser.getNodeIndex(pricing, "final_total");
    _ = openpricing.comptime_parser.getNodeIndex(pricing, "base_price");
}
```

### 4. Use Descriptive Metadata

```json
{
  "id": "discount_amount",
  "operation": "multiply",
  "metadata": {
    "name": "Discount Amount",
    "description": "Dollar amount of discount applied",
    "category": "discounts",
    "version": "1.0"
  }
}
```

### 5. Test Your Models

```zig
test "pricing model calculation" {
    const pricing = openpricing.parseComptimeJSON(
        @embedFile("../models/pricing.json")
    );
    
    const Executor = openpricing.ComptimeExecutorFromNodes(pricing);
    var exec = Executor{};
    
    try exec.setInput("base_price", 100.0);
    try exec.setInput("quantity", 5.0);
    
    const result = try exec.getOutput("final_total");
    try testing.expectApproxEqRel(486.0, result, 0.01);
}
```

## Troubleshooting

### Error: "Failed to parse JSON at compile-time"

- Check JSON syntax (use a JSON validator)
- Ensure file path is correct relative to source file
- Make sure JSON has a root `"nodes"` array

### Error: "Unknown operation"

- Check operation name matches supported operations
- Ensure operation name is lowercase
- See supported operations in `OperationType` enum

### Error: "Node missing 'id' field"

- Every node must have: `id`, `operation`, `inputs`, `weights`
- `constant_value` defaults to 0.0 if omitted
- `metadata` is optional

## See Also

- [COMPTIME_BUILDER.md](./backend-openpricing/COMPTIME_BUILDER.md) - Pure Zig API
- [examples/json_comptime_example.zig](./backend-openpricing/examples/json_comptime_example.zig) - Complete example
- [COMPILE_TIME_APPROACH.md](./backend-openpricing/COMPILE_TIME_APPROACH.md) - Technical details

# OpenPricing

A **compile-time pricing engine** that turns visual pricing models into optimized machine code.

Design pricing graphs in React, export as JSON, and compile directly into your binary with zero runtime overhead.

## Quick Start

```bash
# 1. Design your pricing model in the UI
cd frontend-openpricing
npm install && npm run dev
# Open http://localhost:5173, design your graph, download JSON

# 2. Build and run
cd ../backend-openpricing
cp ~/Downloads/pricing_model.json models/
zig build run
# Your pricing model is now compiled into the binary!
```

## How It Works

1. **Design**: Visual node editor (React Flow) - build your pricing logic graphically
2. **Export**: Save as JSON - your pricing model is just data
3. **Generate**: Build step converts JSON → Zig code at compile time
4. **Compile**: Zig compiler inlines the entire graph into pure arithmetic
5. **Execute**: Runtime is just math - no parsing, no allocation, no overhead

## Project Structure

```
openpricing/
├── backend-openpricing/
│   ├── models/
│   │   └── pricing_model.json      # Your pricing graph (from frontend)
│   ├── tools/
│   │   └── json_to_zig.zig         # Build-time JSON→Zig converter
│   ├── src/
│   │   ├── core/node.zig           # Node types and operations
│   │   ├── json/
│   │   │   ├── comptime_parser.zig # Compile-time types
│   │   │   └── comptime_builder.zig# (unused - alternative API)
│   │   ├── simd/
│   │   │   └── comptime_executor.zig # Stack-based executor
│   │   ├── main.zig                # CLI demo
│   │   └── root.zig                # Public API
│   └── build.zig                   # Build with codegen step
│
└── frontend-openpricing/
    ├── src/
    │   ├── types/pricing.ts        # TypeScript types
    │   ├── App.tsx                 # Node editor UI
    │   └── main.tsx
    └── package.json
```

## Supported Operations

**Arithmetic**: `add`, `subtract`, `multiply`, `divide`, `power`, `modulo`  
**Math**: `abs`, `sqrt`, `exp`, `log`, `sin`, `cos`, `negate`  
**Aggregation**: `weighted_sum`, `max`, `min`, `clamp`  
**Values**: `input` (runtime value), `constant` (compile-time value)

## JSON Format

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
        "description": "Starting price",
        "position_x": 100,
        "position_y": 100
      }
    },
    {
      "id": "markup",
      "operation": "constant",
      "constant_value": 1.2,
      ...
    },
    {
      "id": "final",
      "operation": "multiply",
      "inputs": ["base_price", "markup"],
      ...
    }
  ]
}
```

## Example Usage

```zig
const openpricing = @import("openpricing");
const generated = @import("generated_nodes");

// Executor type created at compile time from your JSON
const Executor = openpricing.ComptimeExecutorFromNodes(generated.nodes);

pub fn main() !void {
    var executor = Executor.init();
    
    try executor.setInput("base_price", 100.0);
    const result = try executor.getOutput("final");
    
    std.debug.print("Result: {d}\n", .{result});
}
```

## Why Compile-Time?

**Traditional approach**: Parse JSON → Validate → Build graph → Execute  
**OpenPricing**: *(all at build time)* → Pure arithmetic at runtime

- No JSON parsing overhead
- No graph traversal
- No heap allocations
- Fully inlined by compiler
- Just a few CPU instructions

## Frontend

React + TypeScript + React Flow

```bash
cd frontend-openpricing
npm install
npm run dev      # Development server
npm run build    # Production build
```

## Requirements

- **Backend**: Zig 0.13+ (tested on 0.15.2)
- **Frontend**: Node.js 18+

## License

ISC

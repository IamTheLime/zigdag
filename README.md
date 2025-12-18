# OpenPricing

A high-performance SIMD-accelerated pricing engine built with Zig and React. Create complex pricing calculations using a visual node-based graph editor, with blazing-fast execution powered by SIMD vectorization.

## Features

- **Node-Based Pricing Graph**: Define pricing logic using a visual directed acyclic graph (DAG)
- **SIMD Acceleration**: Batch process pricing calculations using AVX vector instructions (4x f64 lanes)
- **Topological Execution**: Automatic dependency resolution and optimal execution ordering
- **Type-Safe FFI**: C bindings for seamless TypeScript/JavaScript integration
- **React UI**: Interactive node graph editor built with ReactFlow
- **JSON Serialization**: Define and persist pricing graphs as JSON

## Project Structure

```
openpricing/
├── backend-openpricing/     # Zig backend
│   ├── src/
│   │   ├── core/           # Core node types and operations
│   │   ├── graph/          # Graph representation and topological sort
│   │   ├── simd/           # SIMD execution engine
│   │   ├── json/           # JSON parser/serializer
│   │   ├── ffi/            # C bindings for FFI
│   │   ├── main.zig        # CLI entry point
│   │   └── root.zig        # Library root
│   └── build.zig
│
└── frontend-openpricing/    # React frontend
    ├── src/
    │   ├── components/     # React components
    │   ├── types/          # TypeScript type definitions
    │   ├── App.tsx         # Main app with node editor
    │   └── main.tsx        # Entry point
    ├── package.json
    ├── tsconfig.json
    └── vite.config.ts
```

## Backend (Zig)

### Building

```bash
cd backend-openpricing

# Build the library and CLI
zig build

# Run the CLI demo
zig build run

# Run tests
zig build test

# Build the shared library for FFI
zig build
# Output: zig-out/lib/libopenpricing.so (Linux) or .dylib (macOS) or .dll (Windows)
```

### Architecture

#### Core Components

1. **PricingNode** (`src/core/node.zig`)
   - Represents a single node in the pricing graph
   - Supports operations: add, subtract, multiply, divide, weighted_sum, max, min, etc.
   - Includes metadata for UI positioning

2. **PricingGraph** (`src/graph/pricing_graph.zig`)
   - DAG representation with topological sort
   - Kahn's algorithm for dependency resolution
   - Cycle detection and validation

3. **SIMD Executor** (`src/simd/executor.zig`)
   - Vectorized execution using `@Vector(4, f64)`
   - Batched calculations for maximum throughput
   - Scalar wrapper for single-value operations

4. **JSON Parser** (`src/json/parser.zig`)
   - Bidirectional JSON serialization
   - Validates graph structure on parse

5. **FFI Bindings** (`src/ffi/bindings.zig`)
   - C-compatible API
   - Opaque handle-based interface
   - Error code returns

### Supported Operations

#### Binary Operations
- `add`, `subtract`, `multiply`, `divide`
- `power`, `modulo`

#### Unary Operations
- `negate`, `abs`, `sqrt`
- `exp`, `log`
- `sin`, `cos`

#### Special Operations
- `weighted_sum` - Weighted sum of inputs
- `max`, `min` - Maximum/minimum of inputs
- `clamp` - Clamp value between min and max
- `input` - Input node (requires value at runtime)
- `constant` - Constant value node

### Example Usage (Zig)

```zig
const std = @import("std");
const openpricing = @import("openpricing");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse graph from JSON
    var parser = openpricing.GraphParser.init(allocator);
    var graph = try parser.parseJson(json_string);
    defer graph.deinit();

    // Create execution context
    var ctx = openpricing.ScalarExecutionContext.init(allocator, &graph);
    defer ctx.deinit();

    // Set inputs
    try ctx.setInput("base_price", 100.0);

    // Execute
    const result = try ctx.execute("final_price");
    std.debug.print("Result: {d}\n", .{result});
}
```

### JSON Graph Format

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
      "inputs": [],
      "weights": [],
      "constant_value": 1.2,
      "metadata": {
        "name": "Markup",
        "description": "20% markup",
        "position_x": 100,
        "position_y": 200
      }
    },
    {
      "id": "final_price",
      "operation": "multiply",
      "inputs": ["base_price", "markup"],
      "weights": [],
      "constant_value": 0.0,
      "metadata": {
        "name": "Final Price",
        "description": "Price with markup applied",
        "position_x": 300,
        "position_y": 150
      }
    }
  ]
}
```

## Frontend (React + TypeScript)

### Setup

```bash
cd frontend-openpricing

# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build
```

### Features

- **Interactive Node Editor**: Drag-and-drop node placement
- **Visual Connections**: Connect nodes to define data flow
- **JSON Export**: Export graph definitions for the backend
- **ReactFlow Integration**: Professional node-graph UI

### TypeScript Types

All backend types are mirrored in TypeScript (`src/types/pricing.ts`):

```typescript
import type { PricingGraph, OperationType } from './types/pricing';

const graph: PricingGraph = {
  nodes: [
    {
      id: 'input1',
      operation: 'input',
      inputs: [],
      weights: [],
      constant_value: 0,
      metadata: {
        name: 'Input 1',
        description: '',
        position_x: 100,
        position_y: 100,
      },
    },
    // ... more nodes
  ],
};
```

## SIMD Performance

The engine uses SIMD vectorization to process 4 double-precision values simultaneously:

```zig
// Process 4 prices at once
const prices: SimdVec = .{ 100.0, 200.0, 300.0, 400.0 };
const markup: SimdVec = .{ 1.2, 1.2, 1.2, 1.2 };
const result = prices * markup; // 4 multiplications in parallel
// result = { 120.0, 240.0, 360.0, 480.0 }
```

This provides significant performance benefits when processing large batches of pricing calculations.

## Integration Example

### Using the FFI from TypeScript

```typescript
// Load the Zig shared library
const lib = await loadWasmOrNative('libopenpricing.so');

// Create graph
const graphJson = JSON.stringify(pricingGraph);
const graphHandle = await lib.pricing_graph_from_json(graphJson);

// Create context
const ctxHandle = await lib.pricing_context_create(graphHandle);

// Set inputs
lib.pricing_context_set_input(ctxHandle, 'base_price', 100.0);

// Execute
const result = await lib.pricing_context_execute(ctxHandle, 'final_price');
console.log('Final price:', result);

// Cleanup
lib.pricing_context_free(ctxHandle);
lib.pricing_graph_free(graphHandle);
```

## Development Roadmap

- [x] Core node types and operations
- [x] Graph representation with topological sort
- [x] SIMD execution engine
- [x] JSON serialization
- [x] C FFI bindings
- [x] React UI with node editor
- [x] TypeScript type definitions
- [ ] WebAssembly build target
- [ ] More node operations (conditionals, loops)
- [ ] Graph optimization passes
- [ ] Benchmarking suite
- [ ] Node library/templates
- [ ] Real-time execution visualization

## Requirements

### Backend
- Zig 0.15.2 or later
- CPU with AVX support (for SIMD)

### Frontend
- Node.js 18+ (for npm)
- Modern browser with ES2020 support

## License

ISC

## Contributing

Contributions welcome! Please ensure:
- All Zig code passes `zig build test`
- Frontend code is properly typed
- New operations include tests
- Update documentation for API changes

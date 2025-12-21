# OpenPricing Codebase Summary

**Total LOC**: ~1,179 lines of Zig code  
**Last Cleaned**: December 2024

## What This Project Does

Converts visual pricing graphs (designed in React) into compile-time optimized Zig code that executes at native speed with zero runtime overhead.

**Workflow**: React UI → JSON export → Build-time codegen → Compiled binary

## Directory Structure

```
backend-openpricing/
├── models/
│   └── pricing_model.json          # Input: pricing graph from frontend
├── tools/
│   └── json_to_zig.zig            # Build tool: JSON → Zig codegen
├── src/
│   ├── core/
│   │   └── node.zig               # Node types & operations (add, multiply, etc.)
│   ├── json/
│   │   ├── comptime_parser.zig    # Compile-time node type definitions
│   │   └── comptime_builder.zig   # Alternative: manual node builder API
│   ├── simd/
│   │   └── comptime_executor.zig  # Stack-based executor with topological sort
│   ├── generated_nodes.zig        # Auto-generated from pricing_model.json
│   ├── root.zig                   # Public API exports
│   └── main.zig                   # CLI demo application
└── build.zig                       # Build script with codegen step
```

## Key Files

### Build System
- **build.zig**: Orchestrates the build, runs JSON→Zig codegen as a build step
- **tools/json_to_zig.zig**: Reads `pricing_model.json`, writes `generated_nodes.zig`

### Core Logic
- **src/core/node.zig**: Defines `OperationType` enum and node operations
- **src/json/comptime_parser.zig**: Defines `ComptimeNode` struct
- **src/simd/comptime_executor.zig**: The magic - topological sort + inlined execution
- **src/root.zig**: Public API surface (exports `ComptimeExecutorFromNodes`)

### Runtime
- **src/main.zig**: CLI that demonstrates the compiled pricing model
- **src/generated_nodes.zig**: Auto-generated array of nodes (don't edit!)

## How It Works

### Build Time
1. `zig build` compiles `tools/json_to_zig.zig`
2. Runs it: `json_to_zig models/pricing_model.json generated_nodes.zig`
3. Generated file contains: `pub const nodes = &[_]ComptimeNode{ ... }`
4. Main binary imports this and creates executor type

### Compile Time
```zig
const Executor = ComptimeExecutorFromNodes(generated.nodes);
```
This triggers:
- Topological sort of the graph (comptime)
- Validation of all connections (comptime)
- Type generation with inlined execute() method (comptime)

### Runtime
```zig
var executor = Executor.init();
try executor.setInput("base_price", 100.0);
const result = try executor.getOutput("final");
```
Just pure arithmetic - the graph has been compiled away!

## Removed Files (No Longer Needed)

### What Was Deleted
- `examples/` - Demo code (not core functionality)
- `test/test_comptime_builder.zig` - Standalone test
- `src/pricing_models.zig` - Alternative hardcoded models
- `src/graph/` - Runtime graph representation (unused)
- `src/simd/executor.zig` - Runtime SIMD executor (unused)
- `src/ffi/` - C FFI bindings (not implemented yet)
- `src/json/parser.zig` - Runtime JSON parser (unused)
- `src/json/comptime_json_parser.zig` - Broken attempt at comptime JSON parsing
- `models/pricing_model_complex.json` - Extra example model
- Various markdown files (COMPILE_TIME_APPROACH.md, etc.)

### Why Removed
The codebase had multiple approaches that were experimented with:
1. Runtime JSON parsing + execution
2. Compile-time JSON parsing (doesn't work in Zig)
3. Build-time codegen (current approach - works!)

Only #3 is actually used, so everything else was removed.

## Current Active Code Paths

### The One True Path™
1. Frontend exports JSON
2. User copies JSON to `models/pricing_model.json`
3. `zig build` runs `json_to_zig` tool
4. Tool generates `generated_nodes.zig`
5. `main.zig` imports generated nodes
6. Creates `ComptimeExecutorFromNodes(nodes)` type
7. Runtime: just sets inputs and reads outputs

### Unused But Kept
- `src/json/comptime_builder.zig`: Alternative API for manually defining nodes in Zig (not used by main workflow, but valid use case)

## What To Review

If you're trying to understand this codebase, read in this order:

1. **models/pricing_model.json** - See what the input looks like
2. **tools/json_to_zig.zig** - See how JSON becomes Zig code
3. **src/json/comptime_parser.zig** - See the `ComptimeNode` type definition
4. **src/core/node.zig** - See all supported operations
5. **src/simd/comptime_executor.zig** - See the executor logic (topological sort, execution)
6. **src/main.zig** - See it all come together
7. **build.zig** - See the build orchestration

Total reading: ~1,200 lines of code. That's it!

## Dependencies

**Zig stdlib only** - no external dependencies

## Build Commands

```bash
zig build       # Build the CLI
zig build run   # Build and run
zig build test  # Run tests
```

## Notes for Future Work

- Frontend currently exists but needs to be reviewed separately
- FFI layer was designed but not implemented
- Runtime executor code was removed (not needed for current approach)
- All focus is on the compile-time approach

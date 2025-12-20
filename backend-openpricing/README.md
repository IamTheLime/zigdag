# OpenPricing - High-Performance Pricing Engine

A blazing-fast, SIMD-accelerated pricing computation library written in Zig, designed to be embedded in Python applications for maximum performance.

## Key Features

- **100% Compile-Time**: Pricing models are fully static - parsed, validated, and optimized at compile time
- **Stack Allocation**: All node values live on the stack - zero heap allocations in hot path
- **Zero Runtime Overhead**: No JSON parsing, no file I/O, no graph validation at runtime
- **Fully Inlined**: Execution is pure arithmetic, completely inlined by the compiler
- **SIMD Ready**: Designed for SIMD vectorization (future enhancement)
- **Graph-Based**: DAG-based pricing model with compile-time topological sorting
- **Python-Ready**: Designed for zero-overhead FFI bindings with Python

## Architecture

### Pricing Model Flow

```
Compile Time:
  Node Definitions → Parse → Validate → Generate Static Structures
  ↓
  Stored in .rodata section (read-only data in binary)

Runtime Initialization:
  Stack-allocate node value array [3]f64 (example)
  Create input hashmap

Execution (Hot Path):
  Input Values → Fully Inlined Computation → Output Price
  ↓
  node_values[0] = inputs.get("base_price")
  node_values[1] = 1.2  // compile-time constant
  node_values[2] = node_values[0] * node_values[1]
  return node_values[2]
```

### Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Model Loading | 0ns | Everything is compile-time! |
| Initialization | <1μs | Just allocates input hashmap |
| Single Calculation | ~10-50ns | Pure inlined arithmetic |
| Memory Overhead | Stack only | Node values: `[N]f64` on stack |

## Project Structure

```
src/
├── main.zig                    # CLI entry point with embedded model
├── root.zig                    # Library exports
├── core/
│   └── node.zig               # Pricing node definitions
├── graph/
│   └── pricing_graph.zig      # DAG implementation
├── simd/
│   ├── executor.zig           # Runtime SIMD executor
│   └── comptime_executor.zig  # Compile-time optimized executor (WIP)
├── json/
│   ├── parser.zig             # Runtime JSON parser
│   └── comptime_parser.zig    # Compile-time JSON parser (WIP)
└── ffi/
    └── bindings.zig           # C FFI exports for Python

models/
└── pricing_model.json         # External pricing model (for reference)
```

## Quick Start

### Build and Run

```bash
# Build and run the CLI
make run

# Build the library
make build

# Run tests
make test

# Check compilation (for ZLS/LSP)
make check

# Watch mode (auto-rebuild on changes)
make watch
```

### Define Your Pricing Model

Define your pricing nodes as compile-time constants in `src/main.zig`:

```zig
const PricingNodes = &[_]openpricing.ComptimeNode{
    .{
        .id = "base_price",
        .operation = .input,
        .inputs = &.{},
        .weights = &.{},
        .constant_value = 0.0,
        .name = "Base Price",
        .description = "Starting price input",
    },
    .{
        .id = "markup",
        .operation = .constant,
        .inputs = &.{},
        .weights = &.{},
        .constant_value = 1.2,
        .name = "Markup Multiplier",
        .description = "20% markup (1.2x)",
    },
    .{
        .id = "final_price",
        .operation = .multiply,
        .inputs = &.{ "base_price", "markup" },
        .weights = &.{},
        .constant_value = 0.0,
        .name = "Final Price",
        .description = "Base price with markup applied",
    },
};

const PricingExecutor = openpricing.ComptimeExecutorFromNodes(PricingNodes);
```

## Supported Operations

### Binary Operations
- `add` - Addition (a + b)
- `subtract` - Subtraction (a - b)
- `multiply` - Multiplication (a × b)
- `divide` - Division (a ÷ b)
- `power` - Exponentiation (a^b)
- `modulo` - Modulo (a % b)

### Unary Operations
- `negate` - Negation (-a)
- `abs` - Absolute value (|a|)
- `sqrt` - Square root (√a)
- `exp` - Exponential (e^a)
- `log` - Natural logarithm (ln a)
- `sin` - Sine
- `cos` - Cosine

### Multi-Input Operations
- `weighted_sum` - Weighted sum (w₁a₁ + w₂a₂ + ...)
- `max` - Maximum value
- `min` - Minimum value
- `clamp` - Clamp value between min and max

### Special Operations
- `input` - Input node (runtime value)
- `constant` - Constant value (compile-time)

## Python Integration (Coming Soon)

```python
import ctypes

# Load the shared library
lib = ctypes.CDLL("./zig-out/lib/libopenpricing.so")

# Define function signatures
lib.calculate_price.argtypes = [ctypes.c_double]
lib.calculate_price.restype = ctypes.c_double

# Use it!
base_price = 100.0
final_price = lib.calculate_price(base_price)
print(f"Final price: ${final_price:.2f}")
```

## Development

### LSP Support (ZLS)

The project includes a `check` step for real-time diagnostics in your editor:

```bash
zig build check
```

ZLS will automatically detect this and provide instant feedback as you type.

### Watch Mode

For continuous development:

```bash
make watch        # Auto-run on changes
make watch-test   # Auto-test on changes
```

Requires `entr`:
- Ubuntu: `sudo apt install entr`
- macOS: `brew install entr`

## Why Zig?

1. **Performance**: Compiled to native code with LLVM optimizations
2. **No Runtime**: Zero-cost abstractions, no garbage collector
3. **Comptime**: Powerful compile-time execution
4. **C Interop**: Seamless FFI with Python/C/C++
5. **Safety**: Memory safety without garbage collection
6. **Simplicity**: Cleaner than C, more explicit than Rust

## Roadmap

- [x] Core pricing graph engine
- [x] SIMD vectorization
- [x] JSON parsing
- [x] Compile-time model embedding
- [ ] Full compile-time graph optimization
- [ ] Python bindings (ctypes/cffi)
- [ ] Performance benchmarks
- [ ] Extended operation set
- [ ] Graph visualization tools

## License

[Your License Here]

## Contributing

Contributions welcome! Please ensure all tests pass:

```bash
zig build test
```

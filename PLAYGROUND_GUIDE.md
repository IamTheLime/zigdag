# OpenPricing Playground Guide

The playground system allows you to rapidly test and iterate on pricing models before deploying them to production.

## 🚀 Quick Start

### Option 1: Using the Visual UI (Recommended)

1. **Start the Frontend**
   ```bash
   cd frontend-openpricing
   npm install
   npm run dev
   ```

2. **Design Your Model**
   - Open `http://localhost:5173` in your browser
   - Drag nodes from the left palette onto the canvas
   - Connect nodes by dragging from output (right) to input (left) handles
   - Edit node values directly in the node cards

3. **Save and Test**
   - Click "Generate JSON" to create the pricing model
   - Click "Save to Playground"
   - Save the downloaded file to `playground/pricing_model.json`
   - Run: `./test-playground.sh`

4. **Watch It Work!**
   - The script validates your JSON
   - Copies it to the backend
   - Compiles it into optimized machine code
   - Runs your pricing model
   - Shows the results!

### Option 2: Manual JSON Editing

1. **Edit the Model**
   ```bash
   vim playground/pricing_model.json
   ```

2. **Test It**
   ```bash
   ./test-playground.sh
   ```

3. **Watch Mode** (auto-rebuild on changes)
   ```bash
   ./test-playground.sh --watch
   ```

## 📊 Node Types Reference

### Dynamic Inputs (Runtime Values)
These accept user input at runtime via FFI:

- **`dynamic_input_num`** - Numeric user input
  - Requires: `allowed_values` array
  - Example: Price tiers, quantities, rates
  
- **`dynamic_input_str`** - String user input
  - Requires: `allowed_values` array
  - Example: Regions, customer types, product SKUs

### Constants (Compile-Time Values)
These are baked into the compiled binary:

- **`constant_input_num`** - Fixed numeric value
  - Requires: `constant_value` field
  - Example: Tax rates, fixed fees, multipliers
  
- **`constant_input_str`** - Fixed string value
  - Requires: `constant_str_value` field
  - Example: Configuration strings

### Binary Operations (2 inputs)
- `add` - Addition (a + b)
- `subtract` - Subtraction (a - b)
- `multiply` - Multiplication (a × b)
- `divide` - Division (a ÷ b)
- `power` - Exponentiation (a ^ b)
- `modulo` - Modulo (a % b)

### Unary Operations (1 input)
- `negate` - Negation (-a)
- `abs` - Absolute value |a|
- `sqrt` - Square root √a
- `exp` - Exponential e^x
- `log` - Natural logarithm ln(a)
- `sin` - Sine function
- `cos` - Cosine function

### Advanced Operations
- `max` - Maximum of variable inputs
- `min` - Minimum of variable inputs
- `weighted_sum` - Weighted sum (requires `weights` array)
- `clamp` - Clamp value between min and max (3 inputs: value, min, max)
- `conditional_value_input` - Map input values to outputs

## 📝 Example Pricing Models

### Simple Volume Pricing
```json
{
  "nodes": [
    {
      "id": "quantity",
      "operation": "dynamic_input_num",
      "inputs": [],
      "weights": [],
      "constant_value": 0.0,
      "allowed_values": [1, 10, 50, 100],
      "metadata": {
        "name": "Quantity",
        "description": "Number of units",
        "position_x": 50,
        "position_y": 50
      }
    },
    {
      "id": "unit_price",
      "operation": "constant_input_num",
      "inputs": [],
      "weights": [],
      "constant_value": 10.0,
      "metadata": {
        "name": "Unit Price",
        "description": "$10 per unit",
        "position_x": 50,
        "position_y": 150
      }
    },
    {
      "id": "total",
      "operation": "multiply",
      "inputs": ["quantity", "unit_price"],
      "weights": [],
      "constant_value": 0.0,
      "metadata": {
        "name": "Total Price",
        "description": "Quantity × Unit Price",
        "position_x": 250,
        "position_y": 100
      }
    }
  ]
}
```

### Tiered Discount Pricing
```json
{
  "nodes": [
    {
      "id": "base_price",
      "operation": "dynamic_input_num",
      "inputs": [],
      "allowed_values": [100, 200, 300, 500],
      "metadata": {
        "name": "Base Price",
        "description": "Starting price",
        "position_x": 50,
        "position_y": 50
      }
    },
    {
      "id": "discount_rate",
      "operation": "constant_input_num",
      "inputs": [],
      "constant_value": 0.15,
      "metadata": {
        "name": "Discount",
        "description": "15% discount",
        "position_x": 50,
        "position_y": 150
      }
    },
    {
      "id": "discount_amount",
      "operation": "multiply",
      "inputs": ["base_price", "discount_rate"],
      "metadata": {
        "name": "Discount Amount",
        "description": "Price × Rate",
        "position_x": 250,
        "position_y": 100
      }
    },
    {
      "id": "final_price",
      "operation": "subtract",
      "inputs": ["base_price", "discount_amount"],
      "metadata": {
        "name": "Final Price",
        "description": "After discount",
        "position_x": 450,
        "position_y": 75
      }
    }
  ]
}
```

## 🔧 Advanced Features

### Watch Mode
Auto-rebuild on file changes:
```bash
./test-playground.sh --watch
```

Requires: `inotifywait` (Linux) or `fswatch` (macOS)
```bash
# Linux
sudo apt install inotify-tools

# macOS
brew install fswatch
```

### Debugging
All logs are saved to `playground/output/`:
- `build.log` - Compilation output
- `execution.log` - Runtime output

### Type Safety
The system enforces:
- ✅ Correct node input counts (compile-time)
- ✅ Valid operation types (compile-time)
- ✅ DAG structure (no cycles) (compile-time)
- ✅ Proper dependency ordering (compile-time)

Invalid models will fail at **compile time**, not runtime!

## 🎯 Best Practices

### 1. Use Descriptive IDs
```json
// Good
"id": "volume_discount_rate"

// Bad
"id": "node_42"
```

### 2. Add Metadata
```json
"metadata": {
  "name": "Volume Discount",
  "description": "10% off for orders > 100 units",
  "position_x": 250,
  "position_y": 100
}
```

### 3. Separate Concerns
- Use **dynamic inputs** for user-provided values
- Use **constants** for business rules
- Keep pricing logic modular

### 4. Test Incrementally
Start simple, then add complexity:
1. Build basic calculation
2. Test it works
3. Add discount logic
4. Test again
5. Add tax calculation
6. Test again

### 5. Use the Visual UI
The frontend helps you:
- Visualize dependencies
- Avoid cycles
- Set proper input counts
- Generate valid JSON

## 🐛 Troubleshooting

### "Circular dependency detected"
Your model has a cycle. Use the visual UI to see the flow and remove loops.

### "Operation X not implemented"
Check that the operation name matches exactly (case-sensitive).

### "Invalid JSON"
Run `jq . playground/pricing_model.json` to validate syntax.

### "Node not found"
Ensure all `inputs` arrays reference valid node IDs.

### Build fails
Check `playground/output/build.log` for details.

## 🚢 Deploying to Production

Once your model is tested:

1. **Copy to Backend**
   ```bash
   cp playground/pricing_model.json backend-openpricing/models/pricing_model.json
   ```

2. **Rebuild Backend**
   ```bash
   cd backend-openpricing
   make build
   ```

3. **Your model is now compiled into the binary!**
   - Zero runtime parsing
   - Zero overhead
   - Maximum performance

## 📚 Next Steps

- Explore `frontend-openpricing/src/config/nodeDefinitions.ts` for all node types
- Read `backend-openpricing/src/core/node.zig` to understand the type system
- Check `backend-openpricing/TODO.md` for upcoming features

## 💡 Tips & Tricks

- **Shift+Click** on a node type in the palette to add multiple
- **Delete key** removes selected nodes/edges
- **Ctrl+C** copies selected nodes
- Use **constants** for values that never change at runtime
- Use **dynamic inputs** for values users provide
- The topological sort ensures correct execution order automatically!

Happy pricing! 🎉

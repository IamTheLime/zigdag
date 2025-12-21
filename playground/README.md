# OpenPricing Playground

This directory is for testing and experimenting with pricing models before deploying them to production.

## Usage

### Option 1: Using the Frontend UI

1. Start the frontend: `cd frontend-openpricing && npm run dev`
2. Design your pricing model in the visual editor
3. Click "Save to Playground" - saves to `playground/pricing_model.json`
4. Run the test script: `./test-playground.sh`
5. View the results and iterate!

### Option 2: Manual JSON Editing

1. Edit `pricing_model.json` directly
2. Run the test script: `./test-playground.sh`
3. The script watches for changes and auto-rebuilds

## File Structure

- `pricing_model.json` - Your experimental pricing model
- `README.md` - This file

## Supported Node Types

### Dynamic Inputs (Runtime values)
- `dynamic_input_num` - Numeric input with allowed values
- `dynamic_input_str` - String input with allowed values

### Constants (Compile-time values)
- `constant_input_num` - Hardcoded numeric value
- `constant_input_str` - Hardcoded string value

### Binary Operations
- `add` - Addition (a + b)
- `subtract` - Subtraction (a - b)
- `multiply` - Multiplication (a × b)
- `divide` - Division (a ÷ b)
- `power` - Exponentiation (a ^ b)
- `modulo` - Modulo (a % b)

### Unary Operations
- `negate` - Negation (-a)
- `abs` - Absolute value
- `sqrt` - Square root
- `exp` - Exponential (e^x)
- `log` - Natural logarithm
- `sin` - Sine
- `cos` - Cosine

### Variadic Operations
- `max` - Maximum of inputs
- `min` - Minimum of inputs
- `weighted_sum` - Weighted sum (requires weights array)
- `clamp` - Clamp value between min and max

## Example Pricing Models

See the `examples/` directory for inspiration!

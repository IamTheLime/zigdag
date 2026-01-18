#!/usr/bin/env python3
"""
Example: Using OpenPricing from Python.

This demonstrates the modern, user-friendly interface with type hints
and IDE autocomplete support.

Before running this example:
1. Run `zig build python-package` to generate the Python package
2. Run `pip install -e zig-out/python-dist` to install it
"""

from openpricing import PricingEngine


def main():
    print("=" * 50)
    print("OpenPricing Python Example")
    print("=" * 50)
    print()

    # Create the pricing engine
    engine = PricingEngine()

    print(f"Engine: {engine}")
    print(f"Dynamic inputs: {engine.dynamic_input_ids}")
    print()

    # Set input values and calculate
    print("Setting input values:")
    input_values = {}
    value_gen = iter([500, 250, 125, 62, 31, 15])

    for input_id in engine.dynamic_input_ids:
        value = next(value_gen, 100)
        input_values[input_id] = float(value)
        print(f"  {input_id} = {value}")

    print()
    print("Calculating price...")

    # Calculate using kwargs (with IDE autocomplete!)
    result = engine.calculate(**input_values)

    print(f"Final price: ${result:.2f}")
    print()
    print("=" * 50)
    print("Performance Notes:")
    print("  - JSON parsing: ZERO (done at compile time)")
    print("  - Graph traversal: ZERO (inlined at compile time)")
    print("  - Only actual arithmetic happens at runtime!")
    print("=" * 50)


if __name__ == "__main__":
    main()

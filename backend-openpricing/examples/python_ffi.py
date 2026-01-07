#!/usr/bin/env python3
"""
Example: Using OpenPricing from Python via the new typed library.

This demonstrates the modern, user-friendly interface with type hints
and IDE autocomplete support.

For the legacy ctypes FFI example, see python_ffi_legacy.py
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add examples to path for local development
sys.path.insert(0, str(Path(__file__).parent))

from openpricing import PricingEngine

# Paths
MODEL_PATH = Path(__file__).parent.parent.parent / "playground" / "pricing_model.json"
LIB_PATH = Path(__file__).parent.parent / "zig-out" / "lib" / "libopenpricing.so"


def main():
    print("=" * 50)
    print("OpenPricing Python FFI Example")
    print("=" * 50)
    print()
    
    if not LIB_PATH.exists():
        print(f"Error: Library not found at {LIB_PATH}")
        print("Run 'zig build' in the backend-openpricing directory first.")
        sys.exit(1)
    
    # Create the pricing engine
    engine = PricingEngine(
        lib_path=str(LIB_PATH),
        model_json_path=str(MODEL_PATH) if MODEL_PATH.exists() else None
    )
    
    print("Pricing engine initialized")
    print(f"Engine: {engine}")
    print()
    
    # Show model info
    info = engine.model_info
    print(f"Loaded pricing model with {info.node_count} nodes")
    print()
    
    # List dynamic inputs
    print("Dynamic inputs:")
    if info.dynamic_inputs:
        for di in info.dynamic_inputs:
            print(f"  - {di.id}")
            if di.allowed_values:
                print(f"    Allowed values: {di.allowed_values}")
    else:
        print("  (none - model uses only constants)")
    print()
    
    # Set input values and calculate
    print("Setting input values:")
    input_values = {}
    value_gen = iter([500, 250, 125, 62, 31, 15])
    
    for di in info.dynamic_inputs:
        if di.input_type == 'num':
            value = next(value_gen, 100)
            input_values[di.id] = float(value)
            print(f"  {di.id} = {value}")
    
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

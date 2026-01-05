#!/usr/bin/env python3
"""
Example: Using OpenPricing from Python via FFI

This demonstrates how to call the OpenPricing shared library from Python
using ctypes. The pricing model is compiled into the library at build time.
"""

from ctypes import CDLL, c_double, c_int, c_char_p, create_string_buffer, byref, POINTER
import os
import sys

# Path to the shared library
lib_path = os.path.join(os.path.dirname(__file__), "../zig-out/lib/libopenpricing.so")

if not os.path.exists(lib_path):
    print(f"Error: Library not found at {lib_path}")
    print("Run 'zig build' in the backend-openpricing directory first.")
    sys.exit(1)

# Load the shared library
lib = CDLL(lib_path)

# Define function signatures
lib.pricing_init.restype = c_int
lib.pricing_init.argtypes = []

lib.pricing_set_input.restype = c_int
lib.pricing_set_input.argtypes = [c_char_p, c_double]

lib.pricing_calculate.restype = c_int
lib.pricing_calculate.argtypes = [POINTER(c_double)]

lib.pricing_node_count.restype = c_int
lib.pricing_node_count.argtypes = []

lib.pricing_get_node_id.restype = c_int
lib.pricing_get_node_id.argtypes = [c_int, c_char_p, c_int]

lib.pricing_is_dynamic_input.restype = c_int
lib.pricing_is_dynamic_input.argtypes = [c_char_p]

def input_gen():
    start = 1000
    while True:
        start //= 2
        yield start

def main():
    print("=" * 50)
    print("OpenPricing Python FFI Example")
    print("=" * 50)
    print()
    
    # Initialize the pricing engine
    if lib.pricing_init() != 0:
        print("Error: Failed to initialize pricing engine")
        sys.exit(1)
    
    print("✓ Pricing engine initialized")
    
    # Get node count
    node_count = lib.pricing_node_count()
    print(f"✓ Loaded pricing model with {node_count} nodes")
    print()
    
    # List all dynamic inputs
    print("Dynamic inputs:")
    buffer = create_string_buffer(256)
    dynamic_inputs = []
    
    for i in range(node_count):
        if lib.pricing_get_node_id(i, buffer, 256) > 0:
            node_id = buffer.value.decode('utf-8')
            if lib.pricing_is_dynamic_input(buffer) == 1:
                dynamic_inputs.append(node_id)
                print(f"  - {node_id}")
    
    if not dynamic_inputs:
        print("  (none - model uses only constants)")
    print()
    
    # Set input values
    print("Setting input values:")
    value_gen = input_gen()
    for node_id in dynamic_inputs:
        value = next(value_gen)
        result = lib.pricing_set_input(node_id.encode('utf-8'), c_double(value))
        if result == 0:
            print(f"  ✓ {node_id} = {value}")
        else:
            print(f"  ✗ Failed to set {node_id} (error code: {result})")
    print()
    
    # Calculate the price
    print("Calculating price...")
    result = c_double()
    if lib.pricing_calculate(byref(result)) == 0:
        print(f"✓ Final price: ${result.value:.2f}")
    else:
        print("✗ Calculation failed")
    
    print()
    print("=" * 50)
    print("Performance Notes:")
    print("  - JSON parsing: ZERO (done at compile time)")
    print("  - Graph traversal: ZERO (inlined at compile time)")
    print("  - Only actual arithmetic happens at runtime!")
    print("=" * 50)

if __name__ == "__main__":
    main()

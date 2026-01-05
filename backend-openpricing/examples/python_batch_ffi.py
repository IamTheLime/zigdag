#!/usr/bin/env python3
"""
Example: Batch Processing with OpenPricing FFI
This demonstrates how to efficiently process large batches of pricing calculations
using the OpenPricing shared library. Processing in Zig is MUCH faster than Python loops!
Benchmark comparison:
- Python loop calling C function: ~10x slower
- Direct batch processing in Zig: BLAZING FAST! 🚀
"""
from ctypes import CDLL, c_double, c_int, c_char_p, POINTER, byref
import ctypes
import os
import sys
import time
import numpy as np

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

lib.pricing_get_dynamic_inputs.restype = c_int
lib.pricing_get_dynamic_inputs.argtypes = [
    POINTER(POINTER(ctypes.c_char)),  # ✅ FIXED: Match the actual type
    c_int, 
    c_int
]

lib.pricing_calculate_batch.restype = c_int
lib.pricing_calculate_batch.argtypes = [POINTER(c_double), c_int, c_int, POINTER(c_double)]

def main():
    print("=" * 60)
    print("OpenPricing Batch Processing Example")
    print("=" * 60)
    print()
    
    # Initialize the pricing engine
    if lib.pricing_init() != 0:
        print("Error: Failed to initialize pricing engine")
        sys.exit(1)
    
    print("✓ Pricing engine initialized")
    
    # Get dynamic inputs
    max_inputs = 10
    buffers = [ctypes.create_string_buffer(256) for _ in range(max_inputs)]
    buffer_ptrs = (ctypes.POINTER(ctypes.c_char) * max_inputs)(*buffers) 
    
    num_inputs = lib.pricing_get_dynamic_inputs(buffer_ptrs, 256, max_inputs)
    
    if num_inputs < 0:
        print("Error getting dynamic inputs")
        sys.exit(1)
    
    dynamic_input_ids = [buffers[i].value.decode('utf-8') for i in range(num_inputs)]
    
    print(f"✓ Found {num_inputs} dynamic inputs:")
    for input_id in dynamic_input_ids:
        print(f"  - {input_id}")
    print()
    
    # Prepare batch data
    batch_size = 10_000_000
    print(f"Preparing {batch_size:,} pricing calculations...")
    
    # Create random input data (or use real data)
    # Shape: (batch_size, num_inputs)
    input_data = np.random.uniform(50, 200, size=(batch_size, num_inputs))
    
    # Flatten to 1D array for C FFI
    input_values_flat = input_data.flatten()
    input_c_array = (c_double * len(input_values_flat))(*input_values_flat)
    
    # Prepare output array
    results = np.zeros(batch_size, dtype=np.float64)
    results_c_array = results.ctypes.data_as(POINTER(c_double))
    
    print()
    print("=" * 60)
    print("Method 1: Python Loop (calling C function each time)")
    print("=" * 60)
    
    start_time = time.time()
    python_results = []
    
    for i in range(batch_size):
        # Set inputs
        for j, input_id in enumerate(dynamic_input_ids):
            lib.pricing_set_input(input_id.encode('utf-8'), c_double(input_data[i, j]))
        
        # Calculate
        result = c_double()
        if lib.pricing_calculate(byref(result)) == 0:
            python_results.append(result.value)
        else:
            print(f"Error calculating row {i}")
            sys.exit(1)
    
    python_time = time.time() - start_time
    python_per_item = (python_time * 1e9) / batch_size  # nanoseconds
    
    print(f"Total time: {python_time*1000:.2f}ms")
    print(f"Per item: {python_per_item:.2f}ns")
    print(f"Throughput: {batch_size/python_time:,.0f} calculations/sec")
    print()
    
    print("=" * 60)
    print("Method 2: Batch Processing (native Zig loop)")
    print("=" * 60)
    
    start_time = time.time()
    
    # Call batch function
    ret = lib.pricing_calculate_batch(
        input_c_array,
        c_int(num_inputs),
        c_int(batch_size),
        results_c_array
    )
    
    batch_time = time.time() - start_time
    batch_per_item = (batch_time * 1e9) / batch_size  # nanoseconds
    
    if ret != 0:
        print(f"Error in batch calculation (code: {ret})")
        sys.exit(1)
    
    print(f"Total time: {batch_time*1000:.2f}ms")
    print(f"Per item: {batch_per_item:.2f}ns")
    print(f"Throughput: {batch_size/batch_time:,.0f} calculations/sec")
    print()
    
    # Verify results match
    if np.allclose(python_results, results, rtol=1e-9):
        print("✓ Results verified: Python loop and batch processing match!")
    else:
        print("✗ Warning: Results differ between methods")
        # Debug: show first few differences
        for i in range(min(5, batch_size)):
            if abs(python_results[i] - results[i]) > 1e-9:
                print(f"  Row {i}: Python={python_results[i]:.6f}, Batch={results[i]:.6f}")
    
    print()
    print("=" * 60)
    print("Performance Comparison")
    print("=" * 60)
    speedup = python_time / batch_time
    print(f"Batch processing is {speedup:.1f}x FASTER than Python loop!")
    print(f"Time saved: {(python_time - batch_time)*1000:.2f}ms for {batch_size:,} items")
    print()
    
    # Show sample results
    print("Sample results (first 10):")
    for i in range(min(10, batch_size)):
        print(f"  Row {i}: ${results[i]:.2f}")
    print()
    
    print("=" * 60)
    print("💡 Key Takeaway:")
    print("   Always use batch processing for large datasets!")
    print("   Python loops are slow - let Zig handle the iteration!")
    print("=" * 60)

if __name__ == "__main__":
    main()

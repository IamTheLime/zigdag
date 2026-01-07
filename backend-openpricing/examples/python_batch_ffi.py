#!/usr/bin/env python3
"""
Example: Batch Processing with OpenPricing

This demonstrates high-performance batch processing using the typed
OpenPricing library. Processing in native Zig is much faster than
Python loops!

Benchmark comparison:
- Python loop calling C function: ~10x slower
- Native batch processing in Zig: BLAZING FAST!
"""

from __future__ import annotations

import random
import sys
import time
from pathlib import Path

# Add examples to path for local development
sys.path.insert(0, str(Path(__file__).parent))

from openpricing import PricingEngine

# Paths
MODEL_PATH = Path(__file__).parent.parent.parent / "playground" / "pricing_model.json"
LIB_PATH = Path(__file__).parent.parent / "zig-out" / "lib" / "libopenpricing.so"


def main():
    print("=" * 60)
    print("OpenPricing Batch Processing Example")
    print("=" * 60)
    print()
    
    if not LIB_PATH.exists():
        print(f"Error: Library not found at {LIB_PATH}")
        print("Run 'zig build' in the backend-openpricing directory first.")
        sys.exit(1)
    
    # Create engine
    engine = PricingEngine(
        lib_path=str(LIB_PATH),
        model_json_path=str(MODEL_PATH) if MODEL_PATH.exists() else None
    )
    
    # Get dynamic inputs
    info = engine.model_info
    dynamic_input_ids = [di.id for di in info.dynamic_inputs if di.input_type == 'num']
    
    print(f"Found {len(dynamic_input_ids)} numeric dynamic inputs:")
    for input_id in dynamic_input_ids:
        print(f"  - {input_id}")
    print()
    
    # Prepare batch data
    batch_size = 1_000_000
    print(f"Preparing {batch_size:,} pricing calculations...")
    
    # Create random input data (pure Python lists)
    input_data = {
        input_id: [random.uniform(50, 200) for _ in range(batch_size)]
        for input_id in dynamic_input_ids
    }
    
    print()
    print("=" * 60)
    print("Method 1: Python Loop (calling engine.calculate each time)")
    print("=" * 60)
    
    # Only run small sample for Python loop (it's slow!)
    small_batch = 10_000
    
    start_time = time.perf_counter()
    python_results = []
    
    for i in range(small_batch):
        kwargs = {input_id: input_data[input_id][i] for input_id in dynamic_input_ids}
        result = engine.calculate(**kwargs)
        python_results.append(result)
    
    python_time = time.perf_counter() - start_time
    python_per_item = (python_time * 1e9) / small_batch  # nanoseconds
    
    print(f"Processed: {small_batch:,} items (subset)")
    print(f"Total time: {python_time*1000:.2f}ms")
    print(f"Per item: {python_per_item:.2f}ns")
    print(f"Throughput: {small_batch/python_time:,.0f} calculations/sec")
    print()
    
    print("=" * 60)
    print("Method 2: Native Batch Processing (Zig handles the loop)")
    print("=" * 60)
    
    start_time = time.perf_counter()
    
    # Call batch function - processes ALL items in native code
    results = engine.calculate_batch(input_data)
    
    batch_time = time.perf_counter() - start_time
    batch_per_item = (batch_time * 1e9) / batch_size  # nanoseconds
    
    print(f"Processed: {batch_size:,} items")
    print(f"Total time: {batch_time*1000:.2f}ms")
    print(f"Per item: {batch_per_item:.2f}ns")
    print(f"Throughput: {batch_size/batch_time:,.0f} calculations/sec")
    print()
    
    # Verify results match (compare subset)
    batch_subset = results[:small_batch]
    matches = all(
        abs(python_results[i] - batch_subset[i]) < 1e-9
        for i in range(small_batch)
    )
    
    if matches:
        print("Results verified: Python loop and batch processing match!")
    else:
        print("Warning: Results differ between methods")
        for i in range(min(5, small_batch)):
            if abs(python_results[i] - batch_subset[i]) > 1e-9:
                print(f"  Row {i}: Python={python_results[i]:.6f}, Batch={batch_subset[i]:.6f}")
    
    print()
    print("=" * 60)
    print("Performance Comparison")
    print("=" * 60)
    
    # Extrapolate Python time to full batch
    python_time_extrapolated = python_time * (batch_size / small_batch)
    speedup = python_time_extrapolated / batch_time
    
    print(f"Extrapolated Python time for {batch_size:,}: {python_time_extrapolated*1000:.2f}ms")
    print(f"Actual batch time: {batch_time*1000:.2f}ms")
    print(f"Batch processing is ~{speedup:.0f}x FASTER than Python loop!")
    print()
    
    # Show sample results
    print("Sample results (first 10):")
    for i in range(min(10, batch_size)):
        inputs_str = ", ".join(f"{input_data[id_][i]:.1f}" for id_ in dynamic_input_ids)
        print(f"  Row {i}: inputs=({inputs_str}) -> ${results[i]:.2f}")
    print()
    
    print("=" * 60)
    print("Key Takeaway:")
    print("  Always use calculate_batch() for large datasets!")
    print("  Python loops are slow - let Zig handle the iteration!")
    print("=" * 60)


if __name__ == "__main__":
    main()

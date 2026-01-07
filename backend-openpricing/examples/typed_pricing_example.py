#!/usr/bin/env python3
"""
Example: Using OpenPricing with Type Hints and Autocomplete

This example demonstrates how to use the typed OpenPricing interface
with full IDE autocomplete support for dynamic inputs.

The type hints are generated from the pricing_model.json file,
so you get proper autocomplete for all input node IDs.
"""

from __future__ import annotations

import random
import sys
import time
from pathlib import Path

# Add the examples directory to path for local development
sys.path.insert(0, str(Path(__file__).parent))

from openpricing import PricingEngine, generate_typed_engine

# For the playground model, we need to reference it
MODEL_PATH = Path(__file__).parent.parent.parent / "playground" / "pricing_model.json"
LIB_PATH = Path(__file__).parent.parent / "zig-out" / "lib" / "libopenpricing.so"


def example_basic():
    """Basic usage with the standard engine."""
    print("=" * 60)
    print("Example 1: Basic PricingEngine Usage")
    print("=" * 60)
    print()
    
    # Create engine (automatically finds the library)
    engine = PricingEngine(
        lib_path=str(LIB_PATH) if LIB_PATH.exists() else None,
        model_json_path=str(MODEL_PATH) if MODEL_PATH.exists() else None
    )
    
    print(f"Engine: {engine}")
    print()
    
    # Show model info
    info = engine.model_info
    print(f"Model has {info.node_count} nodes")
    print(f"Dynamic inputs ({len(info.dynamic_inputs)}):")
    for di in info.dynamic_inputs:
        print(f"  - {di.id}: {di.name}")
        if di.description:
            print(f"    Description: {di.description}")
        if di.allowed_values:
            print(f"    Allowed: {di.allowed_values}")
    print()
    
    # Calculate with dynamic inputs from model
    input_values = {}
    for i, di in enumerate(info.dynamic_inputs):
        if di.input_type == 'num':
            input_values[di.id] = 100.0 * (i + 1)
    
    print("Input values:")
    for k, v in input_values.items():
        print(f"  {k} = {v}")
    
    result = engine.calculate(**input_values)
    print(f"Result: ${result:.2f}")
    print()


def example_typed():
    """Usage with generated typed engine for autocomplete."""
    print("=" * 60)
    print("Example 2: Typed Engine with Autocomplete")
    print("=" * 60)
    print()
    
    # Generate a typed engine class from the model
    TypedEngine = generate_typed_engine(
        str(MODEL_PATH),
        lib_path=str(LIB_PATH) if LIB_PATH.exists() else None
    )
    
    engine = TypedEngine()
    
    # Now your IDE will autocomplete the input names!
    # Try typing: engine.calculate(dyn<TAB>)
    info = engine.model_info
    input_values = {}
    for i, di in enumerate(info.dynamic_inputs):
        if di.input_type == 'num':
            input_values[di.id] = 150.0 * (i + 1)
    
    result = engine.calculate(**input_values)
    
    print(f"Typed engine result: ${result:.2f}")
    print()


def example_batch():
    """Batch processing for high throughput."""
    print("=" * 60)
    print("Example 3: High-Performance Batch Processing")
    print("=" * 60)
    print()
    
    engine = PricingEngine(
        lib_path=str(LIB_PATH) if LIB_PATH.exists() else None,
        model_json_path=str(MODEL_PATH) if MODEL_PATH.exists() else None
    )
    
    # Prepare batch data
    batch_size = 100_000
    print(f"Processing {batch_size:,} calculations...")
    
    # Create random inputs based on model (pure Python lists)
    info = engine.model_info
    inputs = {}
    for di in info.dynamic_inputs:
        if di.input_type == 'num':
            inputs[di.id] = [random.uniform(50, 200) for _ in range(batch_size)]
    
    # Time the batch calculation
    start = time.perf_counter()
    results = engine.calculate_batch(inputs)
    elapsed = time.perf_counter() - start
    
    print(f"Time: {elapsed*1000:.2f}ms")
    print(f"Throughput: {batch_size/elapsed:,.0f} calculations/sec")
    print(f"Per calculation: {elapsed*1e9/batch_size:.1f}ns")
    print()
    
    # Show sample results
    print("Sample results:")
    input_ids = list(inputs.keys())
    for i in range(5):
        input_str = ", ".join(f"{inputs[id_][i]:.1f}" for id_ in input_ids)
        print(f"  [{i}] inputs=({input_str}) -> ${results[i]:.2f}")
    print()


def example_generate_stubs():
    """Generate type stub file for IDE support."""
    print("=" * 60)
    print("Example 4: Generate Type Stubs")
    print("=" * 60)
    print()
    
    from openpricing.codegen import generate_typed_stub
    
    stub_content = generate_typed_stub(str(MODEL_PATH))
    
    print("Generated stub file content:")
    print("-" * 40)
    print(stub_content)
    print("-" * 40)
    print()
    print("Save this to 'typed_engine.pyi' for IDE autocomplete support.")
    print()


def main():
    if not LIB_PATH.exists():
        print(f"Error: Library not found at {LIB_PATH}")
        print("Run 'zig build' in backend-openpricing first.")
        sys.exit(1)
    
    if not MODEL_PATH.exists():
        print(f"Warning: Model JSON not found at {MODEL_PATH}")
        print("Some features (like allowed values) won't be available.")
    
    example_basic()
    example_typed()
    example_batch()
    example_generate_stubs()
    
    print("=" * 60)
    print("All examples completed!")
    print("=" * 60)


if __name__ == "__main__":
    main()

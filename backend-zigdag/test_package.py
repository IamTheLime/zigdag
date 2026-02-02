#!/usr/bin/env python3
"""Simple test to verify the package works."""

import sys

sys.path.insert(0, "./zig-out/python-dist")

import my_dag_model


def main():
    print("=" * 60)
    print("ZigDag Simple Test")
    print("=" * 60)

    # Create engine
    engine = my_dag_model.PricingEngine()
    dynamic_input_ids = engine.dynamic_input_ids

    print(f"Found {len(dynamic_input_ids)} dynamic inputs:")
    for input_id in dynamic_input_ids:
        print(f"  - {input_id}")

    print()
    print("Single calculation test:")

    # Test single calculation
    # Now we can use actual string values for 'nome'
    kwargs = {"nome": "tiago", "discount": 100.0}
    result = engine.calculate(**kwargs)
    print(f"Input: {kwargs}")
    print(f"Result: {result}")

    print()
    print("Batch calculation test:")

    # Test batch calculation
    batch_size = 10
    input_data = {
        "nome": [200.0] * batch_size,  # For batch, still need numeric values
        "discount": [float(i + 1) * 10.0 for i in range(batch_size)],
    }

    results = engine.calculate_batch(input_data)
    print(f"Batch size: {batch_size}")
    print(f"First 5 results: {results[:5]}")

    print()
    print("✅ Package is working correctly!")


if __name__ == "__main__":
    main()

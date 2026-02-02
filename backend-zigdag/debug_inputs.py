#!/usr/bin/env python3
"""Debug script to check input IDs."""

import sys

sys.path.insert(0, "./zig-out/python-dist")

import my_dag_model


def main():
    engine = my_dag_model.DAGEngine()
    print("Available input IDs:", engine.dynamic_input_ids)

    # Try to inspect the engine
    print("Type of dynamic_input_ids:", type(engine.dynamic_input_ids))
    if hasattr(engine, "_lib"):
        print("Native library loaded successfully")


if __name__ == "__main__":
    main()

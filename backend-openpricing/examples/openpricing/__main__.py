"""
CLI entry point for OpenPricing code generation.

Usage:
    python -m openpricing path/to/pricing_model.json -o typed_engine.pyi
"""

from .codegen import main

if __name__ == "__main__":
    main()

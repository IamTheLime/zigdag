"""
OpenPricing Python Library

A high-performance pricing engine with compile-time graph optimization.
This library provides typed Python bindings to the native Zig pricing engine.

Usage:
    from openpricing import PricingEngine
    
    engine = PricingEngine()
    
    # With type hints and autocomplete!
    result = engine.calculate(
        dynamic_input_num_1=100.0,
        dynamic_input_num_2=200.0
    )
"""

from .engine import PricingEngine
from .codegen import generate_typed_engine

__all__ = ["PricingEngine", "generate_typed_engine"]
__version__ = "0.1.0"

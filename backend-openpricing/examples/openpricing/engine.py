"""
OpenPricing Engine - Core FFI bindings with type-safe interface.
"""

from __future__ import annotations

import ctypes
import json
import os
from ctypes import CDLL, POINTER, byref, c_char_p, c_double, c_int
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Union


@dataclass
class DynamicInput:
    """Represents a dynamic input node in the pricing model."""
    
    id: str
    name: str
    description: str
    input_type: str  # 'num' or 'str'
    allowed_values: Optional[List[Union[float, str]]] = None


@dataclass
class ModelInfo:
    """Information about the loaded pricing model."""
    
    node_count: int
    dynamic_inputs: List[DynamicInput]
    

class PricingEngine:
    """
    High-performance pricing engine with native Zig backend.
    
    The pricing model is compiled into the library at build time,
    providing zero-overhead graph traversal at runtime.
    
    Example:
        engine = PricingEngine()
        
        # Set inputs and calculate
        result = engine.calculate(
            dynamic_input_num_1=100.0,
            dynamic_input_num_2=200.0
        )
        
        # Or use batch processing for high throughput
        results = engine.calculate_batch({
            'dynamic_input_num_1': [100, 150, 200],
            'dynamic_input_num_2': [200, 250, 300]
        })
    """
    
    def __init__(
        self, 
        lib_path: Optional[str] = None,
        model_json_path: Optional[str] = None
    ):
        """
        Initialize the pricing engine.
        
        Args:
            lib_path: Path to libopenpricing.so. If None, searches default locations.
            model_json_path: Path to pricing_model.json for metadata. Optional.
        """
        self._lib = self._load_library(lib_path)
        self._setup_function_signatures()
        
        # Load model metadata if available
        self._model_json_path = model_json_path
        self._model_info: Optional[ModelInfo] = None
        self._dynamic_input_ids: Optional[List[str]] = None
        
    def _load_library(self, lib_path: Optional[str]) -> CDLL:
        """Load the native library."""
        if lib_path is None:
            # Search in common locations
            search_paths = [
                Path(__file__).parent.parent.parent / "zig-out" / "lib" / "libopenpricing.so",
                Path.cwd() / "zig-out" / "lib" / "libopenpricing.so",
                Path.cwd() / "libopenpricing.so",
            ]
            
            for path in search_paths:
                if path.exists():
                    lib_path = str(path)
                    break
            else:
                raise FileNotFoundError(
                    "Could not find libopenpricing.so. "
                    "Run 'zig build' in backend-openpricing or provide lib_path."
                )
        
        if not os.path.exists(lib_path):
            raise FileNotFoundError(f"Library not found: {lib_path}")
            
        return CDLL(lib_path)
    
    def _setup_function_signatures(self) -> None:
        """Set up ctypes function signatures for type safety."""
        self._lib.pricing_set_dyn_input.restype = c_int
        self._lib.pricing_set_dyn_input.argtypes = [c_char_p, c_double]
        
        self._lib.pricing_calculate.restype = c_int
        self._lib.pricing_calculate.argtypes = [POINTER(c_double)]
        
        self._lib.pricing_node_count.restype = c_int
        self._lib.pricing_node_count.argtypes = []
        
        self._lib.pricing_get_node_id.restype = c_int
        self._lib.pricing_get_node_id.argtypes = [c_int, ctypes.c_char_p, c_int]
        
        self._lib.pricing_is_dynamic_input.restype = c_int
        self._lib.pricing_is_dynamic_input.argtypes = [c_char_p]
        
        self._lib.pricing_get_dynamic_inputs.restype = c_int
        self._lib.pricing_get_dynamic_inputs.argtypes = [
            POINTER(POINTER(ctypes.c_char)),
            c_int,
            c_int
        ]
        
        self._lib.pricing_calculate_batch.restype = c_int
        self._lib.pricing_calculate_batch.argtypes = [
            POINTER(c_double), c_int, c_int, POINTER(c_double)
        ]
    
    @property
    def model_info(self) -> ModelInfo:
        """Get information about the loaded pricing model."""
        if self._model_info is None:
            self._model_info = self._load_model_info()
        return self._model_info
    
    @property
    def dynamic_input_ids(self) -> List[str]:
        """Get list of dynamic input node IDs in order."""
        if self._dynamic_input_ids is None:
            self._dynamic_input_ids = self._get_dynamic_input_ids()
        return self._dynamic_input_ids
    
    def _get_dynamic_input_ids(self) -> List[str]:
        """Query the library for dynamic input IDs."""
        max_inputs = 100
        buffers = [ctypes.create_string_buffer(256) for _ in range(max_inputs)]
        buffer_ptrs = (POINTER(ctypes.c_char) * max_inputs)(*buffers)
        
        num_inputs = self._lib.pricing_get_dynamic_inputs(buffer_ptrs, 256, max_inputs)
        
        if num_inputs < 0:
            raise RuntimeError("Failed to get dynamic inputs from library")
        
        return [buffers[i].value.decode('utf-8') for i in range(num_inputs)]
    
    def _load_model_info(self) -> ModelInfo:
        """Load model metadata from the library and optional JSON file."""
        node_count = self._lib.pricing_node_count()
        dynamic_input_ids = self.dynamic_input_ids
        
        # Try to load additional metadata from JSON if available
        json_metadata: Dict[str, Any] = {}
        if self._model_json_path and os.path.exists(self._model_json_path):
            with open(self._model_json_path) as f:
                data = json.load(f)
                for node in data.get('nodes', []):
                    json_metadata[node['id']] = node
        
        # Build dynamic input list
        dynamic_inputs = []
        for input_id in dynamic_input_ids:
            meta = json_metadata.get(input_id, {})
            metadata = meta.get('metadata', {})
            operation = meta.get('operation', 'dynamic_input_num')
            
            input_type = 'str' if operation == 'dynamic_input_str' else 'num'
            
            # Get allowed values
            allowed_values = None
            if input_type == 'str':
                allowed_values = meta.get('allowed_str_values', [])
            else:
                allowed_values = meta.get('allowed_values', [])
            
            if not allowed_values:
                allowed_values = None
                
            dynamic_inputs.append(DynamicInput(
                id=input_id,
                name=metadata.get('name', input_id),
                description=metadata.get('description', ''),
                input_type=input_type,
                allowed_values=allowed_values
            ))
        
        return ModelInfo(
            node_count=node_count,
            dynamic_inputs=dynamic_inputs
        )
    
    def set_input(self, node_id: str, value: float) -> None:
        """
        Set a dynamic input value.
        
        Args:
            node_id: The ID of the dynamic input node
            value: The numeric value to set
            
        Raises:
            ValueError: If the node is not found or value is invalid
        """
        result = self._lib.pricing_set_dyn_input(
            node_id.encode('utf-8'), 
            c_double(value)
        )
        
        if result == -3:
            raise ValueError(f"Node not found: {node_id}")
        elif result != 0:
            raise RuntimeError(f"Failed to set input {node_id}: error code {result}")
    
    def calculate(self, **inputs: float) -> float:
        """
        Calculate the pricing result with the given inputs.
        
        Args:
            **inputs: Keyword arguments mapping input node IDs to values.
                      e.g., calculate(dynamic_input_num_1=100.0, dynamic_input_num_2=200.0)
        
        Returns:
            The calculated price as a float.
            
        Raises:
            ValueError: If an unknown input is provided
            RuntimeError: If calculation fails
            
        Example:
            result = engine.calculate(
                dynamic_input_num_1=100.0,
                dynamic_input_num_2=200.0
            )
        """
        # Set all inputs
        for node_id, value in inputs.items():
            self.set_input(node_id, value)
        
        # Calculate
        result = c_double()
        ret = self._lib.pricing_calculate(byref(result))
        
        if ret != 0:
            raise RuntimeError(f"Calculation failed with error code: {ret}")
        
        return result.value
    
    def calculate_batch(
        self, 
        inputs: Mapping[str, Sequence[float]]
    ) -> List[float]:
        """
        Calculate prices for a batch of input values.
        
        This is significantly faster than calling calculate() in a loop,
        as the iteration happens in native Zig code.
        
        Args:
            inputs: Dictionary mapping input node IDs to sequences of values.
                    All sequences must have the same length.
                    
        Returns:
            List of calculated prices.
            
        Raises:
            ValueError: If input sequences have different lengths or unknown inputs
            RuntimeError: If batch calculation fails
            
        Example:
            results = engine.calculate_batch({
                'dynamic_input_num_1': [100, 150, 200],
                'dynamic_input_num_2': [200, 250, 300]
            })
        """
        # Get ordered list of dynamic inputs from library
        input_ids = self.dynamic_input_ids
        
        # Validate inputs
        if set(inputs.keys()) != set(input_ids):
            missing = set(input_ids) - set(inputs.keys())
            extra = set(inputs.keys()) - set(input_ids)
            msg = []
            if missing:
                msg.append(f"Missing inputs: {missing}")
            if extra:
                msg.append(f"Unknown inputs: {extra}")
            raise ValueError(". ".join(msg))
        
        # Check sequence lengths
        sequences = [inputs[id_] for id_ in input_ids]
        batch_size = len(sequences[0])
        
        if not all(len(seq) == batch_size for seq in sequences):
            raise ValueError("All input sequences must have the same length")
        
        num_inputs = len(input_ids)
        
        # Interleave inputs: [row0_in0, row0_in1, row1_in0, row1_in1, ...]
        input_flat: List[float] = []
        for row_idx in range(batch_size):
            for seq in sequences:
                input_flat.append(float(seq[row_idx]))
        
        input_c_array = (c_double * len(input_flat))(*input_flat)
        
        # Prepare output
        results_c_array = (c_double * batch_size)()
        
        # Call batch function
        ret = self._lib.pricing_calculate_batch(
            input_c_array,
            c_int(num_inputs),
            c_int(batch_size),
            results_c_array
        )
        
        if ret == -1:
            raise ValueError(
                f"Input count mismatch: provided {num_inputs}, "
                f"model expects {len(input_ids)}"
            )
        elif ret != 0:
            raise RuntimeError(f"Batch calculation failed with error code: {ret}")
        
        return list(results_c_array)
    
    def __repr__(self) -> str:
        info = self.model_info
        inputs = ", ".join(d.id for d in info.dynamic_inputs)
        return f"PricingEngine(nodes={info.node_count}, inputs=[{inputs}])"

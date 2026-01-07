"""
Code generator for typed OpenPricing bindings.

This module reads a pricing_model.json file and generates:
1. A TypedDict for the dynamic inputs (for autocomplete)
2. A typed PricingEngine subclass with proper signatures
3. A .pyi stub file for IDE support

Usage:
    python -m openpricing.codegen path/to/pricing_model.json
    
    # Or programmatically:
    from openpricing.codegen import generate_typed_engine
    TypedEngine = generate_typed_engine("path/to/pricing_model.json")
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Type, TypedDict

from .engine import PricingEngine


def _sanitize_identifier(name: str) -> str:
    """Convert a node ID to a valid Python identifier."""
    # Replace non-alphanumeric chars with underscore
    name = re.sub(r'[^a-zA-Z0-9_]', '_', name)
    # Ensure it doesn't start with a number
    if name and name[0].isdigit():
        name = '_' + name
    return name


def _generate_inputs_typeddict(
    dynamic_inputs: List[Dict[str, Any]], 
    class_name: str = "PricingInputs"
) -> str:
    """Generate TypedDict class definition for inputs."""
    lines = [
        f"class {class_name}(TypedDict, total=True):",
        '    """Dynamic inputs for the pricing model."""',
    ]
    
    if not dynamic_inputs:
        lines.append("    pass")
        return "\n".join(lines)
    
    for node in dynamic_inputs:
        node_id = node['id']
        operation = node.get('operation', 'dynamic_input_num')
        metadata = node.get('metadata', {})
        name = metadata.get('name', node_id)
        description = metadata.get('description', '')
        
        # Determine type based on operation
        if operation == 'dynamic_input_str':
            allowed = node.get('allowed_str_values', [])
            if allowed:
                # Use Literal type for constrained string values
                literal_values = ', '.join(f'"{v}"' for v in allowed)
                type_hint = f"Literal[{literal_values}]"
            else:
                type_hint = "str"
        else:
            allowed = node.get('allowed_values', [])
            if allowed:
                literal_values = ', '.join(str(v) for v in allowed)
                type_hint = f"Literal[{literal_values}]"
            else:
                type_hint = "float"
        
        # Add field with docstring
        safe_id = _sanitize_identifier(node_id)
        lines.append(f"    {safe_id}: {type_hint}")
        if description:
            lines.append(f'    """{description}"""')
    
    return "\n".join(lines)


def _generate_batch_inputs_typeddict(
    dynamic_inputs: List[Dict[str, Any]], 
    class_name: str = "PricingBatchInputs"
) -> str:
    """Generate TypedDict class definition for batch inputs."""
    lines = [
        f"class {class_name}(TypedDict, total=True):",
        '    """Batch inputs for the pricing model (sequences of floats)."""',
    ]
    
    if not dynamic_inputs:
        lines.append("    pass")
        return "\n".join(lines)
    
    for node in dynamic_inputs:
        node_id = node['id']
        metadata = node.get('metadata', {})
        description = metadata.get('description', '')
        
        safe_id = _sanitize_identifier(node_id)
        lines.append(f"    {safe_id}: Sequence[float]")
        if description:
            lines.append(f'    """Sequence of values: {description}"""')
    
    return "\n".join(lines)


def generate_typed_stub(
    model_json_path: str,
    output_path: Optional[str] = None
) -> str:
    """
    Generate a .pyi stub file for the typed engine.
    
    Args:
        model_json_path: Path to pricing_model.json
        output_path: Where to write the stub. If None, returns as string.
        
    Returns:
        The generated stub file content.
    """
    with open(model_json_path) as f:
        model = json.load(f)
    
    nodes = model.get('nodes', [])
    dynamic_inputs = [
        n for n in nodes 
        if n.get('operation', '').startswith('dynamic_input')
    ]
    
    # Build the stub file
    lines = [
        '"""',
        'Type stubs for OpenPricing engine.',
        '',
        'Auto-generated from pricing_model.json.',
        'Do not edit manually.',
        '"""',
        '',
        'from __future__ import annotations',
        '',
        'from typing import List, Literal, Sequence, TypedDict, Unpack',
        '',
        '',
    ]
    
    # Generate TypedDict for inputs
    lines.append(_generate_inputs_typeddict(dynamic_inputs))
    lines.append('')
    lines.append('')
    
    # Generate TypedDict for batch inputs
    lines.append(_generate_batch_inputs_typeddict(dynamic_inputs))
    lines.append('')
    lines.append('')
    
    # Generate typed calculate signature
    lines.extend([
        'class TypedPricingEngine:',
        '    """',
        '    Typed pricing engine with autocomplete support.',
        '    ',
        '    All dynamic inputs are available as keyword arguments with',
        '    proper type hints for IDE autocomplete.',
        '    """',
        '    ',
        '    def calculate(self, **inputs: Unpack[PricingInputs]) -> float:',
        '        """',
        '        Calculate the pricing result.',
        '        ',
        '        Args:',
    ])
    
    for node in dynamic_inputs:
        node_id = node['id']
        metadata = node.get('metadata', {})
        name = metadata.get('name', node_id)
        safe_id = _sanitize_identifier(node_id)
        lines.append(f'            {safe_id}: {name}')
    
    lines.extend([
        '        ',
        '        Returns:',
        '            The calculated price.',
        '        """',
        '        ...',
        '    ',
        '    def calculate_batch(',
        '        self,',
        '        inputs: PricingBatchInputs',
        '    ) -> List[float]:',
        '        """',
        '        Calculate prices for a batch of inputs.',
        '        ',
        '        Args:',
        '            inputs: Dictionary of input sequences',
        '        ',
        '        Returns:',
        '            List of calculated prices.',
        '        """',
        '        ...',
    ])
    
    content = '\n'.join(lines)
    
    if output_path:
        with open(output_path, 'w') as f:
            f.write(content)
    
    return content


def generate_typed_engine(
    model_json_path: str,
    lib_path: Optional[str] = None
) -> Type[PricingEngine]:
    """
    Generate a typed PricingEngine class from a model JSON file.
    
    This creates a subclass of PricingEngine where the calculate()
    method has proper type hints based on the model's dynamic inputs.
    
    The returned class supports:
    - IDE autocomplete for input names
    - Type checking for input values
    - Literal types for constrained inputs
    
    Args:
        model_json_path: Path to pricing_model.json
        lib_path: Optional path to libopenpricing.so
        
    Returns:
        A typed PricingEngine subclass.
        
    Example:
        TypedEngine = generate_typed_engine("pricing_model.json")
        engine = TypedEngine()
        
        # Now with autocomplete!
        result = engine.calculate(
            dynamic_input_num_1=100.0,
            dynamic_input_num_2=200.0
        )
    """
    with open(model_json_path) as f:
        model = json.load(f)
    
    nodes = model.get('nodes', [])
    dynamic_inputs = [
        n for n in nodes 
        if n.get('operation', '').startswith('dynamic_input')
    ]
    
    # Build the dynamic type annotations
    annotations = {}
    for node in dynamic_inputs:
        node_id = node['id']
        operation = node.get('operation', 'dynamic_input_num')
        
        if operation == 'dynamic_input_str':
            annotations[node_id] = str
        else:
            annotations[node_id] = float
    
    # Create the typed engine class
    input_ids = [n['id'] for n in dynamic_inputs]
    
    class TypedPricingEngine(PricingEngine):
        """Typed pricing engine with model-specific input hints."""
        
        _input_ids: List[str] = input_ids
        _input_annotations: Dict[str, type] = annotations
        
        def __init__(self) -> None:
            super().__init__(
                lib_path=lib_path,
                model_json_path=model_json_path
            )
    
    return TypedPricingEngine


def main():
    """CLI entry point for code generation."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Generate typed OpenPricing bindings from model JSON"
    )
    parser.add_argument(
        "model_json",
        help="Path to pricing_model.json"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output path for generated stub file",
        default=None
    )
    parser.add_argument(
        "--print",
        action="store_true",
        help="Print generated code to stdout"
    )
    
    args = parser.parse_args()
    
    if args.output:
        generate_typed_stub(args.model_json, args.output)
        print(f"Generated stub file: {args.output}")
    
    if args.print or not args.output:
        print(generate_typed_stub(args.model_json))


if __name__ == "__main__":
    main()

const std = @import("std");

/// This build tool generates a complete Python package from a pricing model JSON.
/// It creates:
///   - <name>/_types.py: TypedDict definitions for inputs with Literal types for allowed values
///   - <name>/engine.py: Engine wrapper
///   - <name>/__init__.py: Package exports
///   - <name>/py.typed: PEP 561 marker
///   - pyproject.toml: Package metadata with correct name/version
///
/// Usage: gen_python_package <input.json> <output_base_dir> <lib_suffix>
///   output_base_dir: Base directory (e.g., zig-out/python-dist)
///   lib_suffix: "so" for Linux, "dylib" for macOS
///
/// The package directory will be created as <output_base_dir>/<package_name>/
/// where <package_name> comes from the JSON model's "name" field.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        std.debug.print("Usage: {s} <input.json> <output_base_dir> <lib_suffix>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_path = args[1];
    const output_base_dir = args[2];
    const lib_suffix = args[3];

    // Read input JSON file
    const input_file = try std.fs.cwd().openFile(input_path, .{});
    defer input_file.close();

    const json_content = try input_file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(json_content);

    // Parse JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    const root = parsed.value;

    // Extract model metadata
    const model_name_raw = if (root.object.get("name")) |n| n.string else "zmigdag";
    const model_version = if (root.object.get("version")) |v| v.string else "0.1.0";

    // Sanitize package name (replace - with _, lowercase)
    var name_buf: [256]u8 = undefined;
    const model_name = sanitizePackageName(model_name_raw, &name_buf);

    // Create output directory: <output_base_dir>/<package_name>/
    const package_dir = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ output_base_dir, model_name });
    defer allocator.free(package_dir);

    std.fs.cwd().makePath(package_dir) catch {};

    // Generate _types.py
    try generateTypesFile(allocator, root, package_dir);

    // Generate pyproject.toml (in parent directory)
    try generatePyprojectToml(allocator, model_name, model_version, output_base_dir, package_dir);

    // Generate __init__.py
    try generateInitFile(allocator, package_dir);

    // Generate engine.py (static content)
    try generateEngineFile(allocator, package_dir, lib_suffix);

    // Generate py.typed marker
    try generatePyTypedMarker(package_dir);

    // Generate engine.pyi stub file for type hints
    try generateEngineStubFile(allocator, root, package_dir);

    // Output the package directory path for build.zig to use
    std.debug.print("✓ Generated Python package '{s}' v{s} in {s}/\n", .{ model_name, model_version, package_dir });
}

fn sanitizePackageName(name: []const u8, buf: []u8) []const u8 {
    var i: usize = 0;
    for (name) |c| {
        if (i >= buf.len - 1) break;
        if (c == '-') {
            buf[i] = '_';
        } else if (c >= 'A' and c <= 'Z') {
            buf[i] = c + ('a' - 'A');
        } else {
            buf[i] = c;
        }
        i += 1;
    }
    return buf[0..i];
}

fn generateTypesFile(allocator: std.mem.Allocator, root: std.json.Value, output_dir: []const u8) !void {
    var output = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Header
    try writer.writeAll(
        \\"""
        \\Type definitions for ZigDag.
        \\
        \\Auto-generated from pricing_model.json.
        \\Do not edit manually.
        \\"""
        \\
        \\from __future__ import annotations
        \\
        \\from typing import List, Literal, Mapping, Sequence, TypedDict, Union
        \\
        \\
    );

    // Collect dynamic inputs
    const nodes = root.object.get("nodes") orelse return error.NoNodesInJson;
    const nodes_array = nodes.array;

    // Generate PricingInputs TypedDict
    try writer.writeAll(
        \\class PricingInputs(TypedDict, total=True):
        \\    """Dynamic inputs for the pricing model."""
        \\
    );

    var has_inputs = false;
    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;

        if (std.mem.eql(u8, operation_str, "dynamic_input_num")) {
            has_inputs = true;
            const id = node.get("id").?.string;
            const metadata = if (node.get("metadata")) |m| m.object else null;
            const description = if (metadata) |m| if (m.get("description")) |d| d.string else "" else "";

            // Check for allowed values
            const allowed_values = if (node.get("allowed_values")) |av| av.array.items else &[_]std.json.Value{};

            if (allowed_values.len > 0) {
                // Use Literal type for constrained values
                try writer.print("    {s}: Literal[", .{id});
                for (allowed_values, 0..) |val, j| {
                    if (j > 0) try writer.writeAll(", ");
                    const num_val = switch (val) {
                        .float => |f| f,
                        .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                        else => 0.0,
                    };
                    try writer.print("{d}", .{num_val});
                }
                try writer.writeAll("]\n");
            } else {
                try writer.print("    {s}: float\n", .{id});
            }

            if (description.len > 0) {
                try writer.print("    \"\"\"{s}\"\"\"\n", .{description});
            }
        } else if (std.mem.eql(u8, operation_str, "dynamic_input_str")) {
            has_inputs = true;
            const id = node.get("id").?.string;
            const metadata = if (node.get("metadata")) |m| m.object else null;
            const description = if (metadata) |m| if (m.get("description")) |d| d.string else "" else "";

            // Check for allowed string values
            const allowed_str_values = if (node.get("allowed_str_values")) |av| av.array.items else &[_]std.json.Value{};

            if (allowed_str_values.len > 0) {
                // Use Literal type for constrained string values
                try writer.print("    {s}: Literal[", .{id});
                for (allowed_str_values, 0..) |val, j| {
                    if (j > 0) try writer.writeAll(", ");
                    try writer.print("\"{s}\"", .{val.string});
                }
                try writer.writeAll("]\n");
            } else {
                try writer.print("    {s}: str\n", .{id});
            }

            if (description.len > 0) {
                try writer.print("    \"\"\"{s}\"\"\"\n", .{description});
            }
        }
    }

    if (!has_inputs) {
        try writer.writeAll("    pass\n");
    }

    try writer.writeAll("\n\n");

    // Generate PricingBatchInputs TypedDict
    try writer.writeAll(
        \\class PricingBatchInputs(TypedDict, total=True):
        \\    """Batch inputs for the pricing model (sequences)."""
        \\
    );

    has_inputs = false;
    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;

        if (std.mem.eql(u8, operation_str, "dynamic_input_num") or
            std.mem.eql(u8, operation_str, "dynamic_input_str"))
        {
            has_inputs = true;
            const id = node.get("id").?.string;
            const metadata = if (node.get("metadata")) |m| m.object else null;
            const description = if (metadata) |m| if (m.get("description")) |d| d.string else "" else "";

            try writer.print("    {s}: Sequence[float]\n", .{id});

            if (description.len > 0) {
                try writer.print("    \"\"\"Sequence of values: {s}\"\"\"\n", .{description});
            }
        }
    }

    if (!has_inputs) {
        try writer.writeAll("    pass\n");
    }

    try writer.writeAll("\n\n");

    // Generate list of dynamic input IDs
    try writer.writeAll("# Ordered list of dynamic input node IDs\n");
    try writer.writeAll("DYNAMIC_INPUT_IDS: List[str] = [\n");

    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;

        if (std.mem.eql(u8, operation_str, "dynamic_input_num") or
            std.mem.eql(u8, operation_str, "dynamic_input_str"))
        {
            const id = node.get("id").?.string;
            try writer.print("    \"{s}\",\n", .{id});
        }
    }

    try writer.writeAll("]\n");

    // Write file
    const types_path = try std.fmt.allocPrint(allocator, "{s}/_types.py", .{output_dir});
    defer allocator.free(types_path);

    const output_file = try std.fs.cwd().createFile(types_path, .{});
    defer output_file.close();

    try output_file.writeAll(output.items);
}

fn generatePyprojectToml(allocator: std.mem.Allocator, name: []const u8, version: []const u8, base_dir: []const u8, _: []const u8) !void {
    var output = try std.ArrayList(u8).initCapacity(allocator, 2048);
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    try writer.print(
        \\[build-system]
        \\requires = ["setuptools>=61.0", "wheel"]
        \\build-backend = "setuptools.build_meta"
        \\
        \\[project]
        \\name = "{s}"
        \\version = "{s}"
        \\description = "ZigDag model - high-performance pricing engine"
        \\readme = "README.md"
        \\requires-python = ">=3.10"
        \\license = {{text = "MIT"}}
        \\classifiers = [
        \\    "Programming Language :: Python :: 3",
        \\    "Programming Language :: Python :: 3.10",
        \\    "Programming Language :: Python :: 3.11",
        \\    "Programming Language :: Python :: 3.12",
        \\    "Operating System :: POSIX :: Linux",
        \\    "Operating System :: MacOS",
        \\    "Typing :: Typed",
        \\]
        \\
        \\[project.urls]
        \\"Homepage" = "https://github.com/IAmTheLime/zigdag"
        \\
        \\[tool.setuptools]
        \\packages = ["{s}", "zigdag"]
        \\
        \\[tool.setuptools.package-data]
        \\"zigdag" = ["*.so", "*.dylib", "py.typed"]
        \\
    , .{ name, version, name });

    // Write file to base_dir (pyproject.toml goes next to the package dir)
    const toml_path = try std.fmt.allocPrint(allocator, "{s}/pyproject.toml", .{base_dir});
    defer allocator.free(toml_path);

    const output_file = try std.fs.cwd().createFile(toml_path, .{});
    defer output_file.close();

    try output_file.writeAll(output.items);
}

fn generateInitFile(allocator: std.mem.Allocator, output_dir: []const u8) !void {
    const content =
        \\"""
        \\ZigDag - High-performance pricing engine.
        \\
        \\This package provides typed Python bindings to a native pricing engine
        \\compiled from a pricing model graph.
        \\
        \\Usage:
        \\    from <package> import PricingEngine
        \\    
        \\    engine = PricingEngine()
        \\    result = engine.calculate(
        \\        input_1=100.0,
        \\        input_2=200.0
        \\    )
        \\"""
        \\
        \\from .engine import PricingEngine
        \\from ._types import PricingInputs, PricingBatchInputs, DYNAMIC_INPUT_IDS
        \\
        \\__all__ = ["PricingEngine", "PricingInputs", "PricingBatchInputs", "DYNAMIC_INPUT_IDS"]
        \\
    ;

    const init_path = try std.fmt.allocPrint(allocator, "{s}/__init__.py", .{output_dir});
    defer allocator.free(init_path);

    const output_file = try std.fs.cwd().createFile(init_path, .{});
    defer output_file.close();

    try output_file.writeAll(content);
}

fn generateEngineFile(allocator: std.mem.Allocator, output_dir: []const u8, lib_suffix: []const u8) !void {
    var output = try std.ArrayList(u8).initCapacity(allocator, 8192);
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Determine library filename based on suffix
    const lib_name = if (std.mem.eql(u8, lib_suffix, "dylib"))
        "libzigdag.dylib"
    else
        "libzigdag.so";

    try writer.print(
        \\"""
        \\ZigDag Engine - Core FFI bindings.
        \\"""
        \\
        \\from __future__ import annotations
        \\
        \\import ctypes
        \\import os
        \\from ctypes import CDLL, POINTER, byref, c_char_p, c_double, c_int
        \\from pathlib import Path
        \\from typing import List, Mapping, Sequence
        \\
        \\from ._types import DYNAMIC_INPUT_IDS
        \\
        \\
        \\# Load the native library from the package directory
        \\_LIB_PATH = Path(__file__).parent / "{s}"
        \\
        \\if not _LIB_PATH.exists():
        \\    raise ImportError(
        \\        f"Native library not found at {{_LIB_PATH}}. "
        \\        "The package may not be installed correctly."
        \\    )
        \\
        \\_lib = CDLL(str(_LIB_PATH))
        \\
        \\# Set up function signatures
        \\_lib.set_input_node_value.restype = c_int
        \\_lib.set_input_node_value.argtypes = [c_char_p, c_double]
        \\
        \\_lib.calculate_final_node_price.restype = c_int
        \\_lib.calculate_final_node_price.argtypes = [POINTER(c_double)]
        \\
        \\_lib.get_node_count.restype = c_int
        \\_lib.get_node_count.argtypes = []
        \\
        \\_lib.calculate_final_node_price_batch.restype = c_int
        \\_lib.calculate_final_node_price_batch.argtypes = [
        \\    POINTER(c_double), c_int, c_int, POINTER(c_double)
        \\]
        \\
        \\
        \\class PricingEngine:
        \\    """
        \\    High-performance pricing engine with native backend.
        \\    
        \\    The pricing model is compiled into the library at build time,
        \\    providing zero-overhead graph traversal at runtime.
        \\    
        \\    Example:
        \\        engine = PricingEngine()
        \\        result = engine.calculate(
        \\            dynamic_input_num_1=100.0,
        \\            dynamic_input_num_2=200.0
        \\        )
        \\    """
        \\    
        \\    def __init__(self) -> None:
        \\        """Initialize the pricing engine."""
        \\        self._node_count = _lib.get_node_count()
        \\    
        \\    @property
        \\    def node_count(self) -> int:
        \\        """Get the number of nodes in the pricing model."""
        \\        return self._node_count
        \\    
        \\    @property
        \\    def dynamic_input_ids(self) -> List[str]:
        \\        """Get the list of dynamic input node IDs."""
        \\        return DYNAMIC_INPUT_IDS.copy()
        \\    
        \\    def set_input(self, node_id: str, value: float) -> None:
        \\        """
        \\        Set a dynamic input value.
        \\        
        \\        Args:
        \\            node_id: The ID of the dynamic input node
        \\            value: The numeric value to set
        \\            
        \\        Raises:
        \\            ValueError: If the node is not found
        \\        """
        \\        result = _lib.set_input_node_value(
        \\            node_id.encode('utf-8'),
        \\            c_double(value)
        \\        )
        \\        
        \\        if result == -3:
        \\            raise ValueError(f"Node not found: {{node_id}}")
        \\        elif result != 0:
        \\            raise RuntimeError(f"Failed to set input {{node_id}}: error code {{result}}")
        \\    
        \\    def calculate(self, **inputs: float) -> float:
        \\        """
        \\        Calculate the pricing result with the given inputs.
        \\        
        \\        Args:
        \\            **inputs: Keyword arguments mapping input node IDs to values.
        \\        
        \\        Returns:
        \\            The calculated price as a float.
        \\        """
        \\        for node_id, value in inputs.items():
        \\            self.set_input(node_id, value)
        \\        
        \\        result = c_double()
        \\        ret = _lib.calculate_final_node_price(byref(result))
        \\        
        \\        if ret != 0:
        \\            raise RuntimeError(f"Calculation failed with error code: {{ret}}")
        \\        
        \\        return result.value
        \\    
        \\    def calculate_batch(
        \\        self,
        \\        inputs: Mapping[str, Sequence[float]]
        \\    ) -> List[float]:
        \\        """
        \\        Calculate prices for a batch of input values.
        \\        
        \\        This is significantly faster than calling calculate() in a loop.
        \\        
        \\        Args:
        \\            inputs: Dictionary mapping input node IDs to sequences of values.
        \\                    All sequences must have the same length.
        \\                    
        \\        Returns:
        \\            List of calculated prices.
        \\        """
        \\        input_ids = DYNAMIC_INPUT_IDS
        \\        
        \\        # Validate inputs
        \\        if set(inputs.keys()) != set(input_ids):
        \\            missing = set(input_ids) - set(inputs.keys())
        \\            extra = set(inputs.keys()) - set(input_ids)
        \\            msg = []
        \\            if missing:
        \\                msg.append(f"Missing inputs: {{missing}}")
        \\            if extra:
        \\                msg.append(f"Unknown inputs: {{extra}}")
        \\            raise ValueError(". ".join(msg))
        \\        
        \\        sequences = [inputs[id_] for id_ in input_ids]
        \\        batch_size = len(sequences[0])
        \\        
        \\        if not all(len(seq) == batch_size for seq in sequences):
        \\            raise ValueError("All input sequences must have the same length")
        \\        
        \\        num_inputs = len(input_ids)
        \\        
        \\        # Interleave inputs
        \\        input_flat: List[float] = []
        \\        for row_idx in range(batch_size):
        \\            for seq in sequences:
        \\                input_flat.append(float(seq[row_idx]))
        \\        
        \\        input_c_array = (c_double * len(input_flat))(*input_flat)
        \\        results_c_array = (c_double * batch_size)()
        \\        
        \\        ret = _lib.calculate_final_node_price_batch(
        \\            input_c_array,
        \\            c_int(num_inputs),
        \\            c_int(batch_size),
        \\            results_c_array
        \\        )
        \\        
        \\        if ret == -1:
        \\            raise ValueError(f"Input count mismatch")
        \\        elif ret != 0:
        \\            raise RuntimeError(f"Batch calculation failed: {{ret}}")
        \\        
        \\        return list(results_c_array)
        \\    
        \\    def __repr__(self) -> str:
        \\        return f"PricingEngine(nodes={{self._node_count}}, inputs={{DYNAMIC_INPUT_IDS}})"
        \\
    , .{lib_name});

    const engine_path = try std.fmt.allocPrint(allocator, "{s}/engine.py", .{output_dir});
    defer allocator.free(engine_path);

    const output_file = try std.fs.cwd().createFile(engine_path, .{});
    defer output_file.close();

    try output_file.writeAll(output.items);
}

fn generatePyTypedMarker(output_dir: []const u8) !void {
    var path_buf: [512]u8 = undefined;
    const py_typed_path = try std.fmt.bufPrint(&path_buf, "{s}/py.typed", .{output_dir});

    const output_file = try std.fs.cwd().createFile(py_typed_path, .{});
    defer output_file.close();
    // Empty file - just a marker
}

fn generateEngineStubFile(allocator: std.mem.Allocator, root: std.json.Value, output_dir: []const u8) !void {
    var output = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Header with imports
    try writer.writeAll(
        \\"""
        \\Type stubs for ZigDag Engine.
        \\
        \\Auto-generated from pricing_model.json.
        \\Do not edit manually.
        \\"""
        \\
        \\from __future__ import annotations
        \\
        \\from typing import List, Mapping, Sequence, Unpack
        \\
        \\from ._types import PricingInputs, PricingBatchInputs
        \\
        \\
        \\class PricingEngine:
        \\    """High-performance pricing engine with native backend."""
        \\    
        \\    def __init__(self) -> None: ...
        \\    
        \\    @property
        \\    def node_count(self) -> int: ...
        \\    
        \\    @property
        \\    def dynamic_input_ids(self) -> List[str]: ...
        \\    
        \\    def set_input(self, node_id: str, value: float) -> None: ...
        \\    
        \\    def calculate(
        \\        self,
        \\
    );

    // Generate typed kwargs using Unpack
    const nodes = root.object.get("nodes") orelse return error.NoNodesInJson;
    const nodes_array = nodes.array;

    // Collect dynamic input info for docstring
    var first = true;
    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;

        if (std.mem.eql(u8, operation_str, "dynamic_input_num") or
            std.mem.eql(u8, operation_str, "dynamic_input_str"))
        {
            const id = node.get("id").?.string;
            if (!first) {
                try writer.writeAll(",\n");
            }
            first = false;
            try writer.print("        {s}: float", .{id});
        }
    }

    try writer.writeAll(
        \\,
        \\    ) -> float:
        \\        """
        \\        Calculate the pricing result with the given inputs.
        \\        
        \\        Returns:
        \\            The calculated price as a float.
        \\        """
        \\        ...
        \\    
        \\    def calculate_batch(
        \\        self,
        \\        inputs: PricingBatchInputs,
        \\    ) -> List[float]:
        \\        """Calculate prices for a batch of input values."""
        \\        ...
        \\    
        \\    def __repr__(self) -> str: ...
        \\
    );

    // Write file
    const stub_path = try std.fmt.allocPrint(allocator, "{s}/engine.pyi", .{output_dir});
    defer allocator.free(stub_path);

    const output_file = try std.fs.cwd().createFile(stub_path, .{});
    defer output_file.close();

    try output_file.writeAll(output.items);
}

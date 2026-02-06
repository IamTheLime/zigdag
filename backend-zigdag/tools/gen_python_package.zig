const std = @import("std");

//NOTE: This file needs to be rebuilt, too much vibecodeing went around here

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
    const model_name_raw = if (root.object.get("name")) |n| n.string else "zigdag";
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
    try generateEngineFile(allocator, model_name, package_dir, lib_suffix);

    // Generate py.typed marker
    try generatePyTypedMarker(package_dir);

    // Generate engine.pyi stub file for type hints
    try generateEngineStubFile(allocator, model_name, package_dir);

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

fn generateCalcInterface(writer: anytype, nodes_array: std.json.Array, dag_type: enum { batch, transactional }) !void {

    // Pre-compute batch wrappers
    const seq_prefix = if (dag_type == .batch) "Sequence[" else "";
    const seq_suffix = if (dag_type == .batch) "]" else "";

    // Generate DAGInputs TypedDict
    if (dag_type == .transactional) {
        try writer.writeAll(
            \\class DAGInputs(TypedDict, total=True):
            \\    """Dynamic inputs for the pricing model."""
            \\
        );
    } else {
        try writer.writeAll(
            \\class DAGBatchInputs(TypedDict, total=True):
            \\    """Batch inputs for the pricing model (sequences)."""
            \\
        );
    }

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
                try writer.print("    {s}: {s}Literal[", .{ id, seq_prefix });
                for (allowed_values, 0..) |val, j| {
                    if (j > 0) try writer.writeAll(", ");
                    const num_val = switch (val) {
                        .float => |f| f,
                        .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                        else => 0.0,
                    };
                    try writer.print("{d}", .{num_val});
                }
                try writer.print("]{s}\n", .{seq_suffix});
            } else {
                try writer.print("    {s}: {s}float{s}\n", .{ id, seq_prefix, seq_suffix });
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
                try writer.print("    {s}: {s}Literal[", .{ id, seq_prefix });
                for (allowed_str_values, 0..) |val, j| {
                    if (j > 0) try writer.writeAll(", ");
                    try writer.print("\"{s}\"", .{val.string});
                }
                try writer.print("]{s}\n", .{seq_suffix});
            } else {
                try writer.print("    {s}: {s}str{s}\n", .{ id, seq_prefix, seq_suffix });
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
        \\Auto-generated from dag_model.json.
        \\Do not edit manually.
        \\"""
        \\
        \\from __future__ import annotations
        \\
        \\from typing import List, Literal, Sequence, TypedDict
        \\
        \\
    );


    // Collect dynamic inputs
    const nodes = root.object.get("nodes") orelse return error.NoNodesInJson;
    const nodes_array = nodes.array;

    try generateCalcInterface(&writer, nodes_array, .transactional);
    try generateCalcInterface(&writer, nodes_array, .batch);

    
    try writer.writeAll(
        \\DYNAMIC_INPUT_IDS = [
        \\
    );
    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;

        if (std.mem.eql(u8, operation_str, "dynamic_input_str")){
            try writer.print(
                \\  "{s}",
                \\
             , .{node.get("id").?.string}   
            );
        }
        if (std.mem.eql(u8, operation_str, "dynamic_input_num")){
            try writer.print(
                \\  "{s}",
                \\
             , .{node.get("id").?.string}   
            );
        }

    }
    try writer.writeAll(
        \\]
        \\
        \\
    );

    // Generate NUMERIC_INPUT_IDS
    try writer.writeAll(
        \\NUMERIC_INPUT_IDS: List[str] = [
        \\
    );
    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;
        if (std.mem.eql(u8, operation_str, "dynamic_input_num")) {
            try writer.print(
                \\    "{s}",
                \\
            , .{node.get("id").?.string});
        }
    }
    try writer.writeAll(
        \\]
        \\
        \\
    );

    // Generate STRING_INPUT_IDS
    try writer.writeAll(
        \\STRING_INPUT_IDS: List[str] = [
        \\
    );
    for (nodes_array.items) |node_value| {
        const node = node_value.object;
        const operation_str = node.get("operation").?.string;
        if (std.mem.eql(u8, operation_str, "dynamic_input_str")) {
            try writer.print(
                \\    "{s}",
                \\
            , .{node.get("id").?.string});
        }
    }
    try writer.writeAll(
        \\]
        \\
    );

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
        \\zigdag = ["*.so", "*.dylib", "py.typed"]
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
        \\    from <package> import DAGEngine
        \\    
        \\    engine = DAGEngine()
        \\    result = engine.calculate(
        \\        input_1=100.0,
        \\        input_2=200.0
        \\    )
        \\"""
        \\
        \\from .engine import DAGEngine
        \\from ._types import DAGInputs, DAGBatchInputs, DYNAMIC_INPUT_IDS, NUMERIC_INPUT_IDS, STRING_INPUT_IDS
        \\
        \\__all__ = ["DAGEngine", "DAGInputs", "DAGBatchInputs", "DYNAMIC_INPUT_IDS", "NUMERIC_INPUT_IDS", "STRING_INPUT_IDS"]
        \\
    ;

    const init_path = try std.fmt.allocPrint(allocator, "{s}/__init__.py", .{output_dir});
    defer allocator.free(init_path);

    const output_file = try std.fs.cwd().createFile(init_path, .{});
    defer output_file.close();

    try output_file.writeAll(content);
}

fn generateEngineFile(
    allocator: std.mem.Allocator,
    model_name: []const u8,
    output_dir: []const u8,
    lib_suffix: []const u8,
) !void {
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
        \\from ctypes import CDLL, POINTER, byref, c_char_p, c_double, c_int
        \\from pathlib import Path
        \\from typing import List, Sequence
        \\
        \\from {s}._types import DAGInputs, DYNAMIC_INPUT_IDS, NUMERIC_INPUT_IDS, STRING_INPUT_IDS
        \\
        \\
        \\# Load the native library from the package directory
        \\_LIB_PATH = Path(__file__).parent.parent / "zigdag" / "{s}"
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
        \\_lib.set_input_node_value_num.restype = c_int
        \\_lib.set_input_node_value_num.argtypes = [c_char_p, c_double]
        \\
        \\_lib.set_input_node_value_str.restype = c_int
        \\_lib.set_input_node_value_str.argtypes = [c_char_p, c_char_p]
        \\
        \\_lib.calculate_final_node_price.restype = c_int
        \\_lib.calculate_final_node_price.argtypes = [POINTER(c_double)]
        \\
        \\_lib.get_node_count.restype = c_int
        \\_lib.get_node_count.argtypes = []
        \\
        \\_lib.calculate_final_node_price_batch.restype = c_int
        \\_lib.calculate_final_node_price_batch.argtypes = [
        \\    POINTER(c_double), POINTER(c_char_p), c_int, c_int, c_int, POINTER(c_double)
        \\]
        \\
        \\
        \\class DAGEngine:
        \\    """
        \\    High-performance pricing engine with native backend.
        \\    
        \\    The pricing model is compiled into the library at build time,
        \\    providing zero-overhead graph traversal at runtime.
        \\    
        \\    Example:
        \\        engine = DAGEngine()
        \\        result = engine.calculate(
        \\            dynamic_input_num_1=100.0,
        \\            dynamic_input_num_2=200.0
        \\        )
        \\    """
        \\
        \\    _BATCH_CHUNK_SIZE = 1_000_000
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
        \\    def set_num_input(self, node_id: str, value: float) -> None:
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
        \\        result = _lib.set_input_node_value_num(
        \\            node_id.encode('utf-8'),
        \\            c_double(value)
        \\        )
        \\        
        \\        if result == -3:
        \\            raise ValueError(f"Node not found: {{node_id}}")
        \\        elif result != 0:
        \\            raise RuntimeError(f"Failed to set input {{node_id}}: error code {{result}}")
        \\    
        \\    def set_str_input(self, node_id: str, value: str) -> None:
        \\        """
        \\        Set a dynamic str input value.
        \\        
        \\        Args:
        \\            node_id: The ID of the dynamic input node
        \\            value: The numeric value to set
        \\            
        \\        Raises:
        \\            ValueError: If the node is not found
        \\        """
        \\        result = _lib.set_input_node_value_str(
        \\            node_id.encode('utf-8'),
        \\            value.encode('utf-8'),
        \\        )
        \\        
        \\        if result == -3:
        \\            raise ValueError(f"Node not found: {{node_id}}")
        \\        elif result != 0:
        \\            raise RuntimeError(f"Failed to set input {{node_id}}: error code {{result}}")
        \\
        \\    def calculate(self, **inputs: float | str ) -> float:
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
        \\            match value:
        \\                case str():
        \\                    self.set_str_input(node_id, value)
        \\                case float() | int():
        \\                    self.set_num_input(node_id, float(value))
        \\                case _:
        \\                    raise TypeError(
        \\                        f"Unsupported value type for {{node_id}}: {{type(value).__name__}}"
        \\                    )
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
        \\        rows: Sequence[DAGInputs],
        \\    ) -> List[float]:
        \\        """
        \\        Calculate prices for a batch of input sets.
        \\
        \\        This is significantly faster than calling calculate() in a loop.
        \\        Large batches are automatically chunked to bound memory usage.
        \\
        \\        Args:
        \\            rows: Sequence of input dictionaries, each matching DAGInputs.
        \\
        \\        Returns:
        \\            List of calculated prices.
        \\        """
        \\        if not rows:
        \\            return []
        \\
        \\        num_rows = len(rows)
        \\        all_results: List[float] = []
        \\
        \\        for chunk_start in range(0, num_rows, self._BATCH_CHUNK_SIZE):
        \\            chunk_end = min(chunk_start + self._BATCH_CHUNK_SIZE, num_rows)
        \\            chunk = rows[chunk_start:chunk_end]
        \\            chunk_size = len(chunk)
        \\
        \\            numeric_flat: List[float] = []
        \\            string_flat: List[bytes] = []
        \\
        \\            for row in chunk:
        \\                for input_id in NUMERIC_INPUT_IDS:
        \\                    numeric_flat.append(float(row[input_id]))
        \\                for input_id in STRING_INPUT_IDS:
        \\                    string_flat.append(row[input_id].encode("utf-8"))
        \\
        \\            numeric_arr = (c_double * len(numeric_flat))(*numeric_flat)
        \\            string_arr = (c_char_p * len(string_flat))(*string_flat)
        \\            results_arr = (c_double * chunk_size)()
        \\
        \\            ret = _lib.calculate_final_node_price_batch(
        \\                numeric_arr,
        \\                string_arr,
        \\                c_int(len(NUMERIC_INPUT_IDS)),
        \\                c_int(len(STRING_INPUT_IDS)),
        \\                c_int(chunk_size),
        \\                results_arr,
        \\            )
        \\
        \\            if ret == -1:
        \\                raise ValueError("Input count mismatch with compiled model")
        \\            elif ret != 0:
        \\                raise RuntimeError(f"Batch calculation failed: {{ret}}")
        \\
        \\            all_results.extend(results_arr)
        \\
        \\        return all_results
        \\    
        \\    def __repr__(self) -> str:
        \\        return f"DAGEngine(nodes={{self._node_count}}, inputs={{DYNAMIC_INPUT_IDS}})"
        \\
    , .{ model_name, lib_name });

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

fn generateEngineStubFile(allocator: std.mem.Allocator, model_name: []const u8, output_dir: []const u8) !void {
    var output = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Header with imports
    try writer.print(
        \\"""
        \\Type stubs for ZigDag Engine.
        \\
        \\Auto-generated from dag_model.json.
        \\Do not edit manually.
        \\"""
        \\
        \\from __future__ import annotations
        \\
        \\from typing import List, Sequence, Unpack
        \\
        \\from {s}._types import DAGInputs, DAGBatchInputs
        \\
        \\
        \\class DAGEngine:
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
        \\    def set_num_input(self, node_id: str, value: float) -> None: ...
        \\
        \\    def set_str_input(self, node_id: str, value: str) -> None: ...
        \\    
        \\    def calculate(
        \\        self,
        \\        **kwargs: Unpack[DAGInputs],
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
        \\        rows: Sequence[DAGInputs],
        \\    ) -> List[float]:
        \\        """Calculate prices for a batch of input sets."""
        \\        ...
        \\    
        \\    def __repr__(self) -> str: ...
        \\
    , .{model_name});

    // Write file
    const stub_path = try std.fmt.allocPrint(allocator, "{s}/engine.pyi", .{output_dir});
    defer allocator.free(stub_path);

    const output_file = try std.fs.cwd().createFile(stub_path, .{});
    defer output_file.close();

    try output_file.writeAll(output.items);
}

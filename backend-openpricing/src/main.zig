const std = @import("std");
const openpricing = @import("openpricing");
const generated = @import("generated_nodes");

// ============================================================================
// FFI LIBRARY - Exposes pricing calculation functions for Python/C/etc
// ============================================================================
// This library provides C-compatible functions that can be called from:
// - Python (via ctypes/cffi)
// - Node.js (via FFI)
// - Any language with C FFI support
//
// The pricing model is compiled in at build time, so you must rebuild
// when the model changes.

const PRICING_NODES = generated.nodes;
const PRICING_EXECUTOR = openpricing.ComptimeExecutorFromNodes(PRICING_NODES);

// Thread-local executor instance
threadlocal var executor: PRICING_EXECUTOR = undefined;
threadlocal var executor_initialized: bool = false;

/// Initialize the pricing executor (call once per thread)
/// Returns 0 on success, non-zero on error
export fn pricing_init() c_int {
    executor = PRICING_EXECUTOR.init();
    executor_initialized = true;
    return 0;
}

/// Set a dynamic input value by node ID
/// @param node_id: C string containing the node ID
/// @param value: The numeric value to set
/// Returns 0 on success, non-zero on error
export fn pricing_set_input(node_id: [*:0]const u8, value: f64) c_int {
    if (!executor_initialized) return -1;

    const id = std.mem.span(node_id);

    // Find the node with this ID
    inline for (PRICING_NODES) |node| {
        if (std.mem.eql(u8, node.node_id, id)) {
            executor.setInput(node.node_id, value) catch return -2;
            return 0;
        }
    }

    return -3; // Node not found
}

/// Calculate the final pricing result
/// @param result: Pointer to store the result
/// Returns 0 on success, non-zero on error
export fn pricing_calculate(result: *f64) c_int {
    if (!executor_initialized) return -1;

    // Find the funnel node (the final output node)
    const output_node = comptime blk: {
        for (PRICING_NODES) |node| {
            if (node.operation == .funnel) {
                break :blk node;
            }
        }
        @compileError("No funnel node found in pricing model! Every model must have a funnel node as the final output.");
    };
    result.* = executor.getOutput(output_node.node_id) catch return -2;

    return 0;
}

/// Get the number of nodes in the pricing model
export fn pricing_node_count() c_int {
    return @intCast(PRICING_NODES.len);
}

/// Get node ID by index (for introspection)
/// @param index: Node index (0 to node_count-1)
/// @param buffer: Buffer to store the node ID
/// @param buffer_len: Size of the buffer
/// Returns length of node ID on success, -1 on error
export fn pricing_get_node_id(index: c_int, buffer: [*]u8, buffer_len: c_int) c_int {
    if (index < 0 or index >= PRICING_NODES.len) return -1;

    const node = PRICING_NODES[@intCast(index)];
    const id_len: c_int = @intCast(node.node_id.len);

    if (id_len >= buffer_len) return -2; // Buffer too small

    @memcpy(buffer[0..node.node_id.len], node.node_id);
    buffer[node.node_id.len] = 0; // Null terminate

    return id_len;
}

/// Check if a node is a dynamic input (requires runtime value)
/// @param node_id: C string containing the node ID
/// Returns 1 if dynamic input, 0 if not, -1 on error
export fn pricing_is_dynamic_input(node_id: [*:0]const u8) c_int {
    const id = std.mem.span(node_id);

    inline for (PRICING_NODES) |node| {
        if (std.mem.eql(u8, node.node_id, id)) {
            return if (node.operation == .dynamic_input_num or
                node.operation == .dynamic_input_str) 1 else 0;
        }
    }

    return -1; // Node not found
}

// Note: This library doesn't have a main() function
// Use the benchmark executable to test the pricing model
// Example Python usage:
//
// from ctypes import CDLL, c_double, c_int, c_char_p, create_string_buffer
//
// lib = CDLL("./libopenpricing.so")
//
// # Initialize
// lib.pricing_init()
//
// # Set inputs
// lib.pricing_set_input(b"dynamic_input_num_1", c_double(100.0))
// lib.pricing_set_input(b"dynamic_input_num_2", c_double(200.0))
//
// # Calculate
// result = c_double()
// lib.pricing_calculate(byref(result))
// print(f"Price: ${result.value:.2f}")

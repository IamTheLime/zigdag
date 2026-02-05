const std = @import("std");
const zigdag = @import("zigdag");
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
const PRICING_EXECUTOR = zigdag.ComptimeExecutorFromNodes(PRICING_NODES);

// Thread-local executor instance
threadlocal var executor: PRICING_EXECUTOR = PRICING_EXECUTOR.init();

/// Set a dynamic numeric input value by node ID
/// @param node_id: C string containing the node ID
/// @param value: The numeric value to set
/// Returns 0 on success, non-zero on error
export fn set_input_node_value_num(node_id: [*:0]const u8, value: f64) c_int {
    const id = std.mem.span(node_id);

    // Find the node with this ID
    inline for (PRICING_NODES) |node| {
        if (std.mem.eql(u8, node.node_id, id) and node.operation == .dynamic_input_num) {
            executor.setInputNum(node.node_id, value) catch return -2;
            return 0;
        }
    }

    return -3; // Node not found
}

/// Set a dynamic string input value by node ID
/// @param node_id: C string containing the node ID
/// @param value: C string containing the string value to set
/// Returns 0 on success, non-zero on error
export fn set_input_node_value_str(node_id: [*:0]const u8, value: [*:0]const u8) c_int {
    const id = std.mem.span(node_id);
    const val = std.mem.span(value);

    // Find the node with this ID
    inline for (PRICING_NODES) |node| {
        if (std.mem.eql(u8, node.node_id, id) and node.operation == .dynamic_input_str) {
            executor.setInputStr(node.node_id, val) catch return -2;
            return 0;
        }
    }

    return -3; // Node not found
}

/// Calculate the final pricing result (using the funnel node)
/// @param result: Pointer to store the result
/// Returns 0 on success, non-zero on error
export fn calculate_final_node_price(result: *f64) c_int {
    result.* = executor.getOutput() catch return -2;

    return 0;
}

/// Calculate result from a specific node by ID
/// @param node_id: C string containing the node ID
/// @param result: Pointer to store the result
/// Returns 0 on success, non-zero on error
export fn calculate_node_price(node_id: [*:0]const u8, result: *f64) c_int {
    const id = std.mem.span(node_id);

    // Find the node with this ID
    inline for (PRICING_NODES) |node| {
        if (std.mem.eql(u8, node.node_id, id)) {
            result.* = executor.getOutput() catch return -2;
            return 0;
        }
    }

    return -3; // Node not found
}

/// Get the number of nodes in the pricing model
export fn get_node_count() c_int {
    return @intCast(PRICING_NODES.len);
}

/// Get node ID by index (for introspection)
/// @param index: Node index (0 to node_count-1)
/// @param buffer: Buffer to store the node ID
/// @param buffer_len: Size of the buffer
/// Returns length of node ID on success, -1 on error
export fn get_node_id(index: c_int, buffer: [*]u8, buffer_len: c_int) c_int {
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
export fn is_dynamic_input(node_id: [*:0]const u8) c_int {
    const id = std.mem.span(node_id);

    inline for (PRICING_NODES) |node| {
        if (std.mem.eql(u8, node.node_id, id)) {
            return if (node.operation == .dynamic_input_num or
                node.operation == .dynamic_input_str) 1 else 0;
        }
    }

    return -1; // Node not found
}

/// Get list of dynamic input node IDs (for batch processing setup)
/// @param ids: Array of C string buffers to fill with node IDs
/// @param buffer_size: Size of each buffer
/// @param max_count: Maximum number of IDs to return
/// Returns the actual count of dynamic inputs
export fn get_dynamic_inputs(ids: [*][*]u8, buffer_size: c_int, max_count: c_int) c_int {
    var count: c_int = 0;

    inline for (PRICING_NODES) |node| {
        if (node.operation == .dynamic_input_num or node.operation == .dynamic_input_str) {
            if (count >= max_count) break;

            const id_len = @min(node.node_id.len, @as(usize, @intCast(buffer_size - 1)));
            @memcpy(ids[@intCast(count)][0..id_len], node.node_id[0..id_len]);
            ids[@intCast(count)][id_len] = 0; // Null terminate

            count += 1;
        }
    }

    return count;
}

/// This struct will guarantee order of arguments for the batch processing
/// the simplistic approach used to set input values will not work for the
/// batch processing scenarios without introducing a considerable amount
/// of bugs into the system
const InputType = enum(c_int) {
    numeric = 0,
    string = 1,
    // leaving an option here for future types: boolean = 2, date = 3, etc.
};

const InputMeta = extern struct {
    node_id: [*:0]const u8,
    input_type: InputType,
    index: c_int,
};

const INPUT_METADATA = blk: {
    var meta: []const InputMeta = &.{};
    var num_idx: c_int = 0;
    var str_idx: c_int = 0;

    for (PRICING_NODES) |node| {
        if (node.operation == .dynamic_input_num) {
            meta = meta ++ &[_]InputMeta{
                InputMeta{
                    .node_id = node.node_id.ptr,
                    .input_type = InputType.numeric,
                    .index = num_idx,
                },
            };
            num_idx += 1;
        } else if (node.operation == .dynamic_input_str) {
            meta = meta ++ &[_]InputMeta{
                InputMeta{
                    .node_id = node.node_id.ptr,
                    .input_type = InputType.string,
                    .index = str_idx,
                },
            };
            str_idx += 1;
        }
    }

    break :blk meta;
};

export fn get_input_count() c_int {
    return INPUT_METADATA.len;
}

export fn get_input_meta(index: c_int, out_meta: *InputMeta) c_int {
    if (index < 0 or index >= INPUT_METADATA.len) return -1;
    out_meta.* = INPUT_METADATA[@intCast(index)];
    return 0;
}

/// Batch calculate prices for multiple input sets
/// This is much faster than calling calculate_final_node_price in a Python loop!
///
/// @param input_values: Flat array of input values [row0_input0, row0_input1, ..., row1_input0, row1_input1, ...]
/// @param num_inputs: Number of dynamic inputs per row
/// @param num_rows: Number of rows to process
/// @param results: Output array for results (must have space for num_rows elements)
/// Returns 0 on success, non-zero on error
///
/// Example:
///   If you have 2 dynamic inputs and want to process 3 rows:
///   input_values = [100.0, 200.0,  150.0, 250.0,  175.0, 225.0]
///                   ^row0^         ^row1^         ^row2^
///   num_inputs = 2, num_rows = 3
export fn calculate_final_node_price_batch(
    input_values: [*]const f64,
    string_values: [*]const [*:0]const u8,
    num_rows: c_int,
    results: [*]f64,
) c_int {
    // Get list of dynamic input node IDs (compile time)
    const dynamic_inputs = comptime blk: {
        var inputs: []const []const u8 = &.{};
        for (PRICING_NODES) |node| {
            if (node.operation == .dynamic_input_num or node.operation == .dynamic_input_str) {
                inputs = inputs ++ &[_][]const u8{node.node_id};
            }
        }
        break :blk inputs;
    };

    // Validate input count
    if (num_inputs != dynamic_inputs.len) {
        return -1; // Input count mismatch
    }

    // Create a local executor for batch processing
    var batch_executor = PRICING_EXECUTOR.init();

    // Process each row
    var row: usize = 0;
    while (row < @as(usize, @intCast(num_rows))) : (row += 1) {
        // Set inputs for this row
        const row_offset = row * @as(usize, @intCast(num_inputs));

        inline for (dynamic_inputs, 0..) |node_id, i| {
            const value = input_values[row_offset + i];
            batch_executor.setInputNum(node_id, value) catch return -2;
        }

        // Calculate result
        results[row] = batch_executor.getOutput() catch return -3;
    }

    return 0;
}

// Note: This library doesn't have a main() function
// Use the benchmark executable to test the pricing model
// Example Python usage:
//
// from ctypes import CDLL, c_double, c_int, c_char_p, create_string_buffer
//
// lib = CDLL("./libzigdag.so")
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
// lib.calculate_final_node_price(byref(result))
// print(f"Price: ${result.value:.2f}")

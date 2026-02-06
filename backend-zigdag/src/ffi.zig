const std = @import("std");

const generated = @import("generated_nodes");
const PRICING_NODES = generated.nodes;
const zigdag = @import("zigdag");
const DAGNode = zigdag.node.DAGNode;

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
                    .node_id = @ptrCast(node.node_id.ptr),
                    .input_type = InputType.numeric,
                    .index = num_idx,
                },
            };
            num_idx += 1;
        } else if (node.operation == .dynamic_input_str) {
            meta = meta ++ &[_]InputMeta{
                InputMeta{
                    .node_id = @ptrCast(node.node_id.ptr),
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
/// @param numeric_input_values: Flat array of numeric inputs, ordered by PRICING_NODES declaration order
/// @param string_input_values: Flat array of string inputs (C strings), ordered by PRICING_NODES declaration order
/// @param num_numeric_inputs: Number of numeric inputs per row (for validation)
/// @param num_string_inputs: Number of string inputs per row (for validation)
/// @param num_rows: Number of rows to process
/// @param results: Output array for results (must have space for num_rows elements)
/// Returns 0 on success, non-zero on error
export fn calculate_final_node_price_batch(
    numeric_input_values: [*]const f64,
    string_input_values: [*]const [*:0]const u8,
    num_numeric_inputs: c_int,
    num_string_inputs: c_int,
    num_rows: c_int,
    results: [*]f64,
) c_int {
    const dynamic_inputs = comptime blk: {
        var inputs: []const *const DAGNode = &.{};
        for (PRICING_NODES) |node| {
            if (node.operation == .dynamic_input_num or node.operation == .dynamic_input_str) {
                inputs = inputs ++ &[_]*const DAGNode{&node};
            }
        }
        break :blk inputs;
    };

    const expected_numeric = comptime blk: {
        var count: c_int = 0;
        for (PRICING_NODES) |node| {
            if (node.operation == .dynamic_input_num) count += 1;
        }
        break :blk count;
    };

    const expected_string = comptime blk: {
        var count: c_int = 0;
        for (PRICING_NODES) |node| {
            if (node.operation == .dynamic_input_str) count += 1;
        }
        break :blk count;
    };

    // Validate input counts match compiled model
    if (num_numeric_inputs != expected_numeric or num_string_inputs != expected_string) {
        return -1;
    }

    var batch_executor = PRICING_EXECUTOR.init();
    var num_offset: usize = 0;
    var string_offset: usize = 0;
    for (0..@as(usize, @intCast(num_rows))) |row| {
        inline for (dynamic_inputs) |node| {
            if (node.operation == .dynamic_input_num) {
                batch_executor.setInputNum(node.node_id, numeric_input_values[num_offset]) catch return -2;
                num_offset += 1;
            } else if (node.operation == .dynamic_input_str) {
                batch_executor.setInputStr(node.node_id, std.mem.span(string_input_values[string_offset])) catch return -2;
                string_offset += 1;
            }
        }
        results[row] = batch_executor.getOutput() catch return -3;
    }

    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "single calculation: nome=tiago, discount=10" {
    // Set inputs via the FFI functions
    try std.testing.expectEqual(@as(c_int, 0), set_input_node_value_str("nome", "tiago"));
    try std.testing.expectEqual(@as(c_int, 0), set_input_node_value_num("discount", 10.0));

    var result: f64 = 0.0;
    try std.testing.expectEqual(@as(c_int, 0), calculate_final_node_price(&result));

    // nome=tiago -> 200, * 100 = 20000, + 30000 = 50000, / 10 = 5000
    try std.testing.expectApproxEqAbs(@as(f64, 5000.0), result, 0.001);
}

test "batch calculation: single row" {
    const numeric_values = [_]f64{10.0}; // discount
    const string_values = [_][*:0]const u8{"tiago"}; // nome
    var results = [_]f64{0.0};

    const ret = calculate_final_node_price_batch(
        &numeric_values,
        &string_values,
        1, // num_numeric_inputs
        1, // num_string_inputs
        1, // num_rows
        &results,
    );

    try std.testing.expectEqual(@as(c_int, 0), ret);
    try std.testing.expectApproxEqAbs(@as(f64, 5000.0), results[0], 0.001);
}

test "batch calculation: multiple rows" {
    // 3 rows: tiago/10, ben/20, test/5
    const numeric_values = [_]f64{ 10.0, 20.0, 5.0 };
    const string_values = [_][*:0]const u8{ "tiago", "zefaria", "test" };
    var results = [_]f64{ 0.0, 0.0, 0.0 };

    const ret = calculate_final_node_price_batch(
        &numeric_values,
        &string_values,
        1, // num_numeric_inputs
        1, // num_string_inputs
        3, // num_rows
        &results,
    );

    try std.testing.expectEqual(@as(c_int, 0), ret);
    // tiago: 200*100+30000=50000, /10=5000
    try std.testing.expectApproxEqAbs(@as(f64, 5000.0), results[0], 0.001);
    // ben: 400*100+30000=70000, /20=3500
    try std.testing.expectApproxEqAbs(@as(f64, 3500.0), results[1], 0.001);
    // test: 100*100+30000=40000, /5=8000
    try std.testing.expectApproxEqAbs(@as(f64, 8000.0), results[2], 0.001);
}

test "batch calculation: validation rejects wrong counts" {
    const numeric_values = [_]f64{10.0};
    const string_values = [_][*:0]const u8{"tiago"};
    var results = [_]f64{0.0};

    // Wrong numeric count
    const ret = calculate_final_node_price_batch(
        &numeric_values,
        &string_values,
        99, // wrong
        1,
        1,
        &results,
    );
    try std.testing.expectEqual(@as(c_int, -1), ret);
}

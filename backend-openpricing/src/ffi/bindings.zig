const std = @import("std");
const openpricing = @import("openpricing");

const PricingGraph = openpricing.PricingGraph;
const ScalarExecutionContext = openpricing.ScalarExecutionContext;
const GraphParser = openpricing.GraphParser;

/// C-compatible opaque pointer types
const GraphHandle = *anyopaque;
const ContextHandle = *anyopaque;

/// Global allocator for FFI operations
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// Error codes for C API
pub const ErrorCode = enum(c_int) {
    Success = 0,
    InvalidJson = 1,
    GraphValidationFailed = 2,
    ExecutionFailed = 3,
    InvalidHandle = 4,
    InputNotSet = 5,
    OutOfMemory = 6,
    _,
};

// ============================================================================
// Graph Management API
// ============================================================================

/// Create a pricing graph from JSON definition
export fn pricing_graph_from_json(json_str: [*:0]const u8, json_len: usize, out_handle: *?GraphHandle) ErrorCode {
    const json = json_str[0..json_len];

    var parser = GraphParser.init(allocator);
    const graph = parser.parseJson(json) catch |err| {
        std.debug.print("Failed to parse JSON: {}\n", .{err});
        return .InvalidJson;
    };

    const graph_ptr = allocator.create(PricingGraph) catch {
        return .OutOfMemory;
    };
    graph_ptr.* = graph;

    out_handle.* = @ptrCast(graph_ptr);
    return .Success;
}

/// Free a pricing graph
export fn pricing_graph_free(handle: GraphHandle) void {
    const graph: *PricingGraph = @ptrCast(@alignCast(handle));
    graph.deinit();
    allocator.destroy(graph);
}

/// Export graph to JSON
export fn pricing_graph_to_json(handle: GraphHandle, out_json: *[*:0]u8, out_len: *usize) ErrorCode {
    const graph: *PricingGraph = @ptrCast(@alignCast(handle));

    var parser = GraphParser.init(allocator);
    const json = parser.toJson(graph) catch {
        return .ExecutionFailed;
    };

    // Null-terminate for C
    const null_terminated = allocator.allocSentinel(u8, json.len, 0) catch {
        allocator.free(json);
        return .OutOfMemory;
    };
    @memcpy(null_terminated, json);
    allocator.free(json);

    out_json.* = null_terminated.ptr;
    out_len.* = null_terminated.len;
    return .Success;
}

/// Free a JSON string returned by pricing_graph_to_json
export fn pricing_json_free(json: [*:0]u8, len: usize) void {
    const slice = json[0..len :0];
    allocator.free(slice);
}

// ============================================================================
// Execution Context API
// ============================================================================

/// Create an execution context for a graph
export fn pricing_context_create(graph_handle: GraphHandle, out_handle: *?ContextHandle) ErrorCode {
    const graph: *PricingGraph = @ptrCast(@alignCast(graph_handle));

    const ctx = allocator.create(ScalarExecutionContext) catch {
        return .OutOfMemory;
    };
    ctx.* = ScalarExecutionContext.init(allocator, graph);

    out_handle.* = @ptrCast(ctx);
    return .Success;
}

/// Free an execution context
export fn pricing_context_free(handle: ContextHandle) void {
    const ctx: *ScalarExecutionContext = @ptrCast(@alignCast(handle));
    ctx.deinit();
    allocator.destroy(ctx);
}

/// Set an input value in the context
export fn pricing_context_set_input(handle: ContextHandle, node_id: [*:0]const u8, value: f64) ErrorCode {
    const ctx: *ScalarExecutionContext = @ptrCast(@alignCast(handle));
    const id = std.mem.span(node_id);

    ctx.setInput(id, value) catch {
        return .InputNotSet;
    };
    return .Success;
}

/// Execute the pricing graph and get result
export fn pricing_context_execute(handle: ContextHandle, output_node_id: [*:0]const u8, out_result: *f64) ErrorCode {
    const ctx: *ScalarExecutionContext = @ptrCast(@alignCast(handle));
    const id = std.mem.span(output_node_id);

    const result = ctx.execute(id) catch |err| {
        std.debug.print("Execution failed: {}\n", .{err});
        return .ExecutionFailed;
    };

    out_result.* = result;
    return .Success;
}

// ============================================================================
// Batch Execution API (SIMD)
// ============================================================================

/// Execute pricing in batch mode using SIMD
export fn pricing_execute_batch(
    handle: ContextHandle,
    output_node_id: [*:0]const u8,
    batch_size: usize,
    out_results: [*]f64,
) ErrorCode {
    _ = handle;
    _ = output_node_id;
    _ = batch_size;
    _ = out_results;
    // TODO: Implement batch execution API
    return .Success;
}

// ============================================================================
// Utility API
// ============================================================================

/// Get the last error message (if any)
var last_error_msg: ?[]const u8 = null;

export fn pricing_get_last_error(out_msg: *[*]const u8, out_len: *usize) bool {
    if (last_error_msg) |msg| {
        out_msg.* = msg.ptr;
        out_len.* = msg.len;
        return true;
    }
    return false;
}

/// Validate a JSON graph definition without creating a graph
export fn pricing_validate_json(json_str: [*:0]const u8, json_len: usize) ErrorCode {
    const json = json_str[0..json_len];

    var parser = GraphParser.init(allocator);
    var graph = parser.parseJson(json) catch {
        return .InvalidJson;
    };
    defer graph.deinit();

    graph.validate() catch {
        return .GraphValidationFailed;
    };

    return .Success;
}

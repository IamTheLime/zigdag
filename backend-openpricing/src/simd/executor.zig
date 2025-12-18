const std = @import("std");
const node_module = @import("../core/node.zig");
const graph_module = @import("../graph/pricing_graph.zig");
const PricingNode = node_module.PricingNode;
const PricingGraph = graph_module.PricingGraph;
const OperationType = node_module.OperationType;

/// SIMD vector size - using 256-bit AVX (4 doubles)
pub const SIMD_WIDTH = 4;
pub const SimdVec = @Vector(SIMD_WIDTH, f64);

/// Execution context for pricing calculations
pub const ExecutionContext = struct {
    allocator: std.mem.Allocator,
    graph: *PricingGraph,
    node_values: std.StringHashMap(SimdVec), // Stores SIMD vectors for each node
    input_values: std.StringHashMap(SimdVec), // Input values provided by user

    pub fn init(allocator: std.mem.Allocator, graph: *PricingGraph) ExecutionContext {
        return ExecutionContext{
            .allocator = allocator,
            .graph = graph,
            .node_values = std.StringHashMap(SimdVec).init(allocator),
            .input_values = std.StringHashMap(SimdVec).init(allocator),
        };
    }

    pub fn deinit(self: *ExecutionContext) void {
        self.node_values.deinit();
        self.input_values.deinit();
    }

    /// Set input value for a batch of calculations
    pub fn setInput(self: *ExecutionContext, node_id: []const u8, values: SimdVec) !void {
        try self.input_values.put(node_id, values);
    }

    /// Set input value from a scalar (broadcasts to all lanes)
    pub fn setInputScalar(self: *ExecutionContext, node_id: []const u8, value: f64) !void {
        const vec: SimdVec = @splat(value);
        try self.input_values.put(node_id, vec);
    }

    /// Execute the pricing graph and return the result for the output node
    pub fn execute(self: *ExecutionContext, output_node_id: []const u8) !SimdVec {
        // Clear previous computation
        self.node_values.clearRetainingCapacity();

        const execution_order = self.graph.getExecutionOrder();

        for (execution_order) |node_id| {
            const node = self.graph.getNode(node_id) orelse return error.NodeNotFound;
            const result = try self.evaluateNode(node);
            try self.node_values.put(node_id, result);
        }

        return self.node_values.get(output_node_id) orelse error.OutputNodeNotFound;
    }

    /// Evaluate a single node
    fn evaluateNode(self: *ExecutionContext, node: *const PricingNode) !SimdVec {
        switch (node.operation) {
            .input => {
                return self.input_values.get(node.id) orelse {
                    std.debug.print("Input node {s} has no value set\n", .{node.id});
                    return error.InputNotSet;
                };
            },
            .constant => {
                const vec: SimdVec = @splat(node.constant_value);
                return vec;
            },
            .add => {
                if (node.inputs.len != 2) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                const b = self.node_values.get(node.inputs[1]) orelse return error.InputNotComputed;
                return a + b;
            },
            .subtract => {
                if (node.inputs.len != 2) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                const b = self.node_values.get(node.inputs[1]) orelse return error.InputNotComputed;
                return a - b;
            },
            .multiply => {
                if (node.inputs.len != 2) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                const b = self.node_values.get(node.inputs[1]) orelse return error.InputNotComputed;
                return a * b;
            },
            .divide => {
                if (node.inputs.len != 2) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                const b = self.node_values.get(node.inputs[1]) orelse return error.InputNotComputed;
                return a / b;
            },
            .negate => {
                if (node.inputs.len != 1) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                const zero: SimdVec = @splat(0.0);
                return zero - a;
            },
            .abs => {
                if (node.inputs.len != 1) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                return @abs(a);
            },
            .sqrt => {
                if (node.inputs.len != 1) return error.InvalidInputCount;
                const a = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                return @sqrt(a);
            },
            .max => {
                if (node.inputs.len < 2) return error.InvalidInputCount;
                var result = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                for (node.inputs[1..]) |input_id| {
                    const val = self.node_values.get(input_id) orelse return error.InputNotComputed;
                    result = @max(result, val);
                }
                return result;
            },
            .min => {
                if (node.inputs.len < 2) return error.InvalidInputCount;
                var result = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                for (node.inputs[1..]) |input_id| {
                    const val = self.node_values.get(input_id) orelse return error.InputNotComputed;
                    result = @min(result, val);
                }
                return result;
            },
            .weighted_sum => {
                if (node.inputs.len != node.weights.len) return error.WeightMismatch;
                if (node.inputs.len == 0) return error.InvalidInputCount;

                const zero: SimdVec = @splat(0.0);
                var result = zero;

                for (node.inputs, 0..) |input_id, i| {
                    const val = self.node_values.get(input_id) orelse return error.InputNotComputed;
                    const weight: SimdVec = @splat(node.weights[i]);
                    result += val * weight;
                }
                return result;
            },
            .clamp => {
                if (node.inputs.len != 3) return error.InvalidInputCount;
                const val = self.node_values.get(node.inputs[0]) orelse return error.InputNotComputed;
                const min_val = self.node_values.get(node.inputs[1]) orelse return error.InputNotComputed;
                const max_val = self.node_values.get(node.inputs[2]) orelse return error.InputNotComputed;
                return @min(@max(val, min_val), max_val);
            },
            else => {
                std.debug.print("Operation {s} not yet implemented\n", .{@tagName(node.operation)});
                return error.OperationNotImplemented;
            },
        }
    }
};

/// Single-value execution context (convenience wrapper for non-batched operations)
pub const ScalarExecutionContext = struct {
    allocator: std.mem.Allocator,
    graph: *PricingGraph,
    node_values: std.StringHashMap(f64),
    input_values: std.StringHashMap(f64),

    pub fn init(allocator: std.mem.Allocator, graph: *PricingGraph) ScalarExecutionContext {
        return ScalarExecutionContext{
            .allocator = allocator,
            .graph = graph,
            .node_values = std.StringHashMap(f64).init(allocator),
            .input_values = std.StringHashMap(f64).init(allocator),
        };
    }

    pub fn deinit(self: *ScalarExecutionContext) void {
        self.node_values.deinit();
        self.input_values.deinit();
    }

    pub fn setInput(self: *ScalarExecutionContext, node_id: []const u8, value: f64) !void {
        try self.input_values.put(node_id, value);
    }

    pub fn execute(self: *ScalarExecutionContext, output_node_id: []const u8) !f64 {
        var simd_ctx = ExecutionContext.init(self.allocator, self.graph);
        defer simd_ctx.deinit();

        // Convert scalar inputs to SIMD
        var input_iter = self.input_values.iterator();
        while (input_iter.next()) |entry| {
            try simd_ctx.setInputScalar(entry.key_ptr.*, entry.value_ptr.*);
        }

        const result = try simd_ctx.execute(output_node_id);
        return result[0]; // Return first lane
    }
};

test "SIMD executor basic operations" {
    const allocator = std.testing.allocator;
    var graph = PricingGraph.init(allocator);
    defer graph.deinit();

    // Create graph: A + B = C
    const node_a = try PricingNode.init(allocator, "A", .input);
    const node_b = try PricingNode.init(allocator, "B", .input);
    var node_c = try PricingNode.init(allocator, "C", .add);
    node_c.inputs = try allocator.dupe([]const u8, &[_][]const u8{ "A", "B" });

    try graph.addNode(node_a);
    try graph.addNode(node_b);
    try graph.addNode(node_c);
    try graph.topologicalSort();

    var ctx = ExecutionContext.init(allocator, &graph);
    defer ctx.deinit();

    const vec_a: SimdVec = .{ 1.0, 2.0, 3.0, 4.0 };
    const vec_b: SimdVec = .{ 5.0, 6.0, 7.0, 8.0 };

    try ctx.setInput("A", vec_a);
    try ctx.setInput("B", vec_b);

    const result = try ctx.execute("C");

    try std.testing.expectEqual(@as(f64, 6.0), result[0]);
    try std.testing.expectEqual(@as(f64, 8.0), result[1]);
    try std.testing.expectEqual(@as(f64, 10.0), result[2]);
    try std.testing.expectEqual(@as(f64, 12.0), result[3]);
}

test "Scalar executor wrapper" {
    const allocator = std.testing.allocator;
    var graph = PricingGraph.init(allocator);
    defer graph.deinit();

    // Create graph: A * B = C
    const node_a = try PricingNode.init(allocator, "A", .input);
    const node_b = try PricingNode.init(allocator, "B", .input);
    var node_c = try PricingNode.init(allocator, "C", .multiply);
    node_c.inputs = try allocator.dupe([]const u8, &[_][]const u8{ "A", "B" });

    try graph.addNode(node_a);
    try graph.addNode(node_b);
    try graph.addNode(node_c);
    try graph.topologicalSort();

    var ctx = ScalarExecutionContext.init(allocator, &graph);
    defer ctx.deinit();

    try ctx.setInput("A", 3.0);
    try ctx.setInput("B", 4.0);

    const result = try ctx.execute("C");
    try std.testing.expectEqual(@as(f64, 12.0), result);
}

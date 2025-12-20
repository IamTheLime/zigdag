const std = @import("std");
const comptime_parser = @import("../json/comptime_parser.zig");
const OperationType = @import("../core/node.zig").OperationType;
const ComptimeNode = comptime_parser.ComptimeNode;

/// SIMD vector size - using 256-bit AVX (4 doubles)
pub const SIMD_WIDTH = 4;
pub const SimdVec = @Vector(SIMD_WIDTH, f64);

/// Compile-time executor that works with static nodes from JSON
/// All graph structure is resolved at compile time - only values are runtime!
pub fn ComptimeExecutorFromNodes(comptime nodes: []const ComptimeNode) type {
    const node_count = nodes.len;
    const execution_order = comptime_parser.computeExecutionOrder(nodes);

    return struct {
        const Self = @This();

        // Static arrays for node values (on the stack!)
        node_values: [node_count]f64,
        // Input values - only thing we need at runtime
        inputs: std.StringHashMap(f64),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .node_values = [_]f64{0.0} ** node_count,
                .inputs = std.StringHashMap(f64).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.inputs.deinit();
        }

        /// Set input value
        pub fn setInput(self: *Self, comptime node_id: []const u8, value: f64) !void {
            try self.inputs.put(node_id, value);
        }

        /// Execute the pricing graph - completely inlined at compile time!
        pub fn execute(self: *Self, comptime output_node_id: []const u8) !f64 {
            // Process nodes in execution order
            inline for (execution_order) |node_idx| {
                const node = nodes[node_idx];
                self.node_values[node_idx] = try self.evaluateNode(node);
            }

            // Return the requested output node
            const output_idx = comptime comptime_parser.getNodeIndex(nodes, output_node_id);
            return self.node_values[output_idx];
        }

        /// Evaluate a single node - completely inlined!
        fn evaluateNode(self: *Self, comptime node: ComptimeNode) !f64 {
            switch (node.operation) {
                .input => {
                    return self.inputs.get(node.id) orelse {
                        std.debug.print("Input node {s} has no value set\n", .{node.id});
                        return error.InputNotSet;
                    };
                },
                .constant => {
                    return node.constant_value;
                },
                .add => {
                    comptime if (node.inputs.len != 2) @compileError("Add requires 2 inputs");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[1]);
                    return self.node_values[a_idx] + self.node_values[b_idx];
                },
                .subtract => {
                    comptime if (node.inputs.len != 2) @compileError("Subtract requires 2 inputs");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[1]);
                    return self.node_values[a_idx] - self.node_values[b_idx];
                },
                .multiply => {
                    comptime if (node.inputs.len != 2) @compileError("Multiply requires 2 inputs");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[1]);
                    return self.node_values[a_idx] * self.node_values[b_idx];
                },
                .divide => {
                    comptime if (node.inputs.len != 2) @compileError("Divide requires 2 inputs");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[1]);
                    return self.node_values[a_idx] / self.node_values[b_idx];
                },
                .power => {
                    comptime if (node.inputs.len != 2) @compileError("Power requires 2 inputs");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[1]);
                    return std.math.pow(f64, self.node_values[a_idx], self.node_values[b_idx]);
                },
                .negate => {
                    comptime if (node.inputs.len != 1) @compileError("Negate requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return -self.node_values[a_idx];
                },
                .abs => {
                    comptime if (node.inputs.len != 1) @compileError("Abs requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return @abs(self.node_values[a_idx]);
                },
                .sqrt => {
                    comptime if (node.inputs.len != 1) @compileError("Sqrt requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return @sqrt(self.node_values[a_idx]);
                },
                .exp => {
                    comptime if (node.inputs.len != 1) @compileError("Exp requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return @exp(self.node_values[a_idx]);
                },
                .log => {
                    comptime if (node.inputs.len != 1) @compileError("Log requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return @log(self.node_values[a_idx]);
                },
                .sin => {
                    comptime if (node.inputs.len != 1) @compileError("Sin requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return @sin(self.node_values[a_idx]);
                },
                .cos => {
                    comptime if (node.inputs.len != 1) @compileError("Cos requires 1 input");
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, node.inputs[0]);
                    return @cos(self.node_values[a_idx]);
                },
                .max => {
                    comptime if (node.inputs.len < 2) @compileError("Max requires at least 2 inputs");
                    var result = self.node_values[comptime comptime_parser.getNodeIndex(nodes, node.inputs[0])];
                    inline for (node.inputs[1..]) |input_id| {
                        const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, input_id)];
                        result = @max(result, val);
                    }
                    return result;
                },
                .min => {
                    comptime if (node.inputs.len < 2) @compileError("Min requires at least 2 inputs");
                    var result = self.node_values[comptime comptime_parser.getNodeIndex(nodes, node.inputs[0])];
                    inline for (node.inputs[1..]) |input_id| {
                        const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, input_id)];
                        result = @min(result, val);
                    }
                    return result;
                },
                .weighted_sum => {
                    comptime if (node.inputs.len != node.weights.len) @compileError("Weighted sum requires equal number of inputs and weights");
                    comptime if (node.inputs.len == 0) @compileError("Weighted sum requires at least 1 input");

                    var result: f64 = 0.0;
                    inline for (node.inputs, 0..) |input_id, i| {
                        const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, input_id)];
                        result += val * node.weights[i];
                    }
                    return result;
                },
                .clamp => {
                    comptime if (node.inputs.len != 3) @compileError("Clamp requires 3 inputs");
                    const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, node.inputs[0])];
                    const min_val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, node.inputs[1])];
                    const max_val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, node.inputs[2])];
                    return @min(@max(val, min_val), max_val);
                },
                else => {
                    @compileError("Operation " ++ @tagName(node.operation) ++ " not implemented in comptime executor");
                },
            }
        }
    };
}

/// Helper function to create executor from JSON at compile time
pub fn ComptimeExecutorFromJson(comptime json_str: []const u8) type {
    const nodes = comptime comptime_parser.parseComptimeGraph(json_str);
    return ComptimeExecutorFromNodes(nodes);
}

/// OLD API - kept for compatibility
/// Compile-time optimized executor that works with ComptimeGraph
/// This eliminates hash map lookups and uses static arrays instead
pub fn ComptimeExecutor(comptime GraphType: type) type {
    const node_count = GraphType.NodeCount;

    return struct {
        const Self = @This();

        // Static arrays for node values (indexed by node position in graph)
        node_values: [node_count]SimdVec,
        // Input values stored separately
        inputs: std.StringHashMap(SimdVec),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .node_values = undefined,
                .inputs = std.StringHashMap(SimdVec).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.inputs.deinit();
        }

        /// Set input value for a batch of calculations
        pub fn setInput(self: *Self, comptime node_id: []const u8, values: SimdVec) !void {
            try self.inputs.put(node_id, values);
        }

        /// Set input value from a scalar (broadcasts to all lanes)
        pub fn setInputScalar(self: *Self, comptime node_id: []const u8, value: f64) !void {
            const vec: SimdVec = @splat(value);
            try self.inputs.put(node_id, vec);
        }

        /// Execute the pricing graph - completely inlined at compile time!
        pub fn execute(self: *Self, comptime output_node_id: []const u8) !SimdVec {
            // Process nodes in order (they're already topologically sorted in the graph)
            inline for (GraphType.nodes, 0..) |node, i| {
                self.node_values[i] = try self.evaluateNode(node);
            }

            // Return the requested output node
            const output_idx = comptime GraphType.getNodeIndex(output_node_id);
            return self.node_values[output_idx];
        }

        /// Evaluate a single node - completely inlined!
        fn evaluateNode(self: *Self, comptime node: GraphType.NodeInfo) !SimdVec {
            switch (node.operation) {
                .input => {
                    return self.inputs.get(node.id) orelse {
                        std.debug.print("Input node {s} has no value set\n", .{node.id});
                        return error.InputNotSet;
                    };
                },
                .constant => {
                    const vec: SimdVec = @splat(node.constant_value);
                    return vec;
                },
                .add => {
                    comptime if (node.inputs.len != 2) @compileError("Add requires 2 inputs");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    const b = self.node_values[comptime GraphType.getNodeIndex(node.inputs[1])];
                    return a + b;
                },
                .subtract => {
                    comptime if (node.inputs.len != 2) @compileError("Subtract requires 2 inputs");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    const b = self.node_values[comptime GraphType.getNodeIndex(node.inputs[1])];
                    return a - b;
                },
                .multiply => {
                    comptime if (node.inputs.len != 2) @compileError("Multiply requires 2 inputs");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    const b = self.node_values[comptime GraphType.getNodeIndex(node.inputs[1])];
                    return a * b;
                },
                .divide => {
                    comptime if (node.inputs.len != 2) @compileError("Divide requires 2 inputs");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    const b = self.node_values[comptime GraphType.getNodeIndex(node.inputs[1])];
                    return a / b;
                },
                .negate => {
                    comptime if (node.inputs.len != 1) @compileError("Negate requires 1 input");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    const zero: SimdVec = @splat(0.0);
                    return zero - a;
                },
                .abs => {
                    comptime if (node.inputs.len != 1) @compileError("Abs requires 1 input");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    return @abs(a);
                },
                .sqrt => {
                    comptime if (node.inputs.len != 1) @compileError("Sqrt requires 1 input");
                    const a = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    return @sqrt(a);
                },
                .max => {
                    comptime if (node.inputs.len < 2) @compileError("Max requires at least 2 inputs");
                    var result = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    inline for (node.inputs[1..]) |input_id| {
                        const val = self.node_values[comptime GraphType.getNodeIndex(input_id)];
                        result = @max(result, val);
                    }
                    return result;
                },
                .min => {
                    comptime if (node.inputs.len < 2) @compileError("Min requires at least 2 inputs");
                    var result = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    inline for (node.inputs[1..]) |input_id| {
                        const val = self.node_values[comptime GraphType.getNodeIndex(input_id)];
                        result = @min(result, val);
                    }
                    return result;
                },
                .weighted_sum => {
                    comptime if (node.inputs.len != node.weights.len) @compileError("Weighted sum requires equal number of inputs and weights");
                    comptime if (node.inputs.len == 0) @compileError("Weighted sum requires at least 1 input");

                    const zero: SimdVec = @splat(0.0);
                    var result = zero;

                    inline for (node.inputs, 0..) |input_id, i| {
                        const val = self.node_values[comptime GraphType.getNodeIndex(input_id)];
                        const weight: SimdVec = @splat(node.weights[i]);
                        result += val * weight;
                    }
                    return result;
                },
                .clamp => {
                    comptime if (node.inputs.len != 3) @compileError("Clamp requires 3 inputs");
                    const val = self.node_values[comptime GraphType.getNodeIndex(node.inputs[0])];
                    const min_val = self.node_values[comptime GraphType.getNodeIndex(node.inputs[1])];
                    const max_val = self.node_values[comptime GraphType.getNodeIndex(node.inputs[2])];
                    return @min(@max(val, min_val), max_val);
                },
                else => {
                    @compileError("Operation " ++ @tagName(node.operation) ++ " not implemented in comptime executor");
                },
            }
        }
    };
}

/// Scalar wrapper for comptime executor (non-batched operations)
pub fn ComptimeScalarExecutor(comptime GraphType: type) type {
    const SimdExecutor = ComptimeExecutor(GraphType);

    return struct {
        const Self = @This();

        executor: SimdExecutor,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .executor = SimdExecutor.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.executor.deinit();
        }

        pub fn setInput(self: *Self, comptime node_id: []const u8, value: f64) !void {
            try self.executor.setInputScalar(node_id, value);
        }

        pub fn execute(self: *Self, comptime output_node_id: []const u8) !f64 {
            const result = try self.executor.execute(output_node_id);
            return result[0]; // Return first lane
        }
    };
}

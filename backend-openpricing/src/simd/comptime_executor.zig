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
        node_values: [node_count]f64 = [_]f64{0.0} ** node_count,

        pub fn init() Self {
            return Self{};
        }

        /// Set input value by storing it directly in the node values array
        pub fn setInput(self: *Self, comptime node_id: []const u8, value: f64) !void {
            const idx = comptime comptime_parser.getNodeIndex(nodes, node_id);
            self.node_values[idx] = value;
        }

        /// Get output value - executes the graph if needed
        pub fn getOutput(self: *Self, comptime output_node_id: []const u8) !f64 {
            return try self.execute(output_node_id);
        }

        /// Execute the pricing graph - completely inlined at compile time!
        fn execute(self: *Self, comptime output_node_id: []const u8) !f64 {
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
                    // Input values are already stored in node_values by setInput
                    const idx = comptime comptime_parser.getNodeIndex(nodes, node.id);
                    return self.node_values[idx];
                },
                .conditional_input => {
                    // Input values are already stored in node_values by setInput
                    const idx = comptime comptime_parser.getNodeIndex(nodes, node.id);
                    return self.node_values[idx];
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

// Aux funcctions 
//
fn roundTo2dp(value: f64) f64 {
    return @round(value * 100.0) / 100.0;
}

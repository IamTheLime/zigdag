const std = @import("std");
const comptime_parser = @import("../core/comptime_parser.zig");
const corenode = @import("../core/node.zig");
const OperationType = corenode.OperationType;
const PricingNode = corenode.PricingNode;

const ExecutorError = error{
    MappingNotFound,
};

/// Compile-time executor that works with static nodes from JSON
/// All graph structure is resolved at compile time - only values are runtime!
pub fn ComptimeExecutorFromNodes(comptime nodes: []const PricingNode) type {
    const node_count = nodes.len;
    const execution_order = comptime_parser.computeExecutionOrder(nodes);
    const _funnel_node = comptime blk: {
        for (nodes) |node| {
            if (node.operation == .funnel) {
                break :blk node.node_id;
            }
        }
        @compileError("No funnel node found in pricing model! Every model must have a funnel node as the final output.");
    };

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
        pub fn getOutput(self: *Self) !f64 {
            return try self.execute(_funnel_node);
        }

        /// Execute the pricing graph - completely inlined at compile time!
        fn execute(self: *Self, comptime output_node_id: []const u8) ExecutorError!f64 {
            // Process nodes in execution order
            inline for (execution_order) |node_idx| {
                const node = nodes[node_idx];
                self.node_values[node_idx] = try self.evaluateNode(node);
            }

            // Return the requested output node
            const output_idx = comptime comptime_parser.getNodeIndex(nodes, output_node_id);
            return self.node_values[output_idx];
        }

        /// Evaluate a single node - completely inlined using the typed union!
        fn evaluateNode(self: *Self, comptime node: PricingNode) !f64 {
            @setEvalBranchQuota(10000); // Increase quota for complex conditional lookups
            return switch (node.operation) {
                .dynamic_input_num => |_| {
                    // Dynamic input values are set at runtime by setInput
                    const idx = comptime comptime_parser.getNodeIndex(nodes, node.node_id);
                    return self.node_values[idx];
                },
                .dynamic_input_str => |_| {
                    // Dynamic string input values are set at runtime by setInput
                    const idx = comptime comptime_parser.getNodeIndex(nodes, node.node_id);
                    return self.node_values[idx];
                },
                .conditional_value_input => |op| {
                    // Get the input node and look up its string value
                    const input_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node);
                    const input_node = comptime nodes[input_idx];

                    // The input must be a constant_input_str
                    const str_value = switch (input_node.operation) {
                        .constant_input_str => |str_op| str_op.value,
                        .dynamic_input_str => |str_op| str_op.user_value,
                        else => @compileError("conditional_value_input must have a constant_input_str as input"),
                    };

                    // Look up the value in the map at compile time
                    var result: f64 = 0.0;
                    var found = false;
                    const sv = str_value orelse "";  // or return, break, etc.
                    inline for (op.value_map) |mapping| {
                        if (std.mem.eql(u8, mapping.key, sv)) {
                            result = mapping.value;
                            found = true;
                            break;
                        }
                    }

                    if (!found) {
                        return ExecutorError.MappingNotFound;
                    }

                    return result;
                },
                .constant_input_num => |op| {
                    // Constant values are baked into the graph at compile time
                    return op.value;
                },
                .constant_input_str => |_| {
                    // For now, string constants return 0.0 (will be enhanced later)
                    // This is a placeholder for string-based logic
                    return 0.0;
                },

                // Binary operations
                .add => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.left_input_node_id);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, op.right_input_node_id);
                    return self.node_values[a_idx] + self.node_values[b_idx];
                },
                .subtract => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.left_input_node_id);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, op.right_input_node_id);
                    return self.node_values[a_idx] - self.node_values[b_idx];
                },
                .multiply => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.left_input_node_id);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, op.right_input_node_id);
                    return self.node_values[a_idx] * self.node_values[b_idx];
                },
                .divide => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.left_input_node_id);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, op.right_input_node_id);
                    return self.node_values[a_idx] / self.node_values[b_idx];
                },
                .power => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.left_input_node_id);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, op.right_input_node_id);
                    return std.math.pow(f64, self.node_values[a_idx], self.node_values[b_idx]);
                },
                .modulo => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.left_input_node_id);
                    const b_idx = comptime comptime_parser.getNodeIndex(nodes, op.right_input_node_id);
                    return @mod(self.node_values[a_idx], self.node_values[b_idx]);
                },

                // Unary operations
                .negate => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return -self.node_values[a_idx];
                },
                .abs => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return @abs(self.node_values[a_idx]);
                },
                .sqrt => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return @sqrt(self.node_values[a_idx]);
                },
                .exp => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return @exp(self.node_values[a_idx]);
                },
                .log => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return @log(self.node_values[a_idx]);
                },
                .sin => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return @sin(self.node_values[a_idx]);
                },
                .cos => |op| {
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return @cos(self.node_values[a_idx]);
                },
                .funnel => |op| {
                    // Funnel just passes through its input value
                    const a_idx = comptime comptime_parser.getNodeIndex(nodes, op.input_node_id);
                    return self.node_values[a_idx];
                },

                // Variadic operations
                .max => |op| {
                    comptime std.debug.assert(op.node_input_ids.len >= 2);
                    var result = self.node_values[comptime comptime_parser.getNodeIndex(nodes, op.node_input_ids[0])];
                    inline for (op.node_input_ids[1..]) |input_id| {
                        const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, input_id)];
                        result = @max(result, val);
                    }
                    return result;
                },
                .min => |op| {
                    comptime std.debug.assert(op.node_input_ids.len >= 2);
                    var result = self.node_values[comptime comptime_parser.getNodeIndex(nodes, op.node_input_ids[0])];
                    inline for (op.node_input_ids[1..]) |input_id| {
                        const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, input_id)];
                        result = @min(result, val);
                    }
                    return result;
                },

                // Weighted sum
                .weighted_sum => |op| {
                    comptime std.debug.assert(op.node_input_ids.len == op.weights.len);
                    var result: f64 = 0.0;
                    inline for (op.node_input_ids, op.weights) |input_id, weight| {
                        const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, input_id)];
                        result += val * weight;
                    }
                    return result;
                },

                // Clamp
                .clamp => |op| {
                    const val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, op.value)];
                    const min_val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, op.min)];
                    const max_val = self.node_values[comptime comptime_parser.getNodeIndex(nodes, op.max)];
                    return @min(@max(val, min_val), max_val);
                },
            };
        }
    };
}

// Aux functions
fn roundTo2dp(value: f64) f64 {
    return @round(value * 100.0) / 100.0;
}

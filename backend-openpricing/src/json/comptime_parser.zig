const std = @import("std");
const node_module = @import("../core/node.zig");
const OperationType = node_module.OperationType;
const NodeOperation = node_module.NodeOperation;
const PricingNode = node_module.PricingNode;

/// Helper function to define nodes at compile time manually
pub fn defineComptimeNodes(comptime nodes: []const PricingNode) []const PricingNode {
    return nodes;
}

/// Extract all dependency node IDs from a NodeOperation at compile time
pub fn getDependencies(comptime operation: NodeOperation) []const []const u8 {
    return switch (operation) {
        // Binary operations
        .add, .subtract, .multiply, .divide, .power, .modulo => |op| &[_][]const u8{
            op.left_input_node_id,
            op.right_input_node_id,
        },

        // Unary operations
        .negate, .abs, .sqrt, .exp, .log, .sin, .cos, .funnel => |op| &[_][]const u8{
            op.input_node_id,
        },

        // Variadic operations
        .max, .min => |op| op.node_input_ids,

        // Weighted sum
        .weighted_sum => |op| op.node_input_ids,

        // Clamp
        .clamp => |op| &[_][]const u8{
            op.value,
            op.min,
            op.max,
        },

        // Conditional value input
        .conditional_value_input => |op| &[_][]const u8{
            op.input_node,
        },

        // Constants and dynamic inputs have no dependencies
        .constant_input_num, .constant_input_str, .dynamic_input_num, .dynamic_input_str => &[_][]const u8{},
    };
}

/// Find node index by ID at compile time
pub fn getNodeIndex(comptime nodes: []const PricingNode, comptime id: []const u8) usize {
    inline for (nodes, 0..) |node, i| {
        if (std.mem.eql(u8, node.node_id, id)) {
            return i;
        }
    }
    @compileError("Node not found: " ++ id);
}

/// Perform topological sort at compile time using Kahn's algorithm
/// This ensures nodes are executed in dependency order (DAG)
pub fn computeExecutionOrder(comptime nodes: []const PricingNode) []const usize {
    comptime {
        const n = nodes.len;

        // Calculate in-degree for each node (how many dependencies it has)
        var in_degree: [n]usize = [_]usize{0} ** n;

        // Build in-degree counts by examining dependencies from the typed operations
        for (nodes, 0..) |node, i| {
            const deps = getDependencies(node.operation);
            in_degree[i] = deps.len;
        }

        // Kahn's algorithm: start with nodes that have no dependencies
        var order: []const usize = &.{};
        var visited = [_]bool{false} ** n;
        var temp_in_degree = in_degree;

        // Repeatedly find nodes with in-degree 0 and add them to order
        var added = true;
        while (added) {
            added = false;
            for (0..n) |i| {
                if (!visited[i] and temp_in_degree[i] == 0) {
                    order = order ++ &[_]usize{i};
                    visited[i] = true;
                    added = true;

                    // Reduce in-degree for all nodes that depend on this one
                    for (nodes, 0..) |other_node, j| {
                        if (visited[j]) continue;
                        const deps = getDependencies(other_node.operation);
                        for (deps) |input_id| {
                            const dep_idx = getNodeIndex(nodes, input_id);
                            if (dep_idx == i) {
                                temp_in_degree[j] -= 1;
                            }
                        }
                    }
                }
            }
        }

        // Check if we processed all nodes (ensures DAG, no cycles)
        if (order.len != n) {
            @compileError("Circular dependency detected in pricing model! The graph must be a DAG.");
        }

        return order;
    }
}

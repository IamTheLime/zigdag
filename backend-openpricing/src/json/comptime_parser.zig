const std = @import("std");
const node_module = @import("../core/node.zig");
const OperationType = node_module.OperationType;
const NodeOperation = node_module.NodeOperation;

/// Compile-time parsed node information
/// This is a flattened version of NodeOperation for easier JSON parsing
pub const ComptimeNode = struct {
    id: []const u8,
    operation: OperationType,
    // Flattened inputs from the union - actual meaning depends on operation type
    inputs: []const []const u8,
    weights: []const f64,
    constant_value: f64,
    constant_str_value: []const u8,
    allowed_values: []const f64,
    name: []const u8,
    description: []const u8,
};

/// Helper function to define nodes at compile time manually
pub fn defineComptimeNodes(comptime nodes: []const ComptimeNode) []const ComptimeNode {
    return nodes;
}

fn parseOperation(comptime op_str: []const u8) OperationType {
    const op_map = std.StaticStringMap(OperationType).initComptime(.{
        .{ "add", .add },
        .{ "subtract", .subtract },
        .{ "multiply", .multiply },
        .{ "divide", .divide },
        .{ "power", .power },
        .{ "modulo", .modulo },
        .{ "negate", .negate },
        .{ "abs", .abs },
        .{ "sqrt", .sqrt },
        .{ "exp", .exp },
        .{ "log", .log },
        .{ "sin", .sin },
        .{ "cos", .cos },
        .{ "weighted_sum", .weighted_sum },
        .{ "max", .max },
        .{ "min", .min },
        .{ "clamp", .clamp },
        .{ "dynamic_input_num", .dynamic_input_num },
        .{ "dynamic_input_str", .dynamic_input_str },
        .{ "conditional_value_input", .conditional_value_input },
        .{ "constant_input_num", .constant_input_num },
        .{ "constant_input_str", .constant_input_str },
    });

    return op_map.get(op_str) orelse @compileError("Unknown operation: " ++ op_str);
}

/// Find node index by ID at compile time
pub fn getNodeIndex(comptime nodes: []const ComptimeNode, comptime id: []const u8) usize {
    inline for (nodes, 0..) |node, i| {
        if (std.mem.eql(u8, node.id, id)) {
            return i;
        }
    }
    @compileError("Node not found: " ++ id);
}

/// Perform topological sort at compile time using Kahn's algorithm
/// This ensures nodes are executed in dependency order (DAG)
pub fn computeExecutionOrder(comptime nodes: []const ComptimeNode) []const usize {
    comptime {
        const n = nodes.len;

        // Calculate in-degree for each node (how many dependencies it has)
        var in_degree: [n]usize = [_]usize{0} ** n;

        // Build in-degree counts by examining dependencies
        for (nodes, 0..) |node, i| {
            in_degree[i] = node.inputs.len;
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
                        for (other_node.inputs) |input_id| {
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

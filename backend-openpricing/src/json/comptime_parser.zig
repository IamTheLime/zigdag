const std = @import("std");
const node_module = @import("../core/node.zig");
const OperationType = node_module.OperationType;

/// Compile-time parsed node information
pub const ComptimeNode = struct {
    id: []const u8,
    operation: OperationType,
    inputs: []const []const u8,
    weights: []const f64,
    constant_value: f64,
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
        .{ "input", .input },
        .{ "constant", .constant },
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

/// Perform topological sort at compile time
pub fn computeExecutionOrder(comptime nodes: []const ComptimeNode) []const usize {
    // Simple topological sort using node order (assumes they're already in valid order)
    // For a more complex implementation, we'd need to compute dependencies
    // TODO: Fix this, this is absolutely wrogn  the topoligical sort needs  to care about order
    var order: []const usize = &.{};
    inline for (0..nodes.len) |i| {
        order = order ++ &[_]usize{i};
    }
    return order;
}

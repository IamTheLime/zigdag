const std = @import("std");

/// Operation types supported by pricing nodes
pub const OperationType = enum {
    // Binary operations
    add,
    subtract,
    multiply,
    divide,
    power,
    modulo,

    // Unary operations
    negate,
    abs,
    sqrt,
    exp,
    log,
    sin,
    cos,

    // Special operations
    weighted_sum, // sum of inputs with weights
    max,
    min,
    clamp,

    // Input/constant nodes
    conditional_value_input,
    constant_input_str,
    constant_input_num,
    dynamic_input_str,
    dynamic_input_num,
};

pub const BinaryInputs = struct {
    left_input_node_id: []const u8,
    right_input_node_id: []const u8,
};

pub const UnaryInput = struct {
    input_node_id: []const u8,
};

pub const VariadicInputs = struct {
    node_input_ids: []const []const u8,
};

pub const WeightedInputs = struct {
    node_input_ids: []const []const u8,
    weights: []const f64,
};

pub const ClampInputs = struct {
    value: []const u8,
    min: []const u8,
    max: []const u8,
};

pub const ConditionalValueInput = struct {
    input_node: []const u8,
    value_map: std.StringHashMap(f64), // Maps condition values to outputs
};

pub const ValueInputNum = struct {
    // This is the only way that a user can
    // provide an input to the system
    user_value: ?f64,
    allowed_values: []const f64,
};
pub const ValueInputStr = struct {
    // This is the only way that a user can
    // provide an input to the system
    user_value: ?[]u8,
    allowed_values: ?[]const f64,
};

pub const ConstantInputNum = struct {
    // This Type of input is hardcoded in the graph
    value: f64,
};
pub const ConstantInputStr = struct {
    // This Type of input is hardcoded in the graph
    value: []const u8,
};

pub const NodeOperation = union(OperationType) {
    // Binary operations - 2 inputs
    add: BinaryInputs,
    subtract: BinaryInputs,
    multiply: BinaryInputs,
    divide: BinaryInputs,
    power: BinaryInputs,
    modulo: BinaryInputs,

    // Unary operations - 1 input
    negate: UnaryInput,
    abs: UnaryInput,
    sqrt: UnaryInput,
    exp: UnaryInput,
    log: UnaryInput,
    sin: UnaryInput,
    cos: UnaryInput,

    // Special operations
    weighted_sum: WeightedInputs,
    max: VariadicInputs,
    min: VariadicInputs,
    clamp: ClampInputs,

    // Input/constant nodes
    conditional_value_input: ConditionalValueInput,
    constant_input_str: ConstantInputStr,
    constant_input_num: ConstantInputNum,
    dynamic_input_str: ValueInputStr,
    dynamic_input_num: ValueInputNum,
};

/// A pricing node in the computational graph
pub const PricingNode = struct {
    node_id: []const u8,
    operation: NodeOperation,
    metadata: NodeMetadata,

    pub const NodeMetadata = struct {
        name: []const u8,
        description: []const u8,
        position_x: f64,
        position_y: f64,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        id: []const u8,
        operation: NodeOperation,
    ) !PricingNode {
        return PricingNode{
            .node_id = try allocator.dupe(u8, id),
            .operation = operation,
            .metadata = .{
                .name = try allocator.dupe(u8, id),
                .description = "",
                .position_x = 0.0,
                .position_y = 0.0,
            },
        };
    }

    pub fn deinit(self: *PricingNode, allocator: std.mem.Allocator) void {
        allocator.free(self.node_id);
        allocator.free(self.metadata.name);
        if (self.metadata.description.len > 0) {
            allocator.free(self.metadata.description);
        }
    }

    /// Returns true if this node requires multiple inputs
    pub fn isMultiInput(self: PricingNode) bool {
        return switch (self.operation) {
            .add, .subtract, .multiply, .divide, .power, .modulo, .weighted_sum, .max, .min, .clamp => true,
            else => false,
        };
    }

    /// Returns the expected number of inputs (-1 means variable)
    pub fn expectedDependencyNodeCount(self: PricingNode) i32 {
        return switch (self.operation) {
            .constant_input_num, .constant_input_str, .dynamic_input_num, .dynamic_input_str => 0,
            .conditional_value_input => 1,
            .negate, .abs, .sqrt, .exp, .log, .sin, .cos => 1,
            .add, .subtract, .multiply, .divide, .power, .modulo => 2,
            .clamp => 3, // value, min, max
            .max, .min, .weighted_sum => -1, // variable inputs
        };
    }

    /// Returns all dependency node IDs for this node
    /// Used for topological sorting and dependency analysis
    pub fn getDependencies(self: PricingNode, allocator: std.mem.Allocator) ![]const []const u8 {
        return switch (self.operation) {
            // No dependencies
            .constant_input_num, .constant_input_str, .dynamic_input_num, .dynamic_input_str => &.{},

            // Single dependency
            .conditional_value_input => |input| blk: {
                var deps = try allocator.alloc([]const u8, 1);
                deps[0] = input.input_node;
                break :blk deps;
            },

            // Unary operations - 1 dependency
            .negate, .abs, .sqrt, .exp, .log, .sin, .cos => |input| blk: {
                var deps = try allocator.alloc([]const u8, 1);
                deps[0] = input.input_node_id;
                break :blk deps;
            },

            // Binary operations - 2 dependencies
            .add, .subtract, .multiply, .divide, .power, .modulo => |inputs| blk: {
                var deps = try allocator.alloc([]const u8, 2);
                deps[0] = inputs.left_input_node_id;
                deps[1] = inputs.right_input_node_id;
                break :blk deps;
            },

            // Clamp - 3 dependencies
            .clamp => |inputs| blk: {
                var deps = try allocator.alloc([]const u8, 3);
                deps[0] = inputs.value;
                deps[1] = inputs.min;
                deps[2] = inputs.max;
                break :blk deps;
            },

            // Variadic operations - variable dependencies
            .max, .min => |inputs| try allocator.dupe([]const u8, inputs.node_input_ids),

            // Weighted sum - variable dependencies
            .weighted_sum => |inputs| try allocator.dupe([]const u8, inputs.node_input_ids),
        };
    }
};

test "PricingNode init and deinit" {
    const allocator = std.testing.allocator;
    const operation = NodeOperation{ .add = .{
        .left_input_node_id = "node1",
        .right_input_node_id = "node2",
    } };
    var node = try PricingNode.init(allocator, "test_node", operation);
    defer node.deinit(allocator);

    try std.testing.expectEqualStrings("test_node", node.node_id);
    try std.testing.expectEqual(OperationType.add, @as(OperationType, node.operation));
}

test "PricingNode input expectations" {
    const allocator = std.testing.allocator;

    const add_operation = NodeOperation{ .add = .{
        .left_input_node_id = "node1",
        .right_input_node_id = "node2",
    } };
    var add_node = try PricingNode.init(allocator, "add", add_operation);
    defer add_node.deinit(allocator);

    try std.testing.expect(add_node.isMultiInput());
    try std.testing.expectEqual(@as(i32, 2), add_node.expectedDependencyNodeCount());

    const constant_operation = NodeOperation{ .constant_input_num = .{
        .value = 42.0,
    } };
    var constant_node = try PricingNode.init(allocator, "const", constant_operation);
    defer constant_node.deinit(allocator);

    try std.testing.expect(!constant_node.isMultiInput());
    try std.testing.expectEqual(@as(i32, 0), constant_node.expectedDependencyNodeCount());
}

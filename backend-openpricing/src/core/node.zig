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
    input,
    constant,
};

/// A pricing node in the computational graph
pub const PricingNode = struct {
    id: []const u8,
    operation: OperationType,
    weights: []const f64, // For weighted operations
    constant_value: f64, // For constant nodes
    inputs: []const []const u8, // IDs of input nodes
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
        operation: OperationType,
    ) !PricingNode {
        return PricingNode{
            .id = try allocator.dupe(u8, id),
            .operation = operation,
            .weights = &[_]f64{},
            .constant_value = 0.0,
            .inputs = &[_][]const u8{},
            .metadata = .{
                .name = try allocator.dupe(u8, id),
                .description = "",
                .position_x = 0.0,
                .position_y = 0.0,
            },
        };
    }

    pub fn deinit(self: *PricingNode, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.weights.len > 0) {
            allocator.free(self.weights);
        }
        for (self.inputs) |input| {
            allocator.free(input);
        }
        if (self.inputs.len > 0) {
            allocator.free(self.inputs);
        }
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
    pub fn expectedInputCount(self: PricingNode) i32 {
        return switch (self.operation) {
            .input, .constant => 0,
            .negate, .abs, .sqrt, .exp, .log, .sin, .cos => 1,
            .add, .subtract, .multiply, .divide, .power, .modulo => 2,
            .clamp => 3, // value, min, max
            .weighted_sum, .max, .min => -1, // variable inputs
        };
    }
};

test "PricingNode init and deinit" {
    const allocator = std.testing.allocator;
    var node = try PricingNode.init(allocator, "test_node", .add);
    defer node.deinit(allocator);

    try std.testing.expectEqualStrings("test_node", node.id);
    try std.testing.expectEqual(OperationType.add, node.operation);
}

test "PricingNode input expectations" {
    const allocator = std.testing.allocator;
    var add_node = try PricingNode.init(allocator, "add", .add);
    defer add_node.deinit(allocator);

    try std.testing.expect(add_node.isMultiInput());
    try std.testing.expectEqual(@as(i32, 2), add_node.expectedInputCount());

    var constant_node = try PricingNode.init(allocator, "const", .constant);
    defer constant_node.deinit(allocator);

    try std.testing.expect(!constant_node.isMultiInput());
    try std.testing.expectEqual(@as(i32, 0), constant_node.expectedInputCount());
}

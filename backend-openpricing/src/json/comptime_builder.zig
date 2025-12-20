const std = @import("std");
const node_module = @import("../core/node.zig");
const OperationType = node_module.OperationType;
const ComptimeNode = @import("comptime_parser.zig").ComptimeNode;

/// Builder API for creating pricing models at compile time
/// This provides a clean, type-safe way to define nodes without JSON
///
/// Example usage:
/// ```zig
/// const pricing_model = comptimeModel(&.{
///     input("base_price", "Base Price", "Product base price"),
///     input("quantity", "Quantity", "Number of items"),
///     multiply("subtotal", "Subtotal", "Price × Quantity", &.{"base_price", "quantity"}),
///     constant("discount_rate", "Discount Rate", "10% discount", 0.1),
///     multiply("discount_amount", "Discount Amount", "Discount in dollars", &.{"subtotal", "discount_rate"}),
///     subtract("after_discount", "After Discount", "Price after discount", &.{"subtotal", "discount_amount"}),
///     constant("tax_rate", "Tax Rate", "8% sales tax", 0.08),
///     multiply("tax_amount", "Tax Amount", "Tax in dollars", &.{"after_discount", "tax_rate"}),
///     add("final_total", "Final Total", "Total price with tax", &.{"after_discount", "tax_amount"}),
/// });
/// ```
/// Main entry point: convert array of node builders into ComptimeNode array
pub fn comptimeModel(comptime builders: []const NodeBuilder) []const ComptimeNode {
    var nodes: [builders.len]ComptimeNode = undefined;
    inline for (builders, 0..) |builder, i| {
        nodes[i] = builder.build();
    }
    const final_nodes = nodes;
    return &final_nodes;
}

/// Internal builder type - users don't need to interact with this directly
pub const NodeBuilder = struct {
    id: []const u8,
    operation: OperationType,
    inputs: []const []const u8,
    weights: []const f64,
    constant_value: f64,
    name: []const u8,
    description: []const u8,

    pub fn build(comptime self: NodeBuilder) ComptimeNode {
        return ComptimeNode{
            .id = self.id,
            .operation = self.operation,
            .inputs = self.inputs,
            .weights = self.weights,
            .constant_value = self.constant_value,
            .name = self.name,
            .description = self.description,
        };
    }
};

// ============================================================================
// Convenience functions for creating nodes
// ============================================================================

/// Create an input node
pub fn input(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .input,
        .inputs = &.{},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a constant node
pub fn constant(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime value: f64,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .constant,
        .inputs = &.{},
        .weights = &.{},
        .constant_value = value,
        .name = name,
        .description = description,
    };
}

/// Create an addition node
pub fn add(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .add,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a subtraction node
pub fn subtract(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .subtract,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a multiplication node
pub fn multiply(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .multiply,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a division node
pub fn divide(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .divide,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a power node
pub fn power(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .power,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a modulo node
pub fn modulo(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .modulo,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a negate node
pub fn negate(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .negate,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create an absolute value node
pub fn abs(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .abs,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a square root node
pub fn sqrt(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .sqrt,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create an exponential node
pub fn exp(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .exp,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a natural logarithm node
pub fn log(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .log,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a sine node
pub fn sin(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .sin,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a cosine node
pub fn cos(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime input_: []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .cos,
        .inputs = &.{input_},
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a weighted sum node
pub fn weightedSum(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
    comptime weights_: []const f64,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .weighted_sum,
        .inputs = inputs_,
        .weights = weights_,
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a max node
pub fn max(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .max,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a min node
pub fn min(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .min,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

/// Create a clamp node (clamp value between min and max)
pub fn clamp(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime inputs_: []const []const u8,
) NodeBuilder {
    return .{
        .id = id,
        .operation = .clamp,
        .inputs = inputs_,
        .weights = &.{},
        .constant_value = 0.0,
        .name = name,
        .description = description,
    };
}

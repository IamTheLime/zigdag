const std = @import("std");
const node_module = @import("../core/node.zig");
const graph_module = @import("../graph/pricing_graph.zig");
const PricingNode = node_module.PricingNode;
const PricingGraph = graph_module.PricingGraph;
const OperationType = node_module.OperationType;

/// JSON schema for a pricing graph definition
/// Expected format:
/// {
///   "nodes": [
///     {
///       "id": "node1",
///       "operation": "add",
///       "inputs": ["input1", "input2"],
///       "weights": [0.5, 0.5],
///       "constant_value": 0.0,
///       "metadata": {
///         "name": "Node 1",
///         "description": "Adds two inputs",
///         "position_x": 100,
///         "position_y": 200
///       }
///     }
///   ]
/// }
pub const GraphParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GraphParser {
        return GraphParser{ .allocator = allocator };
    }

    /// Parse a JSON string into a PricingGraph
    pub fn parseJson(self: *GraphParser, json_str: []const u8) !PricingGraph {
        var graph = PricingGraph.init(self.allocator);
        errdefer graph.deinit();

        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json_str,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;
        const nodes_array = root.get("nodes") orelse return error.MissingNodesArray;

        if (nodes_array != .array) return error.InvalidNodesType;

        for (nodes_array.array.items) |node_value| {
            const node = try self.parseNode(node_value);
            try graph.addNode(node);
        }

        try graph.validate();
        return graph;
    }

    fn parseNode(self: *GraphParser, value: std.json.Value) !PricingNode {
        if (value != .object) return error.InvalidNodeType;
        const obj = value.object;

        // Parse required fields
        const id_value = obj.get("id") orelse return error.MissingNodeId;
        const id = if (id_value == .string) id_value.string else return error.InvalidNodeId;

        const op_value = obj.get("operation") orelse return error.MissingOperation;
        const op_str = if (op_value == .string) op_value.string else return error.InvalidOperation;
        const operation = try self.parseOperation(op_str);

        var node = try PricingNode.init(self.allocator, id, operation);
        errdefer node.deinit(self.allocator);

        // Parse optional fields
        if (obj.get("inputs")) |inputs_value| {
            if (inputs_value == .array) {
                const inputs_array = inputs_value.array;
                var inputs = try self.allocator.alloc([]const u8, inputs_array.items.len);
                for (inputs_array.items, 0..) |item, i| {
                    if (item == .string) {
                        inputs[i] = try self.allocator.dupe(u8, item.string);
                    } else {
                        return error.InvalidInputType;
                    }
                }
                node.inputs = inputs;
            }
        }

        if (obj.get("weights")) |weights_value| {
            if (weights_value == .array) {
                const weights_array = weights_value.array;
                var weights = try self.allocator.alloc(f64, weights_array.items.len);
                for (weights_array.items, 0..) |item, i| {
                    weights[i] = switch (item) {
                        .float => |f| f,
                        .integer => |int| @floatFromInt(int),
                        else => return error.InvalidWeightType,
                    };
                }
                node.weights = weights;
            }
        }

        if (obj.get("constant_value")) |const_value| {
            node.constant_value = switch (const_value) {
                .float => |f| f,
                .integer => |int| @floatFromInt(int),
                else => return error.InvalidConstantType,
            };
        }

        if (obj.get("metadata")) |metadata_value| {
            if (metadata_value == .object) {
                const meta = metadata_value.object;

                if (meta.get("name")) |name_value| {
                    if (name_value == .string) {
                        self.allocator.free(node.metadata.name);
                        node.metadata.name = try self.allocator.dupe(u8, name_value.string);
                    }
                }

                if (meta.get("description")) |desc_value| {
                    if (desc_value == .string) {
                        if (node.metadata.description.len > 0) {
                            self.allocator.free(node.metadata.description);
                        }
                        node.metadata.description = try self.allocator.dupe(u8, desc_value.string);
                    }
                }

                if (meta.get("position_x")) |x_value| {
                    node.metadata.position_x = switch (x_value) {
                        .float => |f| f,
                        .integer => |int| @floatFromInt(int),
                        else => 0.0,
                    };
                }

                if (meta.get("position_y")) |y_value| {
                    node.metadata.position_y = switch (y_value) {
                        .float => |f| f,
                        .integer => |int| @floatFromInt(int),
                        else => 0.0,
                    };
                }
            }
        }

        return node;
    }

    fn parseOperation(self: *GraphParser, op_str: []const u8) !OperationType {
        _ = self;
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

        return op_map.get(op_str) orelse error.UnknownOperation;
    }

    /// Serialize a PricingGraph to JSON
    pub fn toJson(self: *GraphParser, graph: *PricingGraph) ![]u8 {
        var string = std.ArrayList(u8).fromOwnedSlice(&[_]u8{});
        errdefer string.deinit(self.allocator);

        var writer = string.writer(self.allocator);
        try writer.writeAll("{\"nodes\":[");

        var node_iter = graph.nodes.iterator();
        var first = true;
        while (node_iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            first = false;

            const node = entry.value_ptr;
            try self.writeNode(writer.any(), node);
        }

        try writer.writeAll("]}");
        return string.toOwnedSlice(self.allocator);
    }

    fn writeNode(self: *GraphParser, writer: std.io.AnyWriter, node: *const PricingNode) !void {
        _ = self;
        try writer.writeAll("{");
        try std.fmt.format(writer, "\"id\":\"{s}\",", .{node.id});
        try std.fmt.format(writer, "\"operation\":\"{s}\",", .{@tagName(node.operation)});

        // Write inputs
        try writer.writeAll("\"inputs\":[");
        for (node.inputs, 0..) |input, i| {
            if (i > 0) try writer.writeAll(",");
            try std.fmt.format(writer, "\"{s}\"", .{input});
        }
        try writer.writeAll("],");

        // Write weights
        try writer.writeAll("\"weights\":[");
        for (node.weights, 0..) |weight, i| {
            if (i > 0) try writer.writeAll(",");
            try std.fmt.format(writer, "{d}", .{weight});
        }
        try writer.writeAll("],");

        try std.fmt.format(writer, "\"constant_value\":{d},", .{node.constant_value});

        // Write metadata
        try writer.writeAll("\"metadata\":{");
        try std.fmt.format(writer, "\"name\":\"{s}\",", .{node.metadata.name});
        try std.fmt.format(writer, "\"description\":\"{s}\",", .{node.metadata.description});
        try std.fmt.format(writer, "\"position_x\":{d},", .{node.metadata.position_x});
        try std.fmt.format(writer, "\"position_y\":{d}", .{node.metadata.position_y});
        try writer.writeAll("}");

        try writer.writeAll("}");
    }
};

test "Parse simple JSON graph" {
    const allocator = std.testing.allocator;
    var parser = GraphParser.init(allocator);

    const json =
        \\{
        \\  "nodes": [
        \\    {
        \\      "id": "A",
        \\      "operation": "input",
        \\      "inputs": [],
        \\      "weights": [],
        \\      "constant_value": 0.0,
        \\      "metadata": {
        \\        "name": "Input A",
        \\        "description": "First input",
        \\        "position_x": 0,
        \\        "position_y": 0
        \\      }
        \\    },
        \\    {
        \\      "id": "B",
        \\      "operation": "input",
        \\      "inputs": [],
        \\      "weights": [],
        \\      "constant_value": 0.0,
        \\      "metadata": {
        \\        "name": "Input B",
        \\        "description": "Second input",
        \\        "position_x": 0,
        \\        "position_y": 100
        \\      }
        \\    },
        \\    {
        \\      "id": "C",
        \\      "operation": "add",
        \\      "inputs": ["A", "B"],
        \\      "weights": [],
        \\      "constant_value": 0.0,
        \\      "metadata": {
        \\        "name": "Sum",
        \\        "description": "A + B",
        \\        "position_x": 200,
        \\        "position_y": 50
        \\      }
        \\    }
        \\  ]
        \\}
    ;

    var graph = try parser.parseJson(json);
    defer graph.deinit();

    try std.testing.expect(graph.nodes.contains("A"));
    try std.testing.expect(graph.nodes.contains("B"));
    try std.testing.expect(graph.nodes.contains("C"));

    const order = graph.getExecutionOrder();
    try std.testing.expectEqual(@as(usize, 3), order.len);
}

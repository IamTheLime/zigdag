const std = @import("std");
const openpricing = @import("openpricing");

const PricingGraph = openpricing.PricingGraph;
const ScalarExecutionContext = openpricing.ScalarExecutionContext;
const GraphParser = openpricing.GraphParser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("OpenPricing CLI v0.1.0\n", .{});
    std.debug.print("=====================\n\n", .{});

    // Example usage
    const example_json =
        \\{
        \\  "nodes": [
        \\    {
        \\      "id": "base_price",
        \\      "operation": "input",
        \\      "inputs": [],
        \\      "weights": [],
        \\      "constant_value": 0.0,
        \\      "metadata": {
        \\        "name": "Base Price",
        \\        "description": "Starting price",
        \\        "position_x": 100,
        \\        "position_y": 100
        \\      }
        \\    },
        \\    {
        \\      "id": "markup",
        \\      "operation": "constant",
        \\      "inputs": [],
        \\      "weights": [],
        \\      "constant_value": 1.2,
        \\      "metadata": {
        \\        "name": "Markup",
        \\        "description": "20% markup",
        \\        "position_x": 100,
        \\        "position_y": 200
        \\      }
        \\    },
        \\    {
        \\      "id": "final_price",
        \\      "operation": "multiply",
        \\      "inputs": ["base_price", "markup"],
        \\      "weights": [],
        \\      "constant_value": 0.0,
        \\      "metadata": {
        \\        "name": "Final Price",
        \\        "description": "Price with markup applied",
        \\        "position_x": 300,
        \\        "position_y": 150
        \\      }
        \\    }
        \\  ]
        \\}
    ;

    std.debug.print("Parsing pricing graph from JSON...\n", .{});
    var parser = GraphParser.init(allocator);
    var graph = try parser.parseJson(example_json);
    defer graph.deinit();

    std.debug.print("Graph loaded successfully with {} nodes\n", .{graph.nodes.count()});

    const execution_order = graph.getExecutionOrder();
    std.debug.print("Execution order: ", .{});
    for (execution_order, 0..) |node_id, i| {
        if (i > 0) std.debug.print(" -> ", .{});
        std.debug.print("{s}", .{node_id});
    }
    std.debug.print("\n\n", .{});

    // Execute pricing
    std.debug.print("Executing pricing calculation...\n", .{});
    var ctx = ScalarExecutionContext.init(allocator, &graph);
    defer ctx.deinit();

    try ctx.setInput("base_price", 100.0);

    const result = try ctx.execute("final_price");
    std.debug.print("Base price: $100.00\n", .{});
    std.debug.print("Markup: 1.2x (20%)\n", .{});
    std.debug.print("Final price: ${d:.2}\n\n", .{result});

    std.debug.print("OpenPricing is ready!\n", .{});
    std.debug.print("Build the shared library with: zig build\n", .{});
    std.debug.print("Run tests with: zig build test\n", .{});
}

const std = @import("std");
const node_module = @import("../core/node.zig");
const PricingNode = node_module.PricingNode;

/// Represents a directed acyclic graph (DAG) of pricing nodes
pub const PricingGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.StringHashMap(PricingNode),
    adjacency_list: std.StringHashMap(std.ArrayList([]const u8)),
    execution_order: std.ArrayList([]const u8), // Topologically sorted node IDs

    pub fn init(allocator: std.mem.Allocator) PricingGraph {
        return PricingGraph{
            .allocator = allocator,
            .nodes = std.StringHashMap(PricingNode).init(allocator),
            .adjacency_list = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .execution_order = std.ArrayList([]const u8).fromOwnedSlice(&[_][]const u8{}),
        };
    }

    pub fn deinit(self: *PricingGraph) void {
        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            var node = entry.value_ptr;
            node.deinit(self.allocator);
        }
        self.nodes.deinit();

        var adj_iter = self.adjacency_list.iterator();
        while (adj_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.adjacency_list.deinit();

        self.execution_order.deinit(self.allocator);
    }

    /// Add a node to the graph
    pub fn addNode(self: *PricingGraph, node: PricingNode) !void {
        try self.nodes.put(node.id, node);

        // Initialize adjacency list entry
        if (!self.adjacency_list.contains(node.id)) {
            try self.adjacency_list.put(node.id, std.ArrayList([]const u8).fromOwnedSlice(&[_][]const u8{}));
        }

        // Add edges for this node's inputs
        for (node.inputs) |input_id| {
            try self.addEdge(input_id, node.id);
        }
    }

    /// Add an edge from source to destination
    fn addEdge(self: *PricingGraph, from: []const u8, to: []const u8) !void {
        const result = try self.adjacency_list.getOrPut(from);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList([]const u8).fromOwnedSlice(&[_][]const u8{});
        }
        try result.value_ptr.append(self.allocator, to);
    }

    /// Perform topological sort using Kahn's algorithm
    pub fn topologicalSort(self: *PricingGraph) !void {
        self.execution_order.clearRetainingCapacity();

        // Calculate in-degrees
        var in_degree = std.StringHashMap(usize).init(self.allocator);
        defer in_degree.deinit();

        var node_iter = self.nodes.keyIterator();
        while (node_iter.next()) |node_id| {
            try in_degree.put(node_id.*, 0);
        }

        var adj_iter = self.adjacency_list.iterator();
        while (adj_iter.next()) |entry| {
            for (entry.value_ptr.items) |neighbor| {
                const degree = in_degree.get(neighbor) orelse 0;
                try in_degree.put(neighbor, degree + 1);
            }
        }

        // Queue nodes with no incoming edges
        var queue = std.ArrayList([]const u8).fromOwnedSlice(&[_][]const u8{});
        defer queue.deinit(self.allocator);

        var degree_iter = in_degree.iterator();
        while (degree_iter.next()) |entry| {
            if (entry.value_ptr.* == 0) {
                try queue.append(self.allocator, entry.key_ptr.*);
            }
        }

        // Process queue
        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);
            try self.execution_order.append(self.allocator, current);

            if (self.adjacency_list.get(current)) |neighbors| {
                for (neighbors.items) |neighbor| {
                    const degree = in_degree.get(neighbor).?;
                    try in_degree.put(neighbor, degree - 1);
                    if (degree - 1 == 0) {
                        try queue.append(self.allocator, neighbor);
                    }
                }
            }
        }

        // Check for cycles
        if (self.execution_order.items.len != self.nodes.count()) {
            return error.GraphHasCycle;
        }
    }

    /// Validate the graph structure
    pub fn validate(self: *PricingGraph) !void {
        // Check that all referenced input nodes exist
        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            const node = entry.value_ptr;
            for (node.inputs) |input_id| {
                if (!self.nodes.contains(input_id)) {
                    std.debug.print("Node {s} references non-existent input {s}\n", .{ node.id, input_id });
                    return error.InvalidInputReference;
                }
            }
        }

        // Ensure graph is acyclic by performing topological sort
        try self.topologicalSort();
    }

    /// Get a node by ID
    pub fn getNode(self: *PricingGraph, id: []const u8) ?*PricingNode {
        return self.nodes.getPtr(id);
    }

    /// Get the execution order (must call topologicalSort first)
    pub fn getExecutionOrder(self: *PricingGraph) []const []const u8 {
        return self.execution_order.items;
    }
};

test "PricingGraph add nodes" {
    const allocator = std.testing.allocator;
    var graph = PricingGraph.init(allocator);
    defer graph.deinit();

    const node_a = try PricingNode.init(allocator, "A", .input);
    try graph.addNode(node_a);

    try std.testing.expect(graph.nodes.contains("A"));
}

test "PricingGraph topological sort simple" {
    const allocator = std.testing.allocator;
    var graph = PricingGraph.init(allocator);
    defer graph.deinit();

    // Create A -> B -> C
    const node_a = try PricingNode.init(allocator, "A", .input);
    var node_b = try PricingNode.init(allocator, "B", .add);
    var node_c = try PricingNode.init(allocator, "C", .multiply);

    // B depends on A
    node_b.inputs = try allocator.dupe([]const u8, &[_][]const u8{"A"});
    // C depends on B
    node_c.inputs = try allocator.dupe([]const u8, &[_][]const u8{"B"});

    try graph.addNode(node_a);
    try graph.addNode(node_b);
    try graph.addNode(node_c);

    try graph.topologicalSort();

    const order = graph.getExecutionOrder();
    try std.testing.expectEqual(@as(usize, 3), order.len);
    try std.testing.expectEqualStrings("A", order[0]);
    try std.testing.expectEqualStrings("B", order[1]);
    try std.testing.expectEqualStrings("C", order[2]);
}

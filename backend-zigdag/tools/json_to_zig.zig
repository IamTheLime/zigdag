const std = @import("std");

/// This build tool converts a JSON pricing model into compile-time Zig code
/// This allows the entire pricing model to be baked into the binary at compile time!
///
/// Usage: json_to_zig <input.json> <output.zig>
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <input.json> <output.zig>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_path = args[1];
    const output_path = args[2];

    // Read input JSON file
    const input_file = try std.fs.cwd().openFile(input_path, .{});
    defer input_file.close();

    const json_content = try input_file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(json_content);

    // Parse JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    const root = parsed.value;

    // Generate Zig code
    var output = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Write header
    try writer.writeAll(
        \\// AUTO-GENERATED FILE - DO NOT EDIT
        \\// Generated from dag_model.json
        \\// This file is generated at build time by tools/json_to_zig.zig
        \\
        \\const zigdag = @import("zigdag");
        \\const PricingNode = zigdag.node.PricingNode;
        \\const NodeOperation = zigdag.node.NodeOperation;
        \\const NodeMetadata = zigdag.node.PricingNode.NodeMetadata;
        \\
        \\/// Compile-time pricing nodes generated from JSON
        \\/// These are fully static and live in the .rodata section
        \\pub const nodes = &[_]PricingNode{
        \\
    );

    // Parse nodes array
    const nodes = root.object.get("nodes") orelse return error.NoNodesInJson;
    const nodes_array = nodes.array;

    for (nodes_array.items, 0..) |node_value, i| {
        const node = node_value.object;

        const id = node.get("id").?.string;
        const operation_str = node.get("operation").?.string;

        // Get metadata
        const metadata = if (node.get("metadata")) |m| m.object else null;
        const name = if (metadata) |m| if (m.get("name")) |n| n.string else id else id;
        const description = if (metadata) |m| if (m.get("description")) |d| d.string else "" else "";
        const position_x = if (metadata) |m| if (m.get("position_x")) |px| switch (px) {
            .float => |f| f,
            .integer => |int_val| @as(f64, @floatFromInt(int_val)),
            else => 0.0,
        } else 0.0 else 0.0;
        const position_y = if (metadata) |m| if (m.get("position_y")) |py| switch (py) {
            .float => |f| f,
            .integer => |int_val| @as(f64, @floatFromInt(int_val)),
            else => 0.0,
        } else 0.0 else 0.0;

        // Write node definition
        try writer.print("    .{{\n", .{});
        try writer.print("        .node_id = \"{s}\",\n", .{id});

        // Generate the typed operation union
        try writeOperation(writer, operation_str, node);

        // Write metadata
        try writer.writeAll("        .metadata = .{\n");
        try writer.print("            .name = \"{s}\",\n", .{name});
        try writer.print("            .description = \"{s}\",\n", .{description});
        try writer.print("            .position_x = {d},\n", .{position_x});
        try writer.print("            .position_y = {d},\n", .{position_y});
        try writer.writeAll("        },\n");

        try writer.writeAll("    }");

        if (i < nodes_array.items.len - 1) {
            try writer.writeAll(",\n");
        } else {
            try writer.writeAll("\n");
        }
    }

    // Write footer
    try writer.writeAll(
        \\};
        \\
    );

    // Write output file
    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    try output_file.writeAll(output.items);

    std.debug.print("✓ Generated {d} nodes from {s} -> {s}\n", .{ nodes_array.items.len, input_path, output_path });
}

fn writeOperation(writer: anytype, operation: []const u8, node: std.json.ObjectMap) !void {
    try writer.print("        .operation = .{{ .{s} = ", .{operation});

    if (std.mem.eql(u8, operation, "add") or
        std.mem.eql(u8, operation, "subtract") or
        std.mem.eql(u8, operation, "multiply") or
        std.mem.eql(u8, operation, "divide") or
        std.mem.eql(u8, operation, "power") or
        std.mem.eql(u8, operation, "modulo"))
    {
        // Binary operations
        const inputs = node.get("inputs").?.array.items;
        if (inputs.len != 2) return error.BinaryOpRequires2Inputs;
        try writer.print(".{{ .left_input_node_id = \"{s}\", .right_input_node_id = \"{s}\" }}", .{
            inputs[0].string,
            inputs[1].string,
        });
    } else if (std.mem.eql(u8, operation, "negate") or
        std.mem.eql(u8, operation, "abs") or
        std.mem.eql(u8, operation, "sqrt") or
        std.mem.eql(u8, operation, "exp") or
        std.mem.eql(u8, operation, "log") or
        std.mem.eql(u8, operation, "sin") or
        std.mem.eql(u8, operation, "cos") or
        std.mem.eql(u8, operation, "funnel"))
    {
        // Unary operations
        const inputs = node.get("inputs").?.array.items;
        if (inputs.len != 1) return error.UnaryOpRequires1Input;
        try writer.print(".{{ .input_node_id = \"{s}\" }}", .{inputs[0].string});
    } else if (std.mem.eql(u8, operation, "max") or std.mem.eql(u8, operation, "min")) {
        // Variadic operations
        const inputs = node.get("inputs").?.array.items;
        try writer.writeAll(".{ .node_input_ids = &.{");
        for (inputs, 0..) |input, j| {
            if (j > 0) try writer.writeAll(", ");
            try writer.print("\"{s}\"", .{input.string});
        }
        try writer.writeAll("} }");
    } else if (std.mem.eql(u8, operation, "weighted_sum")) {
        // Weighted sum
        const inputs = node.get("inputs").?.array.items;
        const weights = node.get("weights").?.array.items;
        try writer.writeAll(".{ .node_input_ids = &.{");
        for (inputs, 0..) |input, j| {
            if (j > 0) try writer.writeAll(", ");
            try writer.print("\"{s}\"", .{input.string});
        }
        try writer.writeAll("}, .weights = &.{");
        for (weights, 0..) |weight, j| {
            if (j > 0) try writer.writeAll(", ");
            const weight_val = switch (weight) {
                .float => |f| f,
                .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                else => 0.0,
            };
            try writer.print("{d}", .{weight_val});
        }
        try writer.writeAll("} }");
    } else if (std.mem.eql(u8, operation, "clamp")) {
        // Clamp
        const inputs = node.get("inputs").?.array.items;
        if (inputs.len != 3) return error.ClampRequires3Inputs;
        try writer.print(".{{ .value = \"{s}\", .min = \"{s}\", .max = \"{s}\" }}", .{
            inputs[0].string,
            inputs[1].string,
            inputs[2].string,
        });
    } else if (std.mem.eql(u8, operation, "conditional_value_input")) {
        // Conditional value input - maps string inputs to numeric outputs
        const inputs = if (node.get("inputs")) |inp| inp.array.items else &[_]std.json.Value{};
        const input_node = if (inputs.len > 0) inputs[0].string else "";

        // Parse conditional_values map
        try writer.print(".{{ .input_node = \"{s}\", .value_map = &.{{", .{input_node});

        if (node.get("conditional_values")) |cond_values| {
            const map = cond_values.object;
            var first = true;
            var it = map.iterator();
            while (it.next()) |entry| {
                if (!first) try writer.writeAll(", ");
                first = false;
                const value = switch (entry.value_ptr.*) {
                    .float => |f| f,
                    .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                    else => 0.0,
                };
                try writer.print(".{{ .key = \"{s}\", .value = {d} }}", .{ entry.key_ptr.*, value });
            }
        }

        try writer.writeAll("} }");
    } else if (std.mem.eql(u8, operation, "constant_input_num")) {
        // Constant numeric input
        const constant_value = if (node.get("constant_value")) |cv| switch (cv) {
            .float => |f| f,
            .integer => |int_val| @as(f64, @floatFromInt(int_val)),
            else => 0.0,
        } else 0.0;
        try writer.print(".{{ .value = {d} }}", .{constant_value});
    } else if (std.mem.eql(u8, operation, "constant_input_str")) {
        // Constant string input
        const constant_str_value = if (node.get("constant_str_value")) |cv| cv.string else "";
        try writer.print(".{{ .value = \"{s}\" }}", .{constant_str_value});
    } else if (std.mem.eql(u8, operation, "dynamic_input_num")) {
        // Dynamic numeric input
        const allowed_values = if (node.get("allowed_values")) |av| av.array.items else &[_]std.json.Value{};
        try writer.writeAll(".{ .allowed_values = &.{");
        for (allowed_values, 0..) |val, j| {
            if (j > 0) try writer.writeAll(", ");
            const allowed_val = switch (val) {
                .float => |f| f,
                .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                else => 0.0,
            };
            try writer.print("{d}", .{allowed_val});
        }
        try writer.writeAll("} }");
    } else if (std.mem.eql(u8, operation, "dynamic_input_str")) {
        // Dynamic string input
        try writer.writeAll(".{ .allowed_values = null }");
    } else {
        return error.UnknownOperation;
    }

    try writer.writeAll(" },\n");
}

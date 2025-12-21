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
        \\// Generated from pricing_model.json
        \\// This file is generated at build time by tools/json_to_zig.zig
        \\
        \\const openpricing = @import("openpricing");
        \\const ComptimeNode = openpricing.comptime_parser.ComptimeNode;
        \\
        \\/// Compile-time pricing nodes generated from JSON
        \\/// These are fully static and live in the .rodata section
        \\pub const nodes = &[_]ComptimeNode{
        \\
    );

    // Parse nodes array
    const nodes = root.object.get("nodes") orelse return error.NoNodesInJson;
    const nodes_array = nodes.array;

    for (nodes_array.items, 0..) |node_value, i| {
        const node = node_value.object;

        const id = node.get("id").?.string;
        const operation = node.get("operation").?.string;
        const constant_value = if (node.get("constant_value")) |cv| blk: {
            break :blk switch (cv) {
                .float => |f| f,
                .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                else => 0.0,
            };
        } else 0.0;
        const constant_str_value = if (node.get("constant_str_value")) |cv| cv.string else "";

        // Get inputs array
        const inputs = if (node.get("inputs")) |inp| inp.array.items else &[_]std.json.Value{};

        // Get weights array (for weighted_sum)
        const weights = if (node.get("weights")) |w| w.array.items else &[_]std.json.Value{};

        // Get allowed_values (for dynamic inputs)
        const allowed_values = if (node.get("allowed_values")) |av| av.array.items else &[_]std.json.Value{};

        // Get metadata
        const metadata = if (node.get("metadata")) |m| m.object else null;
        const name = if (metadata) |m| if (m.get("name")) |n| n.string else id else id;
        const description = if (metadata) |m| if (m.get("description")) |d| d.string else "" else "";

        // Write node definition
        try writer.print("    .{{\n", .{});
        try writer.print("        .id = \"{s}\",\n", .{id});
        try writer.print("        .operation = .{s},\n", .{operation});
        try writer.print("        .constant_value = {d},\n", .{constant_value});
        try writer.print("        .constant_str_value = \"{s}\",\n", .{constant_str_value});

        // Write inputs array
        try writer.writeAll("        .inputs = &.{");
        if (inputs.len > 0) {
            for (inputs, 0..) |input, j| {
                if (j > 0) try writer.writeAll(", ");
                try writer.print("\"{s}\"", .{input.string});
            }
        }
        try writer.writeAll("},\n");

        // Write weights array
        try writer.writeAll("        .weights = &.{");
        if (weights.len > 0) {
            for (weights, 0..) |weight, j| {
                if (j > 0) try writer.writeAll(", ");
                const weight_val = switch (weight) {
                    .float => |f| f,
                    .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                    else => 0.0,
                };
                try writer.print("{d}", .{weight_val});
            }
        }
        try writer.writeAll("},\n");

        // Write allowed_values array
        try writer.writeAll("        .allowed_values = &.{");
        if (allowed_values.len > 0) {
            for (allowed_values, 0..) |val, j| {
                if (j > 0) try writer.writeAll(", ");
                const allowed_val = switch (val) {
                    .float => |f| f,
                    .integer => |int_val| @as(f64, @floatFromInt(int_val)),
                    else => 0.0,
                };
                try writer.print("{d}", .{allowed_val});
            }
        }
        try writer.writeAll("},\n");

        try writer.print("        .name = \"{s}\",\n", .{name});
        try writer.print("        .description = \"{s}\",\n", .{description});
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

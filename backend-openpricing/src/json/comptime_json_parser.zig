const std = @import("std");
const node_module = @import("../core/node.zig");
const OperationType = node_module.OperationType;
const ComptimeNode = @import("comptime_parser.zig").ComptimeNode;

/// Parse a JSON pricing model at compile-time using @embedFile
/// This reads the JSON file at compile-time and produces a fully static node array
///
/// Usage:
/// ```zig
/// const nodes = parseComptimeJSON(@embedFile("../../models/pricing_model.json"));
/// const Executor = openpricing.ComptimeExecutorFromNodes(nodes);
/// ```
///
/// Benefits:
/// - No runtime JSON parsing
/// - No heap allocations
/// - Single-step compilation
/// - JSON remains source of truth for frontend
/// - Compile-time validation of your JSON structure
pub fn parseComptimeJSON(comptime json_content: []const u8) []const ComptimeNode {
    // Use std.json.parseFromSliceLeaky which works at comptime
    const parsed = std.json.parseFromSliceLeaky(
        std.json.Value,
        std.testing.allocator, // At comptime, this becomes a comptime allocator
        json_content,
        .{},
    ) catch @compileError("Failed to parse JSON at compile-time. Check JSON syntax.");

    const root = parsed;
    const nodes_value = root.object.get("nodes") orelse @compileError("No 'nodes' field in JSON root object");
    const nodes_array = nodes_value.array;

    // Build result array at compile-time
    comptime var result: []const ComptimeNode = &.{};

    inline for (nodes_array.items) |node_value| {
        const node_obj = node_value.object;

        // Extract required fields
        const id = node_obj.get("id") orelse @compileError("Node missing 'id' field");
        const operation_str = node_obj.get("operation") orelse @compileError("Node missing 'operation' field");

        const id_str = switch (id.*) {
            .string => |s| s,
            else => @compileError("Node 'id' must be a string"),
        };

        const op_str = switch (operation_str.*) {
            .string => |s| s,
            else => @compileError("Node 'operation' must be a string"),
        };

        // Parse operation type
        const operation = parseOperation(op_str);

        // Extract optional constant_value
        const constant_value: f64 = if (node_obj.get("constant_value")) |cv|
            switch (cv.*) {
                .float => |f| f,
                .integer => |int| @floatFromInt(int),
                else => 0.0,
            }
        else
            0.0;

        // Extract inputs array
        comptime var inputs: []const []const u8 = &.{};
        if (node_obj.get("inputs")) |inputs_val| {
            const inputs_arr = switch (inputs_val.*) {
                .array => |a| a,
                else => @compileError("'inputs' must be an array"),
            };

            for (inputs_arr.items) |input_val| {
                const input_str = switch (input_val) {
                    .string => |s| s,
                    else => @compileError("Input must be a string"),
                };
                inputs = inputs ++ &[_][]const u8{input_str};
            }
        }

        // Extract weights array
        comptime var weights: []const f64 = &.{};
        if (node_obj.get("weights")) |weights_val| {
            const weights_arr = switch (weights_val.*) {
                .array => |a| a,
                else => @compileError("'weights' must be an array"),
            };

            for (weights_arr.items) |weight_val| {
                const weight_num: f64 = switch (weight_val) {
                    .float => |f| f,
                    .integer => |int| @floatFromInt(int),
                    else => @compileError("Weight must be a number"),
                };
                weights = weights ++ &[_]f64{weight_num};
            }
        }

        // Extract metadata
        var name: []const u8 = id_str;
        var description: []const u8 = "";

        if (node_obj.get("metadata")) |metadata_val| {
            const metadata_obj = switch (metadata_val.*) {
                .object => |o| o,
                else => @compileError("'metadata' must be an object"),
            };

            if (metadata_obj.get("name")) |name_val| {
                name = switch (name_val.*) {
                    .string => |s| s,
                    else => id_str,
                };
            }

            if (metadata_obj.get("description")) |desc_val| {
                description = switch (desc_val.*) {
                    .string => |s| s,
                    else => "",
                };
            }
        }

        // Build the ComptimeNode
        const node = ComptimeNode{
            .id = id_str,
            .operation = operation,
            .inputs = inputs,
            .weights = weights,
            .constant_value = constant_value,
            .name = name,
            .description = description,
        };

        result = result ++ &[_]ComptimeNode{node};
    }

    return result;
}

/// Helper to parse operation string to enum at compile-time
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

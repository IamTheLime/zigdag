//! OpenPricing - High-performance SIMD-accelerated pricing engine
//!
//! This library provides a node-based pricing system that can execute
//! complex pricing calculations using topologically sorted DAGs and
//! SIMD vectorization for maximum performance.

const std = @import("std");

// Re-export all public modules
pub const node = @import("core/node.zig");
pub const graph = @import("graph/pricing_graph.zig");
pub const executor = @import("simd/executor.zig");
pub const parser = @import("json/parser.zig");
pub const comptime_parser = @import("json/comptime_parser.zig");
pub const comptime_builder = @import("json/comptime_builder.zig");
pub const comptime_json_parser = @import("json/comptime_json_parser.zig");
pub const comptime_executor = @import("simd/comptime_executor.zig");

// Re-export commonly used types
pub const PricingNode = node.PricingNode;
pub const OperationType = node.OperationType;
pub const PricingGraph = graph.PricingGraph;
pub const ExecutionContext = executor.ExecutionContext;
pub const ScalarExecutionContext = executor.ScalarExecutionContext;
pub const GraphParser = parser.GraphParser;

// Compile-time optimized types
pub const ComptimeExecutorFromNodes = comptime_executor.ComptimeExecutorFromNodes;
pub const ComptimeNode = comptime_parser.ComptimeNode;
pub const defineComptimeNodes = comptime_parser.defineComptimeNodes;
pub const parseComptimeJSON = comptime_json_parser.parseComptimeJSON;

test {
    // Run all tests from submodules
    std.testing.refAllDecls(@This());
}

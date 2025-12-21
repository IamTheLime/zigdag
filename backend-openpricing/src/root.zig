//! OpenPricing - Compile-time pricing engine
//!
//! A pricing calculation engine that turns JSON graph definitions into
//! native machine code at compile time with zero runtime overhead.

const std = @import("std");

// Core modules
pub const node = @import("core/node.zig");
pub const comptime_parser = @import("json/comptime_parser.zig");
pub const comptime_executor = @import("simd/comptime_executor.zig");

// Main API
pub const ComptimeExecutorFromNodes = comptime_executor.ComptimeExecutorFromNodes;
pub const ComptimeNode = comptime_parser.ComptimeNode;
pub const OperationType = node.OperationType;

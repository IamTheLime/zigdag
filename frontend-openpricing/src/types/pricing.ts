/**
 * TypeScript types for OpenPricing
 * These mirror the Zig backend structures
 */

export type OperationType =
  // Binary operations
  | 'add'
  | 'subtract'
  | 'multiply'
  | 'divide'
  | 'power'
  | 'modulo'
  // Unary operations
  | 'negate'
  | 'abs'
  | 'sqrt'
  | 'exp'
  | 'log'
  | 'sin'
  | 'cos'
  // Special operations
  | 'weighted_sum'
  | 'max'
  | 'min'
  | 'clamp'
  // Input/constant nodes
  | 'input'
  | 'constant';

export interface NodeMetadata {
  name: string;
  description: string;
  position_x: number;
  position_y: number;
}

export interface PricingNode {
  id: string;
  operation: OperationType;
  weights: number[];
  constant_value: number;
  inputs: string[];
  metadata: NodeMetadata;
}

export interface PricingGraph {
  nodes: PricingNode[];
}

export interface ExecutionResult {
  value: number;
  execution_time_ms?: number;
}

/**
 * FFI bindings to the Zig backend
 */
export interface OpenPricingFFI {
  /**
   * Create a pricing graph from JSON
   */
  createGraph(json: string): Promise<number>; // Returns handle

  /**
   * Free a pricing graph
   */
  freeGraph(handle: number): void;

  /**
   * Create an execution context
   */
  createContext(graphHandle: number): Promise<number>; // Returns handle

  /**
   * Free an execution context
   */
  freeContext(handle: number): void;

  /**
   * Set an input value
   */
  setInput(contextHandle: number, nodeId: string, value: number): void;

  /**
   * Execute the pricing calculation
   */
  execute(contextHandle: number, outputNodeId: string): Promise<number>;

  /**
   * Validate a JSON graph definition
   */
  validateJson(json: string): Promise<boolean>;
}

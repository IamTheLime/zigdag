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
  | 'funnel'
  // Input/constant nodes
  | 'dynamic_input_num'
  | 'dynamic_input_str'
  | 'constant_input_num'
  | 'constant_input_str'
  | 'conditional_value_input';

export interface NodeMetadata {
  name: string;
  description: string;
  position_x: number;
  position_y: number;
}

export interface ConditionalValueMap {
  [key: string]: number;
}

export interface PricingNode {
  id: string;
  operation: OperationType;
  weights: number[];
  constant_value: number;
  constant_str_value?: string;
  allowed_values?: number[];
  allowed_str_values?: string[];
  conditional_values?: ConditionalValueMap;
  inputs: string[];
  metadata: NodeMetadata;
}

/**
 * Node configuration for different operation types
 */
export interface NodeConfig {
  operation: OperationType;
  label: string;
  description: string;
  category: 'input' | 'constant' | 'binary' | 'unary' | 'variadic';
  inputCount: number | 'variable'; // Expected number of inputs
  hasValue?: boolean; // Whether it has a constant_value
  hasWeights?: boolean; // Whether it uses weights
  hasAllowedValues?: boolean; // Whether it has allowed_values (numeric)
  hasAllowedStrValues?: boolean; // Whether it has allowed_str_values (string)
  hasConditionalValues?: boolean; // Whether it has conditional_values
  color: string; // Node color in UI
  icon?: string; // Optional icon
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

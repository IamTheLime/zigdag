import type { NodeConfig, OperationType } from '../types/pricing';

/**
 * Complete node definitions for OpenPricing
 * These define how each node type behaves and appears in the UI
 */
export const NODE_DEFINITIONS: Record<OperationType, NodeConfig> = {
  // Dynamic Inputs - Runtime user values
  dynamic_input_num: {
    operation: 'dynamic_input_num',
    label: 'Dynamic Input (Number)',
    description: 'User-provided numeric input at runtime',
    category: 'input',
    inputCount: 0,
    hasAllowedValues: true,
    color: '#4CAF50',
    icon: '📥',
  },
  dynamic_input_str: {
    operation: 'dynamic_input_str',
    label: 'Dynamic Input (String)',
    description: 'User-provided string input at runtime',
    category: 'input',
    inputCount: 0,
    hasAllowedValues: true,
    color: '#66BB6A',
    icon: '📝',
  },

  // Constants - Compile-time values
  constant_input_num: {
    operation: 'constant_input_num',
    label: 'Constant (Number)',
    description: 'Hardcoded numeric value',
    category: 'constant',
    inputCount: 0,
    hasValue: true,
    color: '#9C27B0',
    icon: '🔢',
  },
  constant_input_str: {
    operation: 'constant_input_str',
    label: 'Constant (String)',
    description: 'Hardcoded string value',
    category: 'constant',
    inputCount: 0,
    hasValue: true,
    color: '#AB47BC',
    icon: '📋',
  },

  // Conditional Input
  conditional_value_input: {
    operation: 'conditional_value_input',
    label: 'Conditional Value',
    description: 'Maps input values to outputs',
    category: 'input',
    inputCount: 1,
    color: '#FF9800',
    icon: '🔀',
  },

  // Binary Operations
  add: {
    operation: 'add',
    label: 'Add',
    description: 'Addition (a + b)',
    category: 'binary',
    inputCount: 2,
    color: '#2196F3',
    icon: '➕',
  },
  subtract: {
    operation: 'subtract',
    label: 'Subtract',
    description: 'Subtraction (a - b)',
    category: 'binary',
    inputCount: 2,
    color: '#2196F3',
    icon: '➖',
  },
  multiply: {
    operation: 'multiply',
    label: 'Multiply',
    description: 'Multiplication (a × b)',
    category: 'binary',
    inputCount: 2,
    color: '#2196F3',
    icon: '✖️',
  },
  divide: {
    operation: 'divide',
    label: 'Divide',
    description: 'Division (a ÷ b)',
    category: 'binary',
    inputCount: 2,
    color: '#2196F3',
    icon: '➗',
  },
  power: {
    operation: 'power',
    label: 'Power',
    description: 'Exponentiation (a ^ b)',
    category: 'binary',
    inputCount: 2,
    color: '#2196F3',
    icon: '🔺',
  },
  modulo: {
    operation: 'modulo',
    label: 'Modulo',
    description: 'Modulo (a % b)',
    category: 'binary',
    inputCount: 2,
    color: '#2196F3',
    icon: '%',
  },

  // Unary Operations
  negate: {
    operation: 'negate',
    label: 'Negate',
    description: 'Negation (-a)',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: '−',
  },
  abs: {
    operation: 'abs',
    label: 'Absolute',
    description: 'Absolute value |a|',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: '||',
  },
  sqrt: {
    operation: 'sqrt',
    label: 'Square Root',
    description: 'Square root √a',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: '√',
  },
  exp: {
    operation: 'exp',
    label: 'Exponential',
    description: 'Exponential (e^x)',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: 'e^',
  },
  log: {
    operation: 'log',
    label: 'Logarithm',
    description: 'Natural log ln(a)',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: 'ln',
  },
  sin: {
    operation: 'sin',
    label: 'Sine',
    description: 'Sine function sin(a)',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: '∿',
  },
  cos: {
    operation: 'cos',
    label: 'Cosine',
    description: 'Cosine function cos(a)',
    category: 'unary',
    inputCount: 1,
    color: '#03A9F4',
    icon: '∿',
  },

  // Variadic Operations
  max: {
    operation: 'max',
    label: 'Maximum',
    description: 'Maximum of inputs',
    category: 'variadic',
    inputCount: 'variable',
    color: '#FF5722',
    icon: '⬆️',
  },
  min: {
    operation: 'min',
    label: 'Minimum',
    description: 'Minimum of inputs',
    category: 'variadic',
    inputCount: 'variable',
    color: '#FF5722',
    icon: '⬇️',
  },
  weighted_sum: {
    operation: 'weighted_sum',
    label: 'Weighted Sum',
    description: 'Sum with weights',
    category: 'variadic',
    inputCount: 'variable',
    hasWeights: true,
    color: '#FF5722',
    icon: '∑',
  },
  clamp: {
    operation: 'clamp',
    label: 'Clamp',
    description: 'Clamp value between min and max',
    category: 'variadic',
    inputCount: 3,
    color: '#FF5722',
    icon: '⊣⊢',
  },
};

/**
 * Get node definition by operation type
 */
export function getNodeDefinition(operation: OperationType): NodeConfig {
  return NODE_DEFINITIONS[operation];
}

/**
 * Get all nodes in a category
 */
export function getNodesByCategory(category: NodeConfig['category']): NodeConfig[] {
  return Object.values(NODE_DEFINITIONS).filter((def) => def.category === category);
}

/**
 * Node categories for the palette
 */
export const NODE_CATEGORIES = [
  { id: 'input', label: 'Inputs', color: '#4CAF50' },
  { id: 'constant', label: 'Constants', color: '#9C27B0' },
  { id: 'binary', label: 'Binary Ops', color: '#2196F3' },
  { id: 'unary', label: 'Unary Ops', color: '#03A9F4' },
  { id: 'variadic', label: 'Advanced', color: '#FF5722' },
] as const;

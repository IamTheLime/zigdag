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
    category: 'common',
    inputCount: 0,
    hasAllowedValues: true,
    color: '#a7f3d0',
    icon: 'arrow-down-to-bracket',
  },
  dynamic_input_str: {
    operation: 'dynamic_input_str',
    label: 'Dynamic Input (String)',
    description: 'User-provided string input at runtime',
    category: 'common',
    inputCount: 0,
    hasAllowedStrValues: true,
    color: '#bfdbfe',
    icon: 'keyboard',
  },

  // Constants - Compile-time values
  constant_input_num: {
    operation: 'constant_input_num',
    label: 'Constant (Number)',
    description: 'Hardcoded numeric value',
    category: 'common',
    inputCount: 0,
    hasValue: true,
    color: '#e9d5ff',
    icon: 'hashtag',
  },
  constant_input_str: {
    operation: 'constant_input_str',
    label: 'Constant (String)',
    description: 'Hardcoded string value',
    category: 'common',
    inputCount: 0,
    hasValue: true,
    color: '#ddd6fe',
    icon: 'quote-left',
  },

  // Conditional Value (Unary Operation)
  conditional_value_input: {
    operation: 'conditional_value_input',
    label: 'Conditional Value',
    description: 'Maps string input to numeric output',
    category: 'unary',
    inputCount: 1,
    hasConditionalValues: true,
    color: '#fed7aa',
    icon: 'code-branch',
  },

  // Binary Operations
  add: {
    operation: 'add',
    label: 'Add',
    description: 'Addition (a + b)',
    category: 'binary',
    inputCount: 2,
    color: '#93c5fd',
    icon: 'plus',
  },
  subtract: {
    operation: 'subtract',
    label: 'Subtract',
    description: 'Subtraction (a - b)',
    category: 'binary',
    inputCount: 2,
    color: '#bae6fd',
    icon: 'minus',
  },
  multiply: {
    operation: 'multiply',
    label: 'Multiply',
    description: 'Multiplication (a × b)',
    category: 'binary',
    inputCount: 2,
    color: '#a5b4fc',
    icon: 'xmark',
  },
  divide: {
    operation: 'divide',
    label: 'Divide',
    description: 'Division (a ÷ b)',
    category: 'binary',
    inputCount: 2,
    color: '#c7d2fe',
    icon: 'divide',
  },
  power: {
    operation: 'power',
    label: 'Power',
    description: 'Exponentiation (a ^ b)',
    category: 'binary',
    inputCount: 2,
    color: '#a5f3fc',
    icon: 'superscript',
  },
  modulo: {
    operation: 'modulo',
    label: 'Modulo',
    description: 'Modulo (a % b)',
    category: 'binary',
    inputCount: 2,
    color: '#99f6e4',
    icon: 'percent',
  },

  // Unary Operations
  negate: {
    operation: 'negate',
    label: 'Negate',
    description: 'Negation (-a)',
    category: 'unary',
    inputCount: 1,
    color: '#fecaca',
    icon: 'minus',
  },
  abs: {
    operation: 'abs',
    label: 'Absolute',
    description: 'Absolute value |a|',
    category: 'unary',
    inputCount: 1,
    color: '#fca5a5',
    icon: 'bars',
  },
  sqrt: {
    operation: 'sqrt',
    label: 'Square Root',
    description: 'Square root √a',
    category: 'unary',
    inputCount: 1,
    color: '#fdba74',
    icon: 'square-root-variable',
  },
  exp: {
    operation: 'exp',
    label: 'Exponential',
    description: 'Exponential (e^x)',
    category: 'unary',
    inputCount: 1,
    color: '#fcd34d',
    icon: 'chart-line',
  },
  log: {
    operation: 'log',
    label: 'Logarithm',
    description: 'Natural log ln(a)',
    category: 'unary',
    inputCount: 1,
    color: '#fde047',
    icon: 'chart-line',
  },
  sin: {
    operation: 'sin',
    label: 'Sine',
    description: 'Sine function sin(a)',
    category: 'unary',
    inputCount: 1,
    color: '#fef08a',
    icon: 'wave-square',
  },
  cos: {
    operation: 'cos',
    label: 'Cosine',
    description: 'Cosine function cos(a)',
    category: 'unary',
    inputCount: 1,
    color: '#fef3c7',
    icon: 'wave-square',
  },

  // Variadic Operations
  max: {
    operation: 'max',
    label: 'Maximum',
    description: 'Maximum of inputs',
    category: 'variadic',
    inputCount: 'variable',
    color: '#f9a8d4',
    icon: 'arrow-up',
  },
  min: {
    operation: 'min',
    label: 'Minimum',
    description: 'Minimum of inputs',
    category: 'variadic',
    inputCount: 'variable',
    color: '#fbcfe8',
    icon: 'arrow-down',
  },
  weighted_sum: {
    operation: 'weighted_sum',
    label: 'Weighted Sum',
    description: 'Sum with weights',
    category: 'variadic',
    inputCount: 'variable',
    hasWeights: true,
    color: '#fbbf24',
    icon: 'sigma',
  },
  clamp: {
    operation: 'clamp',
    label: 'Clamp',
    description: 'Clamp value between min and max',
    category: 'variadic',
    inputCount: 3,
    color: '#fde68a',
    icon: 'arrows-left-right',
  },
  funnel: {
    operation: 'funnel',
    label: 'Final Output',
    description: 'Marks the final output of the pricing model',
    category: 'common',
    inputCount: 1,
    color: '#fca5a5',
    icon: 'bullseye',
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
  { id: 'common', label: 'Common', color: '#a7f3d0' },
  { id: 'binary', label: 'Binary Operations', color: '#93c5fd' },
  { id: 'unary', label: 'Unary Operations', color: '#fcd34d' },
  { id: 'variadic', label: 'Advanced', color: '#f9a8d4' },
] as const;

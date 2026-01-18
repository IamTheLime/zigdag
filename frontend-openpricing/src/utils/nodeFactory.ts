import type { Node } from 'reactflow';
import type { OperationType } from '../types/pricing';
import { getNodeDefinition } from '../config/nodeDefinitions';

let nodeCounter = 0;

/**
 * Generate a unique node ID
 */
export function generateNodeId(operation: OperationType): string {
  nodeCounter++;
  return `${operation}_${nodeCounter}`;
}

/**
 * Create a new node with proper configuration
 */
export function createNode(
  operation: OperationType,
  position: { x: number; y: number }
): Node {
  const def = getNodeDefinition(operation);
  const id = generateNodeId(operation);

  return {
    id,
    type: 'custom',
    position,
    data: {
      operation,
      label: def.label,
      description: def.description,
      category: def.category,
      color: def.color,
      icon: def.icon,
      inputCount: def.inputCount,
      hasValue: def.hasValue,
      hasWeights: def.hasWeights,
      hasAllowedValues: def.hasAllowedValues,
      hasAllowedStrValues: def.hasAllowedStrValues,
      hasConditionalValues: def.hasConditionalValues,
      // Default values
      value: def.hasValue ? 0.0 : undefined,
      stringValue: undefined,
      allowedValues: def.hasAllowedValues ? [] : undefined,
      allowedStrValues: def.hasAllowedStrValues ? [] : undefined,
      conditionalValues: def.hasConditionalValues ? {} : undefined,
      weights: def.hasWeights ? [] : undefined,
    },
  };
}

/**
 * Validate node connections
 */
export function canConnect(
  _sourceOperation: OperationType,
  targetOperation: OperationType,
  currentInputCount: number
): { valid: boolean; reason?: string } {
  const targetDef = getNodeDefinition(targetOperation);

  // Common nodes with no inputs (inputCount === 0) cannot have incoming connections
  if (targetDef.inputCount === 0) {
    return { valid: false, reason: 'This node cannot have incoming connections' };
  }

  // Check if we've exceeded the input count
  if (typeof targetDef.inputCount === 'number') {
    if (currentInputCount >= targetDef.inputCount) {
      return {
        valid: false,
        reason: `This node accepts max ${targetDef.inputCount} input(s)`,
      };
    }
  }

  return { valid: true };
}

/**
 * Get the number of expected inputs for a node
 */
export function getExpectedInputCount(operation: OperationType): number | 'variable' {
  const def = getNodeDefinition(operation);
  return def.inputCount;
}

/**
 * Check if a node is a source node (has no dependencies/inputs)
 */
export function isSourceNode(operation: OperationType): boolean {
  const def = getNodeDefinition(operation);
  return def.inputCount === 0;
}

/**
 * Get handle positions for a node based on its type
 */
export function getHandleConfig(operation: OperationType): {
  hasSource: boolean;
  hasTarget: boolean;
  targetCount: number | 'variable';
} {
  const def = getNodeDefinition(operation);

  return {
    hasSource: true, // All nodes can output
    hasTarget: def.inputCount !== 0, // Only nodes with inputs can have targets
    targetCount: def.inputCount,
  };
}

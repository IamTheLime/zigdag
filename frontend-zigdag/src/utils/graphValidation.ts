import type { Node, Edge } from 'reactflow';

export interface GraphIsland {
  id: number;
  nodeIds: string[];
  color: string;
}

export interface GraphValidation {
  isValid: boolean;
  isFullyConnected: boolean;
  hasFunnelNode: boolean;
  islands: GraphIsland[];
  issues: string[];
}

const ISLAND_COLORS = [
  '#93c5fd', // blue
  '#a7f3d0', // green
  '#fca5a5', // red
  '#fde047', // yellow
  '#c7d2fe', // purple
  '#fdba74', // orange
  '#fbcfe8', // pink
  '#a5f3fc', // cyan
];

/**
 * Detect separate graph islands using union-find algorithm
 */
function findGraphIslands(nodes: Node[], edges: Edge[]): GraphIsland[] {
  if (nodes.length === 0) return [];

  // Build adjacency map (treating graph as undirected for connectivity)
  const adjacency = new Map<string, Set<string>>();
  nodes.forEach(node => {
    adjacency.set(node.id, new Set());
  });

  edges.forEach(edge => {
    adjacency.get(edge.source)?.add(edge.target);
    adjacency.get(edge.target)?.add(edge.source);
  });

  // Find connected components using DFS
  const visited = new Set<string>();
  const islands: GraphIsland[] = [];

  function dfs(nodeId: string, island: string[]) {
    if (visited.has(nodeId)) return;
    visited.add(nodeId);
    island.push(nodeId);

    adjacency.get(nodeId)?.forEach(neighbor => {
      dfs(neighbor, island);
    });
  }

  nodes.forEach(node => {
    if (!visited.has(node.id)) {
      const island: string[] = [];
      dfs(node.id, island);
      islands.push({
        id: islands.length,
        nodeIds: island,
        color: ISLAND_COLORS[islands.length % ISLAND_COLORS.length],
      });
    }
  });

  return islands;
}

/**
 * Validate the pricing graph
 */
export function validateGraph(nodes: Node[], edges: Edge[]): GraphValidation {
  const issues: string[] = [];
  
  // Check if there's at least one node
  if (nodes.length === 0) {
    return {
      isValid: false,
      isFullyConnected: false,
      hasFunnelNode: false,
      islands: [],
      issues: ['Graph has no nodes'],
    };
  }

  // Find graph islands
  const islands = findGraphIslands(nodes, edges);
  const isFullyConnected = islands.length === 1;

  // Check for funnel node (final output)
  const hasFunnelNode = nodes.some(node => node.data.operation === 'funnel');

  // Validate connectivity
  if (!isFullyConnected) {
    issues.push(`Graph has ${islands.length} disconnected components`);
  }

  // Check for funnel node
  if (!hasFunnelNode) {
    issues.push('Missing final output node (funnel)');
  }

  // Check for isolated nodes (nodes with no connections)
  const isolatedNodes = nodes.filter(node => {
    const hasIncoming = edges.some(edge => edge.target === node.id);
    const hasOutgoing = edges.some(edge => edge.source === node.id);
    const requiresInput = node.data.inputCount !== 0;
    
    // Source nodes (inputs/constants) are OK without incoming edges
    if (!requiresInput && hasOutgoing) return false;
    
    // Other nodes need at least one connection
    return !hasIncoming && !hasOutgoing;
  });

  if (isolatedNodes.length > 0) {
    issues.push(`${isolatedNodes.length} isolated node(s)`);
  }

  const isValid = isFullyConnected && hasFunnelNode && isolatedNodes.length === 0;

  return {
    isValid,
    isFullyConnected,
    hasFunnelNode,
    islands,
    issues,
  };
}

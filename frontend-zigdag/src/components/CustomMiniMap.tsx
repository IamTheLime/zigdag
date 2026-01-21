import { memo } from 'react';
import { useStore, getRectOfNodes, getTransformForBounds } from 'reactflow';
import type { Node, Edge } from 'reactflow';

interface CustomMiniMapProps {
  nodeColor?: (node: Node) => string;
  maskColor?: string;
  nodeStrokeWidth?: number;
}

const MINIMAP_WIDTH = 200;
const MINIMAP_HEIGHT = 150;

function CustomMiniMap({ 
  nodeColor = () => 'hsl(var(--primary))',
  maskColor = 'hsl(var(--background) / 0.8)',
  nodeStrokeWidth = 2 
}: CustomMiniMapProps) {
  const nodes = useStore((state) => Array.from(state.nodeInternals.values()));
  const edges = useStore((state) => Array.from(state.edges.values()));
  const transform = useStore((state) => state.transform);
  const width = useStore((state) => state.width);
  const height = useStore((state) => state.height);

  if (nodes.length === 0) {
    return null;
  }

  const nodeRect = getRectOfNodes(nodes);
  const viewBBox = {
    x: -transform[0] / transform[2],
    y: -transform[1] / transform[2],
    width: width / transform[2],
    height: height / transform[2],
  };

  const boundingRect = {
    x: Math.min(nodeRect.x, viewBBox.x),
    y: Math.min(nodeRect.y, viewBBox.y),
    width: Math.max(nodeRect.x + nodeRect.width, viewBBox.x + viewBBox.width) - Math.min(nodeRect.x, viewBBox.x),
    height: Math.max(nodeRect.y + nodeRect.height, viewBBox.y + viewBBox.height) - Math.min(nodeRect.y, viewBBox.y),
  };

  const scaledTransform = getTransformForBounds(
    boundingRect,
    MINIMAP_WIDTH,
    MINIMAP_HEIGHT,
    0.05,
    0.5,
    0.2
  );

  const scale = scaledTransform[2];
  const offsetX = scaledTransform[0];
  const offsetY = scaledTransform[1];

  return (
    <div 
      className="react-flow__minimap"
      style={{
        position: 'absolute',
        bottom: 10,
        right: 10,
        zIndex: 5,
        width: MINIMAP_WIDTH,
        height: MINIMAP_HEIGHT,
      }}
    >
      <svg
        width={MINIMAP_WIDTH}
        height={MINIMAP_HEIGHT}
        viewBox={`0 0 ${MINIMAP_WIDTH} ${MINIMAP_HEIGHT}`}
        style={{
          display: 'block',
          width: '100%',
          height: '100%',
        }}
      >
        {/* Render edges */}
        <g transform={`translate(${offsetX}, ${offsetY}) scale(${scale})`}>
          {edges.map((edge: Edge) => {
            const sourceNode = nodes.find((n: Node) => n.id === edge.source);
            const targetNode = nodes.find((n: Node) => n.id === edge.target);
            
            if (!sourceNode || !targetNode) return null;

            const sourceX = sourceNode.position.x + (sourceNode.width || 0) / 2;
            const sourceY = sourceNode.position.y + (sourceNode.height || 0) / 2;
            const targetX = targetNode.position.x + (targetNode.width || 0) / 2;
            const targetY = targetNode.position.y + (targetNode.height || 0) / 2;

            return (
              <line
                key={edge.id}
                x1={sourceX}
                y1={sourceY}
                x2={targetX}
                y2={targetY}
                stroke="hsl(var(--primary))"
                strokeWidth={2 / scale}
                strokeOpacity={0.6}
                strokeLinecap="round"
              />
            );
          })}

          {/* Render nodes */}
          {nodes.map((node: Node) => {
            const x = node.position.x;
            const y = node.position.y;
            const w = node.width || 100;
            const h = node.height || 50;
            const color = typeof nodeColor === 'function' ? nodeColor(node) : nodeColor;

            return (
              <rect
                key={node.id}
                x={x}
                y={y}
                width={w}
                height={h}
                fill={color}
                stroke="hsl(var(--border))"
                strokeWidth={nodeStrokeWidth / scale}
                rx={4}
              />
            );
          })}
        </g>

        {/* Viewport mask */}
        <rect
          x={offsetX + viewBBox.x * scale}
          y={offsetY + viewBBox.y * scale}
          width={viewBBox.width * scale}
          height={viewBBox.height * scale}
          fill={maskColor}
          stroke="hsl(var(--primary))"
          strokeWidth={2}
          rx={2}
        />
      </svg>
    </div>
  );
}

export default memo(CustomMiniMap);

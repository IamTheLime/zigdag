import { useCallback } from 'react';
import {
  getBezierPath,
  EdgeProps,
  EdgeLabelRenderer,
  BaseEdge,
  useReactFlow,
} from 'reactflow';
import { X } from 'lucide-react';

export default function CustomEdge({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  style = {},
  markerEnd,
}: EdgeProps) {
  const { setEdges } = useReactFlow();

  const [edgePath, labelX, labelY] = getBezierPath({
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition,
  });

  const onEdgeClick = useCallback(() => {
    setEdges((edges) => edges.filter((edge) => edge.id !== id));
  }, [id, setEdges]);

  return (
    <>
      {/* Invisible wider path for easier clicking */}
      <path
        d={edgePath}
        fill="none"
        stroke="transparent"
        strokeWidth={20}
        className="cursor-pointer"
        onClick={onEdgeClick}
      />
      
      {/* Visible edge */}
      <BaseEdge
        path={edgePath}
        markerEnd={markerEnd}
        style={{
          ...style,
          strokeWidth: 2,
          stroke: 'hsl(var(--primary))',
          strokeDasharray: '5,5',
          animation: 'dashdraw 0.5s linear infinite',
          pointerEvents: 'none',
        }}
      />
      
      <EdgeLabelRenderer>
        <div
          style={{
            position: 'absolute',
            transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
            pointerEvents: 'all',
          }}
          className="nodrag nopan"
        >
          <button
            onClick={onEdgeClick}
            className="h-5 w-5 bg-muted border border-border flex items-center justify-center hover:border-red-500 transition-colors group shadow-lg"
          >
            <X className="h-3 w-3 text-red-300 group-hover:text-red-500" />
          </button>
        </div>
      </EdgeLabelRenderer>

      <style>{`
        @keyframes dashdraw {
          to {
            stroke-dashoffset: -10;
          }
        }
      `}</style>
    </>
  );
}

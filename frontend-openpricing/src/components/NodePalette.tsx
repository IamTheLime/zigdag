import { useMemo, useState } from 'react';
import type { OperationType } from '../types/pricing';
import { NODE_CATEGORIES, getNodesByCategory } from '../config/nodeDefinitions';

interface NodePaletteProps {
  onNodeCreate: (operation: OperationType) => void;
}

export default function NodePalette({ onNodeCreate }: NodePaletteProps) {
  const [expandedCategory, setExpandedCategory] = useState<string>('input');

  const categorizedNodes = useMemo(() => {
    return NODE_CATEGORIES.map((cat) => ({
      ...cat,
      nodes: getNodesByCategory(cat.id as any),
    }));
  }, []);

  return (
    <div
      style={{
        width: '280px',
        backgroundColor: '#f8f9fa',
        borderRight: '1px solid #dee2e6',
        padding: '16px',
        overflow: 'auto',
        height: '100%',
      }}
    >
      <h3 style={{ margin: '0 0 16px 0', fontSize: '18px', fontWeight: 'bold' }}>
        Node Palette
      </h3>

      <div style={{ fontSize: '12px', color: '#666', marginBottom: '16px' }}>
        Drag nodes onto the canvas to build your pricing model
      </div>

      {categorizedNodes.map((category) => (
        <div key={category.id} style={{ marginBottom: '12px' }}>
          {/* Category header */}
          <div
            onClick={() =>
              setExpandedCategory(expandedCategory === category.id ? '' : category.id)
            }
            style={{
              backgroundColor: category.color,
              color: 'white',
              padding: '8px 12px',
              borderRadius: '6px',
              cursor: 'pointer',
              fontWeight: 'bold',
              fontSize: '13px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              userSelect: 'none',
            }}
          >
            <span>{category.label}</span>
            <span style={{ fontSize: '16px' }}>
              {expandedCategory === category.id ? '▼' : '▶'}
            </span>
          </div>

          {/* Category nodes */}
          {expandedCategory === category.id && (
            <div style={{ marginTop: '8px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
              {category.nodes.map((node) => (
                <div
                  key={node.operation}
                  onClick={() => onNodeCreate(node.operation)}
                  draggable
                  onDragStart={(e) => {
                    e.dataTransfer.setData('application/reactflow', node.operation);
                    e.dataTransfer.effectAllowed = 'move';
                  }}
                  style={{
                    backgroundColor: 'white',
                    border: `2px solid ${node.color}`,
                    borderRadius: '6px',
                    padding: '10px',
                    cursor: 'grab',
                    transition: 'all 0.2s',
                    userSelect: 'none',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateX(4px)';
                    e.currentTarget.style.boxShadow = `0 2px 8px ${node.color}40`;
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateX(0)';
                    e.currentTarget.style.boxShadow = 'none';
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    {node.icon && <span style={{ fontSize: '18px' }}>{node.icon}</span>}
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 'bold', fontSize: '12px', color: '#333' }}>
                        {node.label}
                      </div>
                      <div style={{ fontSize: '10px', color: '#666', marginTop: '2px' }}>
                        {node.description}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      ))}

      {/* Help section */}
      <div
        style={{
          marginTop: '24px',
          padding: '12px',
          backgroundColor: '#e3f2fd',
          borderRadius: '6px',
          fontSize: '11px',
          color: '#1976d2',
        }}
      >
        <div style={{ fontWeight: 'bold', marginBottom: '6px' }}>💡 Tips:</div>
        <ul style={{ margin: 0, paddingLeft: '16px' }}>
          <li>Drag nodes onto canvas</li>
          <li>Connect nodes with edges</li>
          <li>Edit node values inline</li>
          <li>Save to playground to test</li>
        </ul>
      </div>
    </div>
  );
}

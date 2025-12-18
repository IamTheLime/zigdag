import { useCallback, useState } from 'react';
import ReactFlow, {
  Node,
  Edge,
  addEdge,
  Connection,
  useNodesState,
  useEdgesState,
  Controls,
  Background,
  MiniMap,
} from 'reactflow';
import 'reactflow/dist/style.css';
import type { PricingNode, PricingGraph } from './types/pricing';

const initialNodes: Node[] = [
  {
    id: 'base_price',
    type: 'input',
    data: { label: 'Base Price (Input)', operation: 'input' },
    position: { x: 100, y: 100 },
  },
  {
    id: 'markup',
    type: 'default',
    data: { label: 'Markup (1.2x)', operation: 'constant', value: 1.2 },
    position: { x: 100, y: 200 },
  },
  {
    id: 'final_price',
    type: 'output',
    data: { label: 'Final Price (Multiply)', operation: 'multiply' },
    position: { x: 300, y: 150 },
  },
];

const initialEdges: Edge[] = [
  { id: 'e-bp-fp', source: 'base_price', target: 'final_price' },
  { id: 'e-m-fp', source: 'markup', target: 'final_price' },
];

function App() {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const [jsonOutput, setJsonOutput] = useState<string>('');

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges],
  );

  const exportToJson = useCallback(() => {
    const pricingNodes: PricingNode[] = nodes.map((node) => {
      const inputs = edges
        .filter((edge) => edge.target === node.id)
        .map((edge) => edge.source);

      return {
        id: node.id,
        operation: (node.data.operation as any) || 'input',
        weights: [],
        constant_value: node.data.value || 0,
        inputs,
        metadata: {
          name: node.data.label || node.id,
          description: '',
          position_x: node.position.x,
          position_y: node.position.y,
        },
      };
    });

    const graph: PricingGraph = { nodes: pricingNodes };
    const json = JSON.stringify(graph, null, 2);
    setJsonOutput(json);
    console.log('Exported graph:', json);
  }, [nodes, edges]);

  return (
    <div style={{ width: '100vw', height: '100vh', display: 'flex' }}>
      <div style={{ flex: 1, height: '100%' }}>
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          fitView
        >
          <Controls />
          <MiniMap />
          <Background gap={12} size={1} />
        </ReactFlow>
      </div>
      <div
        style={{
          width: '400px',
          padding: '20px',
          backgroundColor: '#f5f5f5',
          overflow: 'auto',
        }}
      >
        <h2>OpenPricing Graph Editor</h2>
        <button
          onClick={exportToJson}
          style={{
            padding: '10px 20px',
            marginBottom: '20px',
            cursor: 'pointer',
            backgroundColor: '#4CAF50',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
          }}
        >
          Export to JSON
        </button>
        {jsonOutput && (
          <div>
            <h3>Graph JSON:</h3>
            <pre
              style={{
                backgroundColor: '#2d2d2d',
                color: '#f8f8f2',
                padding: '10px',
                borderRadius: '4px',
                fontSize: '12px',
                overflow: 'auto',
              }}
            >
              {jsonOutput}
            </pre>
          </div>
        )}
        <div style={{ marginTop: '20px' }}>
          <h3>Instructions:</h3>
          <ul style={{ fontSize: '14px', lineHeight: '1.6' }}>
            <li>Drag nodes to reposition them</li>
            <li>Connect nodes by dragging from one handle to another</li>
            <li>Click "Export to JSON" to see the graph definition</li>
            <li>The JSON can be sent to the Zig backend for execution</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export default App;

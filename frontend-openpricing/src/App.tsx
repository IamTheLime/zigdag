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
          description: node.data.description || '',
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

  const downloadJson = useCallback(() => {
    if (!jsonOutput) {
      exportToJson();
      return;
    }

    const blob = new Blob([jsonOutput], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'pricing_model.json';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }, [jsonOutput, exportToJson]);

  const copyToClipboard = useCallback(() => {
    if (!jsonOutput) return;
    navigator.clipboard.writeText(jsonOutput);
    alert('JSON copied to clipboard!');
  }, [jsonOutput]);

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
        <div style={{ display: 'flex', gap: '10px', marginBottom: '20px', flexWrap: 'wrap' }}>
          <button
            onClick={exportToJson}
            style={{
              padding: '10px 20px',
              cursor: 'pointer',
              backgroundColor: '#4CAF50',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              flex: '1',
              minWidth: '120px',
            }}
          >
            Generate JSON
          </button>
          <button
            onClick={downloadJson}
            disabled={!jsonOutput}
            style={{
              padding: '10px 20px',
              cursor: jsonOutput ? 'pointer' : 'not-allowed',
              backgroundColor: jsonOutput ? '#2196F3' : '#cccccc',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              flex: '1',
              minWidth: '120px',
            }}
          >
            Download JSON
          </button>
          <button
            onClick={copyToClipboard}
            disabled={!jsonOutput}
            style={{
              padding: '10px 20px',
              cursor: jsonOutput ? 'pointer' : 'not-allowed',
              backgroundColor: jsonOutput ? '#FF9800' : '#cccccc',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              flex: '1',
              minWidth: '120px',
            }}
          >
            Copy JSON
          </button>
        </div>
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
          <h3>Workflow:</h3>
          <ol style={{ fontSize: '14px', lineHeight: '1.8', paddingLeft: '20px' }}>
            <li>Design your pricing model by connecting nodes</li>
            <li>Click "Generate JSON" to create the model definition</li>
            <li>Click "Download JSON" to save as <code style={{ backgroundColor: '#e0e0e0', padding: '2px 4px' }}>pricing_model.json</code></li>
            <li>Copy to <code style={{ backgroundColor: '#e0e0e0', padding: '2px 4px' }}>backend-openpricing/models/</code></li>
            <li>Run <code style={{ backgroundColor: '#e0e0e0', padding: '2px 4px' }}>zig build</code> - nodes compile into the binary!</li>
            <li>Your pricing model is now pure machine code</li>
          </ol>
          <h3 style={{ marginTop: '20px' }}>Tips:</h3>
          <ul style={{ fontSize: '14px', lineHeight: '1.6' }}>
            <li>Drag nodes to reposition them</li>
            <li>Connect nodes by dragging from handles</li>
            <li>The backend compiles your JSON at build time</li>
            <li>Zero runtime overhead - everything is compile-time!</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export default App;

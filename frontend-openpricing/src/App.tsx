import { useCallback, useState, useRef, useEffect, DragEvent } from 'react';
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
  ReactFlowProvider,
  ReactFlowInstance,
} from 'reactflow';
import 'reactflow/dist/style.css';
import type { PricingNode, PricingGraph, OperationType } from './types/pricing';
import { createNode } from './utils/nodeFactory';
import PricingNodeComponent from './components/PricingNode';
import NodePalette from './components/NodePalette';

const nodeTypes = {
  custom: PricingNodeComponent,
};

function FlowEditor() {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [jsonOutput, setJsonOutput] = useState<string>('');
  const [reactFlowInstance, setReactFlowInstance] = useState<ReactFlowInstance | null>(null);
  const reactFlowWrapper = useRef<HTMLDivElement>(null);

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges]
  );

  const onDragOver = useCallback((event: DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback(
    (event: DragEvent) => {
      event.preventDefault();

      if (!reactFlowWrapper.current || !reactFlowInstance) return;

      const operation = event.dataTransfer.getData('application/reactflow') as OperationType;
      if (!operation) return;

      const bounds = reactFlowWrapper.current.getBoundingClientRect();
      const position = reactFlowInstance.project({
        x: event.clientX - bounds.left,
        y: event.clientY - bounds.top,
      });

      const newNode = createNode(operation, position);
      setNodes((nds) => [...nds, newNode]);
    },
    [reactFlowInstance, setNodes]
  );

  const handleNodeCreate = useCallback(
    (operation: OperationType) => {
      // Create node in center of viewport
      const position = reactFlowInstance
        ? reactFlowInstance.project({ x: window.innerWidth / 2, y: window.innerHeight / 2 })
        : { x: 250, y: 250 };

      const newNode = createNode(operation, position);
      setNodes((nds) => [...nds, newNode]);
    },
    [reactFlowInstance, setNodes]
  );

  const onNodeDataChange = useCallback(
    (nodeId: string, data: any) => {
      setNodes((nds) =>
        nds.map((node) => {
          if (node.id === nodeId) {
            return {
              ...node,
              data: { ...node.data, ...data },
            };
          }
          return node;
        })
      );
    },
    [setNodes]
  );

  const deleteNode = useCallback(
    (nodeId: string) => {
      setNodes((nds) => nds.filter((node) => node.id !== nodeId));
      setEdges((eds) => eds.filter((edge) => edge.source !== nodeId && edge.target !== nodeId));
    },
    [setNodes, setEdges]
  );

  // Add onChange and onDelete handlers to nodes
  const nodesWithHandlers = nodes.map((node) => ({
    ...node,
    data: {
      ...node.data,
      onChange: (data: any) => onNodeDataChange(node.id, data),
      onDelete: () => deleteNode(node.id),
    },
  }));

  const exportToJson = useCallback(() => {
    const pricingNodes: PricingNode[] = nodes.map((node) => {
      const inputs = edges
        .filter((edge) => edge.target === node.id)
        .map((edge) => edge.source);

      return {
        id: node.data.customId || node.id,
        operation: (node.data.operation as OperationType) || 'dynamic_input_num',
        weights: node.data.weights || [],
        constant_value: typeof node.data.value === 'number' ? node.data.value : 0.0,
        constant_str_value: node.data.stringValue,
        allowed_values: node.data.allowedValues || [],
        inputs,
        metadata: {
          name: node.data.customId || node.data.label || node.id,
          description: node.data.customDescription || node.data.description || '',
          position_x: node.position.x,
          position_y: node.position.y,
        },
      };
    });

    const graph: PricingGraph = { nodes: pricingNodes };
    const json = JSON.stringify(graph, null, 2);
    setJsonOutput(json);
    return json;
  }, [nodes, edges]);

  const saveToPlayground = useCallback(() => {
    const json = jsonOutput || exportToJson();

    // Create a blob and download
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'pricing_model.json';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    alert('💾 Saved! Move pricing_model.json to playground/ directory and run ./test-playground.sh');
  }, [jsonOutput, exportToJson]);

  const copyToClipboard = useCallback(() => {
    if (!jsonOutput) return;
    navigator.clipboard.writeText(jsonOutput);
    alert('📋 JSON copied to clipboard!');
  }, [jsonOutput]);

  const clearCanvas = useCallback(() => {
    if (confirm('Clear all nodes? This cannot be undone.')) {
      setNodes([]);
      setEdges([]);
      setJsonOutput('');
    }
  }, [setNodes, setEdges]);

  const deleteSelected = useCallback(() => {
    setNodes((nds) => nds.filter((node) => !node.selected));
    setEdges((eds) => eds.filter((edge) => !edge.selected));
  }, [setNodes, setEdges]);

  // Add keyboard handler for Delete key only (not backspace)
  const onKeyDown = useCallback(
    (event: KeyboardEvent) => {
      // Only delete on Delete key, not backspace (backspace is for text editing)
      if (event.key === 'Delete' && !isInputFocused()) {
        deleteSelected();
      }
    },
    [deleteSelected]
  );

  // Helper to check if an input is focused
  const isInputFocused = () => {
    const activeElement = document.activeElement;
    return (
      activeElement instanceof HTMLInputElement ||
      activeElement instanceof HTMLTextAreaElement
    );
  };

  // Attach keyboard listener
  useEffect(() => {
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [onKeyDown]);

  return (
    <div style={{ width: '100vw', height: '100vh', display: 'flex' }}>
      {/* Node Palette */}
      <NodePalette onNodeCreate={handleNodeCreate} />

      {/* Main Flow Canvas */}
      <div ref={reactFlowWrapper} style={{ flex: 1, height: '100%' }}>
        <ReactFlow
          nodes={nodesWithHandlers}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onInit={setReactFlowInstance}
          onDrop={onDrop}
          onDragOver={onDragOver}
          nodeTypes={nodeTypes}
          fitView
          deleteKeyCode="Delete"
        >
          <Controls />
          <MiniMap />
          <Background gap={12} size={1} />
        </ReactFlow>
      </div>

      {/* Right Panel */}
      <div
        style={{
          width: '380px',
          padding: '20px',
          backgroundColor: '#f5f5f5',
          overflow: 'auto',
          borderLeft: '1px solid #dee2e6',
        }}
      >
        <h2 style={{ margin: '0 0 16px 0' }}>OpenPricing Studio</h2>

        {/* Action Buttons */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '20px' }}>
          <button
            onClick={exportToJson}
            style={{
              padding: '12px 16px',
              cursor: 'pointer',
              backgroundColor: '#4CAF50',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontWeight: 'bold',
              fontSize: '14px',
            }}
          >
            📄 Generate JSON
          </button>
          <button
            onClick={saveToPlayground}
            disabled={!jsonOutput}
            style={{
              padding: '12px 16px',
              cursor: jsonOutput ? 'pointer' : 'not-allowed',
              backgroundColor: jsonOutput ? '#2196F3' : '#cccccc',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontWeight: 'bold',
              fontSize: '14px',
            }}
          >
            💾 Save to Playground
          </button>
          <button
            onClick={copyToClipboard}
            disabled={!jsonOutput}
            style={{
              padding: '12px 16px',
              cursor: jsonOutput ? 'pointer' : 'not-allowed',
              backgroundColor: jsonOutput ? '#FF9800' : '#cccccc',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontWeight: 'bold',
              fontSize: '14px',
            }}
          >
            📋 Copy JSON
          </button>
          <button
            onClick={deleteSelected}
            style={{
              padding: '12px 16px',
              cursor: 'pointer',
              backgroundColor: '#FF5722',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontWeight: 'bold',
              fontSize: '14px',
            }}
          >
            ❌ Delete Selected
          </button>
          <button
            onClick={clearCanvas}
            style={{
              padding: '12px 16px',
              cursor: 'pointer',
              backgroundColor: '#f44336',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontWeight: 'bold',
              fontSize: '14px',
            }}
          >
            🗑️ Clear Canvas
          </button>
        </div>

        {/* Stats */}
        <div
          style={{
            backgroundColor: '#e3f2fd',
            padding: '12px',
            borderRadius: '6px',
            marginBottom: '16px',
            fontSize: '13px',
          }}
        >
          <div style={{ fontWeight: 'bold', marginBottom: '8px' }}>📊 Model Stats</div>
          <div>Nodes: {nodes.length}</div>
          <div>Connections: {edges.length}</div>
        </div>

        {/* JSON Output */}
        {jsonOutput && (
          <div>
            <h3 style={{ fontSize: '16px', marginBottom: '8px' }}>Graph JSON:</h3>
            <pre
              style={{
                backgroundColor: '#2d2d2d',
                color: '#f8f8f2',
                padding: '12px',
                borderRadius: '6px',
                fontSize: '11px',
                overflow: 'auto',
                maxHeight: '300px',
              }}
            >
              {jsonOutput}
            </pre>
          </div>
        )}

        {/* Workflow Instructions */}
        <div style={{ marginTop: '20px' }}>
          <h3 style={{ fontSize: '16px', marginBottom: '8px' }}>🚀 Workflow:</h3>
          <ol style={{ fontSize: '13px', lineHeight: '1.8', paddingLeft: '20px' }}>
            <li>Drag nodes from palette or click to add</li>
            <li>Connect nodes by dragging from handles</li>
            <li>Edit values directly in nodes</li>
            <li>Click "Generate JSON"</li>
            <li>Click "Save to Playground"</li>
            <li>
              Move <code>pricing_model.json</code> to <code>playground/</code>
            </li>
            <li>
              Run <code>./test-playground.sh</code>
            </li>
            <li>Watch it compile and execute! 🎉</li>
          </ol>
        </div>

        {/* Tips */}
        <div
          style={{
            marginTop: '20px',
            backgroundColor: '#fff3e0',
            padding: '12px',
            borderRadius: '6px',
            fontSize: '12px',
          }}
        >
          <div style={{ fontWeight: 'bold', marginBottom: '6px' }}>💡 Pro Tips:</div>
          <ul style={{ margin: 0, paddingLeft: '16px', lineHeight: '1.6' }}>
            <li>Use dynamic inputs for runtime user values</li>
            <li>Use constants for fixed configuration</li>
            <li>The backend compiles everything at build time!</li>
            <li>Zero runtime overhead = blazing fast! 🔥</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <ReactFlowProvider>
      <FlowEditor />
    </ReactFlowProvider>
  );
}

export default App;

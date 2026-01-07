import { useCallback, useState, useRef, useEffect, DragEvent } from 'react';
import ReactFlow, {
  addEdge,
  Connection,
  useNodesState,
  useEdgesState,
  Controls,
  Background,
  MiniMap,
  ReactFlowProvider,
  ReactFlowInstance,
  MarkerType,
} from 'reactflow';
import 'reactflow/dist/style.css';
import type { PricingNode, PricingGraph, OperationType } from './types/pricing';
import { createNode } from './utils/nodeFactory';
import { getNodeDefinition } from './config/nodeDefinitions';
import PricingNodeComponent from './components/PricingNode';
import CustomEdge from './components/CustomEdge';
import NodePalette from './components/NodePalette';
import { CommandPalette } from './components/CommandPalette';
import { ThemeProvider } from './components/theme-provider';
import { ThemeToggle } from './components/theme-toggle';
import { Button } from './components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './components/ui/card';
import {
  FileJson,
  Save,
  Copy,
  Trash2,
  XCircle,
  BarChart3,
  Workflow,
  Upload,
} from 'lucide-react';

const nodeTypes = {
  custom: PricingNodeComponent,
};

const edgeTypes = {
  custom: CustomEdge,
};

const defaultEdgeOptions = {
  type: 'custom',
  animated: true,
  markerEnd: {
    type: MarkerType.ArrowClosed,
    width: 20,
    height: 20,
    color: 'hsl(var(--primary))',
  },
  style: {
    strokeWidth: 2,
    stroke: 'hsl(var(--primary))',
  },
};

function FlowEditor() {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [jsonOutput, setJsonOutput] = useState<string>('');
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false);
  const [reactFlowInstance, setReactFlowInstance] = useState<ReactFlowInstance | null>(null);
  const reactFlowWrapper = useRef<HTMLDivElement>(null);

  const onConnect = useCallback(
    (params: Connection) => {
      // Check if the target handle already has a connection
      setEdges((eds) => {
        const targetHandleId = params.targetHandle || 'target';
        const existingConnection = eds.find(
          (edge) => 
            edge.target === params.target && 
            edge.targetHandle === targetHandleId
        );
        
        // If there's already a connection to this specific handle, remove it first
        if (existingConnection) {
          const filteredEdges = eds.filter((edge) => edge.id !== existingConnection.id);
          return addEdge(params, filteredEdges);
        }
        
        return addEdge(params, eds);
      });
    },
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
      // Get edges connected to this node and sort them by target handle
      const nodeEdges = edges.filter((edge) => edge.target === node.id);
      
      // Sort inputs by handle ID to ensure correct order for binary ops
      const sortedEdges = nodeEdges.sort((a, b) => {
        const handleA = a.targetHandle || 'target';
        const handleB = b.targetHandle || 'target';
        
        // For binary operations with target-a and target-b handles
        if (handleA === 'target-a') return -1;
        if (handleB === 'target-a') return 1;
        if (handleA === 'target-b') return -1;
        if (handleB === 'target-b') return 1;
        
        // For other handles, maintain order
        return handleA.localeCompare(handleB);
      });
      
      const inputs = sortedEdges.map((edge) => edge.source);

      return {
        id: node.data.customId || node.id,
        operation: (node.data.operation as OperationType) || 'dynamic_input_num',
        weights: node.data.weights || [],
        constant_value: typeof node.data.value === 'number' ? node.data.value : 0.0,
        constant_str_value: node.data.stringValue,
        allowed_values: node.data.allowedValues || [],
        allowed_str_values: node.data.allowedStrValues || [],
        conditional_values: node.data.conditionalValues || {},
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

    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'pricing_model.json';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    alert('Saved! Move pricing_model.json to playground/ directory and run ./test-playground.sh');
  }, [jsonOutput, exportToJson]);

  const copyToClipboard = useCallback(() => {
    if (!jsonOutput) return;
    navigator.clipboard.writeText(jsonOutput);
    alert('JSON copied to clipboard!');
  }, [jsonOutput]);

  const clearCanvas = useCallback(() => {
    if (confirm('Clear all nodes? This cannot be undone.')) {
      setNodes([]);
      setEdges([]);
      setJsonOutput('');
    }
  }, [setNodes, setEdges]);

  const importFromJson = useCallback(() => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    
    input.onchange = (e: Event) => {
      const target = e.target as HTMLInputElement;
      const file = target.files?.[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (event) => {
        try {
          const jsonContent = event.target?.result as string;
          const graph: PricingGraph = JSON.parse(jsonContent);
          
          // Clear existing nodes and edges
          setNodes([]);
          setEdges([]);
          
          // Convert PricingNodes to ReactFlow nodes
          const newNodes = graph.nodes.map((pricingNode) => {
            const position = {
              x: pricingNode.metadata.position_x,
              y: pricingNode.metadata.position_y,
            };
            
            // Get the node definition to retrieve all configuration properties
            const def = getNodeDefinition(pricingNode.operation);
            
            return {
              id: pricingNode.id,
              type: 'custom',
              position,
              data: {
                operation: pricingNode.operation,
                label: pricingNode.metadata.name || def.label,
                description: pricingNode.metadata.description || def.description,
                category: def.category,
                color: def.color,
                icon: def.icon,
                inputCount: def.inputCount,
                hasValue: def.hasValue,
                hasWeights: def.hasWeights,
                hasAllowedValues: def.hasAllowedValues,
                hasAllowedStrValues: def.hasAllowedStrValues,
                hasConditionalValues: def.hasConditionalValues,
                customId: pricingNode.id,
                customDescription: pricingNode.metadata.description,
                value: pricingNode.constant_value,
                stringValue: pricingNode.constant_str_value,
                allowedValues: pricingNode.allowed_values || [],
                allowedStrValues: pricingNode.allowed_str_values || [],
                conditionalValues: pricingNode.conditional_values || {},
                weights: pricingNode.weights || [],
              },
            };
          });

          // Create edges from the inputs array
          const newEdges: any[] = [];
          graph.nodes.forEach((pricingNode) => {
            pricingNode.inputs.forEach((sourceId, index) => {
              const targetNode = pricingNode;
              
              // Determine the target handle based on the operation and index
              let targetHandle = 'target';
              
              // For binary operations, use target-a and target-b
              if (['add', 'subtract', 'multiply', 'divide', 'power', 'modulo'].includes(pricingNode.operation)) {
                targetHandle = index === 0 ? 'target-a' : 'target-b';
              } 
              // For clamp, use target-value, target-min, target-max
              else if (pricingNode.operation === 'clamp') {
                targetHandle = ['target-value', 'target-min', 'target-max'][index] || `target-${index}`;
              }
              // For variadic operations (max, min, weighted_sum), use target-0, target-1, etc.
              else if (['max', 'min', 'weighted_sum'].includes(pricingNode.operation)) {
                targetHandle = `target-${index}`;
              }

              newEdges.push({
                id: `${sourceId}-${targetNode.id}-${index}`,
                source: sourceId,
                target: targetNode.id,
                targetHandle,
                type: 'custom',
                animated: true,
              });
            });
          });

          setNodes(newNodes);
          setEdges(newEdges);
          setJsonOutput(jsonContent);
          
          // Fit view to show all imported nodes
          setTimeout(() => {
            reactFlowInstance?.fitView({ padding: 0.2 });
          }, 0);
          
          alert(`Imported ${newNodes.length} nodes successfully!`);
        } catch (error) {
          console.error('Error importing JSON:', error);
          alert('Error importing JSON. Please check the file format.');
        }
      };
      
      reader.readAsText(file);
    };
    
    input.click();
  }, [setNodes, setEdges, reactFlowInstance]);

  const deleteSelected = useCallback(() => {
    setNodes((nds) => nds.filter((node) => !node.selected));
    setEdges((eds) => eds.filter((edge) => !edge.selected));
  }, [setNodes, setEdges]);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // Command/Ctrl + K to open command palette
      if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
        event.preventDefault();
        setCommandPaletteOpen(true);
        return;
      }

      // Delete key to delete selected items
      if (event.key === 'Delete' && !isInputFocused()) {
        deleteSelected();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [deleteSelected]);

  const isInputFocused = () => {
    const activeElement = document.activeElement;
    return (
      activeElement instanceof HTMLInputElement ||
      activeElement instanceof HTMLTextAreaElement
    );
  };

  return (
    <div className="w-screen h-screen flex bg-background">
      {/* Command Palette */}
      <CommandPalette
        open={commandPaletteOpen}
        onOpenChange={setCommandPaletteOpen}
        onSelectNode={handleNodeCreate}
      />

      {/* Node Palette */}
      <NodePalette onNodeCreate={handleNodeCreate} />

      {/* Main Flow Canvas */}
      <div ref={reactFlowWrapper} className="flex-1 h-full relative">
        {/* Theme Toggle - Top Right */}
        <div className="absolute top-4 right-4 z-10 flex items-center gap-2">
          <div className="text-xs text-muted-foreground bg-background/80 backdrop-blur-sm px-2 py-1 rounded border">
            Press{' '}
            <kbd className="px-1 py-0.5 text-xs bg-muted rounded">⌘K</kbd>
            {' '}or{' '}
            <kbd className="px-1 py-0.5 text-xs bg-muted rounded">Ctrl+K</kbd>
            {' '}to search
          </div>
          <ThemeToggle />
        </div>

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
          edgeTypes={edgeTypes}
          defaultEdgeOptions={defaultEdgeOptions}
          fitView
          deleteKeyCode="Delete"
        >
          <Controls />
          <MiniMap />
          <Background gap={12} size={1} />
        </ReactFlow>
      </div>

      {/* Right Panel */}
      <div className="w-[400px] border-l bg-muted/30 overflow-auto p-6 space-y-6">
        <div>
          <h2 className="text-2xl font-bold flex items-center gap-2">
            <Workflow className="h-6 w-6" />
            OpenPricing Studio
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            Build and export pricing models
          </p>
        </div>

        {/* Action Buttons */}
        <div className="space-y-2">
          <Button onClick={importFromJson} className="w-full" size="lg" variant="default">
            <Upload className="mr-2 h-4 w-4" />
            Import Model
          </Button>
          <Button onClick={exportToJson} className="w-full" size="lg">
            <FileJson className="mr-2 h-4 w-4" />
            Generate JSON
          </Button>
          <Button
            onClick={saveToPlayground}
            disabled={!jsonOutput}
            variant="secondary"
            className="w-full"
            size="lg"
          >
            <Save className="mr-2 h-4 w-4" />
            Save to Playground
          </Button>
          <Button
            onClick={copyToClipboard}
            disabled={!jsonOutput}
            variant="outline"
            className="w-full"
            size="lg"
          >
            <Copy className="mr-2 h-4 w-4" />
            Copy JSON
          </Button>
          <Button onClick={deleteSelected} variant="destructive" className="w-full">
            <XCircle className="mr-2 h-4 w-4" />
            Delete Selected
          </Button>
          <Button onClick={clearCanvas} variant="destructive" className="w-full">
            <Trash2 className="mr-2 h-4 w-4" />
            Clear Canvas
          </Button>
        </div>

        {/* Stats */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-sm flex items-center gap-2">
              <BarChart3 className="h-4 w-4" />
              Model Stats
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Nodes:</span>
              <span className="font-medium">{nodes.length}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Connections:</span>
              <span className="font-medium">{edges.length}</span>
            </div>
          </CardContent>
        </Card>

        {/* JSON Output */}
        {jsonOutput && (
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm">Graph JSON</CardTitle>
              <CardDescription className="text-xs">
                Generated pricing model configuration
              </CardDescription>
            </CardHeader>
            <CardContent>
              <pre className="bg-black text-green-400 dark:bg-gray-950 dark:text-green-300 p-3 rounded-md text-xs overflow-auto max-h-[300px] font-mono">
                {jsonOutput}
              </pre>
            </CardContent>
          </Card>
        )}

        {/* Workflow Instructions */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-sm">Workflow</CardTitle>
          </CardHeader>
          <CardContent>
            <ol className="text-xs space-y-2 list-decimal list-inside text-muted-foreground">
              <li>Click "Import Model" to load existing JSON</li>
              <li>Or press <kbd className="bg-muted px-1 rounded">⌘K</kbd> to search for nodes</li>
              <li>Or drag nodes from palette</li>
              <li>Connect nodes by dragging from handles</li>
              <li>Click connections to delete them</li>
              <li>Edit values directly in nodes</li>
              <li>Click "Generate JSON"</li>
              <li>Click "Save to Playground"</li>
              <li>
                Move <code className="bg-muted px-1 rounded">pricing_model.json</code> to{' '}
                <code className="bg-muted px-1 rounded">playground/</code>
              </li>
              <li>
                Run <code className="bg-muted px-1 rounded">./test-playground.sh</code>
              </li>
              <li>Watch it compile and execute!</li>
            </ol>
          </CardContent>
        </Card>

        {/* Tips */}
        <Card className="bg-amber-50 dark:bg-amber-950 border-amber-200 dark:border-amber-800">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm text-amber-900 dark:text-amber-100">
              Pro Tips
            </CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="text-xs space-y-1 text-amber-800 dark:text-amber-200">
              <li>• Use dynamic inputs for runtime user values</li>
              <li>• Use constants for fixed configuration</li>
              <li>• Conditional values map input keys to output values</li>
              <li>• Hover over connections to delete them</li>
              <li>• The backend compiles everything at build time!</li>
              <li>• Zero runtime overhead = blazing fast!</li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function App() {
  return (
    <ThemeProvider defaultTheme="dark" storageKey="openpricing-ui-theme">
      <ReactFlowProvider>
        <FlowEditor />
      </ReactFlowProvider>
    </ThemeProvider>
  );
}

export default App;

import { useCallback, useState, useRef, useEffect, useMemo, DragEvent } from 'react';
import ReactFlow, {
  addEdge,
  Connection,
  useNodesState,
  useEdgesState,
  Controls,
  Background,
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
import CustomMiniMap from './components/CustomMiniMap';
import { IslandHighlight } from './components/IslandHighlight';
import { ThemeProvider } from './components/theme-provider';
import { ThemeToggle } from './components/theme-toggle';
import { Button } from './components/ui/button';
import {
  Save,
  BarChart3,
  Upload,
  PanelLeftClose,
  PanelLeftOpen,
  CheckCircle2,
  AlertCircle,
} from 'lucide-react';
import { validateGraph, type GraphIsland } from './utils/graphValidation';

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
  const [modelName, setModelName] = useState<string>('my-pricing-model');
  const [modelVersion, setModelVersion] = useState<string>('1.0.0');
  const [leftSidebarVisible, setLeftSidebarVisible] = useState(true);
  const [highlightedIslands, setHighlightedIslands] = useState<GraphIsland[]>([]);
  const islandTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  
  // Platform-aware keyboard shortcut
  const isMac = typeof navigator !== 'undefined' && navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  const modKey = isMac ? '⌘' : 'Ctrl';

  // Graph validation
  const validation = useMemo(() => validateGraph(nodes, edges), [nodes, edges]);

  // Handle island highlighting
  const highlightIslands = useCallback((islands: GraphIsland[]) => {
    // Clear any existing timeout
    if (islandTimeoutRef.current) {
      clearTimeout(islandTimeoutRef.current);
    }

    // Apply island colors to nodes
    setNodes((nds) =>
      nds.map((node) => {
        const island = islands.find((isl) => isl.nodeIds.includes(node.id));
        if (island) {
          return {
            ...node,
            data: {
              ...node.data,
              islandColor: island.color,
              islandId: island.id,
            },
          };
        }
        return node;
      })
    );

    // Set highlighted islands for legend
    setHighlightedIslands(islands);

    // Auto-revert after 4 seconds
    islandTimeoutRef.current = setTimeout(() => {
      setNodes((nds) =>
        nds.map((node) => ({
          ...node,
          data: {
            ...node.data,
            islandColor: undefined,
            islandId: undefined,
          },
        }))
      );
      setHighlightedIslands([]);
    }, 4000);
  }, [setNodes]);

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
        id: node.id, // Now uses the actual node ID which gets updated when customId changes
        operation: (node.data.operation as OperationType) || 'dynamic_input_num',
        weights: node.data.weights || [],
        constant_value: typeof node.data.value === 'number' ? node.data.value : 0.0,
        constant_str_value: node.data.stringValue,
        allowed_values: node.data.allowedValues || [],
        allowed_str_values: node.data.allowedStrValues || [],
        default_value: node.data.defaultValue,
        default_str_value: node.data.defaultStrValue,
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

    const graph: PricingGraph = { name: modelName, version: modelVersion, nodes: pricingNodes };
    const json = JSON.stringify(graph, null, 2);
    setJsonOutput(json);
    return json;
  }, [nodes, edges, modelName, modelVersion]);

  const saveJson = useCallback(() => {
    const json = exportToJson();

    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'dag_model.json';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }, [jsonOutput, exportToJson]);



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
                defaultValue: pricingNode.default_value,
                defaultStrValue: pricingNode.default_str_value,
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
          
          // Set model name and version if present
          if (graph.name) setModelName(graph.name);
          if (graph.version) setModelVersion(graph.version);
          
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
  }, [setNodes, setEdges, reactFlowInstance, setModelName, setModelVersion]);

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
    <div className="w-screen h-screen flex flex-col bg-background">
      {/* Command Palette */}
      <CommandPalette
        open={commandPaletteOpen}
        onOpenChange={setCommandPaletteOpen}
        onSelectNode={handleNodeCreate}
      />

      {/* Top Toolbar */}
      <div className="h-12 border-b border-border/40 bg-background flex items-center px-3 gap-3 shrink-0">
        {/* Left: Sidebar toggle + Actions */}
        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8"
            onClick={() => setLeftSidebarVisible(!leftSidebarVisible)}
          >
            {leftSidebarVisible ? (
              <PanelLeftClose className="h-4 w-4" />
            ) : (
              <PanelLeftOpen className="h-4 w-4" />
            )}
          </Button>
          <div className="h-4 w-px bg-border/40 mx-1" />
          <Button variant="ghost" size="sm" className="h-8 text-xs" onClick={importFromJson}>
            <Upload className="h-3.5 w-3.5 mr-1.5" />
            Import
          </Button>
          <Button 
            variant="ghost" 
            size="sm" 
            className="h-8 text-xs" 
            onClick={saveJson}
            disabled={!jsonOutput}
          >
            <Save className="h-3.5 w-3.5 mr-1.5" />
            Save
          </Button>
          <div className="h-4 w-px bg-border/40 mx-1" />
        </div>

        {/* Center: Editable Title */}
        <div className="flex-1 flex items-center justify-center">
          <input
            type="text"
            value={modelName}
            onChange={(e) => setModelName(e.target.value)}
            placeholder="Model Name"
            className="text-sm font-medium bg-transparent border-0 focus:outline-none focus:ring-0 text-center max-w-xs px-2 py-1 rounded hover:bg-muted/50 focus:bg-muted/50 transition-colors"
          />
          <span className="text-xs text-muted-foreground mx-1">v</span>
          <input
            type="text"
            value={modelVersion}
            onChange={(e) => setModelVersion(e.target.value)}
            placeholder="1.0.0"
            className="text-sm text-muted-foreground bg-transparent border-0 focus:outline-none focus:ring-0 w-16 px-1 py-1 rounded hover:bg-muted/50 focus:bg-muted/50 transition-colors"
          />
        </div>

        {/* Right: Theme + Search hint */}
        <div className="flex items-center gap-2">
          <div className="text-[11px] text-muted-foreground px-2">
            <kbd className="px-1.5 py-0.5 text-[10px] bg-muted/50 rounded border border-border/40">{modKey}+K</kbd>
            {' '}search
          </div>
          <ThemeToggle />
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex overflow-hidden">
        {/* Node Palette */}
        <NodePalette onNodeCreate={handleNodeCreate} isVisible={leftSidebarVisible} />

        {/* ReactFlow Canvas */}
        <div ref={reactFlowWrapper} className="flex-1 relative">
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
            defaultViewport={{ x: 0, y: 0, zoom: 0.6 }}
            minZoom={0.1}
            maxZoom={2}
            fitView
            fitViewOptions={{ padding: 0.3, maxZoom: 0.8 }}
            deleteKeyCode="Delete"
          >
            <Controls />
            <CustomMiniMap 
              nodeColor={(node) => {
                return node.data.color || 'hsl(var(--primary))';
              }}
              nodeStrokeWidth={3}
              maskColor="hsl(var(--background) / 0.8)"
            />
            <Background gap={12} size={1} />
          </ReactFlow>
          {highlightedIslands.length > 0 && (
            <IslandHighlight islands={highlightedIslands} />
          )}
        </div>
      </div>

      {/* Bottom Status Bar */}
      <div className="h-6 border-t border-border/40 bg-muted/20 flex items-center px-3 text-[11px] text-muted-foreground shrink-0">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-1.5">
            <BarChart3 className="h-3 w-3" />
            <span>{nodes.length} nodes</span>
          </div>
          <div className="h-3 w-px bg-border/40" />
          <div>{edges.length} connections</div>
          {nodes.length > 0 && (
            <>
              <div className="h-3 w-px bg-border/40" />
              <button
                className="flex items-center gap-1.5 hover:text-foreground transition-colors cursor-pointer"
                onClick={() => {
                  if (!validation.isFullyConnected) {
                    highlightIslands(validation.islands);
                  }
                }}
                title={validation.issues.join(', ')}
              >
                {validation.isValid ? (
                  <>
                    <CheckCircle2 className="h-3 w-3 text-green-600 dark:text-green-400" />
                    <span className="text-green-600 dark:text-green-400">Valid graph</span>
                  </>
                ) : (
                  <>
                    <AlertCircle className="h-3 w-3 text-amber-600 dark:text-amber-400" />
                    <span className="text-amber-600 dark:text-amber-400">
                      {validation.issues[0]}
                      {validation.issues.length > 1 && ` +${validation.issues.length - 1} more`}
                    </span>
                  </>
                )}
              </button>
            </>
          )}
          {jsonOutput && (
            <>
              <div className="h-3 w-px bg-border/40" />
              <div className="text-green-600 dark:text-green-400">JSON generated</div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <ThemeProvider defaultTheme="dark" storageKey="zigdag-ui-theme">
      <ReactFlowProvider>
        <FlowEditor />
      </ReactFlowProvider>
    </ThemeProvider>
  );
}

export default App;

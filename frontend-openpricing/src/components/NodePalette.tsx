import { useMemo, useState } from 'react';
import type { OperationType } from '../types/pricing';
import { NODE_CATEGORIES, getNodesByCategory } from '../config/nodeDefinitions';
import { Input } from '@/components/ui/input';
import { Search } from 'lucide-react';
import { cn } from '@/utils/cn';
import { NodeIcon } from './NodeIcon';

interface NodePaletteProps {
  onNodeCreate: (operation: OperationType) => void;
  isVisible: boolean;
}

export default function NodePalette({ onNodeCreate, isVisible }: NodePaletteProps) {
  const [filter, setFilter] = useState('');

  const categorizedNodes = useMemo(() => {
    return NODE_CATEGORIES.map((cat) => ({
      ...cat,
      nodes: getNodesByCategory(cat.id as any).filter((node) => {
        if (!filter) return true;
        const searchTerm = filter.toLowerCase();
        return (
          node.label.toLowerCase().includes(searchTerm) ||
          node.description.toLowerCase().includes(searchTerm) ||
          node.operation.toLowerCase().includes(searchTerm)
        );
      }),
    })).filter((cat) => cat.nodes.length > 0);
  }, [filter]);

  if (!isVisible) return null;

  return (
    <div className="w-[280px] border-r border-border/40 bg-background overflow-hidden h-full flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-border/40">
        <h3 className="text-sm font-semibold mb-3">Nodes</h3>
        
        {/* Search */}
        <div className="relative">
          <Search className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-muted-foreground" />
          <Input
            placeholder="Filter nodes..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="h-8 pl-8 text-xs bg-muted/40 border-border/40"
          />
        </div>
      </div>

      {/* Categories - All Expanded */}
      <div className="flex-1 overflow-auto">
        <div className="p-2">
          {categorizedNodes.map((category, categoryIndex) => (
            <div key={category.id}>
              {categoryIndex > 0 && (
                <hr className="my-3 border-border/40" />
              )}
              
              {/* Category header */}
              <div className="px-2 py-1.5">
                <h4 className="text-[11px] font-medium text-muted-foreground uppercase tracking-wider">
                  {category.label}
                </h4>
              </div>

              {/* Category nodes */}
              <div className="mt-1">
                {category.nodes.map((node) => (
                  <div
                    key={node.operation}
                    onClick={() => onNodeCreate(node.operation)}
                    draggable
                    onDragStart={(e) => {
                      e.dataTransfer.setData('application/reactflow', node.operation);
                      e.dataTransfer.effectAllowed = 'move';
                    }}
                    className={cn(
                      'group relative flex items-start gap-2.5 px-3 py-2 mx-1 rounded-sm',
                      'cursor-grab active:cursor-grabbing',
                      'transition-colors duration-150',
                      'hover:bg-accent/50',
                    )}
                  >
                    {/* Icon */}
                    {node.icon && (
                      <NodeIcon icon={node.icon} className="text-sm shrink-0 mt-px opacity-70" />
                    )}
                    
                    {/* Content */}
                    <div className="flex-1 min-w-0 space-y-0.5">
                      <div className="text-xs font-medium leading-tight flex items-center gap-1.5">
                        <span>{node.label}</span>
                        <div 
                          className="w-1 h-1 rounded-full shrink-0"
                          style={{ backgroundColor: node.color, opacity: 0.6 }}
                        />
                      </div>
                      <div className="text-[10px] leading-snug text-muted-foreground">
                        {node.description}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}

          {categorizedNodes.length === 0 && (
            <div className="p-4 text-center text-xs text-muted-foreground">
              No nodes found
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

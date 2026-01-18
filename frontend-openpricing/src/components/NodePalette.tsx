import { useMemo, useState } from 'react';
import type { OperationType } from '../types/pricing';
import { NODE_CATEGORIES, getNodesByCategory } from '../config/nodeDefinitions';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ChevronDown, ChevronRight, Info } from 'lucide-react';
import { cn } from '@/utils/cn';

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
    <div className="w-[300px] border-r bg-muted/30 p-4 overflow-auto h-full">
      <div className="mb-6">
        <h3 className="text-lg font-bold mb-2">Node Palette</h3>
        <p className="text-xs text-muted-foreground">
          Drag nodes onto the canvas or click to add them
        </p>
      </div>

      <div className="space-y-3">
        {categorizedNodes.map((category) => (
          <div key={category.id}>
            {/* Category header */}
            <Button
              onClick={() =>
                setExpandedCategory(expandedCategory === category.id ? '' : category.id)
              }
              variant="secondary"
              className="w-full justify-between h-auto py-2 px-3"
              style={{
                backgroundColor: category.color,
                color: 'white',
              }}
            >
              <span className="font-semibold text-sm">{category.label}</span>
              {expandedCategory === category.id ? (
                <ChevronDown className="h-4 w-4" />
              ) : (
                <ChevronRight className="h-4 w-4" />
              )}
            </Button>

            {/* Category nodes */}
            {expandedCategory === category.id && (
              <div className="mt-2 space-y-2">
                {category.nodes.map((node) => (
                  <Card
                    key={node.operation}
                    onClick={() => onNodeCreate(node.operation)}
                    draggable
                    onDragStart={(e) => {
                      e.dataTransfer.setData('application/reactflow', node.operation);
                      e.dataTransfer.effectAllowed = 'move';
                    }}
                    className={cn(
                      'cursor-grab active:cursor-grabbing transition-all hover:shadow-md hover:translate-x-1',
                      'border-2'
                    )}
                    style={{ borderColor: node.color }}
                  >
                    <CardHeader className="p-3 pb-2">
                      <div className="flex items-start gap-2">
                        {node.icon && <span className="text-lg">{node.icon}</span>}
                        <div className="flex-1 min-w-0">
                          <CardTitle className="text-xs font-semibold leading-tight">
                            {node.label}
                          </CardTitle>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="p-3 pt-0">
                      <CardDescription className="text-xs leading-relaxed">
                        {node.description}
                      </CardDescription>
                    </CardContent>
                  </Card>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Help section */}
      <Card className="mt-6 bg-blue-50 dark:bg-blue-950 border-blue-200 dark:border-blue-800">
        <CardHeader className="p-3 pb-2">
          <div className="flex items-center gap-2">
            <Info className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            <CardTitle className="text-xs font-semibold text-blue-900 dark:text-blue-100">
              Quick Tips
            </CardTitle>
          </div>
        </CardHeader>
        <CardContent className="p-3 pt-0">
          <ul className="text-xs space-y-1 text-blue-800 dark:text-blue-200">
            <li>• Drag nodes onto canvas</li>
            <li>• Connect nodes with edges</li>
            <li>• Edit node values inline</li>
            <li>• Save to playground to test</li>
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}

import { useState, useEffect, useMemo, useRef } from 'react';
import Fuse from 'fuse.js';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Command } from 'lucide-react';
import type { OperationType } from '@/types/pricing';
import { NODE_DEFINITIONS } from '@/config/nodeDefinitions';
import { cn } from '@/utils/cn';

interface CommandPaletteProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelectNode: (operation: OperationType) => void;
}

export function CommandPalette({ open, onOpenChange, onSelectNode }: CommandPaletteProps) {
  const [search, setSearch] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  // Create searchable list of nodes
  const nodeList = useMemo(() => {
    return Object.values(NODE_DEFINITIONS).map(node => ({
      ...node,
      searchText: `${node.label} ${node.description} ${node.operation} ${node.category}`,
    }));
  }, []);

  // Setup fuzzy search
  const fuse = useMemo(() => {
    return new Fuse(nodeList, {
      keys: ['label', 'description', 'operation', 'category'],
      threshold: 0.3,
      includeScore: true,
    });
  }, [nodeList]);

  // Filter results
  const results = useMemo(() => {
    if (!search.trim()) {
      return nodeList;
    }
    return fuse.search(search).map(result => result.item);
  }, [search, fuse, nodeList]);

  // Reset state when dialog opens
  useEffect(() => {
    if (open) {
      setSearch('');
      setSelectedIndex(0);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [open]);

  // Reset selection when results change
  useEffect(() => {
    setSelectedIndex(0);
  }, [results]);

  // Handle keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (!open) return;

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault();
          setSelectedIndex(prev => (prev + 1) % results.length);
          break;
        case 'ArrowUp':
          e.preventDefault();
          setSelectedIndex(prev => (prev - 1 + results.length) % results.length);
          break;
        case 'Enter':
          e.preventDefault();
          if (results[selectedIndex]) {
            handleSelect(results[selectedIndex].operation);
          }
          break;
        case 'Escape':
          e.preventDefault();
          onOpenChange(false);
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [open, results, selectedIndex]);

  const handleSelect = (operation: OperationType) => {
    onSelectNode(operation);
    onOpenChange(false);
    setSearch('');
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl p-0">
        <div className="flex flex-col">
          {/* Search Input */}
          <div className="flex items-center border-b px-4 py-3">
            <Command className="mr-2 h-5 w-5 shrink-0 opacity-50" />
            <Input
              ref={inputRef}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search for a node... (try 'add', 'input', 'conditional')"
              className="border-0 shadow-none focus-visible:ring-0 h-10 text-base"
            />
            <kbd className="hidden sm:inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100">
              ESC
            </kbd>
          </div>

          {/* Results */}
          <div className="max-h-[400px] overflow-y-auto p-2">
            {results.length === 0 ? (
              <div className="py-6 text-center text-sm text-muted-foreground">
                No nodes found
              </div>
            ) : (
              <div className="space-y-1">
                {results.map((node, index) => (
                  <button
                    key={node.operation}
                    onClick={() => handleSelect(node.operation)}
                    onMouseEnter={() => setSelectedIndex(index)}
                    className={cn(
                      "w-full flex items-center gap-3 rounded-md px-3 py-2.5 text-left transition-colors",
                      "hover:bg-accent hover:text-accent-foreground",
                      selectedIndex === index && "bg-accent text-accent-foreground"
                    )}
                  >
                    <div
                      className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md text-xl"
                      style={{
                        backgroundColor: `${node.color}20`,
                        color: node.color,
                        border: `2px solid ${node.color}`,
                      }}
                    >
                      {node.icon || '□'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-sm">{node.label}</div>
                      <div className="text-xs text-muted-foreground truncate">
                        {node.description}
                      </div>
                    </div>
                    <div className="text-xs text-muted-foreground hidden sm:block">
                      {node.category}
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Footer hint */}
          <div className="border-t px-4 py-2 text-xs text-muted-foreground flex items-center justify-between">
            <div className="flex items-center gap-4">
              <span className="flex items-center gap-1">
                <kbd className="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium opacity-100">
                  ↑↓
                </kbd>
                <span>Navigate</span>
              </span>
              <span className="flex items-center gap-1">
                <kbd className="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium opacity-100">
                  ↵
                </kbd>
                <span>Select</span>
              </span>
            </div>
            <span className="text-muted-foreground/60">
              {results.length} {results.length === 1 ? 'result' : 'results'}
            </span>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

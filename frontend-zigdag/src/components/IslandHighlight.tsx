import type { GraphIsland } from '../utils/graphValidation';

interface IslandLegendProps {
  islands: GraphIsland[];
}

export function IslandHighlight({ islands }: IslandLegendProps) {
  if (islands.length === 0) return null;

  return (
    <div className="absolute top-16 left-4 z-50 pointer-events-none">
      <div className="bg-background/95 border border-border rounded shadow-lg p-3 space-y-2 pointer-events-auto">
        <div className="text-xs font-semibold text-foreground mb-2">Disconnected Islands</div>
        {islands.map((island) => (
          <div key={island.id} className="flex items-center gap-2">
            <div
              className="w-4 h-4 border border-border/40 shrink-0"
              style={{ backgroundColor: island.color }}
            />
            <div className="text-xs text-muted-foreground">
              Island {island.id + 1}
              <span className="text-[10px] ml-1">({island.nodeIds.length} nodes)</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

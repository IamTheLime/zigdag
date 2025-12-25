import { memo, useCallback, useState } from 'react';
import { Handle, Position, NodeProps } from 'reactflow';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { X, Plus, Trash2 } from 'lucide-react';
import type { ConditionalValueMap } from '@/types/pricing';

interface PricingNodeData {
  operation: string;
  label: string;
  description: string;
  category: string;
  color: string;
  icon?: string;
  inputCount: number | 'variable';
  hasValue?: boolean;
  hasWeights?: boolean;
  hasAllowedValues?: boolean;
  hasConditionalValues?: boolean;
  value?: number;
  stringValue?: string;
  allowedValues?: number[];
  conditionalValues?: ConditionalValueMap;
  weights?: number[];
  customId?: string;
  customDescription?: string;
  onChange?: (data: Partial<PricingNodeData>) => void;
  onDelete?: () => void;
}

/**
 * Custom node component for OpenPricing with modern UI
 */
function PricingNode({ data, selected, id }: NodeProps<PricingNodeData>) {
  const [newCondKey, setNewCondKey] = useState('');
  const [newCondValue, setNewCondValue] = useState('');

  const handleValueChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (data.onChange) {
        const val = e.target.value;
        data.onChange({ value: val === '' ? undefined : parseFloat(val) });
      }
    },
    [data]
  );

  const handleStringValueChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (data.onChange) {
        data.onChange({ stringValue: e.target.value });
      }
    },
    [data]
  );

  const handleAllowedValuesChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (data.onChange) {
        const values = e.target.value
          .split(',')
          .map((v) => parseFloat(v.trim()))
          .filter((v) => !isNaN(v));
        data.onChange({ allowedValues: values });
      }
    },
    [data]
  );

  const handleCustomIdChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (data.onChange) {
        data.onChange({ customId: e.target.value });
      }
    },
    [data]
  );

  const handleCustomDescriptionChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (data.onChange) {
        data.onChange({ customDescription: e.target.value });
      }
    },
    [data]
  );

  const handleAddConditionalValue = useCallback(() => {
    if (!newCondKey || newCondValue === '') return;
    if (data.onChange) {
      const currentValues = data.conditionalValues || {};
      data.onChange({
        conditionalValues: {
          ...currentValues,
          [newCondKey]: parseFloat(newCondValue),
        },
      });
      setNewCondKey('');
      setNewCondValue('');
    }
  }, [data, newCondKey, newCondValue]);

  const handleRemoveConditionalValue = useCallback(
    (key: string) => {
      if (data.onChange) {
        const currentValues = { ...(data.conditionalValues || {}) };
        delete currentValues[key];
        data.onChange({ conditionalValues: currentValues });
      }
    },
    [data]
  );

  const showTargetHandle = data.inputCount !== 0;
  const showSourceHandle = true;

  return (
    <Card
      className="min-w-[240px] transition-shadow"
      style={{
        borderColor: data.color,
        borderWidth: '2px',
        boxShadow: selected ? `0 0 0 2px ${data.color}` : undefined,
      }}
    >
      {/* Delete button */}
      {data.onDelete && (
        <Button
          onClick={(e) => {
            e.stopPropagation();
            data.onDelete?.();
          }}
          variant="destructive"
          size="icon"
          className="absolute -top-2 -right-2 h-6 w-6 rounded-full z-10"
        >
          <X className="h-4 w-4" />
        </Button>
      )}

      {/* Target handles */}
      {showTargetHandle && (
        <>
          {data.inputCount === 'variable' || data.inputCount > 2 ? (
            <>
              <Handle
                type="target"
                position={Position.Left}
                id="target-top"
                style={{ top: '25%', background: data.color }}
                className="w-3 h-3"
              />
              <Handle
                type="target"
                position={Position.Left}
                id="target-middle"
                style={{ top: '50%', background: data.color }}
                className="w-3 h-3"
              />
              <Handle
                type="target"
                position={Position.Left}
                id="target-bottom"
                style={{ top: '75%', background: data.color }}
                className="w-3 h-3"
              />
            </>
          ) : data.inputCount === 2 ? (
            <>
              <Handle
                type="target"
                position={Position.Left}
                id="target-a"
                style={{ top: '35%', background: data.color }}
                className="w-3 h-3"
              />
              <div 
                className="absolute left-1 text-[10px] font-mono text-muted-foreground pointer-events-none"
                style={{ top: '35%', transform: 'translateY(-50%)' }}
              >
                a
              </div>
              <Handle
                type="target"
                position={Position.Left}
                id="target-b"
                style={{ top: '65%', background: data.color }}
                className="w-3 h-3"
              />
              <div 
                className="absolute left-1 text-[10px] font-mono text-muted-foreground pointer-events-none"
                style={{ top: '65%', transform: 'translateY(-50%)' }}
              >
                b
              </div>
            </>
          ) : (
            <Handle
              type="target"
              position={Position.Left}
              id="target"
              style={{ background: data.color }}
              className="w-3 h-3"
            />
          )}
        </>
      )}

      <CardHeader className="p-4 pb-2">
        <div className="flex items-center gap-2">
          {data.icon && <span className="text-xl">{data.icon}</span>}
          <div className="flex-1">
            <CardTitle className="text-sm">{data.label}</CardTitle>
            <CardDescription className="text-xs">{data.operation}</CardDescription>
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 pt-0 space-y-3">
        <p className="text-xs text-muted-foreground">{data.description}</p>

        {/* Custom Node ID */}
        <div className="space-y-1">
          <Label htmlFor={`id-${id}`} className="text-xs">
            Node ID
          </Label>
          <Input
            id={`id-${id}`}
            type="text"
            value={data.customId || ''}
            onChange={handleCustomIdChange}
            placeholder={id}
            className="h-8 text-xs"
          />
        </div>

        {/* Custom Description */}
        <div className="space-y-1">
          <Label htmlFor={`desc-${id}`} className="text-xs">
            Description
          </Label>
          <Input
            id={`desc-${id}`}
            type="text"
            value={data.customDescription || ''}
            onChange={handleCustomDescriptionChange}
            placeholder={data.description}
            className="h-8 text-xs"
          />
        </div>

        {/* Numeric Value - only for numeric constants */}
        {data.hasValue && data.operation !== 'constant_input_str' && (
          <div className="space-y-1">
            <Label htmlFor={`value-${id}`} className="text-xs">
              Value
            </Label>
            <Input
              id={`value-${id}`}
              type="number"
              value={data.value !== undefined ? data.value : ''}
              onChange={handleValueChange}
              step="any"
              placeholder="0.0"
              className="h-8 text-xs"
            />
          </div>
        )}

        {/* String Value */}
        {data.operation === 'constant_input_str' && (
          <div className="space-y-1">
            <Label htmlFor={`strval-${id}`} className="text-xs">
              String Value
            </Label>
            <Input
              id={`strval-${id}`}
              type="text"
              value={data.stringValue || ''}
              onChange={handleStringValueChange}
              className="h-8 text-xs"
            />
          </div>
        )}

        {/* Allowed Values */}
        {data.hasAllowedValues && (
          <div className="space-y-1">
            <Label htmlFor={`allowed-${id}`} className="text-xs">
              Allowed Values (comma-separated)
            </Label>
            <Input
              id={`allowed-${id}`}
              type="text"
              value={data.allowedValues?.join(', ') || ''}
              onChange={handleAllowedValuesChange}
              placeholder="e.g., 100, 200, 300"
              className="h-8 text-xs"
            />
          </div>
        )}

        {/* Conditional Values */}
        {data.hasConditionalValues && (
          <div className="space-y-2">
            <Label className="text-xs">Conditional Value Mappings</Label>
            
            {/* Existing mappings */}
            {data.conditionalValues && Object.keys(data.conditionalValues).length > 0 && (
              <div className="space-y-1">
                {Object.entries(data.conditionalValues).map(([key, value]) => (
                  <div key={key} className="flex items-center gap-2">
                    <div className="flex-1 grid grid-cols-2 gap-2 text-xs bg-muted p-2 rounded">
                      <div className="font-medium">{key}</div>
                      <div className="text-right">{value}</div>
                    </div>
                    <Button
                      onClick={() => handleRemoveConditionalValue(key)}
                      variant="ghost"
                      size="icon"
                      className="h-6 w-6"
                    >
                      <Trash2 className="h-3 w-3" />
                    </Button>
                  </div>
                ))}
              </div>
            )}

            {/* Add new mapping */}
            <div className="space-y-1">
              <div className="grid grid-cols-2 gap-2">
                <Input
                  type="text"
                  value={newCondKey}
                  onChange={(e) => setNewCondKey(e.target.value)}
                  placeholder="Input key"
                  className="h-8 text-xs"
                />
                <Input
                  type="number"
                  value={newCondValue}
                  onChange={(e) => setNewCondValue(e.target.value)}
                  placeholder="Output value"
                  step="any"
                  className="h-8 text-xs"
                />
              </div>
              <Button
                onClick={handleAddConditionalValue}
                variant="outline"
                size="sm"
                className="w-full h-7 text-xs"
                disabled={!newCondKey || newCondValue === ''}
              >
                <Plus className="h-3 w-3 mr-1" />
                Add Mapping
              </Button>
            </div>
          </div>
        )}

        {/* Input count indicator */}
        <div className="text-xs text-muted-foreground pt-1">
          {data.inputCount === 0
            ? 'No inputs'
            : data.inputCount === 'variable'
            ? 'Variable inputs'
            : `${data.inputCount} input${data.inputCount > 1 ? 's' : ''}`}
        </div>
      </CardContent>

      {/* Source handle */}
      {showSourceHandle && (
        <Handle
          type="source"
          position={Position.Right}
          id="source"
          style={{ background: data.color }}
          className="w-3 h-3"
        />
      )}
    </Card>
  );
}

export default memo(PricingNode);

import { memo, useCallback, useState } from 'react';
import { Handle, Position, NodeProps } from 'reactflow';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { X, Plus } from 'lucide-react';
import type { ConditionalValueMap } from '@/types/pricing';
import { NodeIcon } from './NodeIcon';

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
  hasAllowedStrValues?: boolean;
  hasConditionalValues?: boolean;
  value?: number;
  stringValue?: string;
  allowedValues?: number[];
  allowedStrValues?: string[];
  defaultValue?: number;
  defaultStrValue?: string;
  conditionalValues?: ConditionalValueMap;
  weights?: number[];
  customId?: string;
  customDescription?: string;
  islandColor?: string;
  islandId?: number;
  onChange?: (data: Partial<PricingNodeData>) => void;
  onDelete?: () => void;
}

/**
 * Custom node component for OpenPricing with modern UI
 */
function PricingNode({ data, selected, id }: NodeProps<PricingNodeData>) {
  const [newCondKey, setNewCondKey] = useState('');
  const [newCondValue, setNewCondValue] = useState('');
  const [newAllowedStrValue, setNewAllowedStrValue] = useState('');
  const [newAllowedNumValue, setNewAllowedNumValue] = useState('');

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

  const handleAddAllowedNumValue = useCallback(() => {
    if (!newAllowedNumValue || newAllowedNumValue === '') return;
    const numValue = parseFloat(newAllowedNumValue);
    if (isNaN(numValue)) return;
    
    if (data.onChange) {
      const currentValues = data.allowedValues || [];
      if (!currentValues.includes(numValue)) {
        data.onChange({
          allowedValues: [...currentValues, numValue],
        });
      }
      setNewAllowedNumValue('');
    }
  }, [data, newAllowedNumValue]);

  const handleRemoveAllowedNumValue = useCallback(
    (value: number) => {
      if (data.onChange) {
        const currentValues = data.allowedValues || [];
        data.onChange({
          allowedValues: currentValues.filter((v) => v !== value),
        });
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

  const handleAddAllowedStrValue = useCallback(() => {
    if (!newAllowedStrValue) return;
    if (data.onChange) {
      const currentValues = data.allowedStrValues || [];
      if (!currentValues.includes(newAllowedStrValue)) {
        data.onChange({
          allowedStrValues: [...currentValues, newAllowedStrValue],
        });
      }
      setNewAllowedStrValue('');
    }
  }, [data, newAllowedStrValue]);

  const handleRemoveAllowedStrValue = useCallback(
    (value: string) => {
      if (data.onChange) {
        const currentValues = data.allowedStrValues || [];
        data.onChange({
          allowedStrValues: currentValues.filter((v) => v !== value),
        });
      }
    },
    [data]
  );

  const showTargetHandle = data.inputCount !== 0;
  const showSourceHandle = true;

  return (
    <Card
      className="min-w-[240px] transition-all duration-200 rounded-none"
      style={{
        borderColor: `${data.color}${selected ? '90' : '40'}`, // 40% opacity base, 90% when selected 
        borderWidth: '1px',
        backgroundColor: data.islandColor ? `${data.islandColor}40` : undefined, // 25% opacity island color
      }}
    >
      {/* Delete button */}
      {data.onDelete && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            data.onDelete?.();
          }}
          className="absolute -top-2 -right-2 h-5 w-5 bg-muted border border-border flex items-center justify-center z-10 hover:border-red-500 transition-colors group"
        >
          <X className="h-3 w-3 text-red-300 group-hover:text-red-500" />
        </button>
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
                className="w-3 h-3 z-10"
              />
              <div 
                className="absolute -left-0.5 bg-muted border border-border/40 px-1 pointer-events-none text-[9px] font-medium text-foreground/70 z-20"
                style={{ top: 'calc(35% + 10px)' }}
              >
                1
              </div>
              <Handle
                type="target"
                position={Position.Left}
                id="target-b"
                style={{ top: '65%', background: data.color }}
                className="w-3 h-3 z-10"
              />
              <div 
                className="absolute -left-0.5 bg-muted border border-border/40 px-1 pointer-events-none text-[9px] font-medium text-foreground/70 z-20"
                style={{ top: 'calc(65% + 10px)' }}
              >
                2
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
          {data.icon && <NodeIcon icon={data.icon} className="text-base opacity-70" />}
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

        {/* Allowed Values (numeric) */}
        {data.hasAllowedValues && (
          <div className="space-y-2">
            <Label className="text-xs">Allowed Values</Label>
            
            {/* Existing values */}
            {data.allowedValues && data.allowedValues.length > 0 && (
              <div className="space-y-1">
                {data.allowedValues.map((value) => (
                  <div key={value} className="flex items-center gap-2">
                    <div className="flex-1 text-xs bg-muted p-2 rounded font-medium">
                      {value}
                    </div>
                    <button
                      onClick={() => handleRemoveAllowedNumValue(value)}
                      className="h-5 w-5 bg-muted border border-border flex items-center justify-center hover:border-red-500 transition-colors group shrink-0"
                    >
                      <X className="h-3 w-3 text-red-300 group-hover:text-red-500" />
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* Add new value */}
            <div className="space-y-1">
              <div className="flex gap-2">
                <Input
                  type="number"
                  value={newAllowedNumValue}
                  onChange={(e) => setNewAllowedNumValue(e.target.value)}
                  placeholder="Enter allowed value"
                  step="any"
                  className="h-8 text-xs flex-1"
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddAllowedNumValue();
                    }
                  }}
                />
              </div>
              <Button
                onClick={handleAddAllowedNumValue}
                variant="outline"
                size="sm"
                className="w-full h-7 text-xs"
                disabled={!newAllowedNumValue || newAllowedNumValue === ''}
              >
                <Plus className="h-3 w-3 mr-1" />
                Add Value
              </Button>
            </div>

            {/* Default Value for numeric dynamic inputs */}
            {data.allowedValues && data.allowedValues.length > 0 && (
              <div className="space-y-1.5 mt-3">
                <Label className="text-xs text-muted-foreground">Default Value</Label>
                <Input
                  type="number"
                  value={data.defaultValue !== undefined ? data.defaultValue : ''}
                  onChange={(e) => {
                    const val = e.target.value === '' ? undefined : parseFloat(e.target.value);
                    if (data.onChange) {
                      data.onChange({ defaultValue: val });
                    }
                  }}
                  placeholder="Optional default"
                  step="any"
                  className="h-8 text-xs"
                />
                {data.defaultValue !== undefined && 
                 data.allowedValues && 
                 !data.allowedValues.includes(data.defaultValue) && (
                  <div className="text-[10px] text-destructive flex items-center gap-1">
                    <span>⚠</span>
                    <span>Default must be in allowed values</span>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Allowed String Values */}
        {data.hasAllowedStrValues && (
          <div className="space-y-2">
            <Label className="text-xs">Allowed Values</Label>
            
            {/* Existing values */}
            {data.allowedStrValues && data.allowedStrValues.length > 0 && (
              <div className="space-y-1">
                {data.allowedStrValues.map((value) => (
                  <div key={value} className="flex items-center gap-2">
                    <div className="flex-1 text-xs bg-muted p-2 rounded font-medium">
                      {value}
                    </div>
                    <button
                      onClick={() => handleRemoveAllowedStrValue(value)}
                      className="h-5 w-5 bg-muted border border-border flex items-center justify-center hover:border-red-500 transition-colors group shrink-0"
                    >
                      <X className="h-3 w-3 text-red-300 group-hover:text-red-500" />
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* Add new value */}
            <div className="space-y-1">
              <div className="flex gap-2">
                <Input
                  type="text"
                  value={newAllowedStrValue}
                  onChange={(e) => setNewAllowedStrValue(e.target.value)}
                  placeholder="Enter allowed value"
                  className="h-8 text-xs flex-1"
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddAllowedStrValue();
                    }
                  }}
                />
              </div>
              <Button
                onClick={handleAddAllowedStrValue}
                variant="outline"
                size="sm"
                className="w-full h-7 text-xs"
                disabled={!newAllowedStrValue}
              >
                <Plus className="h-3 w-3 mr-1" />
                Add Value
              </Button>
            </div>

            {/* Default Value for string dynamic inputs */}
            {data.allowedStrValues && data.allowedStrValues.length > 0 && (
              <div className="space-y-1.5 mt-3">
                <Label className="text-xs text-muted-foreground">Default Value</Label>
                <Input
                  type="text"
                  value={data.defaultStrValue || ''}
                  onChange={(e) => {
                    if (data.onChange) {
                      data.onChange({ defaultStrValue: e.target.value || undefined });
                    }
                  }}
                  placeholder="Optional default"
                  className="h-8 text-xs"
                />
                {data.defaultStrValue && 
                 data.allowedStrValues && 
                 !data.allowedStrValues.includes(data.defaultStrValue) && (
                  <div className="text-[10px] text-destructive flex items-center gap-1">
                    <span>⚠</span>
                    <span>Default must be in allowed values</span>
                  </div>
                )}
              </div>
            )}
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
                    <button
                      onClick={() => handleRemoveConditionalValue(key)}
                      className="h-5 w-5 bg-muted border border-border flex items-center justify-center hover:border-red-500 transition-colors group shrink-0"
                    >
                      <X className="h-3 w-3 text-red-300 group-hover:text-red-500" />
                    </button>
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

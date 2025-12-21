import { memo, useCallback } from 'react';
import { Handle, Position, NodeProps } from 'reactflow';

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
  value?: number;
  stringValue?: string;
  allowedValues?: number[];
  weights?: number[];
  customId?: string;
  customDescription?: string;
  onChange?: (data: Partial<PricingNodeData>) => void;
  onDelete?: () => void;
}

/**
 * Custom node component for OpenPricing
 */
function PricingNode({ data, selected, id }: NodeProps<PricingNodeData>) {
  const handleValueChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (data.onChange) {
        const val = e.target.value;
        // Allow empty string or valid number
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

  const showTargetHandle = data.inputCount !== 0;
  const showSourceHandle = true; // All nodes can output

  return (
    <div
      style={{
        background: 'white',
        border: `2px solid ${data.color}`,
        borderRadius: '8px',
        padding: '12px',
        minWidth: '200px',
        boxShadow: selected ? `0 0 0 2px ${data.color}` : '0 2px 8px rgba(0,0,0,0.1)',
        transition: 'box-shadow 0.2s',
        position: 'relative',
      }}
    >
      {/* Delete button */}
      {data.onDelete && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            data.onDelete?.();
          }}
          style={{
            position: 'absolute',
            top: '4px',
            right: '4px',
            width: '20px',
            height: '20px',
            border: 'none',
            borderRadius: '50%',
            background: '#f44336',
            color: 'white',
            cursor: 'pointer',
            fontSize: '12px',
            fontWeight: 'bold',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 0,
            lineHeight: 1,
          }}
          title="Delete node"
        >
          ×
        </button>
      )}
      {/* Target handles - multiple for variadic operations */}
      {showTargetHandle && (
        <>
          {data.inputCount === 'variable' || data.inputCount > 2 ? (
            // Multiple target handles for variadic operations
            <>
              <Handle
                type="target"
                position={Position.Left}
                id="target-top"
                style={{ top: '25%', background: data.color }}
              />
              <Handle
                type="target"
                position={Position.Left}
                id="target-middle"
                style={{ top: '50%', background: data.color }}
              />
              <Handle
                type="target"
                position={Position.Left}
                id="target-bottom"
                style={{ top: '75%', background: data.color }}
              />
            </>
          ) : data.inputCount === 2 ? (
            // Two target handles for binary operations
            <>
              <Handle
                type="target"
                position={Position.Left}
                id="target-left"
                style={{ top: '33%', background: data.color }}
              />
              <Handle
                type="target"
                position={Position.Left}
                id="target-right"
                style={{ top: '67%', background: data.color }}
              />
            </>
          ) : (
            // Single target handle for unary operations
            <Handle
              type="target"
              position={Position.Left}
              id="target"
              style={{ background: data.color }}
            />
          )}
        </>
      )}

      {/* Node header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          marginBottom: '8px',
          paddingBottom: '8px',
          borderBottom: `1px solid ${data.color}40`,
        }}
      >
        {data.icon && <span style={{ fontSize: '20px' }}>{data.icon}</span>}
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333' }}>
            {data.label}
          </div>
          <div style={{ fontSize: '11px', color: '#666' }}>{data.operation}</div>
        </div>
      </div>

      {/* Node description */}
      <div style={{ fontSize: '12px', color: '#666', marginBottom: '8px' }}>
        {data.description}
      </div>

      {/* Custom Node ID */}
      <div style={{ marginBottom: '8px' }}>
        <label style={{ fontSize: '11px', color: '#666', display: 'block', marginBottom: '4px' }}>
          Node ID:
        </label>
        <input
          type="text"
          value={data.customId || ''}
          onChange={handleCustomIdChange}
          placeholder={id}
          style={{
            width: '100%',
            padding: '6px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '12px',
          }}
        />
      </div>

      {/* Custom Description */}
      <div style={{ marginBottom: '8px' }}>
        <label style={{ fontSize: '11px', color: '#666', display: 'block', marginBottom: '4px' }}>
          Description:
        </label>
        <input
          type="text"
          value={data.customDescription || ''}
          onChange={handleCustomDescriptionChange}
          placeholder={data.description}
          style={{
            width: '100%',
            padding: '6px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '12px',
          }}
        />
      </div>

      {/* Value input for constants */}
      {data.hasValue && (
        <div style={{ marginBottom: '8px' }}>
          <label style={{ fontSize: '11px', color: '#666', display: 'block', marginBottom: '4px' }}>
            Value:
          </label>
          <input
            type="number"
            value={data.value !== undefined ? data.value : ''}
            onChange={handleValueChange}
            step="any"
            placeholder="0.0"
            style={{
              width: '100%',
              padding: '6px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '12px',
            }}
          />
        </div>
      )}

      {/* String value input */}
      {data.operation === 'constant_input_str' && (
        <div style={{ marginBottom: '8px' }}>
          <label style={{ fontSize: '11px', color: '#666', display: 'block', marginBottom: '4px' }}>
            String Value:
          </label>
          <input
            type="text"
            value={data.stringValue || ''}
            onChange={handleStringValueChange}
            style={{
              width: '100%',
              padding: '6px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '12px',
            }}
          />
        </div>
      )}

      {/* Allowed values for dynamic inputs */}
      {data.hasAllowedValues && (
        <div style={{ marginBottom: '8px' }}>
          <label style={{ fontSize: '11px', color: '#666', display: 'block', marginBottom: '4px' }}>
            Allowed Values (comma-separated):
          </label>
          <input
            type="text"
            value={data.allowedValues?.join(', ') || ''}
            onChange={handleAllowedValuesChange}
            placeholder="e.g., 100, 200, 300"
            style={{
              width: '100%',
              padding: '6px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '12px',
            }}
          />
        </div>
      )}

      {/* Input count indicator */}
      <div style={{ fontSize: '10px', color: '#999', marginTop: '8px' }}>
        {data.inputCount === 0
          ? 'No inputs'
          : data.inputCount === 'variable'
          ? 'Variable inputs'
          : `${data.inputCount} input${data.inputCount > 1 ? 's' : ''}`}
      </div>

      {/* Source handle - output */}
      {showSourceHandle && (
        <Handle
          type="source"
          position={Position.Right}
          id="source"
          style={{ background: data.color }}
        />
      )}
    </div>
  );
}

export default memo(PricingNode);

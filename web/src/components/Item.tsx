import React from 'react';
import { twMerge } from 'tailwind-merge';
import { useDraggable } from '@dnd-kit/core';
import { Tooltip } from './Tooltip';
import { ContextMenu } from './ContextMenu';

// Constants for slot size (must match Grid)
const SLOT_SIZE = 64;
const GAP = 2; // px

interface ItemProps {
    name: string;
    count: number;
    label?: string;
    image?: string;
    size?: { x: number; y: number };
    slot: { x: number; y: number }; // 1-indexed
    isDragging?: boolean;
    rotated?: boolean;
    isEquipment?: boolean;
    type?: string;
}

// Pure Presentational Component
export const ItemView: React.FC<ItemProps & {
    style?: React.CSSProperties,
    listeners?: any,
    attributes?: any,
    innerRef?: (element: HTMLElement | null) => void,
    isOverlay?: boolean
}> = (props) => {
    const {
        name, count, label, image, isDragging, isOverlay,
        style, listeners, attributes, innerRef
    } = props;

    const [showTooltip, setShowTooltip] = React.useState(false);
    const [tooltipPos, setTooltipPos] = React.useState({ x: 0, y: 0 });
    const [showContextMenu, setShowContextMenu] = React.useState(false);
    const [contextMenuPos, setContextMenuPos] = React.useState({ x: 0, y: 0 });

    const handleMouseEnter = (e: React.MouseEvent) => {
        if (!isDragging && !showContextMenu && !isOverlay) {
            setShowTooltip(true);
            setTooltipPos({ x: e.clientX, y: e.clientY });
        }
    };

    const handleMouseMove = (e: React.MouseEvent) => {
        if (showTooltip) {
            setTooltipPos({ x: e.clientX, y: e.clientY });
        }
    };

    const handleMouseLeave = () => {
        setShowTooltip(false);
    };

    const handleContextMenu = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (isOverlay) return;

        setShowTooltip(false);
        setContextMenuPos({ x: e.clientX, y: e.clientY });
        setShowContextMenu(true);
    };

    // Close tooltip/menu if dragging starts
    React.useEffect(() => {
        if (isDragging) {
            setShowTooltip(false);
            setShowContextMenu(false);
        }
    }, [isDragging]);

    const contextOptions = [
        { label: 'Detalhes', action: () => console.log('Detalhes', name) },
        { label: 'Usar', action: () => console.log('Usar', name) },
        { label: 'Descarregar', action: () => console.log('Descarregar', name) },
        { label: 'Dobrar', action: () => console.log('Dobrar', name) },
    ];

    return (
        <>
            <div
                ref={innerRef}
                {...listeners}
                {...attributes}
                className={twMerge(
                    "absolute bg-zinc-800 border border-zinc-600 rounded flex flex-col items-center justify-center select-none overflow-hidden transition-none shadow-lg hover:border-orange-500/50 group cursor-grab active:cursor-grabbing",
                    (isDragging || isOverlay) && "z-50 shadow-orange-500/20 scale-105 ring-2 ring-orange-500",
                    isDragging && !isOverlay && "opacity-50" // Ghost item visible but transparent
                )}
                style={style}
                onMouseEnter={handleMouseEnter}
                onMouseMove={handleMouseMove}
                onMouseLeave={handleMouseLeave}
                onContextMenu={handleContextMenu}
            >
                {image ? (
                    <img src={image} alt={name} className="w-full h-full object-contain p-1 pointer-events-none" />
                ) : (
                    <span className="text-xs text-center text-gray-300 px-1 pointer-events-none">{label || name}</span>
                )}
                {count > 1 && (
                    <span className="absolute bottom-0 right-0 p-0.5 text-[0.6rem] font-bold bg-black/50 text-white rounded-tl pointer-events-none">
                        {count}
                    </span>
                )}
            </div>

            <Tooltip
                label={label || name}
                visible={showTooltip && !isDragging && !showContextMenu && !isOverlay}
                position={tooltipPos}
            />

            <ContextMenu
                visible={showContextMenu && !isDragging && !isOverlay}
                position={contextMenuPos}
                options={contextOptions}
                onClose={() => setShowContextMenu(false)}
            />
        </>
    );
};

// Connected Component
export const Item: React.FC<ItemProps> = (props) => {
    const { name, size, slot, rotated, isEquipment } = props;

    const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
        id: name,
        data: { name, size, slot, rotated },
    });

    const currentSize = (rotated) ? { x: size?.y || 1, y: size?.x || 1 } : (size || { x: 1, y: 1 });

    const style = isEquipment ? {
        // Equipment Item Style: Centered, relative to slot, FULL FILL
        width: '100%',
        height: '100%',
        position: 'absolute' as const, // Change to absolute to ensure it fills the relative parent
        top: 0,
        left: 0,
        zIndex: isDragging ? 100 : undefined,
        transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0)` : undefined,
    } : {
        // Grid Item Style: Absolute, based on slot index
        width: currentSize.x * SLOT_SIZE + (currentSize.x - 1) * GAP,
        height: currentSize.y * SLOT_SIZE + (currentSize.y - 1) * GAP,
        left: (slot.x - 1) * (SLOT_SIZE + GAP),
        top: (slot.y - 1) * (SLOT_SIZE + GAP),
        transform: (transform && !isDragging)
            ? `translate3d(${transform.x}px, ${transform.y}px, 0)`
            : undefined,
        zIndex: isDragging ? 100 : undefined,
    };

    return (
        <ItemView
            {...props}
            isDragging={isDragging}
            innerRef={setNodeRef}
            listeners={listeners}
            attributes={attributes}
            style={style}
        />
    );
};

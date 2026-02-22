import React from 'react';
import { useDroppable } from '@dnd-kit/core';
import { Item } from './Item';
import { useInventoryStore, type ItemType } from '../store/inventoryStore';
import { ArrowDownToLine } from 'lucide-react';

interface EquipmentSlotProps {
    slotId: string;
    label?: string;
    acceptedTypes: ItemType[];
    placeholderImage?: string; // Optional bg image
    className?: string;
    children?: React.ReactNode;
}

export const EquipmentSlot: React.FC<EquipmentSlotProps> = React.memo(({
    slotId,
    label,
    acceptedTypes,
    className,
    children
}) => {
    const item = useInventoryStore(state => state.equipment[slotId]);
    const dragCompat = useInventoryStore(state => state.dragCompatibility);

    const droppableId = `equip-${slotId}`;
    const isCompatibleTarget = dragCompat && dragCompat.targetIds.has(droppableId);

    const { setNodeRef, isOver } = useDroppable({
        id: droppableId,
        data: {
            type: 'equipment',
            slotId,
            acceptedTypes
        }
    });

    return (
        <div className="flex flex-col">
            {label && <span className="text-text-muted text-xs uppercase font-bold tracking-wider pl-2 border border-border-dark">{label}</span>}
            <div
                ref={setNodeRef}
                className={`
                    relative bg-surface-light/40 border overflow-hidden flex items-center justify-center shrink-0
                    ${isOver ? 'border-primary/80 bg-primary/10' : 'border-border-dark/30'}
                    ${isCompatibleTarget ? 'ring-2 ring-green-400/80 border-green-400/60 shadow-[0_0_12px_rgba(74,222,128,0.3)]' : ''}
                    transition-colors duration-200
                    ${className}
                `}
            >
                {item ? (
                    <Item
                        {...item}
                        isEquipment
                        containerId={`equip-${slotId}`}
                    />
                ) : (
                    <>
                        <div className="text-text-subtle text-xs text-center p-2 opacity-50 select-none">
                            EMPTY
                        </div>
                        {isCompatibleTarget && (
                            <div className="absolute inset-0 bg-green-500/15 flex items-center justify-center pointer-events-none animate-pulse">
                                <ArrowDownToLine className="w-6 h-6 text-green-400 drop-shadow-lg" />
                            </div>
                        )}
                    </>
                )}
                {children}
            </div>
        </div>
    );
});

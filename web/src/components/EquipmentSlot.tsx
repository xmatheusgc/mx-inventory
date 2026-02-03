import React from 'react';
import { useDroppable } from '@dnd-kit/core';
import { ItemView } from './Item';
import { useInventoryStore, type ItemType } from '../store/inventoryStore';

interface EquipmentSlotProps {
    slotId: string;
    label?: string;
    acceptedTypes: ItemType[];
    placeholderImage?: string; // Optional bg image
    className?: string;
}

export const EquipmentSlot: React.FC<EquipmentSlotProps> = ({
    slotId,
    label,
    acceptedTypes,
    className
}) => {
    const { equipment } = useInventoryStore();
    const item = equipment[slotId];

    const { setNodeRef, isOver } = useDroppable({
        id: `equip-${slotId}`,
        data: {
            type: 'equipment',
            slotId,
            acceptedTypes
        }
    });

    return (
        <div className="flex flex-col gap-1">
            {label && <span className="text-zinc-500 text-[10px] uppercase font-bold tracking-wider">{label}</span>}
            <div
                ref={setNodeRef}
                className={`
                    relative bg-zinc-800/20 border border-zinc-700/50 rounded-sm overflow-hidden flex items-center justify-center shrink-0
                    ${isOver ? 'border-orange-500/80 bg-orange-500/10' : ''}
                    transition-colors duration-200
                    ${className}
                `}
            >
                {item ? (
                    <ItemView
                        {...item}
                        style={{ position: 'relative', top: 0, left: 0, transform: 'none' }}
                        isEquipment
                    />
                ) : (
                    <div className="text-zinc-700 text-xs text-center p-2 opacity-50 select-none">
                        EMPTY
                    </div>
                )}
            </div>
        </div>
    );
};

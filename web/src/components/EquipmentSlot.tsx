import React from 'react';
import { useDroppable } from '@dnd-kit/core';
import { Item } from './Item';
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
        <div className="flex flex-col">
            {label && <span className="text-zinc-500 text-xs uppercase font-bold tracking-wider pl-2 border border-zinc-700">{label}</span>}
            <div
                ref={setNodeRef}
                className={`
                    relative bg-zinc-800/40 border border-zinc-700/30 overflow-hidden flex items-center justify-center shrink-0
                    ${isOver ? 'border-orange-500/80 bg-orange-500/10' : ''}
                    transition-colors duration-200
                    ${className}
                `}
            >
                {item ? (
                    <Item
                        {...item}
                        isEquipment
                        containerId={`equip-${slotId}`} // Pass ID for context actions
                    />
                ) : (
                    <div className="text-gray-300 text-xs text-center p-2 opacity-50 select-none">
                        EMPTY
                    </div>
                )}
            </div>
        </div>
    );
};

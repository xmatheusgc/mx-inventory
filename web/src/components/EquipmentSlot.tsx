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
    children?: React.ReactNode;
}

export const EquipmentSlot: React.FC<EquipmentSlotProps> = ({
    slotId,
    label,
    acceptedTypes,
    className,
    children
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
            {label && <span className="text-text-muted text-xs uppercase font-bold tracking-wider pl-2 border border-border-dark">{label}</span>}
            <div
                ref={setNodeRef}
                className={`
                    relative bg-surface-light/40 border border-border-dark/30 overflow-hidden flex items-center justify-center shrink-0
                    ${isOver ? 'border-primary/80 bg-primary/10' : ''}
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
                    <div className="text-text-subtle text-xs text-center p-2 opacity-50 select-none">
                        EMPTY
                    </div>
                )}
                {children}
            </div>
        </div>
    );
};

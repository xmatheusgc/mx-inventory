import React from 'react';
import { Item } from './Item';
import { useInventoryStore } from '../store/inventoryStore';
import { useDroppable } from '@dnd-kit/core';
import { twMerge } from 'tailwind-merge';

const SLOT_SIZE = 64;
const GAP = 2;

interface HighlightData {
    slots: { x: number; y: number }[];
    isValid: boolean;
}

interface ContainerProps {
    containerId: string;
    highlight?: HighlightData;
}

export const Container: React.FC<ContainerProps> = ({ containerId, highlight }) => {
    const { containers } = useInventoryStore();
    const container = containers[containerId];

    const { setNodeRef } = useDroppable({
        id: containerId,
        data: { containerId }
    });

    if (!container) return null;

    const { size, items, validSlots } = container;
    const totalWidth = size.width * (SLOT_SIZE + GAP) - GAP;

    const isValidSlot = (x: number, y: number) => {
        if (!validSlots) return true;
        return validSlots.some(vs => vs.x === x && vs.y === y);
    };

    const isHighlighted = (x: number, y: number) => {
        if (!highlight) return false;
        return highlight.slots.some(slot => slot.x === x && slot.y === y);
    };

    const renderSlots = () => {
        const slots = [];
        for (let y = 1; y <= size.height; y++) {
            for (let x = 1; x <= size.width; x++) {
                const isValid = isValidSlot(x, y);
                const highlighted = isHighlighted(x, y);

                // Base slot
                let content = (
                    <div
                        key={`${x}-${y}`}
                        className={twMerge(
                            "relative bg-zinc-800/40 border border-zinc-700/30 rounded-[2px] transition-colors",
                            // Highlight Overlay
                            highlighted && (highlight?.isValid
                                ? "bg-green-500/20 border-green-500/50"
                                : "bg-red-500/20 border-red-500/50")
                        )}
                        style={{
                            width: SLOT_SIZE,
                            height: SLOT_SIZE,
                        }}
                    />
                );

                if (!isValid) {
                    content = (
                        <div
                            key={`${x}-${y}`}
                            className="opacity-0"
                            style={{
                                width: SLOT_SIZE,
                                height: SLOT_SIZE,
                            }}
                        />
                    );
                }

                slots.push(content);
            }
        }
        return slots;
    };

    return (
        <div className="flex flex-col gap-2">


            <div
                ref={setNodeRef}
                className="relative bg-black/40 rounded-lg p-2 w-fit h-fit"
                id={containerId}
            >
                <div
                    style={{
                        display: 'grid',
                        gridTemplateColumns: `repeat(${size.width}, ${SLOT_SIZE}px)`,
                        gap: GAP,
                        width: totalWidth + GAP,
                    }}
                >
                    {renderSlots()}
                </div>

                <div className="absolute top-0 left-0 w-full h-full pointer-events-none">
                    <div className="relative pointer-events-auto top-2 left-2">
                        {items.map((item, index) => (
                            <Item
                                key={`${item.name}-${index}`}
                                {...item}
                            />
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
};

import React from 'react';
import { Item } from './Item';
import { useInventoryStore } from '../store/inventoryStore';
import { useDroppable } from '@dnd-kit/core';
import { twMerge } from 'tailwind-merge';

const SLOT_SIZE = 62;
const GAP = 0;

interface HighlightData {
    slots: { x: number; y: number }[];
    isValid: boolean;
}


interface Region {
    x: number;
    y: number;
    width: number;
    height: number;
}

interface ContainerProps {
    containerId: string;
    droppableId?: string; // Unique ID for dnd-kit (if different from containerId)
    highlight?: HighlightData;
    region?: Region; // Only render slots within this region
}

export const Container: React.FC<ContainerProps> = ({ containerId, droppableId, highlight, region }) => {
    const { containers } = useInventoryStore();
    const container = containers[containerId];

    const { setNodeRef } = useDroppable({
        id: droppableId || containerId,
        data: { containerId, region } // Pass region data for drag handler to know offsets if needed
    });

    if (!container) return null;

    // Use region size if provided, otherwise container size
    const displayWidth = region ? region.width : container.size.width;
    const displayHeight = region ? region.height : container.size.height;

    const { items, validSlots } = container;


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

        // Loop based on Display Grid (Region or Full)
        // If region is provided, we loop from region.y to region.y + height
        const startY = region ? region.y : 1;
        const endY = region ? region.y + displayHeight - 1 : container.size.height;
        const startX = region ? region.x : 1;
        const endX = region ? region.x + displayWidth - 1 : container.size.width;


        for (let y = startY; y <= endY; y++) {
            for (let x = startX; x <= endX; x++) {
                const isValid = isValidSlot(x, y);
                const highlighted = isHighlighted(x, y);

                // Base slot
                let content = (
                    <div
                        key={`${x}-${y}`}
                        className={twMerge(
                            "relative bg-surface-light/40 border border-border-dark/30 transition-colors",
                            highlighted && (highlight?.isValid
                                ? "bg-success/20 border-success/50"
                                : "bg-error/20 border-error/50")
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

    // Filter Items that are INSIDE this region
    const visibleItems = region
        ? items.filter(item => {
            // Check if item's slot is within the region
            // item.slot is top-left. We need to check if it matches the grid we are drawing.
            // actually, an item belongs to this region if its top-left is inside the region?
            // OR if its mostly inside. Simplest is top-left.
            return item.slot.x >= region.x && item.slot.x < region.x + region.width &&
                item.slot.y >= region.y && item.slot.y < region.y + region.height;
        })
        : items;

    return (
        <div className="flex flex-col gap-2 border border-white/20 w-fit">
            <div
                ref={setNodeRef}
                className="relative bg-black/40 w-fit h-fit overflow-hidden"
                id={droppableId || containerId}
            >
                {/* Grid Layer */}
                <div
                    style={{
                        display: 'grid',
                        gridTemplateColumns: `repeat(${displayWidth}, ${SLOT_SIZE}px)`,
                        gap: GAP,
                    }}
                >
                    {renderSlots()}
                </div>

                {/* Items Layer - Adjust positioning relative to Region */}
                <div className="absolute top-0 left-0 w-full h-full pointer-events-none">
                    <div className="relative pointer-events-auto">
                        {visibleItems.map((item, index) => {
                            // Correct position if rendering a region
                            // If region starts at x=1, y=3.
                            // And item is at x=1, y=3. 
                            // Visually, that item should be at 0,0 inside THIS component.

                            const offsetX = region ? (region.x - 1) : 0;
                            const offsetY = region ? (region.y - 1) : 0;

                            // We copy the item but shift its visual slot for rendering
                            const visualItem = {
                                ...item,
                                slot: {
                                    x: item.slot.x - offsetX,
                                    y: item.slot.y - offsetY
                                }
                            };

                            return (
                                <Item
                                    key={`${item.name}-${index}`}
                                    {...visualItem}
                                    containerId={containerId}
                                />
                            )
                        })}
                    </div>
                </div>

                {/* Border Overlay */}
                <div className="absolute top-0 left-0 w-full h-full pointer-events-none border border-border-dark/30" />
            </div>
        </div>
    );
};

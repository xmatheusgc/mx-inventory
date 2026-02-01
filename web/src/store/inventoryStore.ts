import { create } from 'zustand';

interface GridSize {
    width: number;
    height: number;
}

interface Item {
    name: string;
    count: number;
    slot: { x: number; y: number };
    image?: string;
    label?: string;
    size?: { x: number; y: number };
    weight?: number;
    rotated?: boolean;
}

export interface ContainerData {
    id: string; // 'player', 'bag-123', etc.
    type: 'player' | 'bag' | 'vest' | 'stash' | 'drop';
    label: string;
    size: GridSize;
    items: Item[];
    validSlots?: { x: number; y: number }[]; // If defined, only these slots are valid
    weight?: number;
    maxWeight?: number;
}

interface InventoryState {
    isOpen: boolean;
    containers: Record<string, ContainerData>;
    setOpen: (isOpen: boolean) => void;
    setContainerData: (id: string, data: ContainerData) => void;
    moveItem: (
        fromContainerId: string,
        toContainerId: string,
        itemName: string,
        targetSlot: { x: number; y: number },
        rotated?: boolean
    ) => void;
    rotateItem: (containerId: string, itemName: string) => void;
    updateContainerWeight: (containerId: string, weight: number) => void;
}

export const useInventoryStore = create<InventoryState>((set) => ({
    isOpen: false,
    containers: {},
    setOpen: (isOpen) => set({ isOpen }),
    setContainerData: (id, data) =>
        set((state) => ({
            containers: { ...state.containers, [id]: data }
        })),
    updateContainerWeight: (id, weight) => set((state) => {
        const container = state.containers[id];
        if (!container) return state;
        return {
            containers: {
                ...state.containers,
                [id]: { ...container, weight }
            }
        };
    }),

    moveItem: (fromContainerId, toContainerId, itemName, targetSlot, rotated) => {
        set((state) => {
            const sourceContainer = state.containers[fromContainerId];
            const targetContainer = state.containers[toContainerId];

            if (!sourceContainer || !targetContainer) return state;

            const itemIndex = sourceContainer.items.findIndex(i => i.name === itemName);
            if (itemIndex === -1) return state;

            const item = sourceContainer.items[itemIndex];
            const isRotated = rotated !== undefined ? rotated : !!item.rotated;

            const originalSize = item.size || { x: 1, y: 1 };
            const size = isRotated ? { x: originalSize.y, y: originalSize.x } : originalSize;

            // 1. Boundary Check
            if (
                targetSlot.x < 1 ||
                targetSlot.y < 1 ||
                targetSlot.x + size.x - 1 > targetContainer.size.width ||
                targetSlot.y + size.y - 1 > targetContainer.size.height
            ) {
                return state;
            }

            // 2. Custom Layout Mask Check (Pockets)
            if (targetContainer.validSlots) {
                for (let px = 0; px < size.x; px++) {
                    for (let py = 0; py < size.y; py++) {
                        const slotToCheck = { x: targetSlot.x + px, y: targetSlot.y + py };
                        const isValid = targetContainer.validSlots.some(
                            vs => vs.x === slotToCheck.x && vs.y === slotToCheck.y
                        );
                        if (!isValid) return state;
                    }
                }
            }

            // 2.5 Weight Check
            if (fromContainerId !== toContainerId && targetContainer.maxWeight !== undefined) {
                const itemDefWeight = item.weight || 0; // Ensure items have weight prop
                const currentWeight = targetContainer.weight || 0;

                // We need to calculate total weight more robustly if we want live updates
                // For now, let's assume item.weight is populated.
                if (currentWeight + (itemDefWeight * item.count) > targetContainer.maxWeight) {
                    console.log("Overweight!");
                    return state;
                }
            }

            // 3. Collision Check
            const hasCollision = targetContainer.items.some((otherItem) => {
                if (fromContainerId === toContainerId && otherItem.name === item.name) return false;

                const otherRotated = !!otherItem.rotated;
                const otherOriginalSize = otherItem.size || { x: 1, y: 1 };
                const otherSize = otherRotated ? { x: otherOriginalSize.y, y: otherOriginalSize.x } : otherOriginalSize;

                const overlapsX =
                    targetSlot.x < otherItem.slot.x + otherSize.x &&
                    targetSlot.x + size.x > otherItem.slot.x;
                const overlapsY =
                    targetSlot.y < otherItem.slot.y + otherSize.y &&
                    targetSlot.y + size.y > otherItem.slot.y;

                return overlapsX && overlapsY;
            });

            if (hasCollision) return state;

            // UPDATE STATE
            const newSourceItems = [...sourceContainer.items];
            let newTargetItems = (fromContainerId === toContainerId) ? newSourceItems : [...targetContainer.items];

            if (fromContainerId !== toContainerId) {
                newSourceItems.splice(itemIndex, 1);
            }

            const updatedItem = { ...item, slot: targetSlot, rotated: isRotated };

            if (fromContainerId === toContainerId) {
                newTargetItems[itemIndex] = updatedItem;
            } else {
                newTargetItems.push(updatedItem);
            }

            return {
                containers: {
                    ...state.containers,
                    [fromContainerId]: { ...sourceContainer, items: newSourceItems },
                    [toContainerId]: { ...targetContainer, items: newTargetItems }
                }
            };
        });
    },

    rotateItem: (containerId, itemName) => {
        set((state) => {
            const container = state.containers[containerId];
            if (!container) return state;

            const itemIndex = container.items.findIndex(i => i.name === itemName);
            if (itemIndex === -1) return state;

            const item = container.items[itemIndex];
            const newRotated = !item.rotated;

            const newItems = [...container.items];
            newItems[itemIndex] = { ...item, rotated: newRotated };

            return {
                containers: {
                    ...state.containers,
                    [containerId]: { ...container, items: newItems }
                }
            };
        });
    }
}));

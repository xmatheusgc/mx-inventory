import { create } from 'zustand';

export type ItemType = 'weapon_primary' | 'weapon_secondary' | 'weapon_pistol' | 'weapon_melee' | 'helmet' | 'armor' | 'vest' | 'backpack' | 'generic';

interface Item {
    name: string;
    count: number;
    slot: { x: number; y: number };
    image?: string;
    label?: string;
    size?: { x: number; y: number };
    weight?: number;
    rotated?: boolean;
    type?: ItemType;
}

interface GridSize {
    width: number;
    height: number;
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
    equipment: Record<string, Item | null>; // head, body, primary, etc.
    setOpen: (isOpen: boolean) => void;
    setContainerData: (id: string, data: ContainerData) => void;
    setEquipment: (data: Record<string, Item | null>) => void;
    moveItem: (
        fromContainerId: string,
        toContainerId: string,
        itemName: string,
        targetSlot: { x: number; y: number },
        rotated?: boolean
    ) => void;
    rotateItem: (containerId: string, itemName: string) => void;
    updateContainerWeight: (containerId: string, weight: number) => void;
    equipItem: (slot: string, item: Item, fromContainerId: string) => void;
    unequipItem: (slot: string, toContainerId: string, targetSlot: { x: number, y: number }) => void;
}

export const useInventoryStore = create<InventoryState>((set) => ({
    isOpen: false,
    containers: {
        'player-inv': {
            id: 'player-inv',
            type: 'player',
            label: 'Player Inventory',
            size: { width: 5, height: 2 },
            items: [],
            validSlots: undefined
        },
        'rig_st_tipo_4': {
            id: 'rig_st_tipo_4',
            type: 'vest',
            label: 'ST Tipo 4',
            size: { width: 4, height: 10 },
            items: [],
            validSlots: undefined
        },
        'mochila_tatica_expansivel_luc': {
            id: 'mochila_tatica_expansivel_luc',
            type: 'bag',
            label: 'Mochila Tática Expansível Luc',
            size: { width: 5, height: 10 },
            items: [],
            validSlots: undefined
        }
    },
    equipment: {
        head: null,
        armor: null,
        legs: null,
        backpack: { name: 'mochila_tatica_expansivel_luc', count: 1, slot: { x: 1, y: 1 }, size: { x: 2, y: 2 }, type: 'backpack' },
        primary: null,
        secondary: null,
        pistol: null,
        melee: null,
        vest: { name: 'rig_st_tipo_4', count: 1, slot: { x: 1, y: 1 }, size: { x: 2, y: 2 }, type: 'vest' },
    },
    setOpen: (isOpen: boolean) => set({ isOpen }),
    setContainerData: (id: string, data: ContainerData) =>
        set((state: InventoryState) => ({
            containers: { ...state.containers, [id]: data }
        })),
    setEquipment: (data: Record<string, Item | null>) => set({ equipment: data }),

    updateContainerWeight: (id: string, weight: number) => set((state: InventoryState) => {
        const container = state.containers[id];
        if (!container) return state;
        return {
            containers: {
                ...state.containers,
                [id]: { ...container, weight }
            }
        };
    }),

    moveItem: (fromContainerId: string, toContainerId: string, itemName: string, targetSlot: { x: number; y: number }, rotated?: boolean) => {
        set((state: InventoryState) => {
            const sourceContainer = state.containers[fromContainerId];
            const targetContainer = state.containers[toContainerId];

            if (!sourceContainer || !targetContainer) return state;

            const itemIndex = sourceContainer.items.findIndex((i: Item) => i.name === itemName);
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
                            (vs: { x: number, y: number }) => vs.x === slotToCheck.x && vs.y === slotToCheck.y
                        );
                        if (!isValid) return state;
                    }
                }
            }

            // 2.5 Weight Check
            if (fromContainerId !== toContainerId && targetContainer.maxWeight !== undefined) {
                const itemDefWeight = item.weight || 0;
                const currentWeight = targetContainer.weight || 0;
                if (currentWeight + (itemDefWeight * item.count) > targetContainer.maxWeight) {
                    console.log("Overweight!");
                    return state;
                }
            }

            // 3. Collision Check
            const hasCollision = targetContainer.items.some((otherItem: Item) => {
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

    rotateItem: (containerId: string, itemName: string) => {
        set((state: InventoryState) => {
            const container = state.containers[containerId];
            if (!container) return state;

            const itemIndex = container.items.findIndex((i: Item) => i.name === itemName);
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
    },

    equipItem: (slot: string, item: Item, fromContainerId: string) => set((state: InventoryState) => {
        const sourceContainer = state.containers[fromContainerId];
        if (!sourceContainer) return state;

        // Remove from source
        const newSourceItems = sourceContainer.items.filter((i: Item) => i.name !== item.name);

        // Add to equipment
        const newEquipment = { ...state.equipment, [slot]: item };

        return {
            containers: {
                ...state.containers,
                [fromContainerId]: { ...sourceContainer, items: newSourceItems }
            },
            equipment: newEquipment
        };
    }),

    unequipItem: (slot: string, toContainerId: string, targetSlot: { x: number, y: number }) => set((state: InventoryState) => {
        const item = state.equipment[slot];
        if (!item) return state;

        const targetContainer = state.containers[toContainerId];
        if (!targetContainer) return state;

        // Remove from equipment
        const newEquipment = { ...state.equipment, [slot]: null };

        // Add to target container
        const newTargetItems = [...targetContainer.items, { ...item, slot: targetSlot, rotated: false }];

        return {
            containers: {
                ...state.containers,
                [toContainerId]: { ...targetContainer, items: newTargetItems }
            },
            equipment: newEquipment
        };
    })
}));

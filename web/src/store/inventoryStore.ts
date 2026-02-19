import { create } from 'zustand';
import { ITEM_CONFIGS } from '../config/items';

export type ItemType = 'weapon_primary' | 'weapon_secondary' | 'weapon_pistol' | 'weapon_melee' | 'helmet' | 'mask' | 'earpiece' | 'armor' | 'vest' | 'backpack' | 'generic' | 'consumable' | 'throwable' | 'magazine' | 'ammo' | 'attachment_scope' | 'attachment_grip' | 'attachment_muzzle' | 'attachment_skin' | 'weapon_smg' | 'weapon_rifle' | 'weapon_sniper' | 'weapon_shotgun';

export interface Item {
    id: string; // UUID
    name: string;
    count: number;
    slot: { x: number; y: number };
    image?: string;
    label?: string;
    description?: string; // New property
    size?: { x: number; y: number };
    weight?: number;
    rotated?: boolean;
    folded?: boolean;
    type?: ItemType;
    stackable?: boolean;
    maxStack?: number;
    // Static properties from Item Defs
    ammo?: {
        caliber: string;
    };
    magazine?: {
        caliber: string;
        capacity: number;
    };
    // Dynamic State
    metadata?: {
        ammo?: number;           // For magazines: current ammo count
        capacity?: number;       // For magazines: max capacity
        caliber?: string;        // For magazines/ammo: caliber type
        magazine?: {             // For equipped weapons: inserted magazine
            name: string;        // Magazine item name
            label: string;
            ammo: number;        // Current ammo in magazine
            capacity: number;    // Max capacity
            caliber: string;
        };
    };
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
    setContainers: (containers: Record<string, ContainerData>) => void;
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
    swapEquipment: (fromSlot: string, toSlot: string) => void;
    loadMagazine: (weaponSlot: string, magazineItem: Item, fromContainerId: string) => void;
    unloadMagazine: (weaponSlot: string, toContainerId: string, targetSlot: { x: number; y: number }) => void;
    loadAmmoIntoMag: (magazineId: string, ammoItem: Item, magazineContainerId: string, ammoContainerId: string) => void;
    toggleItemFold: (containerId: string, itemName: string) => void;

    // UI Actions
    openWindows: string[];
    toggleWindow: (containerId: string) => void;
    closeWindow: (containerId: string) => void;

    // Details Window
    detailsWindows: Item[];
    openDetails: (item: Item) => void;
    closeDetails: (item: Item) => void;

    // Shortcuts
    shortcuts: Record<string, string | null>; // key -> itemName
    hoveredItem: { name: string, containerId: string } | null;
    setHoveredItem: (data: { name: string, containerId: string } | null) => void;
    setShortcut: (key: string) => void;
    removeShortcut: (key: string) => void;
}

// Helper
const generateUUID = () => {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
};

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
        backpack: { id: 'mock-bp', name: 'mochila_tatica_expansivel_luc', count: 1, slot: { x: 1, y: 1 }, size: { x: 4, y: 5 }, type: 'backpack' },
        primary: null,
        secondary: null,
        pistol: null,
        melee: null,
        vest: { id: 'mock-vest', name: 'rig_st_tipo_4', count: 1, slot: { x: 1, y: 1 }, size: { x: 3, y: 3 }, type: 'vest' },
    },
    // Shortcuts
    shortcuts: { '5': null, '6': null, '7': null, '8': null },
    hoveredItem: null,
    setHoveredItem: (data) => set({ hoveredItem: data }),
    setShortcut: (key: string) => {
        set((state) => {
            if (!state.hoveredItem) return state;
            const { name, containerId } = state.hoveredItem;

            // Validation: Must be in player-inv or vest
            const container = state.containers[containerId];
            if (!container) return state;
            if (container.type !== 'player' && container.type !== 'vest') return state;

            // Exclusivity: Remove this item from other shortcuts
            const newShortcuts = { ...state.shortcuts };
            Object.keys(newShortcuts).forEach(k => {
                if (newShortcuts[k] === name) newShortcuts[k] = null;
            });

            newShortcuts[key] = name;
            return { shortcuts: newShortcuts };
        });
    },
    removeShortcut: (key: string) => set((state) => ({
        shortcuts: { ...state.shortcuts, [key]: null }
    })),

    // UI State
    openWindows: [],
    setOpen: (isOpen: boolean) => set({ isOpen }),
    toggleWindow: (containerId: string) => set((state: InventoryState) => {
        const isOpen = state.openWindows.includes(containerId);
        return {
            openWindows: isOpen
                ? state.openWindows.filter(id => id !== containerId)
                : [...state.openWindows, containerId]
        };
    }),
    closeWindow: (containerId: string) => set((state: InventoryState) => ({
        openWindows: state.openWindows.filter(id => id !== containerId)
    })),
    setContainerData: (id: string, data: ContainerData) =>
        set((state: InventoryState) => ({
            containers: { ...state.containers, [id]: data }
        })),
    setContainers: (containers: Record<string, ContainerData>) => set({ containers }),

    // Details
    detailsWindows: [],
    openDetails: (item: Item) => set((state) => {
        // Prevent duplicates based on name? Or allow same item twice?
        // Usually unique by reference or name. Let's assume name unique for window purposes or just allow multiple.
        // If we want to prevent multiple windows for the EXACT SAME item instance, we need unique ID.
        // For now, let's just append. User can close them.
        // Actually, preventing exact duplicates is better UX.
        if (state.detailsWindows.some(i => i.name === item.name)) return state;
        return { detailsWindows: [...state.detailsWindows, item] };
    }),
    closeDetails: (item: Item) => set((state) => ({
        detailsWindows: state.detailsWindows.filter(i => i.name !== item.name)
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

            const itemIndex = sourceContainer.items.findIndex((i: Item) => i.id === itemName);
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
                if (fromContainerId === toContainerId && otherItem.id === item.id) return false;

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

            const itemIndex = container.items.findIndex((i: Item) => i.id === itemName);
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
        const newSourceItems = sourceContainer.items.filter((i: Item) => i.id !== item.id);

        // Add to equipment (Reset Folded - Ensure Expanded)
        // We need expanded size here.
        let newItem = { ...item, folded: false };
        const config = ITEM_CONFIGS[item.name];
        if (config) {
            newItem.size = config.expandedSize;
        }

        const newEquipment = { ...state.equipment, [slot]: newItem };

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

        // Restore Size (Expanded)
        let newItem = { ...item, slot: targetSlot, rotated: false, folded: false };
        const config = ITEM_CONFIGS[item.name];
        if (config) {
            newItem.size = config.expandedSize;
        }

        // Add to target container
        const newTargetItems = [...targetContainer.items, newItem];

        return {
            containers: {
                ...state.containers,
                [toContainerId]: { ...targetContainer, items: newTargetItems }
            },
            equipment: newEquipment
        };
    }),

    swapEquipment: (fromSlot: string, toSlot: string) => set((state: InventoryState) => {
        const fromItem = state.equipment[fromSlot];
        if (!fromItem) return state;

        const toItem = state.equipment[toSlot]; // Can be null (simple move) or Item (swap)

        return {
            equipment: {
                ...state.equipment,
                [fromSlot]: toItem,  // Put target's item (or null) into source slot
                [toSlot]: fromItem   // Put source's item into target slot
            }
        };
    }),

    loadMagazine: (weaponSlot: string, magazineItem: Item, fromContainerId: string) => set((state: InventoryState) => {
        const weapon = state.equipment[weaponSlot];
        if (!weapon) return state;

        const sourceContainer = state.containers[fromContainerId];
        if (!sourceContainer) return state;

        // Remove magazine from source container
        const newSourceItems = sourceContainer.items.filter((i: Item) => i.id !== magazineItem.id);

        // Attach magazine to weapon metadata
        const magazineMeta = {
            name: magazineItem.name,
            label: magazineItem.label || magazineItem.name,
            ammo: magazineItem.metadata?.ammo ?? 0,
            capacity: magazineItem.metadata?.capacity ?? 30,
            caliber: magazineItem.metadata?.caliber ?? '',
        };

        const updatedWeapon = {
            ...weapon,
            metadata: {
                ...weapon.metadata,
                magazine: magazineMeta,
            }
        };

        return {
            containers: {
                ...state.containers,
                [fromContainerId]: { ...sourceContainer, items: newSourceItems }
            },
            equipment: {
                ...state.equipment,
                [weaponSlot]: updatedWeapon
            }
        };
    }),

    unloadMagazine: (weaponSlot: string, toContainerId: string, targetSlot: { x: number; y: number }) => set((state: InventoryState) => {
        const weapon = state.equipment[weaponSlot];
        if (!weapon || !weapon.metadata?.magazine) return state;

        const targetContainer = state.containers[toContainerId];
        if (!targetContainer) return state;

        const mag = weapon.metadata.magazine;

        // Create magazine item to put back in inventory
        const magazineItem: Item = {
            id: generateUUID(), // Generate Client ID
            name: mag.name,
            label: mag.label,
            count: 1,
            slot: targetSlot,
            size: { x: 1, y: 2 }, // Default magazine size
            type: 'magazine',
            metadata: {
                ammo: mag.ammo,
                capacity: mag.capacity,
                caliber: mag.caliber,
            }
        };

        // Remove magazine from weapon
        const updatedWeapon = {
            ...weapon,
            metadata: {
                ...weapon.metadata,
                magazine: undefined,
            }
        };

        return {
            containers: {
                ...state.containers,
                [toContainerId]: {
                    ...targetContainer,
                    items: [...targetContainer.items, magazineItem]
                }
            },
            equipment: {
                ...state.equipment,
                [weaponSlot]: updatedWeapon
            }
        };
    }),

    loadAmmoIntoMag: (magazineId: string, ammoItem: Item, magazineContainerId: string, ammoContainerId: string) => set((state: InventoryState) => {
        const magContainer = state.containers[magazineContainerId];
        const ammoContainer = state.containers[ammoContainerId];
        if (!magContainer || !ammoContainer) return state;

        // Find Magazine
        const magItemIndex = magContainer.items.findIndex(i => i.id === magazineId);
        if (magItemIndex === -1) return state;
        const magItem = magContainer.items[magItemIndex];

        // Validate Caliber
        const ammoCaliber = ammoItem.ammo?.caliber || ammoItem.metadata?.caliber;
        const magCaliber = magItem.magazine?.caliber || magItem.metadata?.caliber;

        if (!ammoCaliber || !magCaliber || ammoCaliber !== magCaliber) return state;

        // Calculate amount to move
        // Default capacity from Item Def or Metadata
        const capacity = magItem.metadata?.capacity || magItem.magazine?.capacity || 30;
        const currentAmmo = magItem.metadata?.ammo || 0;
        const space = capacity - currentAmmo;

        if (space <= 0) return state; // Full

        const amountToLoad = Math.min(space, ammoItem.count);

        // Update Magazine
        const newMagItem = {
            ...magItem,
            metadata: {
                ...magItem.metadata,
                ammo: currentAmmo + amountToLoad,
                capacity: capacity,
                caliber: magCaliber
            }
        };

        // Update Ammo Stack
        let newAmmoItems;
        if (ammoContainerId === magazineContainerId) {
            // Same container
            newAmmoItems = magContainer.items.map(i => {
                if (i.id === magItem.id) return newMagItem;
                if (i.id === ammoItem.id) {
                    return { ...i, count: i.count - amountToLoad };
                }
                return i;
            }).filter(i => i.count > 0);

            return {
                containers: {
                    ...state.containers,
                    [magazineContainerId]: { ...magContainer, items: newAmmoItems }
                }
            };
        } else {
            // Different containers
            const newMagItems = magContainer.items.map(i => i.id === magazineId ? newMagItem : i);
            const newAmmoSourceItems = ammoContainer.items.map(i => {
                if (i.id === ammoItem.id) {
                    return { ...i, count: i.count - amountToLoad };
                }
                return i;
            }).filter(i => i.count > 0);

            return {
                containers: {
                    ...state.containers,
                    [magazineContainerId]: { ...magContainer, items: newMagItems },
                    [ammoContainerId]: { ...ammoContainer, items: newAmmoSourceItems }
                }
            };
        }
    }),

    toggleItemFold: (containerId: string, itemName: string) => set((state: InventoryState) => {
        // 1. Check Containers
        if (state.containers[containerId]) {
            const container = state.containers[containerId];
            const itemIndex = container.items.findIndex((i: Item) => i.name === itemName);
            if (itemIndex === -1) return state;

            const item = container.items[itemIndex];
            const newFolded = !item.folded;

            // Restriction: Cannot fold if container has items
            if (newFolded) { // Attempting to fold (turn folded=true)
                const internalContainer = state.containers[item.name];
                if (internalContainer && internalContainer.items.length > 0) {
                    console.warn("Cannot fold a container that has items inside!");
                    return state;
                }
            }

            let newSize = item.size;
            const config = ITEM_CONFIGS[item.name];
            if (config) {
                newSize = newFolded ? config.foldedSize : config.expandedSize;
            }

            return {
                containers: {
                    ...state.containers,
                    [containerId]: {
                        ...container,
                        items: container.items.map((it, idx) =>
                            idx === itemIndex ? { ...it, folded: newFolded, size: newSize } : it
                        )
                    }
                }
            };
        }

        // 2. Check Equipment (if containerId is 'equipment' or similar)
        // We will assume if it's not a container, it might be an equipment slot key or we search equipment
        // Let's iterate equipment to find the item by name if containerId implies equipment
        // Or simply if we find the item in equipment.

        let equipSlotFound: string | null = null;
        for (const [slot, item] of Object.entries(state.equipment)) {
            if (item && item.name === itemName) {
                equipSlotFound = slot;
                break;
            }
        }

        if (equipSlotFound) {
            const item = state.equipment[equipSlotFound];
            if (!item) return state;

            const newFolded = !item.folded;

            // Restriction: Cannot fold if container has items
            if (newFolded) { // Attempting to fold (turn folded=true)
                const internalContainer = state.containers[item.name];
                if (internalContainer && internalContainer.items.length > 0) {
                    console.warn("Cannot fold a container that has items inside!");
                    return state;
                }
            }

            let newSize = item.size;
            const config = ITEM_CONFIGS[item.name];
            if (config) {
                newSize = newFolded ? config.foldedSize : config.expandedSize;
            }

            return {
                equipment: {
                    ...state.equipment,
                    [equipSlotFound]: { ...item, folded: newFolded, size: newSize }
                }
            };
        }

        return state;
    })
}));

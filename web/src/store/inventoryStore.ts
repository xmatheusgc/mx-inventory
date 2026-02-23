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
        ammo?: number;           // Total ammo for weapons, or ammo for stacked items
        clip?: number;           // Current clip ammo for equipped weapons
        capacity?: number;       // (Legacy)
        caliber?: string;        // Ammo caliber type
        attachments?: Record<string, string | null>; // slot -> attachment item name (e.g. { muzzle: 'suppressor_pistol', scope: null })
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
    unequipItem: (slot: string, toContainerId: string, targetSlot: { x: number, y: number }, folded?: boolean) => void;
    swapEquipment: (fromSlot: string, toSlot: string) => void;
    loadAmmoIntoWeapon: (weaponIdOrSlot: string, weaponContainerId: string, ammoItem: Item, ammoContainerId: string) => void;
    updateWeaponAmmo: (weaponSlot: string, totalAmmo: number, clipAmmo: number) => void;
    toggleItemFold: (containerId: string, itemName: string) => void;
    stackItems: (fromItemId: string, fromContainerId: string, toItemId: string, toContainerId: string) => void;

    // Attachment Actions
    attachToWeapon: (weaponId: string, weaponContainerId: string, attachmentSlot: string, attachmentItem: Item, fromContainerId: string) => void;
    removeAttachment: (weaponId: string, weaponContainerId: string, attachmentSlot: string, toContainerId: string, targetSlot?: { x: number; y: number }) => void;

    // UI Actions
    openWindows: string[];
    toggleWindow: (containerId: string) => void;
    closeWindow: (containerId: string) => void;

    // Details Window
    detailsWindows: Item[];
    openDetails: (item: Item) => void;
    closeDetails: (item: Item) => void;

    // Give Item
    giveTarget: { item: Item; containerId: string } | null;
    setGiveTarget: (data: { item: Item; containerId: string } | null) => void;
    receiveRequest: { fromSrc: number; fromName: string; itemName: string; itemLabel: string; count: number; image?: string } | null;
    setReceiveRequest: (data: { fromSrc: number; fromName: string; itemName: string; itemLabel: string; count: number; image?: string } | null) => void;

    // Shortcuts
    shortcuts: Record<string, string | null>; // key -> itemName
    hoveredItem: { item: Item, containerId: string } | null;
    setHoveredItem: (data: { item: Item, containerId: string } | null) => void;
    setShortcut: (key: string) => void;
    removeShortcut: (key: string) => void;

    // Drag Compatibility Highlights
    dragCompatibility: { targetIds: Set<string>; dragType: 'ammo' | 'attachment' | 'stack' | null } | null;
    setDragCompatibility: (data: { targetIds: Set<string>; dragType: 'ammo' | 'attachment' | 'stack' } | null) => void;

    // Context Menu (only one open at a time)
    activeContextMenuItemId: string | null;
    setActiveContextMenuItemId: (id: string | null) => void;

    // Notifications
    notifications: { id: string; message: string; type: 'error' | 'success' | 'info'; duration?: number }[];
    addNotification: (message: string, type: 'error' | 'success' | 'info', duration?: number) => void;
    removeNotification: (id: string) => void;
}

// No helpers needed currently

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

    // Drag Compatibility Highlights
    dragCompatibility: null,
    setDragCompatibility: (data) => set({ dragCompatibility: data }),
    setShortcut: (key: string) => {
        set((state) => {
            if (!state.hoveredItem) return state;
            const { item, containerId } = state.hoveredItem;
            const name = item.name;

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

    // Give Item state
    giveTarget: null,
    setGiveTarget: (data) => set({ giveTarget: data }),
    receiveRequest: null,
    setReceiveRequest: (data) => set({ receiveRequest: data }),

    // Context Menu
    activeContextMenuItemId: null,
    setActiveContextMenuItemId: (id) => set({ activeContextMenuItemId: id }),

    // Notifications
    notifications: [],
    addNotification: (message, type, duration = 3000) => set((state) => {
        const id = Math.random().toString(36).substring(2, 9);
        const newNotification = { id, message, type, duration };

        // Auto-remove
        setTimeout(() => {
            useInventoryStore.getState().removeNotification(id);
        }, duration);

        return { notifications: [...state.notifications, newNotification] };
    }),
    removeNotification: (id) => set((state) => ({
        notifications: state.notifications.filter(n => n.id !== id)
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

    unequipItem: (slot: string, toContainerId: string, targetSlot: { x: number, y: number }, folded?: boolean) => set((state: InventoryState) => {
        console.log(`[mx-inv] STORE ACTION > unequipItem: From slot ${slot} to container ${toContainerId} at X:${targetSlot.x} Y:${targetSlot.y}`);
        const item = state.equipment[slot];
        if (!item) return state;

        const targetContainer = state.containers[toContainerId];
        if (!targetContainer) return state;

        // Remove from equipment
        const newEquipment = { ...state.equipment, [slot]: null };

        // Resolve size based on fold state:
        // If explicitly folded (e.g. folded during drag), use foldedSize.
        // If unknown, default to expanded (equip always equips expanded).
        const isFolded = folded ?? false;
        const config = ITEM_CONFIGS[item.name];
        let newItem = { ...item, slot: targetSlot, rotated: false, folded: isFolded };
        if (config) {
            newItem.size = isFolded ? config.foldedSize : config.expandedSize;
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

    loadAmmoIntoWeapon: (weaponIdOrSlot: string, weaponContainerId: string, ammoItem: Item, ammoContainerId: string) => set((state: InventoryState) => {
        let weapon: Item | null | undefined;

        const isEquipment = weaponContainerId.startsWith('equip-');
        const equipSlot = isEquipment ? weaponContainerId.replace('equip-', '') : null;

        if (isEquipment && equipSlot) {
            weapon = state.equipment[equipSlot];
        } else {
            const weaponContainer = state.containers[weaponContainerId];
            if (weaponContainer) {
                weapon = weaponContainer.items.find(i => i.id === weaponIdOrSlot);
            }
        }

        if (!weapon) return state;

        const ammoContainer = state.containers[ammoContainerId];
        if (!ammoContainer) return state;

        const MAX_AMMO = 150;
        const currentTotalAmmo = weapon.metadata?.ammo ?? 0;
        const space = MAX_AMMO - currentTotalAmmo;

        if (space <= 0) return state;

        const amountToLoad = Math.min(space, ammoItem.count);

        const updatedWeapon = {
            ...weapon,
            metadata: {
                ...weapon.metadata,
                ammo: currentTotalAmmo + amountToLoad
                // we don't optimistically update clip here, because ped reload handles it
            }
        };

        const updatedAmmoCount = ammoItem.count - amountToLoad;
        const newAmmoItems = ammoContainer.items.map(i => {
            if (i.id === ammoItem.id) return { ...i, count: updatedAmmoCount };
            return i;
        }).filter(i => i.count > 0);

        if (isEquipment && equipSlot) {
            return {
                containers: {
                    ...state.containers,
                    [ammoContainerId]: { ...ammoContainer, items: newAmmoItems }
                },
                equipment: {
                    ...state.equipment,
                    [equipSlot]: updatedWeapon
                }
            };
        } else {
            const weaponContainer = state.containers[weaponContainerId];
            const newWeaponItems = weaponContainer.items.map(i => i.id === weaponIdOrSlot ? updatedWeapon : i);
            return {
                containers: {
                    ...state.containers,
                    [ammoContainerId]: { ...ammoContainer, items: newAmmoItems },
                    [weaponContainerId]: { ...weaponContainer, items: newWeaponItems }
                }
            };
        }
    }),

    updateWeaponAmmo: (weaponSlot: string, totalAmmo: number, clipAmmo: number) => set((state: InventoryState) => {
        const weapon = state.equipment[weaponSlot];
        if (!weapon) return state;

        return {
            equipment: {
                ...state.equipment,
                [weaponSlot]: {
                    ...weapon,
                    metadata: {
                        ...weapon.metadata,
                        ammo: totalAmmo,
                        clip: clipAmmo
                    }
                }
            }
        };
    }),

    toggleItemFold: (containerId: string, itemId: string) => set((state: InventoryState) => {
        // 1. Check Containers
        if (state.containers[containerId]) {
            const container = state.containers[containerId];
            const itemIndex = container.items.findIndex((i: Item) => i.id === itemId);
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
            if (item && item.id === itemId) {
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
    }),

    // Stack Items Action
    stackItems: (fromItemId: string, fromContainerId: string, toItemId: string, toContainerId: string) => set((state: InventoryState) => {
        console.log(`[mx-inv] STORE > stackItems: ${fromItemId} (${fromContainerId}) -> ${toItemId} (${toContainerId})`);

        const fromContainer = state.containers[fromContainerId];
        const toContainer = state.containers[toContainerId];
        if (!fromContainer || !toContainer) return state;

        const fromItem = fromContainer.items.find(i => i.id === fromItemId);
        const toItem = toContainer.items.find(i => i.id === toItemId);
        if (!fromItem || !toItem) return state;
        if (fromItem.name !== toItem.name) return state;

        const maxStack = toItem.maxStack || 60;
        const space = maxStack - toItem.count;
        if (space <= 0) return state;

        const toTransfer = Math.min(fromItem.count, space);
        const newToCount = toItem.count + toTransfer;
        const newFromCount = fromItem.count - toTransfer;

        const newToItems = toContainer.items.map(i =>
            i.id === toItemId ? { ...i, count: newToCount } : i
        );

        let newFromItems;
        if (newFromCount <= 0) {
            // Fully merged — remove source item
            newFromItems = fromContainer.items.filter(i => i.id !== fromItemId);
        } else {
            newFromItems = fromContainer.items.map(i =>
                i.id === fromItemId ? { ...i, count: newFromCount } : i
            );
        }

        if (fromContainerId === toContainerId) {
            // Same container — combine both changes
            let combinedItems = toContainer.items.map(i => {
                if (i.id === toItemId) return { ...i, count: newToCount };
                if (i.id === fromItemId) return newFromCount <= 0 ? null : { ...i, count: newFromCount };
                return i;
            }).filter(Boolean) as Item[];

            return {
                containers: { ...state.containers, [toContainerId]: { ...toContainer, items: combinedItems } }
            };
        }

        return {
            containers: {
                ...state.containers,
                [fromContainerId]: { ...fromContainer, items: newFromItems },
                [toContainerId]: { ...toContainer, items: newToItems }
            }
        };
    }),

    // Attachment Actions
    attachToWeapon: (weaponId: string, weaponContainerId: string, attachmentSlot: string, attachmentItem: Item, fromContainerId: string) => set((state: InventoryState) => {
        console.log(`[mx-inv] STORE > attachToWeapon: weapon=${weaponId} slot=${attachmentSlot} item=${attachmentItem.name} from=${fromContainerId}`);

        // Find the weapon (could be in equipment or a container)
        let weapon: Item | null = null;
        let weaponLocation: 'equipment' | 'container' = 'container';
        let equipSlotKey = '';

        // Check equipment first
        if (weaponContainerId.startsWith('equip-')) {
            equipSlotKey = weaponContainerId.replace('equip-', '');
            weapon = state.equipment[equipSlotKey] || null;
            weaponLocation = 'equipment';
        } else {
            // Check containers
            const container = state.containers[weaponContainerId];
            if (container) {
                weapon = container.items.find(i => i.id === weaponId) || null;
            }
        }

        if (!weapon) return state;

        // Remove attachment item from source container
        const sourceContainer = state.containers[fromContainerId];
        if (!sourceContainer) return state;
        const newSourceItems = sourceContainer.items.filter(i => i.id !== attachmentItem.id);

        // Update weapon metadata
        const newAttachments = { ...(weapon.metadata?.attachments || {}), [attachmentSlot]: attachmentItem.name };
        const updatedWeapon = {
            ...weapon,
            metadata: { ...weapon.metadata, attachments: newAttachments }
        };

        // Write updated weapon back
        if (weaponLocation === 'equipment') {
            return {
                equipment: { ...state.equipment, [equipSlotKey]: updatedWeapon },
                containers: { ...state.containers, [fromContainerId]: { ...sourceContainer, items: newSourceItems } }
            };
        } else {
            const targetContainer = state.containers[weaponContainerId];
            const newTargetItems = targetContainer.items.map(i => i.id === weaponId ? updatedWeapon : i);
            return {
                containers: {
                    ...state.containers,
                    [fromContainerId]: { ...sourceContainer, items: newSourceItems },
                    [weaponContainerId]: { ...targetContainer, items: newTargetItems }
                }
            };
        }
    }),

    removeAttachment: (weaponId: string, weaponContainerId: string, attachmentSlot: string, toContainerId: string, targetSlot?: { x: number; y: number }) => set((state: InventoryState) => {
        console.log(`[mx-inv] STORE > removeAttachment: weapon=${weaponId} slot=${attachmentSlot} to=${toContainerId}`, targetSlot);

        // Find the weapon
        let weapon: Item | null = null;
        let weaponLocation: 'equipment' | 'container' = 'container';
        let equipSlotKey = '';

        if (weaponContainerId.startsWith('equip-')) {
            equipSlotKey = weaponContainerId.replace('equip-', '');
            weapon = state.equipment[equipSlotKey] || null;
            weaponLocation = 'equipment';
        } else {
            const container = state.containers[weaponContainerId];
            if (container) {
                weapon = container.items.find(i => i.id === weaponId) || null;
            }
        }

        if (!weapon) return state;
        const attachmentName = weapon.metadata?.attachments?.[attachmentSlot];
        if (!attachmentName) return state;

        // Remove from weapon metadata
        const newAttachments = { ...(weapon.metadata?.attachments || {}) };
        delete newAttachments[attachmentSlot];
        const updatedWeapon = {
            ...weapon,
            metadata: { ...weapon.metadata, attachments: newAttachments }
        };

        // We don't add the item back to the frontend here - the server will handle that
        // and send an UpdateClientInventory that refreshes everything.

        if (weaponLocation === 'equipment') {
            return {
                equipment: { ...state.equipment, [equipSlotKey]: updatedWeapon }
            };
        } else {
            const targetContainer = state.containers[weaponContainerId];
            const newTargetItems = targetContainer.items.map(i => i.id === weaponId ? updatedWeapon : i);
            return {
                containers: {
                    ...state.containers,
                    [weaponContainerId]: { ...targetContainer, items: newTargetItems }
                }
            };
        }
    })
}));

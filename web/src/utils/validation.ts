import { useInventoryStore } from "../store/inventoryStore";

export const validatePlacement = (
    rawContainerId: string,
    item: any,
    relativeSlot: { x: number; y: number },
    rotation: boolean,
    containers: Record<string, any>,
    equipment: Record<string, any>,
    parseContainerId: (id: string) => { baseId: string; regionOffset: { x: number; y: number }; pocketRegion?: any }
) => {
    const { baseId, regionOffset, pocketRegion } = parseContainerId(rawContainerId);

    // -- EQUIPMENT VALIDATION: Type Restrictions & Duplicate Weapons --
    if (baseId.startsWith('equip-')) {
        const slotId = baseId.replace('equip-', '');

        // 1. Type Restriction Check
        const state = useInventoryStore.getState();
        const equipmentSlots = state.equipmentSlots;
        const itemDefs = state.itemDefs;

        const itemDef = itemDefs[item.name];
        const itemType = itemDef?.type || item.type || 'generic';

        const allowedTypes = equipmentSlots[slotId];

        if (allowedTypes && !allowedTypes.includes(itemType)) {
            return false;
        }

        // 2. Duplicate Weapon Check
        if (slotId === 'primary' || slotId === 'secondary') {
            const otherSlot = slotId === 'primary' ? 'secondary' : 'primary';
            const currentOther = equipment[otherSlot];
            if (currentOther && currentOther.name === item.name) {
                return false;
            }
        }

        return true; // EARLY RETURN: Equipment slots don't need boundary or collision checks
    }

    const container = containers[baseId];
    if (!container) return false;

    // Convert Relative Slot -> Global Slot
    const slot = {
        x: relativeSlot.x + regionOffset.x,
        y: relativeSlot.y + regionOffset.y
    };

    // 0. Recursion / Self-Storage Check
    // Prevent putting a bag inside itself or similar bags if logic implies they provide the storage
    if (baseId === item.id ||
        baseId.includes(item.name) ||
        (item.type && ['backpack', 'vest', 'bag'].includes(item.type) && baseId.includes(item.type)) ||
        (item.name && baseId.includes(item.name))
    ) {
        return false;
    }

    const originalSize = item.size || { x: 1, y: 1 };
    const size = rotation ? { x: originalSize.y, y: originalSize.x } : originalSize;

    // 0. Pocket Boundary Check (Strict)
    if (pocketRegion) {
        if (
            relativeSlot.x < 1 ||
            relativeSlot.y < 1 ||
            relativeSlot.x + size.x - 1 > pocketRegion.width ||
            relativeSlot.y + size.y - 1 > pocketRegion.height
        ) {
            return false;
        }
    }

    // 1. Global Boundary Check (Fallback)
    if (
        slot.x < 1 ||
        slot.y < 1 ||
        slot.x + size.x - 1 > container.size.width ||
        slot.y + size.y - 1 > container.size.height
    ) {
        return false;
    }

    // 2. Custom Layout Mask Check
    if (container.validSlots) {
        for (let px = 0; px < size.x; px++) {
            for (let py = 0; py < size.y; py++) {
                const slotToCheck = { x: slot.x + px, y: slot.y + py };
                const isValid = container.validSlots.some(
                    (vs: { x: number, y: number }) => vs.x === slotToCheck.x && vs.y === slotToCheck.y
                );
                if (!isValid) return false;
            }
        }
    }

    // 3. Collision Check
    const hasCollision = container.items.some((otherItem: any) => {
        if (otherItem.id === item.id) return false; // Ignore self

        const otherRotated = !!otherItem.rotated;
        const otherOriginalSize = otherItem.size || { x: 1, y: 1 };
        const otherSize = otherRotated ? { x: otherOriginalSize.y, y: otherOriginalSize.x } : otherOriginalSize;

        const overlapsX =
            slot.x < otherItem.slot.x + otherSize.x &&
            slot.x + size.x > otherItem.slot.x;
        const overlapsY =
            slot.y < otherItem.slot.y + otherSize.y &&
            slot.y + size.y > otherItem.slot.y;

        return overlapsX && overlapsY;
    });

    if (hasCollision) return false;

    return true;
};

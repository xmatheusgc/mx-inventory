import { useCallback } from 'react';
import type { DragEndEvent, DragMoveEvent } from '@dnd-kit/core';
import { useInventoryStore } from '../store/inventoryStore';
import { ITEM_CONFIGS } from '../config/items';
import { fetchNui } from '../utils/nui';
import { CONTAINER_LAYOUTS } from '../config/layouts';
import { validatePlacement } from '../utils/validation';

interface HighlightState {
    containerId: string;
    slots: { x: number; y: number }[];
    isValid: boolean;
}

export function useDndHandlers({
    activeId,
    setActiveId,
    activeDragData,
    setActiveDragData,
    setActiveContainerId, // Restored because it's used in handleDragStart
    activeDragRotation,
    setActiveDragRotation,
    activeDragFolded,
    setActiveDragFolded,
    setDragHighlight,
    itemDefs,
    currentDragState,
}: {
    activeId: string | null;
    setActiveId: React.Dispatch<React.SetStateAction<string | null>>;
    activeDragData: any | null;
    setActiveDragData: React.Dispatch<React.SetStateAction<any | null>>;
    setActiveContainerId: React.Dispatch<React.SetStateAction<string | null>>;
    activeDragRotation: boolean;
    setActiveDragRotation: React.Dispatch<React.SetStateAction<boolean>>;
    activeDragFolded: boolean;
    setActiveDragFolded: React.Dispatch<React.SetStateAction<boolean>>;
    setDragHighlight: React.Dispatch<React.SetStateAction<HighlightState | undefined>>;
    itemDefs: Record<string, any>; // Direct from store
    currentDragState: React.MutableRefObject<{ overId: string; activeRect: any } | null>;
}) {
    const {
        containers,
        equipment,
        moveItem,
        equipItem,
        unequipItem,
        swapEquipment,
        loadAmmoIntoWeapon,
        attachToWeapon,
        stackItems,
        setDragCompatibility,
        attachToHelmet,
    } = useInventoryStore();

    const SLOT_SIZE = 64;
    const GAP = 0;

    // Helper to parse complex Drop IDs (e.g. "vest-1::pocket::0")
    const parseContainerId = useCallback((id: string) => {
        if (!id) return { baseId: id, regionOffset: { x: 0, y: 0 } };

        const parts = id.split('::pocket::');
        const baseId = parts[0];

        if (parts.length < 2) return { baseId, regionOffset: { x: 0, y: 0 } };

        const pocketIdx = parseInt(parts[1]);
        const container = containers[baseId];
        if (!container) return { baseId, regionOffset: { x: 0, y: 0 } };

        // Resolve Layout
        const layout = (container.name ? CONTAINER_LAYOUTS[container.name] : null) || CONTAINER_LAYOUTS[container.label] || (container.type === 'vest' ? CONTAINER_LAYOUTS['vest'] : CONTAINER_LAYOUTS['backpack']);

        // Flatten pockets from rows to find the correct index
        const allPockets = layout.rows.flatMap((r: any) => r.pockets);

        if (allPockets && allPockets[pocketIdx]) {
            const pocket = allPockets[pocketIdx];
            return {
                baseId,
                regionOffset: { x: pocket.x - 1, y: pocket.y - 1 },
                pocketRegion: pocket // Return full pocket info (width/height)
            };
        }

        return { baseId, regionOffset: { x: 0, y: 0 } };
    }, [containers]);

    const calculateTargetSlot = useCallback((overId: string, activeRect: any) => {
        const containerElement = document.getElementById(overId);
        if (!containerElement) return null;

        const containerRect = containerElement.getBoundingClientRect();
        const PADDING_X = 13;
        const PADDING_Y = 13;

        const relativeX = activeRect.left - containerRect.left - PADDING_X;
        const relativeY = activeRect.top - containerRect.top - PADDING_Y;

        const slotX = Math.round(relativeX / (SLOT_SIZE + GAP)) + 1;
        const slotY = Math.round(relativeY / (SLOT_SIZE + GAP)) + 1;

        return { x: slotX, y: slotY };
    }, []);


    const updateDragHighlight = useCallback((overId: string, activeRect: any, rotation: boolean, folded: boolean) => {
        if (!overId) {
            setDragHighlight(undefined);
            return;
        }

        const { baseId, regionOffset } = parseContainerId(overId);

        // Only container logic here
        if (!containers[baseId]) {
            setDragHighlight(undefined);
            return;
        }

        const activeItem: any = activeDragData;

        if (!activeItem) return;

        // Resolve current size respecting live fold state
        const config = ITEM_CONFIGS[activeItem.name];
        const baseSize: { x: number; y: number } = config
            ? (folded ? config.foldedSize : config.expandedSize)
            : (activeItem.size || { x: 1, y: 1 });

        // Build a virtual item with the correct current size for validation
        const activeItemWithCurrentSize = { ...activeItem, size: baseSize };

        // calculateTargetSlot returns RELATIVE slot to the droppable element
        const relativeSlot = calculateTargetSlot(overId, activeRect);

        if (relativeSlot) {
            // Validate using Global Logic (inside the helper)
            const isValid = validatePlacement(overId, activeItemWithCurrentSize, relativeSlot, rotation, containers, equipment, parseContainerId);

            const highlightSlots = [];
            const size = rotation ? { x: baseSize.y, y: baseSize.x } : baseSize;

            // Generate Highlight Slots (Visual / Relative)
            for (let x = 0; x < size.x; x++) {
                for (let y = 0; y < size.y; y++) {
                    // Push GLOBAL coordinates for Container highlighting
                    highlightSlots.push({ x: relativeSlot.x + regionOffset.x + x, y: relativeSlot.y + regionOffset.y + y });
                }
            }

            setDragHighlight({
                containerId: baseId,
                slots: highlightSlots,
                isValid
            });
        } else {
            setDragHighlight(undefined);
        }
    }, [activeDragData, containers, calculateTargetSlot, validatePlacement, parseContainerId, setDragHighlight]);

    const handleDragStart = (event: any) => {
        setActiveId(event.active.id);
        setActiveDragData(event.active.data.current);
        if (event.active.data.current?.containerId) {
            setActiveContainerId(event.active.data.current.containerId);
        } else {
            setActiveContainerId(null);
        }

        const item = event.active.data.current;
        if (item && item.rotated !== undefined) {
            setActiveDragRotation(item.rotated);
        }

        if (item) {
            const itemFromEquip = !event.active.data.current?.containerId ||
                (event.active.data.current?.containerId as string)?.startsWith('equip-');
            setActiveDragFolded(itemFromEquip ? false : !!item.folded);
        }

        // Compute compatible targets for visual feedback
        if (item) {
            const defs = itemDefs;
            const compatibleIds = new Set<string>();
            let dragType: 'ammo' | 'attachment' | 'stack' | null = null;

            // Ammo -> find compatible weapons (items + equipment slots)
            if (item.type === 'ammo') {
                dragType = 'ammo';
                const ammoDef = defs[item.name];
                const ammoCaliber = ammoDef?.ammo?.caliber;
                if (ammoCaliber) {
                    for (const c of Object.values(containers)) {
                        for (const ci of c.items) {
                            if (ci.type?.startsWith('weapon_')) {
                                const wDef = defs[ci.name];
                                if (wDef?.equipment?.caliber === ammoCaliber) compatibleIds.add(ci.id);
                            }
                        }
                    }
                    for (const [slot, eq] of Object.entries(equipment)) {
                        if (eq?.type?.startsWith('weapon_')) {
                            const wDef = defs[eq.name];
                            if (wDef?.equipment?.caliber === ammoCaliber) {
                                compatibleIds.add(eq.id);
                                compatibleIds.add(`equip-${slot}`);
                            }
                        }
                    }
                }
            }

            // Attachment -> find compatible weapons (items + equipment slots + attachment slots)
            if (item.type?.startsWith('attachment_')) {
                dragType = 'attachment';
                const attachDef = defs[item.name];
                const attachSlot = attachDef?.attachment?.slot;
                if (attachSlot) {
                    for (const c of Object.values(containers)) {
                        for (const ci of c.items) {
                            if (ci.type?.startsWith('weapon_')) {
                                const wDef = defs[ci.name];
                                const isSupported = wDef?.equipment?.supportedAttachments?.[attachSlot];
                                const matchesCaliber = !attachDef.attachment.caliber || (wDef?.equipment?.caliber === attachDef.attachment.caliber);

                                if (isSupported && matchesCaliber && !ci.metadata?.attachments?.[attachSlot]) {
                                    compatibleIds.add(ci.id);
                                    compatibleIds.add(`attachment-${ci.id}-${attachSlot}`);
                                }
                            }
                        }
                    }
                    for (const [slot, eq] of Object.entries(equipment)) {
                        if (eq?.type?.startsWith('weapon_')) {
                            const wDef = defs[eq.name];
                            const isSupported = wDef?.equipment?.supportedAttachments?.[attachSlot];
                            const matchesCaliber = !attachDef.attachment.caliber || (wDef?.equipment?.caliber === attachDef.attachment.caliber);

                            if (isSupported && matchesCaliber && !eq.metadata?.attachments?.[attachSlot]) {
                                compatibleIds.add(eq.id);
                                compatibleIds.add(`equip-${slot}`);
                                compatibleIds.add(`attachment-${eq.id}-${attachSlot}`);
                            }
                        }
                    }
                }
            }

            // Helmet accessory
            if (item.type === 'helmet_accessory') {
                dragType = 'attachment' as any;
                const accDef = defs[item.name];
                const accSlot = accDef?.helmetAccessory?.slot;
                if (accSlot) {
                    for (const c of Object.values(containers)) {
                        for (const ci of c.items) {
                            if (ci.type === 'helmet') {
                                const hDef = defs[ci.name];
                                const supported: string[] = hDef?.equipment?.supportedAccessories || [];
                                const hasAnyAccessory = ci.metadata?.accessories && Object.keys(ci.metadata.accessories).length > 0;
                                if (supported.includes(accSlot) && !hasAnyAccessory) {
                                    compatibleIds.add(ci.id);
                                    compatibleIds.add(`helmet-acc-${ci.id}-${accSlot}`);
                                }
                            }
                        }
                    }
                    const helmet = equipment['head'];
                    if (helmet) {
                        const hDef = defs[helmet.name];
                        const supported: string[] = hDef?.equipment?.supportedAccessories || [];
                        const hasAnyEquippedAccessory = helmet.metadata?.accessories && Object.keys(helmet.metadata.accessories).length > 0;
                        if (supported.includes(accSlot) && !hasAnyEquippedAccessory) {
                            compatibleIds.add(helmet.id);
                            compatibleIds.add(`equip-head`);
                            compatibleIds.add(`helmet-acc-${helmet.id}-${accSlot}`);
                        }
                    }
                }
            }

            if (item.stackable) {
                dragType = dragType || 'stack';
                for (const c of Object.values(containers)) {
                    for (const ci of c.items) {
                        if (ci.id !== item.id && ci.name === item.name && ci.stackable) {
                            const maxStack = ci.maxStack || 60;
                            if (ci.count < maxStack) compatibleIds.add(ci.id);
                        }
                    }
                }
            }

            if (item.type || true) { // Always check type
                const state = useInventoryStore.getState();
                const itemDef = state.itemDefs[item.name];
                const itemType = itemDef?.type || item.type || 'generic';
                const equipSlotMap = state.equipmentSlots;

                for (const [slot, accepted] of Object.entries(equipSlotMap)) {
                    if (accepted.includes(itemType) && !equipment[slot]) {
                        compatibleIds.add(`equip-${slot}`);
                        dragType = dragType || 'stack';
                    }
                }
            }

            if (compatibleIds.size > 0 && dragType) {
                setDragCompatibility({ targetIds: compatibleIds, dragType });
            } else {
                setDragCompatibility(null);
            }
        }
    };

    const handleDragMove = (event: DragMoveEvent) => {
        const { active, over } = event;

        if (!over || !activeId) {
            setDragHighlight(undefined);
            currentDragState.current = null;
            return;
        }

        // @ts-ignore
        const activeRect = active.rect.current.translated;
        if (!activeRect) return;

        // Update refs
        currentDragState.current = { overId: over.id as string, activeRect };

        updateDragHighlight(over.id as string, activeRect, activeDragRotation, activeDragFolded);
    };

    const handleDragEnd = (event: DragEndEvent) => {
        const { active, over } = event;
        const finalRotation = activeDragRotation;
        // Capture fold state BEFORE clearing — needed for equipment unequip path
        const finalFolded = activeDragFolded;

        // Clear States
        setActiveId(null);
        setActiveDragData(null);
        setActiveContainerId(null);
        setActiveDragRotation(false); // Fix rotation bleed
        setActiveDragFolded(false);   // Fix fold bleed
        setDragHighlight(undefined); // Clear highlight
        currentDragState.current = null;
        setDragCompatibility(null); // Clear compatibility highlights

        if (!over) {
            // If dragging an installed attachment and dropping into empty space, also remove it
            const dragData = active.data.current as any;
            if (dragData?.type === 'installed-attachment') {
                const { weaponId, weaponContainerId, slotId, attachmentName } = dragData;
                useInventoryStore.getState().removeAttachment(weaponId, weaponContainerId, slotId, 'player-inv');
                fetchNui('removeAttachment', {
                    weaponId,
                    weaponContainerId,
                    attachmentSlot: slotId,
                    attachmentItem: attachmentName
                });
            } else if (dragData?.type === 'installed-helmet-accessory') {
                const { helmetId, helmetContainerId, slotId, accessoryName } = dragData;
                useInventoryStore.getState().removeHelmetAccessory(helmetId, helmetContainerId, slotId, 'player-inv');
                fetchNui('removeHelmetAccessory', {
                    helmetId,
                    helmetContainerId,
                    accessorySlot: slotId,
                    accessoryItem: accessoryName
                });
            }
            return;
        }

        // Handle installed-attachment being dropped onto a container
        const dragData = active.data.current as any;
        if (dragData?.type === 'installed-attachment' || dragData?.type === 'installed-helmet-accessory') {
            const isHelmetAcc = dragData.type === 'installed-helmet-accessory';

            const toId = over.id as string;
            const { baseId, regionOffset } = parseContainerId(toId);

            const containerElement = document.getElementById(toId);
            if (!containerElement) return;

            const containerRect = containerElement.getBoundingClientRect();
            const itemRect = (active.rect.current as any).translated;
            if (!itemRect) return;

            const PADDING_X = 13;
            const PADDING_Y = 13;

            const relativeX = itemRect.left - containerRect.left - PADDING_X;
            const relativeY = itemRect.top - containerRect.top - PADDING_Y;

            const relSlotX = Math.max(1, Math.round(relativeX / (SLOT_SIZE + GAP)) + 1);
            const relSlotY = Math.max(1, Math.round(relativeY / (SLOT_SIZE + GAP)) + 1);

            const isValidPlacement = validatePlacement(toId, dragData, { x: relSlotX, y: relSlotY }, finalRotation, containers, equipment, parseContainerId);
            if (!isValidPlacement) return;

            const slotX = relSlotX + regionOffset.x;
            const slotY = relSlotY + regionOffset.y;
            const targetSlot = { x: slotX, y: slotY };

            if (isHelmetAcc) {
                const { helmetId, helmetContainerId, slotId, accessoryName } = dragData;
                useInventoryStore.getState().removeHelmetAccessory(helmetId, helmetContainerId, slotId, baseId, targetSlot);
                fetchNui('removeHelmetAccessory', {
                    helmetId,
                    helmetContainerId,
                    accessorySlot: slotId,
                    accessoryItem: accessoryName,
                    toContainerId: baseId,
                    toSlot: targetSlot,
                    rotated: finalRotation,
                    folded: finalFolded
                });
            } else {
                const { weaponId, weaponContainerId, slotId, attachmentName } = dragData;
                useInventoryStore.getState().removeAttachment(weaponId, weaponContainerId, slotId, baseId, targetSlot);
                fetchNui('removeAttachment', {
                    weaponId,
                    weaponContainerId,
                    attachmentSlot: slotId,
                    attachmentItem: attachmentName,
                    toContainerId: baseId,
                    toSlot: targetSlot,
                    rotated: finalRotation,
                    folded: finalFolded
                });
            }
            return;
        }


        const itemId = active.id as string;

        // Find Item & Source
        let fromContainerId = '';
        let item: any = null;

        // Check containers
        for (const c of Object.values(containers)) {
            const found = c.items.find((i: any) => i.id === itemId);
            if (found) {
                fromContainerId = c.id;
                item = found;
                break;
            }
        }

        // Check equipment if not in container
        if (!item) {
            for (const [slot, equipItem] of Object.entries(equipment)) {
                if (equipItem?.id === itemId) {
                    fromContainerId = `equip-${slot}`; // Special ID for equipment source
                    item = equipItem;
                    break;
                }
            }
        }

        if (!fromContainerId || !item) return;

        const toId = over.id as string;

        // --- HELMET ACCESSORY SLOT LOGIC ---
        if (toId.startsWith('helmet-acc-')) {
            const slotData = over.data.current;
            if (!slotData) return;

            const accessorySlot = slotData.slotId as string;
            const helmetId = slotData.helmetId as string;
            const helmetContainerId = slotData.helmetContainerId as string;

            if (item.type !== 'helmet_accessory') return;

            const accDef = itemDefs[item.name];
            const validSlot = accDef?.helmetAccessory?.slot;

            if (validSlot !== accessorySlot) return;

            // Verify the target helmet supports it (if we can find the target helmet)
            let targetHelmet = null;
            if (helmetContainerId.startsWith('equip-')) {
                targetHelmet = equipment['head'];
            } else {
                const c = containers[helmetContainerId];
                if (c) targetHelmet = c.items.find((i: any) => i.id === helmetId);
            }

            if (targetHelmet) {
                const hDef = itemDefs[targetHelmet.name];
                const supported: string[] = hDef?.equipment?.supportedAccessories || [];
                if (!supported.includes(accessorySlot)) return;

                // Valid! Dispatch attach action
                fetchNui('attachHelmetAccessory', {
                    helmetId,
                    helmetContainerId,
                    accessorySlot,
                    accessoryItemId: item.id,
                    accessoryItem: item.name,
                    fromContainerId
                });
                useInventoryStore.getState().attachToHelmet(helmetId, helmetContainerId, accessorySlot, item, fromContainerId);
            }
            return;
        }

        // --- ATTACHMENT SLOT LOGIC ---
        if (toId.startsWith('attachment-')) {
            // over.data.current contains `{ type: 'attachment-slot', weaponId, slotId, weaponContainerId }`
            const slotData = over.data.current as any;
            if (!slotData) return;

            const attachmentSlot = slotData.slotId as string;
            const weaponId = slotData.weaponId as string;
            const weaponContainerId = slotData.weaponContainerId as string;

            // Verify it's actually an attachment
            if (!item.type?.startsWith('attachment_')) return;

            // Verify target weapon actually supports this slot (double check)
            const attachDef = itemDefs[item.name];
            const validSlot = attachDef?.attachment?.slot;
            const attachCaliber = attachDef?.attachment?.caliber;

            if (validSlot !== attachmentSlot) return;

            let targetWeapon = null;
            if (weaponContainerId.startsWith('equip-')) {
                const equipSlot = weaponContainerId.replace('equip-', '');
                targetWeapon = equipment[equipSlot];
            } else {
                const c = containers[weaponContainerId];
                if (c) {
                    targetWeapon = c.items.find((i: any) => i.id === weaponId);
                }
            }

            if (targetWeapon) {
                const wDef = itemDefs[targetWeapon.name];
                if (!wDef?.equipment?.supportedAttachments?.[attachmentSlot]) return;
                if (attachCaliber && wDef.equipment.caliber !== attachCaliber) return;

                // It is valid! Prevent normal move and handle attachment
                // Update store instantly for feedback
                attachToWeapon(weaponId, weaponContainerId, attachmentSlot, item, fromContainerId);

                // Tell server
                fetchNui('attachToWeapon', {
                    weaponId,
                    weaponContainerId,
                    attachmentSlot,
                    attachmentItemId: item.id,
                    attachmentItem: item.name,
                    fromContainerId
                });
            }

            return;
        }

        // --- NON-ATTACHMENT LOGIC BELOW (Equipment & Containers) ---

        // Handle dropping directly onto items (Stacking/Ammo)
        const overData = over.data.current as any;
        if (overData?.type === 'item') {
            const targetItem = overData.item;
            const targetContainerId = overData.containerId;

            // 1. Ammo Loading (Drag ammo onto weapon)
            if (item.type === 'ammo' && targetItem && targetItem.type?.startsWith('weapon_')) {
                const ammoDef = itemDefs[item.name];
                const weaponDef = itemDefs[targetItem.name];

                if (ammoDef?.ammo?.caliber === weaponDef?.equipment?.caliber) {
                    let weaponSlotToPass = targetItem.id;
                    if (targetContainerId.startsWith('equip-')) {
                        weaponSlotToPass = targetContainerId.replace('equip-', '');
                    }

                    loadAmmoIntoWeapon(weaponSlotToPass, targetContainerId, item, fromContainerId);
                    fetchNui('loadAmmoIntoWeapon', {
                        id: item.id,
                        ammoItem: { name: item.name, slot: item.slot },
                        weaponSlot: weaponSlotToPass,
                        weaponContainer: targetContainerId,
                        ammoContainer: fromContainerId
                    });
                    return;
                }
            }

            // 1.5 Attachment / Accessory Quick-Equip (Drag onto item)
            if (item.type?.startsWith('attachment_') && targetItem && targetItem.type?.startsWith('weapon_')) {
                const attachDef = itemDefs[item.name];
                const weaponDef = itemDefs[targetItem.name];
                const attachSlot = attachDef?.attachment?.slot;
                const attachCaliber = attachDef?.attachment?.caliber;

                if (attachSlot && weaponDef?.equipment?.supportedAttachments?.[attachSlot]) {
                    if (attachCaliber && weaponDef.equipment.caliber !== attachCaliber) return;
                    if (!targetItem.metadata?.attachments?.[attachSlot]) {
                        attachToWeapon(targetItem.id, targetContainerId, attachSlot, item, fromContainerId);
                        fetchNui('attachToWeapon', {
                            weaponId: targetItem.id,
                            weaponContainerId: targetContainerId,
                            attachmentSlot: attachSlot,
                            attachmentItemId: item.id,
                            attachmentItem: item.name,
                            fromContainerId
                        });
                        return;
                    }
                }
            }

            if (item.type === 'helmet_accessory' && targetItem && targetItem.type === 'helmet') {
                const accDef = itemDefs[item.name];
                const helmetDef = itemDefs[targetItem.name];
                const accSlot = accDef?.helmetAccessory?.slot;
                const supported: string[] = helmetDef?.equipment?.supportedAccessories || [];

                if (accSlot && supported.includes(accSlot)) {
                    const hasAccessory = targetItem.metadata?.accessories && Object.keys(targetItem.metadata.accessories).length > 0;
                    if (!hasAccessory) {
                        fetchNui('attachHelmetAccessory', {
                            helmetId: targetItem.id,
                            helmetContainerId: targetContainerId,
                            accessorySlot: accSlot,
                            accessoryItemId: item.id,
                            accessoryItem: item.name,
                            fromContainerId
                        });
                        attachToHelmet(targetItem.id, targetContainerId, accSlot, item, fromContainerId);
                        return;
                    }
                }
            }

            // 2. Ammo Stacking (Drag ammo onto ammo) OR Same Item Stacking
            if (targetItem && targetItem.id !== item.id && targetItem.name === item.name) {
                if (targetItem.stackable && item.stackable) {
                    stackItems(item.id, fromContainerId, targetItem.id, targetContainerId);
                    fetchNui('stackItems', {
                        fromItemId: item.id,
                        fromContainerId: fromContainerId,
                        toItemId: targetItem.id,
                        toContainerId: targetContainerId,
                        amount: item.count || 1 // In future: open modal to select split amount
                    });
                    return;
                }
            }

            // Default: If dropped exactly on another item but they shouldn't stack, just fail (or swap in future?)
            // Let it fall through to slot logic if dragging around them? No, we just reject to be safe.
            // Actually, if it hits an item bounding box, we should probably attempt to find the empty slot near it.
            // For now, if it didn't stack/load ammo, we ignore item drops.
            return;
        }

        // Regular Drop on Container/Equipment Slot
        const isEquipping = toId.startsWith('equip-');
        const isUnequipping = fromContainerId.startsWith('equip-') && !isEquipping;

        if (isEquipping) {
            const targetSlotName = toId.replace('equip-', '');

            // PRE-EMPTIVE VALIDATION: Don't even hit the store if type is mismatched
            const isValid = validatePlacement(toId, item, { x: 1, y: 1 }, finalRotation, containers, equipment, parseContainerId);
            if (!isValid) return;

            const existingEquip = equipment[targetSlotName];

            if (existingEquip) {
                // SWAP LOGIC: If it's already an equipment slot, swap them. 
                // IF it's coming from a container, we use equipItem which will now handle the replacement.
                if (fromContainerId.startsWith('equip-')) {
                    const fromEquipSlot = fromContainerId.replace('equip-', '');
                    if (existingEquip.id !== item.id) {
                        swapEquipment(fromEquipSlot, targetSlotName);
                        fetchNui('swapEquipment', {
                            item: item.name,
                            id: item.id,
                            from: fromContainerId,
                            slot: targetSlotName
                        });
                    }
                } else {
                    // Item from container to occupied equip slot
                    equipItem(targetSlotName, item, fromContainerId);
                    fetchNui('equipItem', {
                        item: item.name,
                        id: item.id,
                        from: fromContainerId,
                        slot: targetSlotName
                    });
                }
            } else {
                equipItem(targetSlotName, item, fromContainerId);
                fetchNui('equipItem', {
                    item: item.name,
                    id: item.id,
                    from: fromContainerId,
                    slot: targetSlotName
                });
            }
        } else {
            // 3. Regular Container Movement
            const { baseId, regionOffset } = parseContainerId(toId);
            const containerElement = document.getElementById(toId);
            if (!containerElement) return;

            const containerRect = containerElement.getBoundingClientRect();
            const itemRect = (active.rect.current as any).translated;
            if (!itemRect) return;

            const PADDING_X = 13;
            const PADDING_Y = 13;

            const relativeX = itemRect.left - containerRect.left - PADDING_X;
            const relativeY = itemRect.top - containerRect.top - PADDING_Y;

            const relSlotX = Math.max(1, Math.round(relativeX / (SLOT_SIZE + GAP)) + 1);
            const relSlotY = Math.max(1, Math.round(relativeY / (SLOT_SIZE + GAP)) + 1);

            const config = ITEM_CONFIGS[item.name];
            const currentSize = config
                ? (finalFolded ? config.foldedSize : config.expandedSize)
                : (item.size || { x: 1, y: 1 });

            const itemWithCurrentSize = { ...item, size: currentSize };

            const isValidPlacement = validatePlacement(toId, itemWithCurrentSize, { x: relSlotX, y: relSlotY }, finalRotation, containers, equipment, parseContainerId);

            if (isValidPlacement) {
                const slotX = relSlotX + regionOffset.x;
                const slotY = relSlotY + regionOffset.y;

                const targetSlot = { x: slotX, y: slotY };
                const actionPayload = {
                    item: item.name,
                    id: item.id,
                    from: fromContainerId,
                    to: baseId,
                    slot: targetSlot,
                    rotated: finalRotation,
                    folded: finalFolded
                };

                if (isUnequipping) {
                    const fromEquipSlot = fromContainerId.replace('equip-', '');
                    unequipItem(fromEquipSlot, baseId, targetSlot, finalFolded, finalRotation);
                    fetchNui('unequipItem', {
                        item: item.name,
                        id: item.id,
                        fromSlot: fromEquipSlot,
                        to: baseId,
                        slot: targetSlot,
                        rotated: finalRotation,
                        folded: finalFolded
                    });
                } else {
                    moveItem(fromContainerId, baseId, item.id, targetSlot, finalRotation, finalFolded);

                    // Only fire rotation sync if the item rotated in-place without moving containers
                    if (fromContainerId === baseId && item.rotated !== finalRotation) {
                        fetchNui('rotateItem', {
                            id: item.id,
                            containerId: baseId,
                            rotated: finalRotation
                        });
                    }

                    // Fold sync
                    if (fromContainerId === baseId && item.folded !== finalFolded) {
                        fetchNui('foldItem', {
                            id: item.id,
                            containerId: baseId,
                            folded: finalFolded
                        });
                    }

                    fetchNui('moveItem', actionPayload);
                }
            } else {
                // console.log('[Dnd] Placement blocked (Collision, Bounds, Type mismatch, or Rotation Mismatch)');
            }
        }
    };

    return { handleDragStart, handleDragMove, handleDragEnd, updateDragHighlight };
}

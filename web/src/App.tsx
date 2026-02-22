import { useEffect, useState, useCallback, useRef } from 'react';
import { useInventoryStore } from './store/inventoryStore';
import { fetchNui, isEnvBrowser } from './utils/nui';
import { mockContainers, mockEquipment } from './utils/mockData';
import { ItemView } from './components/Item';
import { EquipmentPanel } from './components/EquipmentPanel';
import { ContainerWindow } from './components/ContainerWindow';
import { ItemDetailsWindow } from './components/ItemDetailsWindow';
import { snapCenterToCursor } from './utils/modifiers';
import { CONTAINER_LAYOUTS } from './config/layouts';
import { ITEM_CONFIGS } from './config/items';
import { DndContext, type DragEndEvent, type DragMoveEvent, useSensor, useSensors, PointerSensor, rectIntersection, DragOverlay } from '@dnd-kit/core';
import { PlayerInventory } from './components/PlayerInventory';
import { StashInventory } from './components/StashInventory';
import { GiveItemModal } from './components/GiveItemModal';

// Mock data
interface WeightUpdate {
  [key: string]: number;
}

const SLOT_SIZE = 64;
const GAP = 0; // User requested no spacing

interface HighlightState {
  containerId: string;
  slots: { x: number; y: number }[];
  isValid: boolean;
}

function App() {
  const {
    isOpen, setOpen, setContainerData, moveItem, containers, updateContainerWeight,
    equipment, setEquipment, equipItem, unequipItem, swapEquipment, loadAmmoIntoWeapon, toggleItemFold, setContainers,
    openWindows, closeWindow, detailsWindows, closeDetails, attachToWeapon, stackItems, setDragCompatibility,
    giveTarget, setGiveTarget, receiveRequest, setReceiveRequest
  } = useInventoryStore();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [activeDragData, setActiveDragData] = useState<any | null>(null);
  const [activeDragRotation, setActiveDragRotation] = useState<boolean>(false);
  const [activeDragFolded, setActiveDragFolded] = useState<boolean>(false);
  const [dragHighlight, setDragHighlight] = useState<HighlightState | undefined>(undefined);

  const [activeContainerId, setActiveContainerId] = useState<string | null>(null);

  // Keep track of the current drag state so we can re-verify on rotation change
  const currentDragState = useRef<{ overId: string; activeRect: any } | null>(null);

  // Cache Item Definitions to support partial updates
  const itemDefsRef = useRef<Record<string, any>>({});

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 5,
      },
    })
  );

  // Browser Dev Mode: Auto-Open & Load Mocks
  useEffect(() => {
    if (isEnvBrowser()) {
      setOpen(true);
      document.body.style.backgroundColor = '#1a1a1a'; // Dark background

      // Load Mocks so UI isn't empty
      Object.values(mockContainers).forEach((c: any) => setContainerData(c.id, c));
      setEquipment(mockEquipment as any);
    }
  }, [setOpen, setContainerData, setEquipment]);



  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const { action, data } = event.data;
      // console.log('NUI Message:', action, data);

      if (action === 'open' || action === 'update') {
        if (data) {
          const { itemDefs: incomingDefs, equipment: equipData } = data;

          // Update Cache if provided
          if (incomingDefs) {
            itemDefsRef.current = incomingDefs;
            (window as any).__itemDefs = incomingDefs;
          }

          const defs = itemDefsRef.current;

          const enrichItems = (items: any[]) => items.map(item => {
            const def = defs[item.name] || {};

            // Resolve item size: if folded, use foldedSize from ITEM_CONFIGS;
            // otherwise use def.size (from server item definition) or existing item.size.
            const itemConfig = ITEM_CONFIGS[item.name];
            let resolvedSize: { x: number; y: number };
            if (item.folded && itemConfig) {
              resolvedSize = itemConfig.foldedSize;
            } else if (itemConfig && !item.folded) {
              resolvedSize = itemConfig.expandedSize;
            } else {
              resolvedSize = def?.size || item.size || { x: 1, y: 1 };
            }

            return {
              ...def,
              ...item,
              size: resolvedSize,
              weight: def?.weight || item.weight || 0,
              type: def?.type || item.type || 'generic',
              image: (def?.image || item.image) ? `items/${def?.image || item.image}` : undefined
            };
          });


          // Dynamic Container Loading
          const newContainers: Record<string, any> = {};

          Object.entries(data).forEach(([key, value]: [string, any]) => {
            if (key === 'itemDefs' || key === 'equipment') return;
            if (typeof value === 'object' && value !== null && value.items) {
              const enriched = { ...value, items: enrichItems(value.items) };
              newContainers[enriched.id] = enriched;
            }
          });

          setContainers(newContainers);

          // Update Equipment if provided
          if (equipData) {
            const enrichedEquip: any = {};
            Object.entries(equipData).forEach(([slot, item]: [string, any]) => {
              if (item) {
                const def = defs[item.name] || {};
                // Equipment items are always expanded — never folded while equipped
                const itemConfig = ITEM_CONFIGS[item.name];
                enrichedEquip[slot] = {
                  ...def,
                  ...item,
                  folded: false,
                  size: itemConfig ? itemConfig.expandedSize : (def?.size || item.size || { x: 1, y: 1 }),
                  image: (def?.image || item.image) ? `items/${def?.image || item.image}` : undefined
                };
              } else {
                enrichedEquip[slot] = null;
              }
            });
            setEquipment(enrichedEquip);
          }
        }
      }

      if (action === 'open') {
        setOpen(true);
      }


      if (action === 'close') {
        setOpen(false);
        setGiveTarget(null);
        useInventoryStore.setState({ detailsWindows: [] });
      } else if (action === 'updateWeaponAmmo') {
        const { weaponSlot, totalAmmo, clipAmmo } = data;
        useInventoryStore.getState().updateWeaponAmmo(weaponSlot, totalAmmo, clipAmmo);
      } else if (action === 'updateWeights') {
        const weights = data as WeightUpdate;
        Object.entries(weights).forEach(([id, weight]) => {
          updateContainerWeight(id, weight);
        });
      } else if (action === 'receiveItemRequest') {
        // Incoming give request from another player
        useInventoryStore.getState().setReceiveRequest(data);
      } else if (action === 'giveRequestExpired') {
        // Auto-close receiver modal on timeout
        useInventoryStore.getState().setReceiveRequest(null);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [setOpen, setContainerData, updateContainerWeight]);

  useEffect(() => {
    if (activeId) {
      // Check in containers
      let item: any = Object.values(containers).flatMap((c: any) => c.items).find((i: any) => i.id === activeId);
      // Check in equipment
      if (!item) {
        item = Object.values(equipment).find(i => i?.id === activeId);
      }

      if (item) setActiveDragRotation(!!item.rotated);
    }
  }, [activeId, containers, equipment]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (['5', '6', '7', '8'].includes(e.key)) {
        useInventoryStore.getState().setShortcut(e.key);
      }

      if (e.key === 'Escape') {
        fetchNui('close');
        setOpen(false);
      }
      // Keyboard Listeners (Rotate R, Fold F)
      if (!activeId) return;

      if (e.key.toLowerCase() === 'r') {
        setActiveDragRotation(prev => !prev);
        // Only update visual state. Store is updated on Drop.
      }

      if (e.key.toLowerCase() === 'f') {
        const containerId = activeContainerId || activeDragData?.containerId;
        if (!containerId) return;

        if (containerId.startsWith('equip-')) {
          // When dragging FROM equipment, only toggle the visual fold state.
          // The store item stays expanded (slot always shows expanded).
          // finalFolded is read from activeDragFolded at drop time.
          setActiveDragFolded(prev => !prev);
        } else {
          // Container item: update store + visual
          toggleItemFold(containerId, activeId as string);
          setActiveDragFolded(prev => !prev);

          // Persist fold to server
          fetchNui('foldItem', {
            item: activeDragData?.name,
            id: activeId,
            container: containerId
          });
        }
      }

      // Check Shortcuts 5-8
      if (['5', '6', '7', '8'].includes(e.key)) {
        console.log('[DEBUG] Key pressed:', e.key);
        useInventoryStore.getState().setShortcut(e.key);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, activeId, activeContainerId, activeDragData, containers, equipment, toggleItemFold]);

  const handleDragStart = (event: any) => {
    setActiveId(event.active.id);
    setActiveDragData(event.active.data.current);
    if (event.active.data.current?.containerId) {
      setActiveContainerId(event.active.data.current.containerId);
    } else {
      // Fallback or Equipment logic if containerId missing (should cause an issue if missing)
      // Check if it's equipment by checking store
      // Usually we pass containerId from Item.
      setActiveContainerId(null);
    }

    // Check rotation check
    const item = event.active.data.current; // Use data directly!
    if (item && item.rotated !== undefined) {
      setActiveDragRotation(item.rotated);
    }

    // Set fold state from item — but equipment items are ALWAYS expanded
    if (item) {
      const itemFromEquip = !event.active.data.current?.containerId ||
        (event.active.data.current?.containerId as string)?.startsWith('equip-');
      setActiveDragFolded(itemFromEquip ? false : !!item.folded);
    }

    // Compute compatible targets for visual feedback
    if (item) {
      const defs = itemDefsRef.current;
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
                if (wDef?.equipment?.supportedAttachments?.[attachSlot] && !ci.metadata?.attachments?.[attachSlot]) {
                  compatibleIds.add(ci.id);
                  // Add the attachment droppable slot ID for the details window
                  compatibleIds.add(`attachment-${ci.id}-${attachSlot}`);
                }
              }
            }
          }
          for (const [slot, eq] of Object.entries(equipment)) {
            if (eq?.type?.startsWith('weapon_')) {
              const wDef = defs[eq.name];
              if (wDef?.equipment?.supportedAttachments?.[attachSlot] && !eq.metadata?.attachments?.[attachSlot]) {
                compatibleIds.add(eq.id);
                compatibleIds.add(`equip-${slot}`);
                compatibleIds.add(`attachment-${eq.id}-${attachSlot}`);
              }
            }
          }
        }
      }

      // Stackable -> find same-name items with room
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

      // Equipment-compatible items (weapons, vests, etc.) -> highlight matching empty equipment slots
      if (item.type && !item.type.startsWith('attachment_') && item.type !== 'ammo') {
        const equipSlotMap: Record<string, string[]> = {
          primary: ['weapon_primary', 'weapon_secondary', 'weapon_smg', 'weapon_rifle', 'weapon_sniper', 'weapon_shotgun'],
          secondary: ['weapon_primary', 'weapon_secondary', 'weapon_smg', 'weapon_rifle', 'weapon_sniper', 'weapon_shotgun'],
          pistol: ['weapon_pistol'],
          melee: ['weapon_melee'],
          head: ['helmet'],
          face: ['mask'],
          armor: ['armor'],
          earpiece: ['earpiece'],
          vest: ['vest'],
          bag: ['backpack', 'bag'],
        };
        for (const [slot, accepted] of Object.entries(equipSlotMap)) {
          if (accepted.includes(item.type) && !equipment[slot]) {
            compatibleIds.add(`equip-${slot}`);
            dragType = dragType || 'stack'; // Reuse 'stack' as generic drag type
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
    const layout = CONTAINER_LAYOUTS[container.id] || CONTAINER_LAYOUTS[container.label] || (container.type === 'vest' ? CONTAINER_LAYOUTS['vest'] : CONTAINER_LAYOUTS['backpack']);

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

    const slotX = Math.max(1, Math.round(relativeX / (SLOT_SIZE + GAP)) + 1);
    const slotY = Math.max(1, Math.round(relativeY / (SLOT_SIZE + GAP)) + 1);

    return { x: slotX, y: slotY };
  }, []);

  const validatePlacement = useCallback((rawContainerId: string, item: any, relativeSlot: { x: number; y: number }, rotation: boolean) => {
    const { baseId, regionOffset, pocketRegion } = parseContainerId(rawContainerId);
    const container = containers[baseId];
    if (!container) return false;

    // Convert Relative Slot -> Global Slot
    const slot = {
      x: relativeSlot.x + regionOffset.x,
      y: relativeSlot.y + regionOffset.y
    };

    // 0. Recursion / Self-Storage Check
    // Prevent putting a bag inside itself or similar bags if logic implies they provide the storage
    if (baseId.includes(item.name) ||
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
            vs => vs.x === slotToCheck.x && vs.y === slotToCheck.y
          );
          if (!isValid) return false;
        }
      }
    }

    // 3. Collision Check
    const hasCollision = container.items.some((otherItem) => {
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
  }, [containers, parseContainerId]);

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
      const isValid = validatePlacement(overId, activeItemWithCurrentSize, relativeSlot, rotation);

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
  }, [activeId, activeDragFolded, containers, equipment, calculateTargetSlot, validatePlacement, parseContainerId]);


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

  // Trigger update when rotation or fold changes
  useEffect(() => {
    if (currentDragState.current && activeId) {
      updateDragHighlight(currentDragState.current.overId, currentDragState.current.activeRect, activeDragRotation, activeDragFolded);
    }
  }, [activeDragRotation, activeDragFolded, activeId, updateDragHighlight]);

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
      const dragData = active.data.current;
      if (dragData?.type === 'installed-attachment') {
        const { weaponId, weaponContainerId, slotId, attachmentName } = dragData;
        useInventoryStore.getState().removeAttachment(weaponId, weaponContainerId, slotId, 'player-inv');
        fetchNui('removeAttachment', {
          weaponId,
          weaponContainerId,
          attachmentSlot: slotId,
          attachmentItem: attachmentName
        });
      }
      return;
    }

    // Handle installed-attachment being dropped onto a container
    const dragData = active.data.current;
    if (dragData?.type === 'installed-attachment') {
      const { weaponId, weaponContainerId, slotId, attachmentName } = dragData;

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

      const isValidPlacement = validatePlacement(toId, dragData, { x: relSlotX, y: relSlotY }, finalRotation);
      if (!isValidPlacement) return;

      const slotX = relSlotX + regionOffset.x;
      const slotY = relSlotY + regionOffset.y;
      const targetSlot = { x: slotX, y: slotY };

      useInventoryStore.getState().removeAttachment(weaponId, weaponContainerId, slotId, baseId, targetSlot);
      fetchNui('removeAttachment', {
        weaponId,
        weaponContainerId,
        attachmentSlot: slotId,
        attachmentItem: attachmentName,
        toContainerId: baseId,
        toSlot: targetSlot
      });
      return;
    }


    const itemId = active.id as string;

    // Find Item & Source
    let fromContainerId = '';
    let item = null;

    // Check containers
    for (const c of Object.values(containers)) {
      const found = c.items.find(i => i.id === itemId);
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

    // --- ATTACHMENT SLOT LOGIC ---
    if (toId.startsWith('attachment-')) {
      const slotData = over.data.current;
      if (!slotData) return;

      const attachmentSlot = slotData.slotId as string;
      const weaponId = slotData.weaponId as string;
      const weaponContainerId = slotData.weaponContainerId as string;

      // Must be an attachment item
      if (!item.type?.startsWith('attachment_')) return;

      // Validate the attachment type matches the slot
      const defs = itemDefsRef.current;
      const attachDef = defs[item.name];
      if (!attachDef?.attachment || attachDef.attachment.slot !== attachmentSlot) return;

      // Call store action
      attachToWeapon(weaponId, weaponContainerId, attachmentSlot, item, fromContainerId);

      // Notify server
      fetchNui('attachToWeapon', {
        weaponId,
        weaponContainerId,
        attachmentSlot,
        attachmentItem: item.name,
        attachmentItemId: item.id,
        fromContainerId
      });
      return;
    }
    if (toId.startsWith('equip-')) {
      const targetSlotId = toId.replace('equip-', '');
      const acceptedTypes = over.data.current?.acceptedTypes as string[] || [];

      // Validate Type (skip for ammo and attachments — they have special handling)
      const isAmmo = item.type === 'ammo';
      const isAttachment = item.type?.startsWith('attachment_');
      if (!isAmmo && !isAttachment && acceptedTypes.length > 0 && item.type && !acceptedTypes.includes(item.type)) {
        return;
      }

      // --- ATTACHMENT → WEAPON SLOT ---
      if (isAttachment && !fromContainerId.startsWith('equip-')) {
        const weapon = equipment[targetSlotId];
        if (!weapon || !weapon.type?.startsWith('weapon_')) return;

        const defs = itemDefsRef.current;
        const attachDef = defs[item.name];
        if (!attachDef?.attachment?.slot) return;

        const attachmentSlot = attachDef.attachment.slot;
        const weaponDef = defs[weapon.name];
        if (!weaponDef?.equipment?.supportedAttachments?.[attachmentSlot]) return;

        // Check slot not already occupied
        if (weapon.metadata?.attachments?.[attachmentSlot]) return;

        attachToWeapon(weapon.id, `equip-${targetSlotId}`, attachmentSlot, item, fromContainerId);
        fetchNui('attachToWeapon', {
          weaponId: weapon.id,
          weaponContainerId: `equip-${targetSlotId}`,
          attachmentSlot,
          attachmentItem: item.name,
          attachmentItemId: item.id,
          fromContainerId
        });
        return;
      }

      // --- AMMO → WEAPON SLOT ---
      if (isAmmo && !fromContainerId.startsWith('equip-')) {
        // Dragging ammo from inventory onto a weapon equipment slot
        const weapon = equipment[targetSlotId];
        if (!weapon || !weapon.type?.startsWith('weapon_')) return; // Must be a weapon slot with a weapon

        // Strict Frontend Caliber validation
        const defs = itemDefsRef.current;
        const weaponDef = defs[weapon.name];
        const ammoDef = defs[item.name];

        const weaponCaliber = weaponDef?.equipment?.caliber;
        const ammoCaliber = ammoDef?.ammo?.caliber;

        if (!weaponCaliber || !ammoCaliber || weaponCaliber !== ammoCaliber) {
          // Reject drop silently (drag snaps back)
          return;
        }

        loadAmmoIntoWeapon(weapon.id || targetSlotId, `equip-${targetSlotId}`, item, fromContainerId);
        fetchNui('loadAmmoIntoWeapon', {
          id: item.id,
          ammoItem: item,
          weaponSlot: targetSlotId,
          weaponContainer: `equip-${targetSlotId}`,
          ammoContainer: fromContainerId
        });
        return;
      }

      // If Logic: Equip Item
      if (fromContainerId.startsWith('equip-')) {
        // Moving from Equip to Equip (Swap or Move)
        const fromSlotId = fromContainerId.replace('equip-', '');
        if (fromSlotId === targetSlotId) return; // Same slot, no-op
        swapEquipment(fromSlotId, targetSlotId);
        fetchNui('swapEquipment', {
          item: item.name,
          id: item.id,
          fromSlot: fromSlotId,
          toSlot: targetSlotId
        });
      } else {
        // Moving from Container to Equip
        equipItem(targetSlotId, item, fromContainerId);
        fetchNui('equipItem', {
          item: item.name,
          id: item.id,
          slot: targetSlotId,
          from: fromContainerId
        });
      }
      return;
    }

    // --- CONTAINER LOGIC ---
    // Dropping into a container
    const { baseId, regionOffset } = parseContainerId(toId);

    const containerElement = document.getElementById(toId);
    if (!containerElement) return;

    const containerRect = containerElement.getBoundingClientRect();
    // @ts-ignore
    const itemRect = active.rect.current.translated;

    if (!itemRect) return;

    const PADDING_X = 13;
    const PADDING_Y = 13;

    const relativeX = itemRect.left - containerRect.left - PADDING_X;
    const relativeY = itemRect.top - containerRect.top - PADDING_Y;

    // Relative Slot (Visual)
    const relSlotX = Math.max(1, Math.round(relativeX / (SLOT_SIZE + GAP)) + 1);
    const relSlotY = Math.max(1, Math.round(relativeY / (SLOT_SIZE + GAP)) + 1);

    // --- AMMO -> WEAPON IN GRID LOGIC ---
    if (item.type === 'ammo' && !fromContainerId.startsWith('equip-') && containers[baseId]) {
      const targetContainer = containers[baseId];
      // Find item occupying the target slot
      const targetItem = targetContainer.items.find((i: any) => {
        const iX = i.slot.x;
        const iY = i.slot.y;
        const iW = i.size?.x || 1;
        const iH = i.size?.y || 1;
        return relSlotX >= iX && relSlotX < iX + iW &&
          relSlotY >= iY && relSlotY < iY + iH;
      });

      if (targetItem && targetItem.type?.startsWith('weapon_')) {
        const defs = itemDefsRef.current;
        const weaponDef = defs[targetItem.name];
        const ammoDef = defs[item.name];

        const weaponCaliber = weaponDef?.equipment?.caliber;
        const ammoCaliber = ammoDef?.ammo?.caliber;

        if (weaponCaliber && ammoCaliber && weaponCaliber === ammoCaliber) {
          loadAmmoIntoWeapon(targetItem.id, baseId, item, fromContainerId);
          fetchNui('loadAmmoIntoWeapon', {
            id: item.id,
            ammoItem: item,
            weaponSlot: targetItem.id, // send the ID of the weapon
            weaponContainer: baseId,
            ammoContainer: fromContainerId
          });
          return;
        } else {
          // Reject gracefully
          return;
        }
      }
    }

    // --- ATTACHMENT -> WEAPON IN GRID LOGIC ---
    if (item.type?.startsWith('attachment_') && !fromContainerId.startsWith('equip-') && containers[baseId]) {
      const targetContainer = containers[baseId];
      const targetItem = targetContainer.items.find((i: any) => {
        const iX = i.slot.x;
        const iY = i.slot.y;
        const iW = i.size?.x || 1;
        const iH = i.size?.y || 1;
        return relSlotX >= iX && relSlotX < iX + iW &&
          relSlotY >= iY && relSlotY < iY + iH;
      });

      if (targetItem && targetItem.type?.startsWith('weapon_')) {
        const defs = itemDefsRef.current;
        const attachDef = defs[item.name];
        if (attachDef?.attachment?.slot) {
          const attachmentSlot = attachDef.attachment.slot;
          const weaponDef = defs[targetItem.name];
          if (weaponDef?.equipment?.supportedAttachments?.[attachmentSlot] &&
            !targetItem.metadata?.attachments?.[attachmentSlot]) {
            attachToWeapon(targetItem.id, baseId, attachmentSlot, item, fromContainerId);
            fetchNui('attachToWeapon', {
              weaponId: targetItem.id,
              weaponContainerId: baseId,
              attachmentSlot,
              attachmentItem: item.name,
              attachmentItemId: item.id,
              fromContainerId
            });
            return;
          }
        }
        return; // Reject gracefully
      }
    }

    // --- STACKABLE ITEM MERGE LOGIC ---
    if (item.stackable && !fromContainerId.startsWith('equip-') && containers[baseId]) {
      const targetContainer = containers[baseId];
      // Find item occupying the target slot
      const targetItem = targetContainer.items.find((i: any) => {
        if (i.id === item.id) return false; // Skip self
        const iX = i.slot.x;
        const iY = i.slot.y;
        const iW = i.size?.x || 1;
        const iH = i.size?.y || 1;
        return relSlotX >= iX && relSlotX < iX + iW &&
          relSlotY >= iY && relSlotY < iY + iH;
      });

      if (targetItem && targetItem.name === item.name && targetItem.stackable) {
        const maxStack = targetItem.maxStack || 60;
        if (targetItem.count < maxStack) {
          // Merge stacks
          stackItems(item.id, fromContainerId, targetItem.id, baseId);
          fetchNui('stackItems', {
            fromItemId: item.id,
            fromContainerId,
            toItemId: targetItem.id,
            toContainerId: baseId
          });
          return;
        }
        // Target is full — reject the drop entirely
        return;
      }
    }

    // Validate Placement BEFORE Moving
    // When coming from equipment with finalFolded=true, validate against the folded size
    let itemForValidation = item;
    if (fromContainerId.startsWith('equip-') && finalFolded) {
      const cfg = ITEM_CONFIGS[(item as any).name];
      if (cfg) {
        itemForValidation = { ...item, size: cfg.foldedSize } as any;
      }
    }
    const isValidPlacement = validatePlacement(toId, itemForValidation, { x: relSlotX, y: relSlotY }, finalRotation);

    if (!isValidPlacement) {
      // Option: Animate snap back?
      return;
    }

    // Global Slot -> Add Offset
    const slotX = relSlotX + regionOffset.x;
    const slotY = relSlotY + regionOffset.y;

    // Un-equip if coming from equipment
    if (fromContainerId.startsWith('equip-')) {
      const sourceSlotId = fromContainerId.replace('equip-', '');
      // Use finalFolded (from activeDragFolded before clear) — equipment store stays expanded
      unequipItem(sourceSlotId, baseId, { x: slotX, y: slotY }, finalFolded);

      fetchNui('unequipItem', {
        item: item.name,
        id: item.id,
        fromSlot: sourceSlotId,
        to: baseId,
        slot: { x: slotX, y: slotY },
        folded: finalFolded  // Tell server the chosen fold state
      });
    } else {
      // Standard Move
      moveItem(fromContainerId, baseId, itemId, { x: slotX, y: slotY }, finalRotation);

      fetchNui('moveItem', {
        item: item.name,
        id: item.id,
        from: fromContainerId,
        to: baseId,
        slot: { x: slotX, y: slotY },
        fromSlot: item.slot,
        rotated: finalRotation,
        folded: item.folded // Send folded state from store
      });
    }
  };

  // Helper to find active item for Overlay
  const renderDragOverlay = () => {
    if (!activeId || !activeDragData) return null;

    const activeItem = activeDragData;

    // Resolve current size respecting live fold state
    const config = ITEM_CONFIGS[activeItem.name];
    let baseSize: { x: number; y: number };
    if (config) {
      baseSize = activeDragFolded ? config.foldedSize : config.expandedSize;
    } else {
      baseSize = activeItem.size || { x: 1, y: 1 };
    }
    const currentSize = activeDragRotation ? { x: baseSize.y, y: baseSize.x } : baseSize;

    const style = {
      width: currentSize.x * SLOT_SIZE + (currentSize.x - 1) * GAP,
      height: currentSize.y * SLOT_SIZE + (currentSize.y - 1) * GAP,
    };

    return (
      <div style={style} className="relative z-[100] cursor-grabbing">
        <ItemView
          {...activeItem}
          slot={{ x: 1, y: 1 }}
          size={currentSize}
          isDragging
          isOverlay
          style={{ width: '100%', height: '100%' }}
        />
        {/* Visual Hint */}
        <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 whitespace-nowrap bg-black/70 text-white text-[10px] px-2 py-1 rounded border border-white/20 flex gap-2">
          <span><span className="font-bold text-orange-400">[F]</span> {activeDragFolded ? 'Expand' : 'Fold'}</span>
          <span><span className="font-bold text-orange-400">[R]</span> Rotate</span>
        </div>
      </div>
    );
  };

  const handleDragCancel = () => {
    setActiveId(null);
    setActiveDragData(null);
    setActiveContainerId(null);
    setActiveDragFolded(false);
    setDragHighlight(undefined);
    currentDragState.current = null;
    setDragCompatibility(null);
  };

  // Check if any Loot/Stash is open
  const isStashOpen = Object.values(containers).some((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-'));

  return (
    <>
      {/* Give Item Modal — rendered outside DndContext so it isn't blocked by drag events */}
      <GiveItemModal
        giveTarget={giveTarget}
        onCloseSend={() => setGiveTarget(null)}
        receiveRequest={receiveRequest}
        onCloseReceive={() => setReceiveRequest(null)}
      />

      {!isOpen ? null : (
        <DndContext
          sensors={sensors}
          collisionDetection={rectIntersection}
          onDragStart={handleDragStart}
          onDragMove={handleDragMove}
          onDragEnd={handleDragEnd}
          onDragCancel={handleDragCancel}
        >
          <div className="flex items-center min-h-screen w-full max-w-[1920px] h-full text-white font-sans selection:bg-orange-500/30 p-10 transition-all duration-500 ease-in-out">
            <div className={`flex justify-end w-full h-[85vh] gap-6 ${isStashOpen ? 'px-18' : 'px-35'}`}>
              {/* LEFT: Equipment */}
              <EquipmentPanel />

              {/* CENTER: Player Inventory (Grids) */}
              <PlayerInventory dragHighlight={dragHighlight} />

              {/* RIGHT: Loot / Stash / Storage */}
              {isStashOpen && (
                <StashInventory dragHighlight={dragHighlight} />
              )}
            </div>
            {/* Floating Container Windows */}
            {openWindows.map(id => (
              <ContainerWindow
                key={id}
                containerId={id}
                onClose={() => closeWindow(id)}
              />
            ))}

            {/* Item Details Window */}
            {detailsWindows.map((item) => (
              <ItemDetailsWindow
                key={item.name}
                item={item}
                onClose={() => closeDetails(item)}
              />
            ))}

          </div>
          <DragOverlay modifiers={[snapCenterToCursor]}>
            {activeId ? renderDragOverlay() : null}
          </DragOverlay>
        </DndContext>
      )}
    </>
  );
}

export default App;

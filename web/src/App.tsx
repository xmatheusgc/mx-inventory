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
import { DndContext, type DragEndEvent, type DragMoveEvent, useSensor, useSensors, PointerSensor, rectIntersection, DragOverlay } from '@dnd-kit/core';
import { PlayerInventory } from './components/PlayerInventory';
import { StashInventory } from './components/StashInventory';

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
    equipment, setEquipment, equipItem, unequipItem, swapEquipment, toggleItemFold, setContainers,
    openWindows, closeWindow, detailsWindows, closeDetails
  } = useInventoryStore();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [activeDragRotation, setActiveDragRotation] = useState<boolean>(false);
  const [dragHighlight, setDragHighlight] = useState<HighlightState | undefined>(undefined);

  const [activeContainerId, setActiveContainerId] = useState<string | null>(null);

  // Keep track of the current drag state so we can re-verify on rotation change
  const currentDragState = useRef<{ overId: string; activeRect: any } | null>(null);

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
      console.log('NUI Message:', action, data);

      if (action === 'open') {
        setOpen(true);
        if (data) {
          console.log('Processing open data:', data);
          const { itemDefs } = data;

          const enrichItems = (items: any[]) => items.map(item => {
            const def = itemDefs ? itemDefs[item.name] : {};
            return {
              ...def,
              ...item,
              size: def?.size || item.size || { x: 1, y: 1 },
              weight: def?.weight || item.weight || 0,
              type: def?.type || item.type || 'generic'
            };
          });

          // Dynamic Container Loading
          const newContainers: Record<string, any> = {};

          Object.entries(data).forEach(([key, value]: [string, any]) => {
            if (key === 'itemDefs') return;
            if (typeof value === 'object' && value !== null && value.items) {
              const enriched = { ...value, items: enrichItems(value.items) };
              newContainers[enriched.id] = enriched;
            }
          });

          setContainers(newContainers);

          if (data.equipment) {
            // Enrich equipment items individually
            const enrichedEquipment: Record<string, any> = {};
            Object.entries(data.equipment).forEach(([key, item]: [string, any]) => {
              if (item) {
                // Enrich single item
                const def = itemDefs ? itemDefs[item.name] : {};
                enrichedEquipment[key] = {
                  ...def,
                  ...item,
                  size: def?.size || item.size || { x: 1, y: 1 },
                  weight: def?.weight || item.weight || 0,
                  type: def?.type || item.type || 'generic'
                };
              } else {
                enrichedEquipment[key] = null;
              }
            });
            setEquipment(enrichedEquipment);
          }
        }
      } else if (action === 'close') {
        setOpen(false);
      } else if (action === 'updateWeights') {
        const weights = data as WeightUpdate;
        Object.entries(weights).forEach(([id, weight]) => {
          updateContainerWeight(id, weight);
        });
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [setOpen, setContainerData, updateContainerWeight]);

  useEffect(() => {
    if (activeId) {
      // Check in containers
      let item: any = Object.values(containers).flatMap((c: any) => c.items).find((i: any) => i.name === activeId);
      // Check in equipment
      if (!item) {
        item = Object.values(equipment).find(i => i?.name === activeId);
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
        // Toggle Fold - Scoped
        if (activeContainerId) {
          toggleItemFold(activeContainerId, activeId as string);
        } else {
          // Fallback Search
          let itemInfo = Object.values(containers).flatMap((c: any) => c.items.map((i: any) => ({ ...i, containerId: c.id })))
            .find((i: any) => i.name === activeId);

          if (!itemInfo) {
            const equipItem = Object.values(equipment).find((i: any) => i?.name === activeId);
            if (equipItem) {
              itemInfo = { ...equipItem, containerId: 'equipment' };
            }
          }

          if (itemInfo) {
            toggleItemFold(itemInfo.containerId, activeId as string);
          }
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
  }, [isOpen, activeId, activeContainerId, containers, equipment, toggleItemFold]);

  const handleDragStart = (event: any) => {
    setActiveId(event.active.id);
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
      if (otherItem.name === item.name) return false; // Ignore self 

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

  const updateDragHighlight = useCallback((overId: string, activeRect: any, rotation: boolean) => {
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

    let activeItem: any = Object.values(containers).flatMap((c: any) => c.items).find((i: any) => i.name === activeId);
    if (!activeItem) {
      activeItem = Object.values(equipment).find(i => i?.name === activeId);
    }

    if (!activeItem) return;

    // calculateTargetSlot returns RELATIVE slot to the droppable element
    const relativeSlot = calculateTargetSlot(overId, activeRect);

    if (relativeSlot) {
      // Validate using Global Logic (inside the helper)
      const isValid = validatePlacement(overId, activeItem, relativeSlot, rotation);

      const highlightSlots = [];
      const originalSize = activeItem.size || { x: 1, y: 1 };
      const size = rotation ? { x: originalSize.y, y: originalSize.x } : originalSize;

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
  }, [activeId, containers, equipment, calculateTargetSlot, validatePlacement, parseContainerId]);


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

    updateDragHighlight(over.id as string, activeRect, activeDragRotation);
  };

  // Trigger update when rotation changes
  useEffect(() => {
    if (currentDragState.current && activeId) {
      updateDragHighlight(currentDragState.current.overId, currentDragState.current.activeRect, activeDragRotation);
    }
  }, [activeDragRotation, activeId, updateDragHighlight]);

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    setActiveId(null);
    setActiveContainerId(null);
    setDragHighlight(undefined); // Clear highlight
    currentDragState.current = null;
    const finalRotation = activeDragRotation;

    if (!over) return;


    const itemName = active.id as string;

    // Find Item & Source
    let fromContainerId = '';
    let item = null;

    // Check containers
    for (const c of Object.values(containers)) {
      const found = c.items.find(i => i.name === itemName);
      if (found) {
        fromContainerId = c.id;
        item = found;
        break;
      }
    }

    // Check equipment if not in container
    if (!item) {
      for (const [slot, equipItem] of Object.entries(equipment)) {
        if (equipItem?.name === itemName) {
          fromContainerId = `equip-${slot}`; // Special ID for equipment source
          item = equipItem;
          break;
        }
      }
    }

    if (!fromContainerId || !item) return;

    const toId = over.id as string;

    // --- EQUIPMENT LOGIC ---
    if (toId.startsWith('equip-')) {
      const targetSlotId = toId.replace('equip-', '');
      const acceptedTypes = over.data.current?.acceptedTypes as string[] || [];

      // Validate Type
      if (acceptedTypes.length > 0 && item.type && !acceptedTypes.includes(item.type)) {
        // Check if item type matches any of the accepted types
        // If not compatible, return early
        return;
      }

      // If Logic: Equip Item
      if (fromContainerId.startsWith('equip-')) {
        // Moving from Equip to Equip (Swap or Move)
        const fromSlotId = fromContainerId.replace('equip-', '');
        if (fromSlotId === targetSlotId) return; // Same slot, no-op
        swapEquipment(fromSlotId, targetSlotId);
        fetchNui('swapEquipment', {
          item: itemName,
          fromSlot: fromSlotId,
          toSlot: targetSlotId
        });
      } else {
        // Moving from Container to Equip
        equipItem(targetSlotId, item, fromContainerId);
        fetchNui('equipItem', {
          item: itemName,
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

    // Validate Placement BEFORE Moving
    const isValidPlacement = validatePlacement(toId, item, { x: relSlotX, y: relSlotY }, finalRotation);

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
      unequipItem(sourceSlotId, baseId, { x: slotX, y: slotY });

      fetchNui('unequipItem', {
        item: itemName,
        fromSlot: sourceSlotId,
        to: baseId,
        slot: { x: slotX, y: slotY }
      });
    } else {
      // Standard Move
      moveItem(fromContainerId, baseId, itemName, { x: slotX, y: slotY }, finalRotation);

      fetchNui('moveItem', {
        item: itemName,
        from: fromContainerId,
        to: baseId,
        slot: { x: slotX, y: slotY },
        fromSlot: item.slot,
        rotated: finalRotation
      });
    }
  };

  // Helper to find active item for Overlay
  const renderDragOverlay = () => {
    if (!activeId) return null;

    let activeItem: any = null;
    if (activeContainerId) {
      if (containers[activeContainerId]) {
        activeItem = containers[activeContainerId].items.find((i: any) => i.name === activeId);
      } else {
        activeItem = Object.values(equipment).find(i => i?.name === activeId);
      }
    }

    if (!activeItem) {
      activeItem = Object.values(containers).flatMap((c: any) => c.items).find((i: any) => i.name === activeId);
      if (!activeItem) {
        activeItem = Object.values(equipment).find(i => i?.name === activeId);
      }
    }

    if (!activeItem) return null;

    const originalSize = activeItem.size || { x: 1, y: 1 };
    const currentSize = activeDragRotation ? { x: originalSize.y, y: originalSize.x } : originalSize;

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
          <span><span className="font-bold text-orange-400">[F]</span> Expand/Fold</span>
          <span><span className="font-bold text-orange-400">[R]</span> Rotate</span>
        </div>
      </div>
    );
  };

  const handleDragCancel = () => {
    setActiveId(null);
    setActiveContainerId(null);
    setDragHighlight(undefined);
    currentDragState.current = null;
  };

  // Check if any Loot/Stash is open
  const isStashOpen = Object.values(containers).some((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-'));

  if (!isOpen) return null;

  return (
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
    </DndContext >
  );
}

export default App;

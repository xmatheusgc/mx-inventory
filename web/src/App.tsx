import { useEffect, useState, useCallback, useRef } from 'react';
import { useInventoryStore } from './store/inventoryStore';
import { debugData, fetchNui } from './utils/nui';
import { Container } from './components/Container';
import { ItemView } from './components/Item';
import { EquipmentPanel } from './components/EquipmentPanel';
import { EquipmentSlot } from './components/EquipmentSlot';
import { snapCenterToCursor } from './utils/modifiers';
import { DndContext, type DragEndEvent, type DragMoveEvent, useSensor, useSensors, PointerSensor, rectIntersection, DragOverlay } from '@dnd-kit/core';

// Mock data
interface WeightUpdate {
  [key: string]: number;
}

const debugPlayerItems = [
  { name: 'water', count: 1, slot: { x: 1, y: 1 }, label: 'Water', size: { x: 1, y: 2 }, weight: 0.5, type: 'generic' },
  { name: 'pistol', count: 1, slot: { x: 3, y: 1 }, label: 'Pistol', size: { x: 2, y: 2 }, weight: 1.5, type: 'weapon_pistol' },
  { name: 'helmet', count: 1, slot: { x: 1, y: 4 }, label: 'Helmet', size: { x: 2, y: 2 }, weight: 0.8, type: 'helmet' },
  { name: 'rifle', count: 1, slot: { x: 3, y: 4 }, label: 'Rifle', size: { x: 4, y: 2 }, weight: 3.5, type: 'weapon_primary' },
];

const debugVestItems = [
  { name: 'bandage', count: 2, slot: { x: 1, y: 1 }, label: 'Bandage', size: { x: 1, y: 1 }, weight: 0.1, type: 'generic' },
];

debugData([
  {
    action: 'open',
    data: {
      player: {
        id: 'player-inv',
        type: 'player',
        label: 'Player Inventory',
        size: { width: 6, height: 3 },
        items: debugPlayerItems,
        weight: 2.0,
        maxWeight: 40.0
      },
      secondary: {
        id: 'vest-1',
        type: 'vest',
        label: 'Tactical Vest',
        size: { width: 6, height: 6 },
        items: debugVestItems,
        weight: 0.2,
        maxWeight: 10.0,
        validSlots: [
          { x: 1, y: 1 }, { x: 2, y: 1 }, { x: 4, y: 1 }, { x: 5, y: 1 }, { x: 6, y: 1 },
          { x: 1, y: 2 }, { x: 2, y: 2 }, { x: 4, y: 2 }, { x: 5, y: 2 }, { x: 6, y: 2 },
          { x: 1, y: 3 }, { x: 2, y: 3 }, { x: 4, y: 3 }, { x: 5, y: 3 }, { x: 6, y: 3 },
          { x: 1, y: 4 }, { x: 2, y: 4 }, { x: 4, y: 4 }, { x: 5, y: 4 }, { x: 6, y: 4 },
        ]
      }
    }
  }
]);

const SLOT_SIZE = 64;
const GAP = 2;

interface HighlightState {
  containerId: string;
  slots: { x: number; y: number }[];
  isValid: boolean;
}

function App() {
  const { isOpen, setOpen, setContainerData, moveItem, containers, updateContainerWeight, equipment, equipItem, unequipItem } = useInventoryStore();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [activeDragRotation, setActiveDragRotation] = useState<boolean>(false);
  const [dragHighlight, setDragHighlight] = useState<HighlightState | undefined>(undefined);

  // Keep track of the current drag state so we can re-verify on rotation change
  const currentDragState = useRef<{ overId: string; activeRect: any } | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 5,
      },
    })
  );

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

          if (data.player) {
            const enriched = { ...data.player, items: enrichItems(data.player.items) };
            setContainerData(enriched.id, enriched);
          }
          if (data.secondary) {
            const enriched = { ...data.secondary, items: enrichItems(data.secondary.items) };
            setContainerData(enriched.id, enriched);
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
      if (isOpen && (e.key === 'Escape')) {
        fetchNui('close');
        setOpen(false);
      }
      if (isOpen && (e.key === 'r' || e.key === 'R') && activeId) {
        setActiveDragRotation(prev => !prev);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, activeId]);

  const handleDragStart = (event: any) => {
    setActiveId(event.active.id);
  };

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

  const validatePlacement = useCallback((containerId: string, item: any, slot: { x: number; y: number }, rotation: boolean) => {
    const container = containers[containerId];
    if (!container) return false;

    const originalSize = item.size || { x: 1, y: 1 };
    const size = rotation ? { x: originalSize.y, y: originalSize.x } : originalSize;

    // 1. Boundary Check
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
  }, [containers]);

  const updateDragHighlight = useCallback((overId: string, activeRect: any, rotation: boolean) => {
    // Find item logic updated to include equipment if needed, but highlight usually only for grids
    // Actually we might want highlight for equipment slots too, but that's handled by EquipmentSlot component visual
    // So here we only care if overId is a container
    if (!containers[overId]) {
      setDragHighlight(undefined);
      return;
    }

    let activeItem: any = Object.values(containers).flatMap((c: any) => c.items).find((i: any) => i.name === activeId);
    if (!activeItem) {
      activeItem = Object.values(equipment).find(i => i?.name === activeId);
    }

    if (!activeItem) return;

    const targetSlot = calculateTargetSlot(overId, activeRect);

    if (targetSlot) {
      const isValid = validatePlacement(overId, activeItem, targetSlot, rotation);

      const highlightSlots = [];
      const originalSize = activeItem.size || { x: 1, y: 1 };
      const size = rotation ? { x: originalSize.y, y: originalSize.x } : originalSize;

      for (let x = 0; x < size.x; x++) {
        for (let y = 0; y < size.y; y++) {
          highlightSlots.push({ x: targetSlot.x + x, y: targetSlot.y + y });
        }
      }

      setDragHighlight({
        containerId: overId,
        slots: highlightSlots,
        isValid
      });
    } else {
      setDragHighlight(undefined);
    }
  }, [activeId, containers, equipment, calculateTargetSlot, validatePlacement]);


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
        // Moving from Equip to Equip? (Swap or Move)
        // Implementation delayed for simplicity or handle if types match
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

    const slotX = Math.max(1, Math.round(relativeX / (SLOT_SIZE + GAP)) + 1);
    const slotY = Math.max(1, Math.round(relativeY / (SLOT_SIZE + GAP)) + 1);

    // Un-equip if coming from equipment
    if (fromContainerId.startsWith('equip-')) {
      const sourceSlotId = fromContainerId.replace('equip-', '');
      unequipItem(sourceSlotId, toId, { x: slotX, y: slotY });

      fetchNui('unequipItem', {
        item: itemName,
        fromSlot: sourceSlotId,
        to: toId,
        slot: { x: slotX, y: slotY }
      });
    } else {
      // Standard Move
      moveItem(fromContainerId, toId, itemName, { x: slotX, y: slotY }, finalRotation);

      fetchNui('moveItem', {
        item: itemName,
        from: fromContainerId,
        to: toId,
        slot: { x: slotX, y: slotY },
        rotated: finalRotation
      });
    }
  };

  // Helper to find active item for Overlay
  let activeItem: any = activeId ? Object.values(containers).flatMap((c: any) => c.items).find((i: any) => i.name === activeId) : null;
  if (!activeItem && activeId) {
    activeItem = Object.values(equipment).find(i => i?.name === activeId);
  }

  const renderDragOverlay = () => {
    if (!activeItem) return null;

    const currentSize = activeDragRotation ? { x: activeItem.size?.y || 1, y: activeItem.size?.x || 1 } : (activeItem.size || { x: 1, y: 1 });

    const style = {
      width: currentSize.x * SLOT_SIZE + (currentSize.x - 1) * GAP,
      height: currentSize.y * SLOT_SIZE + (currentSize.y - 1) * GAP,
    };

    return (
      <ItemView {...activeItem} rotated={activeDragRotation} isDragging isOverlay style={style} />
    );
  };

  if (!isOpen) return null;

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={rectIntersection}
      onDragStart={handleDragStart}
      onDragMove={handleDragMove}
      onDragEnd={handleDragEnd}
    >
      <div className="flex items-center justify-center min-h-screen bg-black/40 text-white font-sans selection:bg-orange-500/30">
        <div className="flex flex-col p-6 bg-zinc-900/95 backdrop-blur-xl border border-zinc-700/50 rounded-xl shadow-2xl w-full max-w-[95vw] h-[90vh] overflow-hidden animate-in fade-in zoom-in-95 duration-200">
          <header className="flex items-center justify-between mb-6 pb-4 border-b border-zinc-700/50 shrink-0">
            <h1 className="text-2xl font-bold text-zinc-100 tracking-tight flex items-center gap-3">
              <span className="w-2 h-8 bg-orange-500 rounded-full shadow-[0_0_15px_rgba(249,115,22,0.5)]" />
              TACTICAL GEAR
            </h1>
          </header>

          {/* 3-Column Layout */}
          <div className="flex flex-1 gap-6 overflow-hidden min-h-0">

            {/* LEFT: Equipment */}
            <div className="flex-none">
              <EquipmentPanel />
            </div>

            {/* CENTER: Player Inventory (Grids) */}
            <div className="flex-1 flex flex-col gap-4 overflow-y-auto overflow-x-hidden min-w-[300px]">

              {/* Player Main Pockets/Inventory */}
              {containers['player-inv'] &&
                <div className="flex flex-col gap-1 p-2">
                  <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider">Pockets / Belt</span>
                  <Container
                    containerId="player-inv"
                    highlight={dragHighlight?.containerId === 'player-inv' ? dragHighlight : undefined}
                  />
                </div>
              }

              {/* Rig Section */}
              <div className="flex gap-4 items-start">
                <div className="flex flex-col gap-1">
                  <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider mb-1">Rig</span>
                  <EquipmentSlot slotId="vest" acceptedTypes={['vest']} className='w-30 h-30' />
                </div>

                {/* Associated Rig Container(s) */}
                <div className="flex-1">
                  {Object.values(containers)
                    .filter((c: any) => c.type === 'vest')
                    .map((c: any) => (
                      <div key={c.id} className="flex flex-col">
                        <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider">{c.label}</span>
                        <Container
                          containerId={c.id}
                          highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                        />
                      </div>
                    ))
                  }
                </div>
              </div>

              {/* Backpack Section */}
              <div className="flex gap-4 items-start">
                <div className="flex flex-col gap-1">
                  <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider mb-1">Backpack</span>
                  <EquipmentSlot slotId="backpack" acceptedTypes={['backpack']} className="w-30 h-30" />
                </div>

                {/* Associated Backpack Container(s) */}
                <div className="flex-1">
                  {Object.values(containers)
                    .filter((c: any) => c.type === 'bag')
                    .map((c: any) => (
                      <div key={c.id} className="flex flex-col gap-1 p-2 bg-zinc-800/20 rounded border border-zinc-700/30">
                        <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider">{c.label}</span>
                        <Container
                          containerId={c.id}
                          highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                        />
                      </div>
                    ))
                  }
                </div>
              </div>
            </div>

            {/* RIGHT: Loot / Stash / Storage */}
            <div className="flex-1 flex flex-col gap-4 overflow-y-auto overflow-x-hidden min-w-[300px] border-l border-zinc-800/50 pl-6">
              <h2 className="text-zinc-400 text-sm font-bold uppercase tracking-wider mb-2">Vicinity / Loot</h2>
              {Object.values(containers)
                .filter((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-'))
                .map((c: any) => (
                  <div key={c.id} className="flex flex-col gap-1 p-2 bg-zinc-800/20 rounded border border-zinc-700/30">
                    <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider">{c.label}</span>
                    <Container
                      containerId={c.id}
                      highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                    />
                  </div>
                ))
              }
              {/* Placeholder if empty */}
              {Object.values(containers).filter((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-')).length === 0 && (
                <div className="flex items-center justify-center flex-1 opacity-20 text-zinc-500 text-sm italic">
                  No active loot nearby
                </div>
              )}
            </div>

          </div>

          <footer className="mt-6 pt-4 border-t border-zinc-700/50 flex justify-between text-zinc-500 text-sm font-medium items-center shrink-0">
            {containers['player-inv'] && (
              <div className="flex flex-col w-full max-w-md gap-1">
                <div className="flex justify-between">
                  <span>WEIGHT</span>
                  <span><span className="text-zinc-300">{containers['player-inv'].weight?.toFixed(1) || '0.0'}</span> / {containers['player-inv'].maxWeight?.toFixed(1) || '40.0'} KG</span>
                </div>
              </div>
            )}
          </footer>
        </div>
      </div>
      <DragOverlay modifiers={[snapCenterToCursor]}>
        {activeId ? renderDragOverlay() : null}
      </DragOverlay>
    </DndContext>
  );
}

export default App;

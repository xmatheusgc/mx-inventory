import { useEffect, useState, useRef } from 'react';
import { useInventoryStore } from './store/inventoryStore';
import { ItemView } from './components/Item';
import { EquipmentPanel } from './components/EquipmentPanel';
import { ContainerWindow } from './components/ContainerWindow';
import { ItemDetailsWindow } from './components/ItemDetailsWindow';
import { snapCenterToCursor } from './utils/modifiers';
import { ITEM_CONFIGS } from './config/items';
import { DndContext, useSensor, useSensors, PointerSensor, rectIntersection, DragOverlay } from '@dnd-kit/core';
import { PlayerInventory } from './components/PlayerInventory';
import { StashInventory } from './components/StashInventory';
import { GiveItemModal } from './components/GiveItemModal';
import { InventoryNotification } from './components/InventoryNotification';
import { useNuiMessages } from './hooks/useNuiMessages';
import { useKeyboardShortcuts } from './hooks/useKeyboardShortcuts';
import { useDndHandlers } from './hooks/useDndHandlers';

const SLOT_SIZE = 64;
const GAP = 0; // User requested no spacing

interface HighlightState {
  containerId: string;
  slots: { x: number; y: number }[];
  isValid: boolean;
}

function App() {
  const {
    isOpen, containers, equipment,
    openWindows, closeWindow, detailsWindows, closeDetails,
    giveTarget, receiveRequest, setGiveTarget, setReceiveRequest,
    itemDefs // Retrieve from store
  } = useInventoryStore();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [activeDragData, setActiveDragData] = useState<any | null>(null);
  const [activeDragRotation, setActiveDragRotation] = useState<boolean>(false);
  const [activeDragFolded, setActiveDragFolded] = useState<boolean>(false);
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

  useNuiMessages();

  // Browser Dev Mode: Auto-Open & Load Mocks

  useKeyboardShortcuts({
    isOpen,
    activeId,
    activeContainerId,
    activeDragData,
    containers,
    equipment,
    setActiveDragRotation,
    setActiveDragFolded
  });

  const { handleDragStart, handleDragMove, handleDragEnd, updateDragHighlight } = useDndHandlers({
    activeId,
    setActiveId,
    activeDragData,
    setActiveDragData,
    setActiveContainerId,
    activeDragRotation,
    setActiveDragRotation,
    activeDragFolded,
    setActiveDragFolded,
    setDragHighlight,
    itemDefs,
    currentDragState,
  });

  // trigger update when rotation or fold changes
  useEffect(() => {
    if (currentDragState.current && activeId) {
      updateDragHighlight(currentDragState.current.overId, currentDragState.current.activeRect, activeDragRotation, activeDragFolded);
    }
  }, [activeDragRotation, activeDragFolded, activeId, updateDragHighlight]);

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
    useInventoryStore.getState().setDragCompatibility(null);
  };

  // Check if any Loot/Stash is open
  const isStashOpen = Object.values(containers).some((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-'));

  return (
    <>
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
            {openWindows.map(w => (
              <ContainerWindow
                key={w.id}
                containerId={w.id}
                initialPosition={w.position}
                onClose={() => closeWindow(w.id)}
                dragHighlight={dragHighlight}
              />
            ))}

            {/* Item Details Window */}
            {detailsWindows.map((w) => (
              <ItemDetailsWindow
                key={w.item.name}
                item={w.item}
                initialPosition={w.position}
                onClose={() => closeDetails(w.item)}
              />
            ))}

            <GiveItemModal
              giveTarget={giveTarget}
              onCloseSend={() => setGiveTarget(null)}
              receiveRequest={receiveRequest}
              onCloseReceive={() => setReceiveRequest(null)}
            />
            <InventoryNotification />
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

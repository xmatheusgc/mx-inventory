import React, { useState } from 'react';
import { twMerge } from 'tailwind-merge';
import { useDraggable } from '@dnd-kit/core';
import { Tooltip } from './Tooltip';
import { ContextMenu } from './ContextMenu';
import { QuantityModal } from './QuantityModal';
import { fetchNui } from '../utils/nui';
import { useInventoryStore } from '../store/inventoryStore';
import { ArrowDownToLine } from 'lucide-react';

// Constants for slot size (must match Grid and App.tsx)
const SLOT_SIZE = 64;
const GAP = 0; // px

interface ItemProps {
    id: string; // UUID
    name: string;
    count: number;
    label?: string;
    image?: string;
    size?: { x: number; y: number };
    slot: { x: number; y: number }; // 1-indexed
    originalSlot?: { x: number; y: number }; // Global slot for server actions (if different from visual slot)
    isDragging?: boolean;
    rotated?: boolean;
    isEquipment?: boolean;
    type?: string;
    containerId?: string; // Needed for actions to know source
    description?: string;
    weight?: number;
    folded?: boolean;
    metadata?: {
        ammo?: number;
        clip?: number;
        capacity?: number;
        caliber?: string;
    };
}

// Pure Presentational Component
export const ItemView: React.FC<ItemProps & {
    style?: React.CSSProperties,
    listeners?: any,
    attributes?: any,
    innerRef?: (element: HTMLElement | null) => void,
    isOverlay?: boolean
}> = React.memo((props) => {
    const {
        name, count, label, image, isDragging, isOverlay,
        style, listeners, attributes, innerRef, type, containerId, slot, originalSlot,
        description, weight, size, rotated, metadata
    } = props;

    const toggleWindow = useInventoryStore(state => state.toggleWindow);
    const openDetails = useInventoryStore(state => state.openDetails);
    const dragCompat = useInventoryStore(state => state.dragCompatibility);
    const setGiveTarget = useInventoryStore(state => state.setGiveTarget);
    const activeContextMenuItemId = useInventoryStore(state => state.activeContextMenuItemId);
    const setActiveContextMenuItemId = useInventoryStore(state => state.setActiveContextMenuItemId);

    // Determine if THIS item is a compatible target
    const isCompatibleTarget = dragCompat && !isDragging && !isOverlay && dragCompat.targetIds.has(props.id);

    // This item's context menu is visible only when it holds the global active id
    const showContextMenu = activeContextMenuItemId === props.id;

    const isContainer = (type === 'vest' || type === 'backpack' || type === 'bag');
    const isEquipmentItem = type === 'helmet' || type === 'armor' || type === 'mask' || type === 'glasses' || type === 'ear' || type === 'earpiece' || type === 'watch' || type === 'bracelet';
    const contextMenuAllowed = !props.isEquipment ||
        (!!type?.startsWith('weapon_') && type !== 'weapon_melee') ||
        isContainer || isEquipmentItem;

    const [showTooltip, setShowTooltip] = useState(false);
    const [tooltipPos, setTooltipPos] = useState({ x: 0, y: 0 });
    const [contextMenuPos, setContextMenuPos] = useState({ x: 0, y: 0 });

    // Modal State
    const [modalOpen, setModalOpen] = useState(false);
    const [actionType, setActionType] = useState<'drop' | 'split' | null>(null);

    const handleMouseEnter = (e: React.MouseEvent) => {
        if (!isDragging && !showContextMenu && !isOverlay && !modalOpen) {
            console.log('[DEBUG] Hover started:', name, props.id);
            setShowTooltip(true);
            setTooltipPos({ x: e.clientX, y: e.clientY });
            // Reconstruct item object for shortcuts
            const itemData: any = {
                id: props.id, name, count, label, image, type, slot,
                description, weight, size, rotated, metadata: props.metadata,
                isEquipment: props.isEquipment
            };
            useInventoryStore.getState().setHoveredItem({ item: itemData, containerId: props.containerId || 'unknown' });
        }
    };

    const handleMouseMove = (e: React.MouseEvent) => {
        if (showTooltip) {
            setTooltipPos({ x: e.clientX, y: e.clientY });
        }
    };

    const handleMouseLeave = () => {
        console.log('[DEBUG] Hover ended:', name, props.id);
        setShowTooltip(false);
        // Clear global hovered item
        const currentHover = useInventoryStore.getState().hoveredItem;
        if (currentHover?.item.id === props.id) {
            useInventoryStore.getState().setHoveredItem(null);
        }
    };

    const handleContextMenu = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (isOverlay || isDragging || !contextMenuAllowed) return;

        setShowTooltip(false);
        setContextMenuPos({ x: e.clientX, y: e.clientY });
        setActiveContextMenuItemId(props.id); // closes any other open menu
    };

    const handleDoubleClick = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (isOverlay || isDragging) return;

        // Container Check (Backpack/Vest) -> Open Window
        if ((type === 'vest' || type === 'backpack' || type === 'bag') && !props.isEquipment) {
            // Prevent opening if folded
            if (props.folded) return;
            toggleWindow(props.id, { x: e.clientX, y: e.clientY });
        } else {
            // Other Items -> Open Details
            const itemData: any = { // Reconstruct item object for details
                id: props.id, name, count, label, image, type, slot: props.slot,
                description, weight, size, rotated, metadata: props.metadata,
                isEquipment: props.isEquipment
            };
            openDetails(itemData, { x: e.clientX, y: e.clientY });
        }
    };

    // Close tooltip/menu if dragging starts
    React.useEffect(() => {
        if (isDragging) {
            setShowTooltip(false);
            if (showContextMenu) setActiveContextMenuItemId(null);
            setModalOpen(false);
        }
    }, [isDragging, showContextMenu, setActiveContextMenuItemId]);

    // --- Actions ---

    const handleAction = (action: string, qty: number = 1) => {
        const payload = {
            item: name,
            id: props.id,
            itemId: props.id, // For compatibility with server handlers expecting itemId
            name: name,
            slot: originalSlot || slot, // Use Original Global Slot if available
            container: containerId,
            containerId: containerId,
            amount: qty
        };

        switch (action) {
            case 'use':
                fetchNui('useItem', payload);
                break;
            case 'drop':
                fetchNui('dropItem', payload);
                break;
            case 'split':
                fetchNui('splitItem', payload);
                break;
            case 'give':
                fetchNui('giveItem', payload);
                break;
            case 'unload':
                fetchNui('unloadItem', payload);
                break;
            case 'fold':
                fetchNui('foldItem', payload);
                break;
            case 'open':
                toggleWindow(props.id, contextMenuPos);
                break;
            case 'details':
                const itemData: any = {
                    id: props.id, name, count, label, image, type, slot: props.slot,
                    description, weight, size, rotated, metadata: props.metadata,
                    isEquipment: props.isEquipment
                };
                openDetails(itemData, contextMenuPos);
                break;
            case 'equip': {
                let targetSlot = '';
                if (type === 'helmet') targetSlot = 'head';
                else if (type === 'mask') targetSlot = 'face';
                else if (type === 'armor') targetSlot = 'armor';
                else if (type === 'earpiece') targetSlot = 'earpiece';
                else if (type === 'vest') targetSlot = 'vest';
                else if (type === 'backpack') targetSlot = 'backpack';
                else if (type === 'weapon_pistol') targetSlot = 'pistol';
                else if (type === 'weapon_melee') targetSlot = 'melee';
                else if (type?.startsWith('weapon_')) {
                    const eq = useInventoryStore.getState().equipment;
                    if (!eq.primary) targetSlot = 'primary';
                    else if (!eq.secondary) targetSlot = 'secondary';
                    else targetSlot = 'primary';
                }

                if (targetSlot) {
                    fetchNui('equipItem', {
                        item: name,
                        id: props.id,
                        from: containerId,
                        slot: targetSlot
                    });
                }
                break;
            }
            case 'unequip':
                fetchNui('unequipItem', {
                    item: name,
                    id: props.id,
                    fromSlot: (containerId || '').replace('equip-', ''),
                    to: 'player-inv',
                    slot: {}
                });
                break;
        }
        setActiveContextMenuItemId(null);
    };

    const initiateQuantityAction = (type: 'drop' | 'split') => {
        setActionType(type);
        setModalOpen(true);
        setActiveContextMenuItemId(null);
    };

    const onModalConfirm = (qty: number) => {
        if (actionType) {
            handleAction(actionType, qty);
        }
        setActionType(null);
    };

    // Open GiveItemModal (player selection + qty combined in one modal)
    const handleGiveItem = () => {
        setActiveContextMenuItemId(null);
        const itemData: any = {
            id: props.id, name, count, label, image, type, slot,
            description, weight, size, rotated, metadata: props.metadata,
            isEquipment: props.isEquipment
        };
        setGiveTarget({ item: itemData, containerId: containerId || 'player-inv' });
    };


    // --- Context Options Construction ---
    const contextOptions = [];

    // Helper to determine item categorization
    const isBagRigs = type === 'vest' || type === 'backpack' || type === 'bag';
    const isWeapon = type?.startsWith('weapon_') && type !== 'weapon_melee';
    const isConsumable = !type || type === 'generic' || type === 'consumable' || type === 'food' || type === 'drink';

    // 1. Mochila/Rig
    if (isBagRigs) {
        if (props.isEquipment) {
            contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
            contextOptions.push({ label: 'Remover', action: () => handleAction('unequip') });
            contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') }); // Danger block handling if implemented in ContextMenu
        } else {
            contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
            contextOptions.push({ label: 'Abrir', action: () => handleAction('open') });
            // TODO: Equip logic needs to check if slot is free. For now, assuming server handles validation or we add client state check later.
            contextOptions.push({ label: 'Equipar', action: () => handleAction('equip') });
            const bagHasItems = (useInventoryStore.getState().containers[props.id]?.items?.length ?? 0) > 0;

            // Check if there is space to unfold into
            const canUnfold = () => {
                const targetContainer = useInventoryStore.getState().containers[containerId || ''];
                if (!targetContainer) return false;

                const w = rotated ? (size?.y || 1) : (size?.x || 1);
                const h = rotated ? (size?.x || 1) : (size?.y || 1);

                if (slot.x + w - 1 > targetContainer.size.width || slot.y + h - 1 > targetContainer.size.height) return false;

                if (targetContainer.validSlots) {
                    for (let px = 0; px < w; px++) {
                        for (let py = 0; py < h; py++) {
                            const checkX = slot.x + px;
                            const checkY = slot.y + py;
                            if (!targetContainer.validSlots.some(vs => vs.x === checkX && vs.y === checkY)) return false;
                        }
                    }
                }

                return !targetContainer.items.some(other => {
                    if (other.id === props.id) return false;
                    const oW = other.folded ? 1 : (other.rotated ? (other.size?.y || 1) : (other.size?.x || 1));
                    const oH = other.folded ? 1 : (other.rotated ? (other.size?.x || 1) : (other.size?.y || 1));
                    return slot.x < other.slot.x + oW && slot.x + w > other.slot.x && slot.y < other.slot.y + oH && slot.y + h > other.slot.y;
                });
            };

            contextOptions.push({
                label: props.folded ? 'Desenrolar' : 'Enrolar',
                action: () => handleAction('fold'),
                disabled: props.folded ? !canUnfold() : bagHasItems
            });
            contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
        }
    }
    // 2. Equipamentos (Colete, Capacete, etc...)
    else if (isEquipmentItem) {
        if (props.isEquipment) {
            contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
            contextOptions.push({ label: 'Remover', action: () => handleAction('unequip') });
            contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
        } else {
            contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
            contextOptions.push({ label: 'Equipar', action: () => handleAction('equip') });
            contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
        }
    }
    // 3. Armas
    else if (isWeapon) {
        if (props.isEquipment) {
            contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
            contextOptions.push({ label: 'Descarregar', action: () => handleAction('unload') });
            contextOptions.push({ label: 'Remover', action: () => handleAction('unequip') });
            contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
        } else {
            contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
            contextOptions.push({ label: 'Descarregar', action: () => handleAction('unload') });
            contextOptions.push({ label: 'Equipar', action: () => handleAction('equip') });
            contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
        }
    }
    // 4. Consumiveis
    else if (isConsumable) {
        contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
        contextOptions.push({ label: 'Usar', action: () => handleAction('use') });
        contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
    }
    // Fallback for items not matching the explicit categories above (e.g. materials, generic items)
    else {
        contextOptions.push({ label: 'Ver Detalhes', action: () => handleAction('details') });
        contextOptions.push({ label: 'Usar', action: () => handleAction('use') });
        if (count > 1) {
            contextOptions.push({ label: 'Dividir', action: () => initiateQuantityAction('split') });
        }
        contextOptions.push({ label: 'Dar Item', action: () => handleGiveItem() });
        contextOptions.push({ label: 'Descartar', danger: true, action: () => initiateQuantityAction('drop') });
    }

    return (
        <>
            <div
                ref={innerRef}
                {...listeners}
                {...attributes}
                className={twMerge(
                    "absolute bg-surface-light border border-border-light flex flex-col items-center justify-center select-none overflow-hidden transition-none shadow-lg hover:border-primary/50 group cursor-grab active:cursor-grabbing",
                    (isDragging || isOverlay) && "z-50 shadow-primary/20 scale-105 ring-2 ring-primary",
                    isDragging && !isOverlay && "opacity-50", // Ghost item visible but transparent
                    isCompatibleTarget && "ring-2 ring-green-400/80 border-green-400/60 shadow-[0_0_12px_rgba(74,222,128,0.3)] z-20"
                )}
                style={style}
                onMouseEnter={handleMouseEnter}
                onMouseMove={handleMouseMove}
                onMouseLeave={handleMouseLeave}
                onContextMenu={handleContextMenu}
                onDoubleClick={handleDoubleClick}
            >
                {image ? (
                    <img src={image} alt={name} className="w-full h-full object-contain p-1 pointer-events-none" />
                ) : (
                    <span className="text-xs text-center text-text-subtle px-1 pointer-events-none">{label || name}</span>
                )}
                {/* Compatible Target Overlay */}
                {isCompatibleTarget && (
                    <div className="absolute inset-0 bg-green-500/15 flex items-center justify-center pointer-events-none z-10 animate-pulse">
                        <ArrowDownToLine className="w-5 h-5 text-green-400 drop-shadow-lg" />
                    </div>
                )}
                {count > 1 && (
                    <span className="absolute bottom-0 right-0 p-0.5 text-[0.6rem] font-bold bg-black/50 text-white pointer-events-none">
                        {count}
                    </span>
                )}
                {/* Ammo count display for weapons */}
                {(metadata?.ammo !== undefined || metadata?.clip !== undefined) && type !== 'ammo' && type !== 'magazine' && (
                    <span className="absolute bottom-0.5 right-1 bg-black/70 text-[0.65rem] text-amber-400 font-mono px-1 rounded pointer-events-none z-10">
                        {Math.max(0, (metadata.ammo ?? 0) - (metadata.clip ?? 0))} / {metadata.clip ?? 0}
                    </span>
                )}
            </div>

            <Tooltip
                label={label || name}
                visible={showTooltip && !isDragging && !showContextMenu && !isOverlay && !modalOpen}
                position={tooltipPos}
            />

            <ContextMenu
                visible={showContextMenu && !isDragging && !isOverlay}
                position={contextMenuPos}
                options={contextOptions}
                onClose={() => setActiveContextMenuItemId(null)}
            />

            <QuantityModal
                isOpen={modalOpen}
                onClose={() => setModalOpen(false)}
                onConfirm={onModalConfirm}
                maxQuantity={actionType === 'split' ? count - 1 : count}
                title={actionType === 'split' ? 'Dividir Quantidade' : 'Dropar Quantidade'}
            />
        </>
    );
});

// Connected Component
export const Item: React.FC<ItemProps & { containerId?: string }> = React.memo((props) => {
    const { id, size, slot, rotated, isEquipment, containerId } = props;

    const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
        id: id, // Use UUID instead of name
        data: { ...props, containerId },
    });

    const currentSize = (rotated) ? { x: size?.y || 1, y: size?.x || 1 } : (size || { x: 1, y: 1 });

    const style = isEquipment ? {
        // Equipment Item Style: Centered, relative to slot, FULL FILL
        width: '100%',
        height: '100%',
        position: 'absolute' as const, // Change to absolute to ensure it fills the relative parent
        top: 0,
        left: 0,
        zIndex: isDragging ? 100 : undefined,
        transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0)` : undefined,
    } : {
        // Grid Item Style: Absolute, based on slot index
        width: currentSize.x * SLOT_SIZE + (currentSize.x - 1) * GAP,
        height: currentSize.y * SLOT_SIZE + (currentSize.y - 1) * GAP,
        left: (slot.x - 1) * (SLOT_SIZE + GAP),
        top: (slot.y - 1) * (SLOT_SIZE + GAP),
        transform: (transform && !isDragging)
            ? `translate3d(${transform.x}px, ${transform.y}px, 0)`
            : undefined,
        zIndex: isDragging ? 100 : undefined,
    };

    return (
        <ItemView
            {...props}
            containerId={containerId}
            isDragging={isDragging}
            innerRef={setNodeRef}
            listeners={listeners}
            attributes={attributes}
            style={style}
        />
    );
});

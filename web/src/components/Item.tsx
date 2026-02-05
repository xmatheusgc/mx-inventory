import React, { useState } from 'react';
import { twMerge } from 'tailwind-merge';
import { useDraggable } from '@dnd-kit/core';
import { Tooltip } from './Tooltip';
import { ContextMenu } from './ContextMenu';
import { QuantityModal } from './QuantityModal';
import { fetchNui } from '../utils/nui';
import { useInventoryStore } from '../store/inventoryStore';

// Constants for slot size (must match Grid)
const SLOT_SIZE = 64;
const GAP = 0; // px

interface ItemProps {
    name: string;
    count: number;
    label?: string;
    image?: string;
    size?: { x: number; y: number };
    slot: { x: number; y: number }; // 1-indexed
    isDragging?: boolean;
    rotated?: boolean;
    isEquipment?: boolean;
    type?: string;
    containerId?: string; // Needed for actions to know source
    description?: string;
    weight?: number;
}

// Pure Presentational Component
export const ItemView: React.FC<ItemProps & {
    style?: React.CSSProperties,
    listeners?: any,
    attributes?: any,
    innerRef?: (element: HTMLElement | null) => void,
    isOverlay?: boolean
}> = (props) => {
    const {
        name, count, label, image, isDragging, isOverlay,
        style, listeners, attributes, innerRef, type, containerId, slot,
        description, weight, size, rotated
    } = props;

    const toggleWindow = useInventoryStore(state => state.toggleWindow);
    const openDetails = useInventoryStore(state => state.openDetails);

    const [showTooltip, setShowTooltip] = useState(false);
    const [tooltipPos, setTooltipPos] = useState({ x: 0, y: 0 });
    const [showContextMenu, setShowContextMenu] = useState(false);
    const [contextMenuPos, setContextMenuPos] = useState({ x: 0, y: 0 });

    // Modal State
    const [modalOpen, setModalOpen] = useState(false);
    const [actionType, setActionType] = useState<'drop' | 'give' | null>(null);

    const handleMouseEnter = (e: React.MouseEvent) => {
        if (!isDragging && !showContextMenu && !isOverlay && !modalOpen) {
            setShowTooltip(true);
            setTooltipPos({ x: e.clientX, y: e.clientY });
        }
    };

    const handleMouseMove = (e: React.MouseEvent) => {
        if (showTooltip) {
            setTooltipPos({ x: e.clientX, y: e.clientY });
        }
    };

    const handleMouseLeave = () => {
        setShowTooltip(false);
    };

    const handleContextMenu = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (isOverlay || isDragging || props.isEquipment) return;

        setShowTooltip(false);
        setContextMenuPos({ x: e.clientX, y: e.clientY });
        setShowContextMenu(true);
    };

    const handleDoubleClick = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (isOverlay || isDragging) return;

        // Container Check (Backpack/Vest) -> Open Window
        if ((type === 'vest' || type === 'backpack' || type === 'bag') && !props.isEquipment) {
            toggleWindow(name);
        } else {
            // Other Items -> Open Details
            const itemData: any = { // Reconstruct item object for details
                name, count, label, image, type, slot,
                description, weight, size, rotated
            };
            openDetails(itemData);
        }
    };

    // Close tooltip/menu if dragging starts
    React.useEffect(() => {
        if (isDragging) {
            setShowTooltip(false);
            setShowContextMenu(false);
            setModalOpen(false);
        }
    }, [isDragging]);

    // --- Actions ---

    const handleAction = (action: string, qty: number = 1) => {
        const payload = {
            item: name,
            slot: slot, // Pass full slot object usually, or ID if equipment
            container: containerId,
            amount: qty
        };

        switch (action) {
            case 'use':
                fetchNui('useItem', payload);
                break;
            case 'drop':
                fetchNui('dropItem', payload);
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
                toggleWindow(name); // Use name as containerId
                break;
            case 'details':
                console.log('Details:', payload);
                break;
        }
        setShowContextMenu(false);
    };

    const initiateQuantityAction = (type: 'drop' | 'give') => {
        setActionType(type);
        setModalOpen(true);
        setShowContextMenu(false);
    };

    const onModalConfirm = (qty: number) => {
        if (actionType) {
            handleAction(actionType, qty);
        }
        setActionType(null);
    };


    // --- Context Options Construction ---
    const contextOptions = [];

    // [All Items]
    contextOptions.push({ label: 'Enviar', action: () => initiateQuantityAction('give') });
    contextOptions.push({ label: 'Dropar', action: () => initiateQuantityAction('drop') }); // Supports qty
    contextOptions.push({ label: 'Detalhes', action: () => handleAction('details') });

    // [Consumable] (generic for now, or specific type check)
    if (!type || type === 'generic' || type === 'consumable' || type === 'food' || type === 'drink') {
        contextOptions.unshift({ label: 'Usar', action: () => handleAction('use') });
    }

    // [Weapon / Magazine]
    if (type?.startsWith('weapon_') || type === 'magazine' || type === 'ammo_box') {
        contextOptions.push({ label: 'Descarregar', action: () => handleAction('unload') });
    }

    // [Bags/Vests] (Foldable / Openable)
    if (type === 'vest' || type === 'backpack' || type === 'bag') {
        contextOptions.push({ label: 'Abrir', action: () => handleAction('open') });
        contextOptions.push({ label: 'Dobrar', action: () => handleAction('fold') });
    }


    return (
        <>
            <div
                ref={innerRef}
                {...listeners}
                {...attributes}
                className={twMerge(
                    "absolute bg-zinc-800 border border-zinc-600 flex flex-col items-center justify-center select-none overflow-hidden transition-none shadow-lg hover:border-orange-500/50 group cursor-grab active:cursor-grabbing",
                    (isDragging || isOverlay) && "z-50 shadow-orange-500/20 scale-105 ring-2 ring-orange-500",
                    isDragging && !isOverlay && "opacity-50" // Ghost item visible but transparent
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
                    <span className="text-xs text-center text-gray-300 px-1 pointer-events-none">{label || name}</span>
                )}
                {count > 1 && (
                    <span className="absolute bottom-0 right-0 p-0.5 text-[0.6rem] font-bold bg-black/50 text-white pointer-events-none">
                        {count}
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
                onClose={() => setShowContextMenu(false)}
            />

            <QuantityModal
                isOpen={modalOpen}
                onClose={() => setModalOpen(false)}
                onConfirm={onModalConfirm}
                maxQuantity={count}
                title={actionType === 'give' ? 'Enviar Quantidade' : 'Dropar Quantidade'}
            />
        </>
    );
};

// Connected Component
export const Item: React.FC<ItemProps & { containerId?: string }> = (props) => {
    const { name, size, slot, rotated, isEquipment, containerId } = props;

    const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
        id: name,
        data: { name, size, slot, rotated, containerId },
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
};

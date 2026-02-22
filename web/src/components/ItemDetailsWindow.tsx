import React, { useState, useRef, useEffect } from 'react';
import type { Item } from '../store/inventoryStore';
import { useInventoryStore } from '../store/inventoryStore';
import { useDroppable, useDraggable } from '@dnd-kit/core';
import { createPortal } from 'react-dom';
import { ArrowDownToLine } from 'lucide-react';

interface ItemDetailsWindowProps {
    item: Item;
    onClose: () => void;
}

// Draggable installed attachment content
const DraggableAttachment: React.FC<{
    attachmentName: string;
    weaponId: string;
    weaponContainerId: string;
    slotId: string;
    itemDefs: any;
}> = ({ attachmentName, weaponId, weaponContainerId, slotId, itemDefs }) => {
    const attachmentDef = itemDefs[attachmentName];
    const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
        id: `installed-attachment-${weaponId}-${slotId}`,
        data: {
            type: 'installed-attachment',
            attachmentName,
            weaponId,
            weaponContainerId,
            slotId,
            name: attachmentName,
            image: attachmentDef?.image,
            label: attachmentDef?.label || attachmentName,
            size: attachmentDef?.size || { x: 1, y: 1 },
        }
    });

    const style: React.CSSProperties = {
        transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0)` : undefined,
        zIndex: isDragging ? 200 : undefined,
        opacity: isDragging ? 0.5 : 1,
    };

    return (
        <div ref={setNodeRef} {...listeners} {...attributes} style={style} className="w-10 h-10 cursor-grab active:cursor-grabbing">
            {attachmentDef?.image ? (
                <img
                    src={`/images/${attachmentDef.image || 'placeholder.png'}`}
                    alt={attachmentDef.label}
                    className="w-full h-full object-contain drop-shadow-lg pointer-events-none"
                />
            ) : (
                <span className="text-[10px] text-zinc-400">{attachmentName}</span>
            )}
        </div>
    );
};

// Individual Attachment Slot (Droppable)
const AttachmentSlot: React.FC<{
    slotId: string;
    label: string;
    weaponId: string;
    weaponContainerId: string;
    currentAttachment: string | null;
    supported: boolean;
    itemDefs: any;
}> = ({ slotId, label, weaponId, weaponContainerId, currentAttachment, supported, itemDefs }) => {
    const droppableId = `attachment-${weaponId}-${slotId}`;
    const dragCompat = useInventoryStore(state => state.dragCompatibility);
    const isCompatibleTarget = dragCompat && dragCompat.targetIds.has(droppableId);

    const { setNodeRef, isOver } = useDroppable({
        id: droppableId,
        data: {
            type: 'attachment-slot',
            slotId,
            weaponId,
            weaponContainerId
        }
    });

    if (!supported) {
        return (
            <div className="flex flex-col items-center gap-1 opacity-20 select-none">
                <div className="w-14 h-14 bg-black/20 border border-white/5 rounded flex items-center justify-center">
                    <span className="text-[10px] text-zinc-600">—</span>
                </div>
                <span className="text-[9px] text-zinc-600 uppercase tracking-wider">{label}</span>
            </div>
        );
    }

    return (
        <div className="flex flex-col items-center gap-1">
            <div
                ref={setNodeRef}
                className={`
                    relative w-14 h-14 bg-black/40 border rounded flex items-center justify-center
                    transition-all duration-200
                    ${isOver ? 'border-primary/80 bg-primary/10 scale-105' : 'border-white/10 hover:border-white/20'}
                    ${currentAttachment ? 'border-green-500/40 bg-green-900/10' : ''}
                    ${isCompatibleTarget && !currentAttachment ? 'ring-2 ring-green-400/80 border-green-400/60 shadow-[0_0_12px_rgba(74,222,128,0.3)]' : ''}
                `}
                title={currentAttachment ? `Drag to remove` : `Drop ${label} here`}
            >
                {currentAttachment ? (
                    <DraggableAttachment
                        attachmentName={currentAttachment}
                        weaponId={weaponId}
                        weaponContainerId={weaponContainerId}
                        slotId={slotId}
                        itemDefs={itemDefs}
                    />
                ) : (
                    <span className="text-[10px] text-zinc-500">+</span>
                )}
                {isCompatibleTarget && !currentAttachment && (
                    <div className="absolute inset-0 bg-green-500/15 flex items-center justify-center pointer-events-none animate-pulse rounded">
                        <ArrowDownToLine className="w-4 h-4 text-white drop-shadow-lg" />
                    </div>
                )}
                {currentAttachment && (
                    <div className="absolute -top-1 -right-1 w-3 h-3 bg-green-500 rounded-full border border-black" />
                )}
            </div>
            <span className={`text-[9px] uppercase tracking-wider ${currentAttachment ? 'text-green-400' : 'text-zinc-500'}`}>
                {label}
            </span>
        </div>
    );
};

export const ItemDetailsWindow: React.FC<ItemDetailsWindowProps> = ({ item, onClose }) => {
    // Initial random or centered position
    const [position, setPosition] = useState({ x: window.innerWidth / 2 + 50, y: window.innerHeight / 2 - 100 });
    const [isDragging, setIsDragging] = useState(false);
    const dragOffset = useRef({ x: 0, y: 0 });

    // Get itemDefs directly from window (always available after first inventory open)
    const defs = (window as any).__itemDefs || {};

    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            if (isDragging) {
                setPosition({
                    x: e.clientX - dragOffset.current.x,
                    y: e.clientY - dragOffset.current.y
                });
            }
        };

        const handleMouseUp = () => {
            setIsDragging(false);
        };

        if (isDragging) {
            window.addEventListener('mousemove', handleMouseMove);
            window.addEventListener('mouseup', handleMouseUp);
        }

        return () => {
            window.removeEventListener('mousemove', handleMouseMove);
            window.removeEventListener('mouseup', handleMouseUp);
        };
    }, [isDragging]);

    const handleMouseDown = (e: React.MouseEvent) => {
        setIsDragging(true);
        dragOffset.current = {
            x: e.clientX - position.x,
            y: e.clientY - position.y
        };
    };

    const isWeapon = item.type?.startsWith('weapon_');
    const weaponDef = defs[item.name];
    const supportedAttachments = weaponDef?.equipment?.supportedAttachments || {};

    // Read live item data from the store so attachments update immediately
    const containers = useInventoryStore(state => state.containers);
    const equipment = useInventoryStore(state => state.equipment);

    let liveItem = item;
    // Try to find the live version of this item in the store
    for (const c of Object.values(containers)) {
        const found = c.items.find(i => i.id === item.id);
        if (found) { liveItem = found; break; }
    }
    for (const eq of Object.values(equipment)) {
        if (eq && eq.id === item.id) { liveItem = eq; break; }
    }

    const currentAttachments = liveItem.metadata?.attachments || {};

    // Find the weapon's containerId (equipment slot or container)
    // We infer from the store
    let weaponContainerId = 'player-inv';
    for (const [slot, eq] of Object.entries(equipment)) {
        if (eq && eq.id === item.id) {
            weaponContainerId = `equip-${slot}`;
            break;
        }
    }

    const ATTACHMENT_SLOTS = [
        { id: 'muzzle', label: 'MZL' },
        { id: 'scope', label: 'SCP' },
        { id: 'grip', label: 'GRP' },
        { id: 'skin', label: 'SKN' },
    ];

    return createPortal(
        <div
            className="fixed flex flex-col bg-surface-dark/95 border border-border-dark shadow-2xl rounded-sm overflow-hidden min-w-[350px] max-w-[400px] z-[60]"
            style={{ left: position.x, top: position.y }}
        >
            {/* Header / Drag Handle */}
            <div
                className="flex items-center justify-between bg-surface-light p-2 cursor-move border-b border-border-dark select-none"
                onMouseDown={handleMouseDown}
            >
                <div className="flex items-center gap-2">
                    <span className="text-primary font-bold uppercase tracking-wider text-sm">
                        INFO
                    </span>
                    <span className="text-text-subtle text-xs">
                        {item.label || item.name}
                    </span>
                </div>
                <button
                    onClick={(e) => { e.stopPropagation(); onClose(); }}
                    className="text-text-muted hover:text-white transition-colors"
                >
                    ✕
                </button>
            </div>

            {/* Content */}
            <div className="p-4 flex flex-col gap-4">
                {/* Top Section: Image & Description */}
                <div className="flex gap-4">
                    <div className="w-24 h-24 bg-black/40 border border-white/5 rounded flex items-center justify-center shrink-0">
                        {item.image ? (
                            <img src={item.image} alt={item.name} className="w-full h-full object-contain p-2" />
                        ) : (
                            <span className="text-xs text-zinc-600 italic">No Image</span>
                        )}
                    </div>
                    <div className="flex flex-col gap-1 flex-1">
                        <h3 className="text-lg font-bold text-white leading-none">{item.label || item.name}</h3>
                        <span className="text-xs text-text-muted uppercase tracking-widest">{item.type || 'Generic Item'}</span>
                        <div className="h-px bg-white/10 my-1" />
                        <p className="text-xs text-zinc-400 leading-relaxed">
                            {item.description || "No description available for this item."}
                        </p>
                        <div className="flex gap-2 mt-auto">
                            <span className="text-[10px] bg-surface-light px-1.5 py-0.5 rounded text-text-muted">
                                Weight: {item.weight || 0.0}kg
                            </span>
                            {item.metadata?.ammo !== undefined && (
                                <span className="text-[10px] bg-yellow-900/30 px-1.5 py-0.5 rounded text-yellow-400">
                                    Ammo: {item.metadata.ammo}
                                </span>
                            )}
                        </div>
                    </div>
                </div>

                {/* Weapon Attachments Section */}
                {isWeapon && (
                    <div className="flex flex-col gap-2 pt-2 border-t border-white/5">
                        <span className="text-xs font-bold text-text-muted uppercase tracking-wider">Attachments</span>
                        <div className="flex gap-3 justify-center">
                            {ATTACHMENT_SLOTS.map(slot => (
                                <AttachmentSlot
                                    key={slot.id}
                                    slotId={slot.id}
                                    label={slot.label}
                                    weaponId={item.id}
                                    weaponContainerId={weaponContainerId}
                                    currentAttachment={currentAttachments[slot.id] || null}
                                    supported={!!supportedAttachments[slot.id]}
                                    itemDefs={defs}
                                />
                            ))}
                        </div>
                        {Object.keys(supportedAttachments).length === 0 && (
                            <p className="text-[10px] text-zinc-600 text-center italic">This weapon does not support attachments.</p>
                        )}
                    </div>
                )}
            </div>
        </div>,
        document.body
    );
};

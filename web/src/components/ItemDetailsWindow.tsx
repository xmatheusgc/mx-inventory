import React, { useState, useRef, useEffect } from 'react';
import type { Item } from '../store/inventoryStore';
import { createPortal } from 'react-dom';
import { EquipmentSlot } from './EquipmentSlot'; // Reusing for attachment slots

interface ItemDetailsWindowProps {
    item: Item;
    onClose: () => void;
}

export const ItemDetailsWindow: React.FC<ItemDetailsWindowProps> = ({ item, onClose }) => {
    // Initial random or centered position
    const [position, setPosition] = useState({ x: window.innerWidth / 2 + 50, y: window.innerHeight / 2 - 100 });
    const [isDragging, setIsDragging] = useState(false);
    const dragOffset = useRef({ x: 0, y: 0 });

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
                            {item.description || "No description available for this item. double-click usage allows specific actions."}
                        </p>
                        <div className="flex gap-2 mt-auto">
                            <span className="text-[10px] bg-surface-light px-1.5 py-0.5 rounded text-text-muted">
                                Weight: {item.weight || 0.0}kg
                            </span>
                        </div>
                    </div>
                </div>

                {/* Weapon Attachments Section */}
                {isWeapon && (
                    <div className="flex flex-col gap-2 pt-2 border-t border-white/5">
                        <span className="text-xs font-bold text-text-muted uppercase tracking-wider">Attachments</span>
                        <div className="flex gap-2 justify-between">
                            <EquipmentSlot slotId="magazine" label="MAG" className="w-12 h-12 bg-black/40 border-white/5" acceptedTypes={['magazine']} />
                            <EquipmentSlot slotId="scope" label="SCP" className="w-12 h-12 bg-black/40 border-white/5" acceptedTypes={['attachment_scope']} />
                            <EquipmentSlot slotId="skin" label="SKN" className="w-12 h-12 bg-black/40 border-white/5" acceptedTypes={['attachment_skin']} />
                            <EquipmentSlot slotId="grip" label="GRP" className="w-12 h-12 bg-black/40 border-white/5" acceptedTypes={['attachment_grip']} />
                            <EquipmentSlot slotId="muzzle" label="MZL" className="w-12 h-12 bg-black/40 border-white/5" acceptedTypes={['attachment_muzzle']} />
                        </div>
                    </div>
                )}
            </div>
        </div>,
        document.body
    );
};

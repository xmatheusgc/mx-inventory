import React, { useState, useRef, useEffect } from 'react';
import { useInventoryStore } from '../store/inventoryStore';
import { Container } from './Container';
import { CONTAINER_LAYOUTS } from '../config/layouts';
import { createPortal } from 'react-dom';

interface ContainerWindowProps {
    containerId: string;
    onClose: () => void;
}

export const ContainerWindow: React.FC<ContainerWindowProps> = ({ containerId, onClose }) => {
    const container = useInventoryStore(state => state.containers[containerId]);

    // Initial random or centered position
    const [position, setPosition] = useState({ x: window.innerWidth / 2 - 200, y: window.innerHeight / 2 - 150 });
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

    if (!container) return null;

    const layout = CONTAINER_LAYOUTS[container.id] || CONTAINER_LAYOUTS[container.label] ||
        (container.type === 'vest' ? CONTAINER_LAYOUTS['vest'] : CONTAINER_LAYOUTS['backpack']);

    return createPortal(
        <div
            className="fixed flex flex-col gap-1 bg-black/90 border border-zinc-700 shadow-2xl rounded-sm overflow-hidden min-w-[300px] z-[50]"
            style={{ left: position.x, top: position.y }}
        >
            {/* Header / Drag Handle */}
            <div
                className="flex items-center justify-between bg-zinc-800 p-2 cursor-move border-b border-zinc-700 hover:bg-zinc-700 transition-colors"
                onMouseDown={handleMouseDown}
            >
                <span className="text-zinc-300 text-xs font-bold uppercase tracking-wider select-none">
                    {container.label}
                </span>
                <button
                    onClick={(e) => { e.stopPropagation(); onClose(); }}
                    className="text-zinc-400 hover:text-white px-1 font-bold"
                >
                    ✕
                </button>
            </div>

            {/* Content */}
            <div className="p-4 max-h-[60vh] overflow-y-auto custom-scrollbar-hide">
                {layout ? (
                    <div className="flex flex-col gap-1">
                        {layout.rows.map((row: any, rowIdx: number) => (
                            <div key={rowIdx} className={row.className || "flex justify-center gap-2"}>
                                {row.pockets.map((pocket: any, pIdx: number) => {
                                    // Global Index Calculation - simplified assumption that Layout is source of truth
                                    let globalIndex = 0;
                                    for (let i = 0; i < rowIdx; i++) {
                                        globalIndex += layout.rows[i].pockets.length;
                                    }
                                    globalIndex += pIdx;

                                    return (
                                        <div key={globalIndex} className={`flex flex-col ${pocket.className || ''}`}>
                                            <Container
                                                containerId={container.id}
                                                droppableId={`${container.id}::pocket::${globalIndex}`}
                                                region={pocket}
                                            />
                                        </div>
                                    )
                                })}
                            </div>
                        ))}
                    </div>
                ) : (
                    // Default Grid Layout if no specific layout found
                    <Container containerId={container.id} />
                )}
            </div>
        </div>,
        document.body
    );
};

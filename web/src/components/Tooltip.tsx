import React from 'react';
import { createPortal } from 'react-dom';

interface TooltipProps {
    label: string;
    description?: string;
    visible: boolean;
    position: { x: number; y: number };
}

export const Tooltip: React.FC<TooltipProps> = ({ label, description, visible, position }) => {
    if (!visible) return null;

    // Use portal to ensure it's on top of everything
    return createPortal(
        <div
            className="fixed pointer-events-none z-[9999] flex flex-col w-56 bg-surface-dark/95 backdrop-blur-md border border-border-dark/80 shadow-2xl rounded p-2"
            style={{
                left: position.x + 15,
                top: position.y + 15
            }}
        >
            {/* Header */}
            <div className="font-bold text-zinc-100 text-sm mb-1 tracking-wide uppercase">
                {label}
            </div>

            {/* Divider */}
            <div className="h-px bg-gradient-to-r from-border-dark via-border-light to-border-dark my-1.5" />

            {/* Content Body */}
            <div className="flex flex-col gap-1 text-[0.7rem] text-text-subtle font-medium">
                <div className="flex items-center gap-2">
                    <span className="text-primary font-bold">[F]</span>
                    <span>Mover item</span>
                </div>
                <div className="flex items-center gap-2">
                    <span className="text-error font-bold">[X]</span>
                    <span>Descartar item</span>
                </div>
            </div>

            {/* Optional Description if needed later */}
            {description && (
                <div className="mt-2 text-xs text-text-muted italic">
                    {description}
                </div>
            )}
        </div>,
        document.body
    );
};

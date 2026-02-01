import React from 'react';
import { createPortal } from 'react-dom';

interface ContextMenuProps {
    visible: boolean;
    position: { x: number; y: number };
    options: { label: string; action: () => void; danger?: boolean }[];
    onClose: () => void;
}

export const ContextMenu: React.FC<ContextMenuProps> = ({ visible, position, options, onClose }) => {
    // Close on click outside
    React.useEffect(() => {
        const handleClick = () => onClose();
        if (visible) {
            window.addEventListener('click', handleClick);
            window.addEventListener('contextmenu', handleClick); // Close on right click elsewhere
        }
        return () => {
            window.removeEventListener('click', handleClick);
            window.removeEventListener('contextmenu', handleClick);
        };
    }, [visible, onClose]);

    if (!visible) return null;

    return createPortal(
        <div
            className="fixed z-[10000] bg-zinc-900 border border-zinc-700 shadow-xl rounded py-1 min-w-[140px] flex flex-col"
            style={{
                left: position.x,
                top: position.y,
            }}
            // Prevent the menu itself from closing when clicked immediately (action will close it)
            onClick={(e) => e.stopPropagation()}
            // Prevent context menu on the context menu
            onContextMenu={(e) => e.preventDefault()}
        >
            {options.map((option, index) => (
                <button
                    key={index}
                    className={`text-left px-3 py-1.5 text-xs hover:bg-zinc-800 transition-colors ${option.danger ? 'text-red-400 hover:text-red-300' : 'text-zinc-200 hover:text-white'
                        }`}
                    onClick={() => {
                        option.action();
                        onClose();
                    }}
                >
                    {option.label}
                </button>
            ))}
        </div>,
        document.body
    );
};

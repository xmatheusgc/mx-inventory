import React from 'react';
import { Container } from './Container';
import { useInventoryStore } from '../store/inventoryStore';

interface StashInventoryProps {
    dragHighlight?: {
        containerId: string;
        slots: { x: number; y: number }[];
        isValid: boolean;
    };
}

export const StashInventory: React.FC<StashInventoryProps> = ({ dragHighlight }) => {
    const { containers } = useInventoryStore();

    return (
        <div className="flex flex-col gap-4 overflow-y-auto overflow-x-hidden w-[500px] pt-6 border bg-black/60 border-white/10">
            {Object.values(containers)
                .filter((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-'))
                .map((c: any) => (
                    <div key={c.id} className="flex flex-col gap-1 px-4">
                        <span className="text-zinc-500 text-xs font-bold uppercase tracking-wider">{c.label}</span>
                        <Container
                            containerId={c.id}
                            highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                        />
                    </div>
                ))
            }
            {Object.values(containers).filter((c: any) => c.id.startsWith('drop-') || c.id.startsWith('stash-')).length === 0 && (
                <div className="flex items-center justify-center flex-1 opacity-20 text-zinc-500 text-sm italic">
                    No active loot nearby
                </div>
            )}
        </div>
    );
};

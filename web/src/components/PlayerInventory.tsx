import React from 'react';
import { Container } from './Container';
import { EquipmentSlot } from './EquipmentSlot';
import { CONTAINER_LAYOUTS } from '../config/layouts';
import { useInventoryStore } from '../store/inventoryStore';

interface PlayerInventoryProps {
    dragHighlight?: {
        containerId: string;
        slots: { x: number; y: number }[];
        isValid: boolean;
    };
}

export const PlayerInventory: React.FC<PlayerInventoryProps> = ({ dragHighlight }) => {
    const { containers, equipment } = useInventoryStore();

    return (
        <div className="flex flex-col gap-4 overflow-y-auto overflow-x-hidden pt-6 border bg-black/60 border-white/10 w-[520px] shrink-0">
            {/* 1. Pockets (Always Top) */}
            {containers['player-inv'] &&
                <div className="flex flex-col gap-1 shrink-0 px-4">
                    <h2 className="text-zinc-500 text-xs font-bold uppercase tracking-wider pt-2">Pockets</h2>
                    <div className="flex bg-black/40 overflow-hidden w-fit p-1">
                        <Container
                            containerId="player-inv"
                            highlight={dragHighlight?.containerId === 'player-inv' ? dragHighlight : undefined}
                        />
                    </div>
                </div>
            }

            {/* 2. Vest Section (Slot + Container) */}
            <div className="flex flex-col gap-1 shrink-0 px-4">
                <h2 className="text-zinc-500 text-xs font-bold uppercase tracking-wider pt-2">Tactical Vest</h2>
                <div className="flex bg-black/40 overflow-hidden w-fit p-1">
                    {/* Slot */}
                    <div className="flex flex-col gap-2 shrink-0">
                        <EquipmentSlot slotId="vest" label="" acceptedTypes={['vest']} className="w-32 h-32" />
                    </div>

                    {/* Container (Scrollable Area) */}
                    <div className="flex-1 overflow-x-auto custom-scrollbar-hide">
                        {Object.values(containers)
                            .filter((c: any) => c.type === 'vest' && equipment?.vest?.id === c.id)
                            .map((c: any) => {
                                const layout = CONTAINER_LAYOUTS[c.name] || CONTAINER_LAYOUTS['vest'];

                                if (layout) {
                                    return (
                                        <div key={c.id} className="flex flex-col gap-1 p-2">
                                            {layout.rows.map((row: any, rowIdx: number) => (
                                                <div key={rowIdx} className={row.className || "flex justify-center gap-2"}>
                                                    {row.pockets.map((pocket: any, pIdx: number) => {
                                                        // Global Index Calculation
                                                        let globalIndex = 0;
                                                        for (let i = 0; i < rowIdx; i++) {
                                                            globalIndex += layout.rows[i].pockets.length;
                                                        }
                                                        globalIndex += pIdx;

                                                        return (
                                                            <div key={globalIndex} className={`flex flex-col ${pocket.className || ''}`}>
                                                                <Container
                                                                    containerId={c.id}
                                                                    droppableId={`${c.id}::pocket::${globalIndex}`}
                                                                    region={pocket}
                                                                    highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                                                                />
                                                            </div>
                                                        )
                                                    })}
                                                </div>
                                            ))}
                                        </div>
                                    )
                                }

                                return (
                                    <div key={c.id} className="flex flex-col gap-1">
                                        <Container
                                            containerId={c.id}
                                            highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                                        />
                                    </div>
                                )
                            })}
                    </div>
                </div>
            </div>

            {/* 3. Backpack Section (Slot + Container) */}
            <div className="flex flex-col gap-1 shrink-0 px-4 pb-4">
                <h2 className="text-zinc-500 text-xs font-bold uppercase tracking-wider pt-2">Backpack</h2>
                <div className="flex bg-black/40 overflow-hidden w-fit p-1">
                    {/* Slot */}
                    <div className="flex flex-col gap-2 shrink-0">
                        <EquipmentSlot slotId="backpack" label="" acceptedTypes={['backpack']} className="w-32 h-32" />
                    </div>

                    {/* Container (Scrollable Area) */}
                    <div className="flex-1 overflow-x-auto custom-scrollbar-hide">

                        {/* Container (if exists) */}
                        {Object.values(containers)
                            .filter((c: any) => c.type === 'backpack' && equipment?.backpack?.id === c.id)
                            .map((c: any) => {
                                const layout = CONTAINER_LAYOUTS[c.name] || CONTAINER_LAYOUTS['backpack'];

                                if (layout) {
                                    return (
                                        <div key={c.id} className="flex flex-col gap-1 p-2">
                                            {layout.rows.map((row: any, rowIdx: number) => (
                                                <div key={rowIdx} className={row.className || "flex justify-center gap-2"}>
                                                    {row.pockets.map((pocket: any, pIdx: number) => {
                                                        // Global Index Calculation
                                                        let globalIndex = 0;
                                                        for (let i = 0; i < rowIdx; i++) {
                                                            globalIndex += layout.rows[i].pockets.length;
                                                        }
                                                        globalIndex += pIdx;

                                                        return (
                                                            <div key={globalIndex} className={`flex flex-col ${pocket.className || ''}`}>
                                                                <Container
                                                                    containerId={c.id}
                                                                    droppableId={`${c.id}::pocket::${globalIndex}`}
                                                                    region={pocket}
                                                                    highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                                                                />
                                                            </div>
                                                        )
                                                    })}
                                                </div>
                                            ))}
                                        </div>
                                    )
                                }

                                return (
                                    <div key={c.id} className="flex flex-col gap-1">
                                        <Container
                                            containerId={c.id}
                                            highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                                        />
                                    </div>
                                )
                            })}
                    </div>
                </div>
            </div>

            {/* 4. Other Containers */}
            {Object.values(containers)
                .filter((c: any) => c.id !== 'player-inv' && c.type !== 'vest' && c.type !== 'bag' && c.type !== 'backpack' && !c.id.startsWith('drop-') && !c.id.startsWith('stash-'))
                .map((c: any) => (
                    <div key={c.id} className="flex flex-col gap-1 shrink-0 px-4 pb-4">
                        <h2 className="text-zinc-500 text-xs font-bold uppercase tracking-wider pt-2">{c.label}</h2>
                        <div className="p-4 border border-white/5 bg-black/40 rounded-sm">
                            <Container
                                containerId={c.id}
                                highlight={dragHighlight?.containerId === c.id ? dragHighlight : undefined}
                            />
                        </div>
                    </div>
                ))
            }
        </div>
    );
};

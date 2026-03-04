import React from 'react';
import { EquipmentSlot } from './EquipmentSlot';
import { Droplets, HeartPulse, Weight, Zap } from 'lucide-react';
import { useInventoryStore } from '../store/inventoryStore';


export const EquipmentPanel: React.FC = () => {
    const { shortcuts, containers, equipment } = useInventoryStore();

    return (
        <div className="flex flex-col gap-2 p-4 rounded-lg w-[500px] flex flex-col gap-4 overflow-hidden pt-6">
            {/* Main Gear Section (Split for Ped) - Reduced Height */}
            <div className="flex justify-between items-start h-[280px] shrink-0">
                {/* Left Column (Head/Face) */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="head" label="Head" className="w-30 h-30" acceptedTypes={['helmet']} />
                    </div>
                    {/* Face */}
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="face" label="Face" className="w-30 h-30" acceptedTypes={['mask']} />
                    </div>
                </div>

                {/* Center Gap (For Ped) */}
                <div className="flex-1 min-w-[200px] h-full" />

                {/* Right Column (Body/Earpiece) */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="armor" label="Armor" className="w-30 h-30" acceptedTypes={['armor']} />
                    </div>
                    {/* Earpiece */}
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="earpiece" label="Earpiece" className="w-30 h-30" acceptedTypes={['earpiece']} />
                    </div>
                </div>
            </div>

            {/* Bottom Section: Weapons & Hotbar (Vertical Stack) */}
            <div className="flex flex-row justify-between gap-2 mt-24 w-full">
                {/* Primary & Secondary */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="primary" label="Primary Weapon" className="w-62 h-30" acceptedTypes={['weapon_primary', 'weapon_secondary', 'weapon_smg', 'weapon_rifle', 'weapon_sniper', 'weapon_shotgun']} />
                    </div>
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="secondary" label="Secondary Weapon" className="w-62 h-30" acceptedTypes={['weapon_primary', 'weapon_secondary', 'weapon_smg', 'weapon_rifle', 'weapon_sniper', 'weapon_shotgun']} />
                    </div>
                </div>

                {/* Sidearm & Melee (Stacked Vertically) */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="holster" label="Holster" className="w-30 h-30" acceptedTypes={['weapon_pistol']} />
                    </div>
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="melee" label="Melee" className="w-30 h-30" acceptedTypes={['weapon_melee']} />
                    </div>
                </div>
            </div>

            {/* Virtual Hotbar Slots (5-8) - Bottom Row */}
            <div className="flex justify-start w-fit bg-black/60 p-1 gap-1">
                {['5', '6', '7', '8'].map(key => {
                    const itemName = shortcuts[key];
                    let item: any = null;

                    if (itemName) {
                        // Find item in Pockets or Vest
                        const playerContainer = containers['player-inv'];
                        const vestContainer = Object.values(containers).find(c => c.type === 'vest' && equipment?.vest?.name === c.id);

                        if (playerContainer) {
                            item = playerContainer.items.find((i: any) => i.name === itemName);
                        }
                        if (!item && vestContainer) {
                            item = vestContainer.items.find((i: any) => i.name === itemName);
                        }
                    }

                    return (
                        <div key={key} className="relative w-14 h-14 bg-black/40 border border-white/10 flex items-center justify-center">
                            <span className="absolute top-1 left-1 text-xs text-text-subtle font-bold z-10 pointer-events-none">{key}</span>
                            {item ? (
                                <div className="w-full h-full p-1 opacity-80 hover:opacity-100 transition-opacity">
                                    {item.image ? (
                                        <img src={item.image} alt={item.label} className="w-full h-full object-contain" />
                                    ) : (
                                        <span className="text-[10px] text-center w-full break-words">{item.label}</span>
                                    )}
                                    <span className="absolute bottom-0 right-0 p-0.5 text-[0.6rem] font-bold text-white bg-black/50">{item.count}</span>
                                </div>
                            ) : (
                                itemName && !item && <span className="text-red-500 text-xs">Missing</span> // Item assigned but not found
                            )}
                        </div>
                    );
                })}
            </div>
            <div className="flex justify-start w-full bg-black/60 p-1">
                <div className="flex justify-between w-full px-12 bg-black/40 p-6">
                    <span className="flex items-center gap-1 text-[#82BE64] font-medium">
                        <HeartPulse /> 0<span className='text-[#C2C2C0]'>/0</span>
                    </span>
                    <span className="flex items-center gap-1 text-[#EBBB5A] font-medium">
                        <Zap /> 0<span className='text-[#C2C2C0]'>/0</span>
                    </span>
                    <span className="flex items-center gap-1 text-[#78B7FA] font-medium">
                        <Droplets /> 0<span className='text-[#C2C2C0]'>/0</span>
                    </span>
                    <span className="flex items-center gap-1 text-[#8B918D] font-medium">
                        <Weight /> 0,0Kg
                    </span>
                </div>
            </div>
        </div>
    );
}; 

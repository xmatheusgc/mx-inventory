import React from 'react';
import { EquipmentSlot } from './EquipmentSlot';
import { Droplets, HeartPulse, Weight, Zap } from 'lucide-react';


export const EquipmentPanel: React.FC = () => {
    return (
        <div className="flex flex-col gap-2 p-4 rounded-lg min-w-[520px]">
            {/* Main Gear Section (Split for Ped) - Reduced Height */}
            <div className="flex justify-between items-start h-[280px] shrink-0">
                {/* Left Column (Head/Face) */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="head" label="Head" className="w-32 h-32" acceptedTypes={['helmet']} />
                    </div>
                    {/* Face */}
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="face" label="Face" className="w-32 h-32" acceptedTypes={['mask']} />
                    </div>
                </div>

                {/* Center Gap (For Ped) */}
                <div className="flex-1 min-w-[200px] h-full" />

                {/* Right Column (Body/Earpiece) */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="armor" label="Armor" className="w-32 h-32" acceptedTypes={['armor']} />
                    </div>
                    {/* Earpiece */}
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="earpiece" label="Earpiece" className="w-32 h-32" acceptedTypes={['earpiece']} />
                    </div>
                </div>
            </div>

            {/* Bottom Section: Weapons & Hotbar (Vertical Stack) */}
            <div className="flex flex-row justify-between gap-2 mt-24 w-full">
                {/* Primary & Secondary */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="primary" label="Primary Weapon" className="w-64 h-32" acceptedTypes={['weapon_primary', 'weapon_smg', 'weapon_rifle']} />
                    </div>
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="secondary" label="Secondary Weapon" className="w-64 h-32" acceptedTypes={['weapon_secondary', 'weapon_sniper', 'weapon_shotgun']} />
                    </div>
                </div>

                {/* Sidearm & Melee (Stacked Vertically) */}
                <div className="flex flex-col gap-2 bg-black/60 p-1">
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="pistol" label="Holster" className="w-32 h-32" acceptedTypes={['weapon_pistol']} />
                    </div>
                    <div className='bg-black/40'>
                        <EquipmentSlot slotId="melee" label="Melee" className="w-32 h-32" acceptedTypes={['weapon_melee']} />
                    </div>
                </div>
            </div>

            {/* Hotbar Slots (5-8) - Bottom Row */}
            <div className="flex justify-start w-fit bg-black/60 p-1 gap-1">
                {[5, 6, 7, 8].map(num => (
                    <div key={num} className="bg-black/40">
                        <EquipmentSlot
                            slotId={String(num)}
                            label=""
                            className="w-14 h-14"
                            acceptedTypes={[]} // Accept all (or handled by logic)
                        >
                            <span className="absolute top-1 left-1 text-xs text-text-subtle font-bold z-10 pointer-events-none">{num}</span>
                        </EquipmentSlot>
                    </div>
                ))}
            </div>
            <div className="flex justify-start w-full bg-black/60 p-1">
                <div className="flex justify-between w-full px-12 bg-black/40 p-6">
                    <span className="flex items-center gap-1 text-success "><HeartPulse /> 0/0</span>
                    <span className="flex items-center gap-1 text-yellow-500"><Zap /> 0/0</span>
                    <span className="flex items-center gap-1 text-blue-500"><Droplets /> 0/0</span>
                    <span className="flex items-center gap-1 text-text-subtle"><Weight /> 0,0Kg</span>
                </div>
            </div>
        </div>
    );
}; 

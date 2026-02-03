import React from 'react';
import { EquipmentSlot } from './EquipmentSlot';


export const EquipmentPanel: React.FC = () => {
    return (
        <div className="flex flex-col gap-4 p-4 bg-zinc-900/50 rounded-lg min-w-[520px]">
            <h2 className="text-zinc-400 text-sm font-bold uppercase tracking-wider mb-2 border-b border-zinc-700 pb-2">Equipment</h2>

            {/* Top Section: Gear (Squares) */}
            <div className="flex gap-4">
                <div className="flex flex-col gap-4 items-start">
                    <EquipmentSlot slotId="head" label="Headwear" acceptedTypes={['helmet']} className="w-30 h-30" />
                    <EquipmentSlot slotId="armor" label="Body Armor" acceptedTypes={['armor']} className="w-30 h-30" />
                </div>

                {/* Holster / Sidearm (Square as requested) */}
                <div className="flex flex-col gap-4 justify-end items-start">
                    <EquipmentSlot slotId="pistol" label="Sidearm" acceptedTypes={['weapon_pistol']} className="w-30 h-30" />
                </div>
            </div>

            {/* Weapons Section (Rectangles) */}
            <div className="flex flex-col gap-3 mt-4 items-start">
                <EquipmentSlot slotId="primary" label="Primary Weapon" acceptedTypes={['weapon_primary']} className="w-64 h-30" />
                <EquipmentSlot slotId="secondary" label="Secondary" acceptedTypes={['weapon_secondary']} className="w-64 h-30" />
                <EquipmentSlot slotId="melee" label="Melee" acceptedTypes={['weapon_melee']} className="w-30 h-30" />
            </div>
        </div>
    );
};

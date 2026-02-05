import React from 'react';
import { EquipmentSlot } from './EquipmentSlot';


export const EquipmentPanel: React.FC = () => {
    return (
        <div className="flex flex-col gap-4 p-4 rounded-lg min-w-[520px]">
            {/* Top Section: Gear (Squares) */}
            <div className="flex gap-4">
                <div className="flex flex-col gap-4 items-start">
                    <EquipmentSlot slotId="head" label="Headwear" acceptedTypes={['helmet']} className="w-32 h-32" />
                    <EquipmentSlot slotId="armor" label="Body Armor" acceptedTypes={['armor']} className="w-32 h-32" />
                </div>

                <div className="flex flex-col gap-4 items-start">
                    <EquipmentSlot slotId="head" label="Headwear" acceptedTypes={['helmet']} className="w-32 h-32" />
                    <EquipmentSlot slotId="armor" label="Body Armor" acceptedTypes={['armor']} className="w-32 h-32" />
                </div>

                {/* Holster / Sidearm */}
                <div className="flex flex-col gap-4 justify-end items-start">
                    <EquipmentSlot slotId="pistol" label="Sidearm" acceptedTypes={['weapon_pistol']} className="w-32 h-32" />
                </div>
            </div>

            {/* Weapons Section (Rectangles) */}
            <div className="flex flex-col gap-3 mt-4 items-start">
                <EquipmentSlot slotId="primary" label="Primary Weapon" acceptedTypes={['weapon_primary']} className="w-full h-32" />
                <EquipmentSlot slotId="secondary" label="Secondary" acceptedTypes={['weapon_secondary']} className="w-full h-32" />
                <div className="flex gap-4">
                    <EquipmentSlot slotId="melee" label="Melee" acceptedTypes={['weapon_melee']} className="w-32 h-32" />
                </div>
            </div>
        </div>
    );
};

Config = {}

Config.Debug = true

Config.Framework = 'standalone' -- 'qb', 'esx', 'standalone'

-- Inventory Configuration
Config.Inventory = {
    Slots = { width = 6, height = 3 }, -- Player Main Inventory
    MaxWeight = 40.0,                  -- kg
    DefaultDropProp = 'prop_box_pile_06a',
    DropDistance = 1.6,                -- metres
    Animations = {
        Drop = { dict = 'mp_common_ai_returnack', anim = 'returnack_part_1' },
        Pickup = { dict = 'pickup_object', anim = 'pickup_low' }
    },
    DropDespawnTime = 30 -- Minutes until items disappear
}

-- Item Definitions
-- Item Definitions are now in data/items.lua

-- Equipment Slot Mapping (Restrict items to specific slots)
Config.EquipmentSlots = {
    ['primary'] = { 'weapon_primary', 'weapon_secondary', 'weapon_smg', 'weapon_rifle', 'weapon_sniper', 'weapon_shotgun' },
    ['secondary'] = { 'weapon_primary', 'weapon_secondary', 'weapon_smg', 'weapon_rifle', 'weapon_sniper', 'weapon_shotgun' },
    ['holster'] = { 'weapon_pistol' },
    ['melee'] = { 'weapon_melee' },
    ['head'] = { 'helmet' },
    ['face'] = { 'mask' },
    ['armor'] = { 'armor' },
    ['earpiece'] = { 'earpiece' },
    ['vest'] = { 'vest' },
    ['backpack'] = { 'backpack', 'bag' },
}

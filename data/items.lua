Items = {
    ['water'] = {
        label = "Water Bottle",
        weight = 0.5,
        size = { x = 1, y = 2 },
        type = "generic",
        image = "water.png",
        consume = {
            type = "drink", -- drink or eat
            animDict = "mp_player_intdrink",
            anim = "loop_bottle",
            prop = "prop_ld_flow_bottle",
            status = { thirst = 25 }
        }
    },
    ['bread'] = {
        label = "Bread",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "bread.png",
        consume = {
            type = "eat",
            animDict = "mp_player_inteat@burger",
            anim = "mp_player_int_eat_burger_fp",
            prop = "prop_sandwich_01",
            status = { hunger = 25 }
        }
    },
    ['pistol'] = {
        label = "Pistol",
        weight = 1.5,
        size = { x = 2, y = 1 },
        type = "weapon_pistol",
        image = "pistol.png",
        equipment = {
            weaponHash = "WEAPON_PISTOL",
            ammoType = "AMMO_PISTOL"
        }
    },
    ['rifle'] = {
        label = "Assault Rifle",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_rifle",
        image = "rifle.png",
        equipment = {
            weaponHash = "WEAPON_ASSAULTRIFLE",
            ammoType = "AMMO_RIFLE"
        }
    },
    ['shotgun'] = {
        label = "Pump Shotgun",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_shotgun",
        image = "shotgun.png",
        equipment = {
            weaponHash = "WEAPON_PUMPSHOTGUN",
            ammoType = "AMMO_SHOTGUN"
        }
    },
    ['medkit'] = {
        label = "Medkit",
        weight = 0.5,
        size = { x = 2, y = 2 },
        type = "generic",
        image = "medkit.png"
    },
    ['knife'] = {
        label = "Combat Knife",
        weight = 0.3,
        size = { x = 1, y = 3 },
        type = "weapon_melee",
        image = "knife.png",
        equipment = {
            weaponHash = "WEAPON_KNIFE"
        }
    },
    ['helmet'] = {
        label = "KSS Tactical Helmet",
        weight = 0.8,
        size = { x = 2, y = 2 },
        type = "helmet",
        image = "helmet.png",
        equipment = {
            componentId = 0,  -- Head
            drawableId = 120, -- Example ID
            textureId = 0
        }
    },
    ['armor'] = {
        label = "Heavy Armor",
        weight = 3.5,
        size = { x = 3, y = 3 },
        type = "armor",
        image = "armor.png",
        equipment = {
            componentId = 9, -- Kevlar/Vest
            drawableId = 15, -- Example ID
            textureId = 0
        }
    },
    -- New Definitions for Mock Items
    ['rig_st_tipo_4'] = {
        label = "ST Tipo 4",
        weight = 1.2,
        size = { x = 3, y = 3 },
        type = "vest",
        image = "vest_t4.png", -- Ensure this image exists
        equipment = {
            componentId = 9,   -- Vest/Task
            drawableId = 20,   -- Example Vest
            textureId = 1
        }
    },
    ['mochila_tatica_expansivel_luc'] = {
        label = "Mochila Tática Expansível Luc",
        weight = 1.0,
        size = { x = 4, y = 5 },
        type = "backpack",
        image = "backpack_luc.png", -- Ensure this image exists
        equipment = {
            componentId = 5,        -- Bag/Parachute
            drawableId = 45,        -- Example Bag
            textureId = 0
        }
    }
}

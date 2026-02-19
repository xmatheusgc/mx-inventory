Items = {
    -- ============================================================
    -- CONSUMABLES
    -- ============================================================
    ['water'] = {
        label = "Water Bottle",
        weight = 0.5,
        size = { x = 1, y = 2 },
        type = "generic",
        image = "water.png",
        consume = {
            type = "drink",
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
    ['medkit'] = {
        label = "Medkit",
        weight = 0.5,
        size = { x = 2, y = 2 },
        type = "generic",
        image = "medkit.png"
    },

    -- ============================================================
    -- WEAPONS (with caliber system)
    -- ============================================================

    -- 9x19mm family
    ['pistol'] = {
        label = "Pistol",
        weight = 1.5,
        size = { x = 2, y = 1 },
        type = "weapon_pistol",
        image = "pistol.png",
        equipment = {
            weaponHash = "WEAPON_PISTOL",
            caliber = "9x19mm",
            defaultMagCapacity = 12,
        }
    },

    -- 5.56x45mm family
    ['rifle'] = {
        label = "Assault Rifle",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_rifle",
        image = "rifle.png",
        equipment = {
            weaponHash = "WEAPON_ASSAULTRIFLE",
            caliber = "5.56x45",
            defaultMagCapacity = 30,
        }
    },

    -- 12 Gauge family
    ['shotgun'] = {
        label = "Pump Shotgun",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_shotgun",
        image = "shotgun.png",
        equipment = {
            weaponHash = "WEAPON_PUMPSHOTGUN",
            caliber = "12gauge",
            defaultMagCapacity = 8,
        }
    },

    -- Melee (no caliber)
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

    -- ============================================================
    -- MAGAZINES
    -- ============================================================

    -- 9x19mm magazines
    ['mag_pistol_12'] = {
        label = "Pistol Mag (12rnd)",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "magazine",
        image = "mag_pistol.png",
        magazine = {
            caliber = "9x19mm",
            capacity = 12,
        }
    },
    ['mag_pistol_ext_17'] = {
        label = "Extended Pistol Mag (17rnd)",
        weight = 0.25,
        size = { x = 1, y = 1 },
        type = "magazine",
        image = "mag_pistol_ext.png",
        magazine = {
            caliber = "9x19mm",
            capacity = 17,
        }
    },

    -- 5.56x45mm magazines
    ['mag_stanag_30'] = {
        label = "STANAG 30rnd",
        weight = 0.4,
        size = { x = 1, y = 2 },
        type = "magazine",
        image = "mag_stanag.png",
        magazine = {
            caliber = "5.56x45",
            capacity = 30,
        }
    },

    -- 12 Gauge magazines (tube/internal)
    ['mag_shotgun_8'] = {
        label = "Shotgun Shell Tube (8rnd)",
        weight = 0.3,
        size = { x = 1, y = 2 },
        type = "magazine",
        image = "mag_shotgun.png",
        magazine = {
            caliber = "12gauge",
            capacity = 8,
        }
    },

    -- ============================================================
    -- AMMUNITION (stackable, max 60)
    -- ============================================================
    ['ammo_9mm'] = {
        label = "9x19mm",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo_9mm.png",
        stackable = true,
        maxStack = 60,
        ammo = {
            caliber = "9x19mm",
        }
    },
    ['ammo_556'] = {
        label = "5.56x45mm",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo_556.png",
        stackable = true,
        maxStack = 60,
        ammo = {
            caliber = "5.56x45",
        }
    },
    ['ammo_12gauge'] = {
        label = "12 Gauge Shell",
        weight = 0.03,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo_12gauge.png",
        stackable = true,
        maxStack = 60,
        ammo = {
            caliber = "12gauge",
        }
    },

    -- ============================================================
    -- GEAR / CLOTHING
    -- ============================================================
    ['helmet'] = {
        label = "KSS Tactical Helmet",
        weight = 0.8,
        size = { x = 2, y = 2 },
        type = "helmet",
        image = "helmet.png",
        equipment = {
            componentId = 0,
            drawableId = 120,
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
            componentId = 9,
            drawableId = 15,
            textureId = 0
        }
    },
    ['rig_st_tipo_4'] = {
        label = "ST Tipo 4",
        weight = 1.2,
        size = { x = 3, y = 3 },
        type = "vest",
        image = "vest_t4.png",
        equipment = {
            componentId = 9,
            drawableId = 20,
            textureId = 1
        },
        container = {
            size = { width = 4, height = 10 },
            maxWeight = 10.0
        }
    },
    ['mochila_tatica_expansivel_luc'] = {
        label = "Mochila Tática Expansível Luc",
        weight = 1.0,
        size = { x = 4, y = 5 },
        type = "backpack",
        image = "backpack_luc.png",
        equipment = {
            componentId = 5,
            drawableId = 45,
            textureId = 0
        },
        container = {
            size = { width = 5, height = 10 },
            maxWeight = 20.0
        }
    }
}

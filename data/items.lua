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
        dropProp = "prop_ld_flow_bottle",
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
        image = "WEAPON_BREAD.PNG",
        dropProp = "prop_sandwich_01",
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
        image = "medikit.png"
    },

    -- ============================================================
    -- WEAPONS (with caliber system)
    -- ============================================================

    -- 9x19mm family
    ['w_pi_pistol'] = {
        label = "M9 Pistol",
        weight = 1.5,
        size = { x = 2, y = 1 },
        type = "weapon_pistol",
        image = "WEAPON_PISTOL.png",
        dropProp = "w_pi_pistol",
        equipment = {
            weaponHash = "WEAPON_PISTOL",
            caliber = "ammo_9x19",
            defaultMagCapacity = 15,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_PI_SUPP_02" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_PI_FLSH" },
            }
        }
    },

    -- 5.45x39mm family
    ['w_ar_assaultrifle'] = {
        label = "AK74N",
        weight = 3.4,
        size = { x = 4, y = 2 },
        type = "weapon_rifle",
        image = "WEAPON_ASSAULTRIFLE.png",
        dropProp = "w_ar_assaultrifle",
        equipment = {
            weaponHash = "WEAPON_ASSAULTRIFLE",
            caliber = "ammo_545x39",
            defaultMagCapacity = 30,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_AR_SUPP_02" },
                scope  = { label = "Scope", componentHash = "COMPONENT_AT_SCOPE_MACRO_02" },
                grip   = { label = "Grip", componentHash = "COMPONENT_AT_AR_AFGRIP" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_AR_FLSH" },
            }
        }
    },

    -- 5.56x45mm family
    ['w_ar_specialcarbine'] = {
        label = "IA2",
        weight = 3.2,
        size = { x = 4, y = 2 },
        type = "weapon_rifle",
        image = "WEAPON_SPECIALCARBINE.png",
        dropProp = "w_ar_specialcarbine",
        equipment = {
            weaponHash = "WEAPON_SPECIALCARBINE",
            caliber = "ammo_556x45",
            defaultMagCapacity = 30,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_AR_SUPP_02" },
                scope  = { label = "Scope", componentHash = "COMPONENT_AT_SCOPE_MACRO_02" },
                grip   = { label = "Grip", componentHash = "COMPONENT_AT_AR_AFGRIP" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_AR_FLSH" },
            }
        }
    },

    -- 7.62x51mm family
    ['w_sl_battlerifle_m32'] = {
        label = "ParaFAL",
        weight = 4.0,
        size = { x = 4, y = 2 },
        type = "weapon_rifle",
        image = "WEAPON_HEAVYRIFLE.png",
        dropProp = "w_sl_battlerifle_m32",
        equipment = {
            weaponHash = "WEAPON_BATTLERIFLE",
            caliber = "ammo_762x51",
            defaultMagCapacity = 20,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_AR_SUPP_02" },
                scope  = { label = "Scope", componentHash = "COMPONENT_AT_SCOPE_MACRO_02" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_AR_FLSH" },
            }
        }
    },

    -- 12 Gauge family
    ['shotgun'] = {
        label = "Pump Shotgun",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_shotgun",
        image = "WEAPON_PUMPSHOTGUN.png",
        dropProp = "w_sg_pumpshotgun",
        equipment = {
            weaponHash = "WEAPON_PUMPSHOTGUN",
            caliber = "ammo_12gauge",
            defaultMagCapacity = 8,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_SR_SUPP" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_AR_FLSH" },
            }
        }
    },

    -- Melee (no caliber)
    ['knife'] = {
        label = "Combat Knife",
        weight = 0.3,
        size = { x = 1, y = 3 },
        type = "weapon_melee",
        image = "WEAPON_KNIFE.png",
        equipment = {
            weaponHash = "WEAPON_KNIFE"
        }
    },

    -- ============================================================
    -- AMMUNITION (stackable, max 150)
    -- ============================================================
    ['ammo_9x19'] = {
        label = "9x19mm Parabellum",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo-9.png",
        dropProp = "prop_ld_ammo_pack_01",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_9x19",
        }
    },
    ['ammo_545x39'] = {
        label = "5.45x39mm Soviet",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo-rifle2.png",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_545x39",
        }
    },
    ['ammo_556x45'] = {
        label = "5.56x45mm NATO",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo-rifle.png",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_556x45",
        }
    },
    ['ammo_762x51'] = {
        label = "7.62x51mm NATO",
        weight = 0.02,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "rifle_ammo.png",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_762x51",
        }
    },
    ['ammo_12gauge'] = {
        label = "12 Gauge Shell",
        weight = 0.03,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo-shotgun.png",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_12gauge",
        }
    },

    -- ============================================================
    -- WEAPON ATTACHMENTS
    -- ============================================================
    ['suppressor_9x19'] = {
        label = "Suppressor 9x19mm",
        weight = 0.3,
        size = { x = 2, y = 1 },
        type = "attachment_muzzle",
        image = "suppressor_attachment.png",
        attachment = {
            slot = "muzzle",
            caliber = "ammo_9x19",
            componentHash = "COMPONENT_AT_PI_SUPP_02",
        }
    },
    ['suppressor_545x39'] = {
        label = "Suppressor 545x39mm",
        weight = 0.4,
        size = { x = 2, y = 1 },
        type = "attachment_muzzle",
        image = "suppressor_attachment.png",
        attachment = {
            slot = "muzzle",
            caliber = "ammo_545x39",
            componentHash = "COMPONENT_AT_AR_SUPP_02",
        }
    },
    ['suppressor_556x45'] = {
        label = "Suppressor 556x45mm",
        weight = 0.4,
        size = { x = 2, y = 1 },
        type = "attachment_muzzle",
        image = "suppressor_attachment.png",
        attachment = {
            slot = "muzzle",
            caliber = "ammo_556x45",
            componentHash = "COMPONENT_AT_AR_SUPP_02",
        }
    },
    ['suppressor_762x51'] = {
        label = "Suppressor 762x51mm",
        weight = 0.5,
        size = { x = 2, y = 1 },
        type = "attachment_muzzle",
        image = "suppressor_attachment.png",
        attachment = {
            slot = "muzzle",
            caliber = "ammo_762x51",
            componentHash = "COMPONENT_AT_AR_SUPP",
        }
    },
    ['flashlight'] = {
        label = "Tactical Flashlight",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "attachment_scope",
        image = "at_flashlight.png",
        attachment = {
            slot = "flashlight",
            componentHash = "", -- Unified system will resolve from weapon
        }
    },
    ['scope_holo'] = {
        label = "Holographic Sight",
        weight = 0.3,
        size = { x = 1, y = 1 },
        type = "attachment_scope",
        image = "at_scope_holo.png",
        attachment = {
            slot = "scope",
            componentHash = "COMPONENT_AT_SCOPE_MACRO_02",
        }
    },
    ['grip_vertical'] = {
        label = "Vertical Grip",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "attachment_grip",
        image = "at_grip.png",
        attachment = {
            slot = "grip",
            componentHash = "COMPONENT_AT_AR_AFGRIP",
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
        image = "binoculars.png",
        equipment = {
            propId = 0,       -- head prop slot 0 (SetPedPropIndex)
            drawableId = 150, -- base: no accessories
            textureId = 0,
            -- Accessory slots: list of slot IDs this helmet can mount
            supportedAccessories = { 'visor' },
            -- Per-item drawable IDs depending on visor state
            accessoryDrawables = {
                nvg             = {
                    visorDown = 116,
                    visorUp = 117,
                    animDict = 'anim@mp_helmets@on_foot',
                    animUp = 'goggles_up', --visor_up or goggles_up
                    animDown = 'goggles_down' --visor_down or goggles_down
                },
                thermal_monocle = {
                    visorDown = 118,
                    visorUp = 119,
                    animDict = 'anim@mp_helmets@on_foot',
                    animUp = 'goggles_up', --visor_up or goggles_up
                    animDown = 'goggles_down' --visor_down or goggles_down
                },
            }
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

    -- ============================================================
    -- HELMET ACCESSORIES
    -- ============================================================
    ['nvg'] = {
        label = "Night Vision Goggles",
        weight = 0.3,
        size = { x = 1, y = 1 },
        type = "helmet_accessory",
        image = "nvscope_attachment.png",
        helmetAccessory = { slot = 'visor' }
    },
    ['thermal_monocle'] = {
        label = "Thermal Monocle",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "helmet_accessory",
        image = "thermalscope_attachment.png",
        helmetAccessory = { slot = 'visor' }
    },
    ['rig_st_tipo_4'] = {
        label        = "ST Tipo 4",
        weight       = 1.2,
        size         = { x = 3, y = 3 },
        expandedSize = { x = 3, y = 3 },
        foldedSize   = { x = 2, y = 2 },
        type         = "vest",
        image        = "armor.png",
        equipment    = {
            componentId = 7,
            drawableId = 148,
            textureId = 14
        },
        container    = {
            size = { width = 4, height = 10 },
            maxWeight = 10.0,
            layout = 'rig_st_tipo_4'
        }
    },
    ['mochila_tatica_expansivel_luc'] = {
        label        = "Mochila Tática Expansível Luc",
        weight       = 1.0,
        size         = { x = 4, y = 5 },
        expandedSize = { x = 4, y = 5 },
        foldedSize   = { x = 2, y = 2 },
        type         = "backpack",
        image        = "parachute.png",
        equipment    = {
            componentId = 5,
            drawableId = 45,
            textureId = 0
        },
        container    = {
            size = { width = 5, height = 10 },
            maxWeight = 20.0,
            layout = 'mochila_tatica_expansivel_luc'
        }
    },

    -- ============================================================
    -- MEDICAL / SURVIVAL ITEMS (used by mx-survival-core)
    -- ============================================================
    ['bandage'] = {
        label = "Bandage",
        weight = 0.1,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "bandage.png",
        stackable = true,
        maxStack = 10,
        consume = {
            type = "medical",
            animDict = "anim@heists@narcotics@funding@gang_idle",
            anim = "gang_idle_plastering",
            status = {}
        }
    },
    ['suture_kit'] = {
        label = "Suture Kit",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "advancedkit.png",
        consume = {
            type = "medical",
            animDict = "anim@heists@narcotics@funding@gang_idle",
            anim = "gang_idle_plastering",
            status = {}
        }
    },
    ['antiseptic'] = {
        label = "Antiseptic",
        weight = 0.15,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "acetone.png",
        stackable = true,
        maxStack = 5,
        consume = {
            type = "medical",
            animDict = "anim@heists@narcotics@funding@gang_idle",
            anim = "gang_idle_plastering",
            status = {}
        }
    },
    ['antibiotics'] = {
        label = "Antibiotics",
        weight = 0.05,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "oxy.png",
        stackable = true,
        maxStack = 5,
        consume = {
            type = "medical",
            animDict = "mp_player_intdrink",
            anim = "loop_bottle",
            status = {}
        }
    },
    ['painkillers'] = {
        label = "Painkillers",
        weight = 0.05,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "painkillers.png",
        stackable = true,
        maxStack = 10,
        consume = {
            type = "medical",
            animDict = "mp_player_intdrink",
            anim = "loop_bottle",
            status = {}
        }
    },
    ['dirty_water'] = {
        label = "Dirty Water",
        weight = 0.5,
        size = { x = 1, y = 2 },
        type = "generic",
        image = "water_bottle.png",
        consume = {
            type = "drink",
            animDict = "mp_player_intdrink",
            anim = "loop_bottle",
            prop = "prop_ld_flow_bottle",
            status = { thirst = 20 }
        }
    },
    ['canned_food'] = {
        label = "Canned Food",
        weight = 0.4,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "burger.png",
        consume = {
            type = "eat",
            animDict = "mp_player_inteat@burger",
            anim = "mp_player_int_eat_burger_fp",
            status = { hunger = 30 }
        }
    },
    ['raw_meat'] = {
        label = "Raw Meat",
        weight = 0.5,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "sandwich.png",
        consume = {
            type = "eat",
            animDict = "mp_player_inteat@burger",
            anim = "mp_player_int_eat_burger_fp",
            status = { hunger = 35 }
        }
    },
    ['cooked_meat'] = {
        label = "Cooked Meat",
        weight = 0.4,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "tosti.png",
        consume = {
            type = "eat",
            animDict = "mp_player_inteat@burger",
            anim = "mp_player_int_eat_burger_fp",
            status = { hunger = 40 }
        }
    },
}

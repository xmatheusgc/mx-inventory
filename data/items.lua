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
        image = "bread.png",
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
        dropProp = "w_pi_pistol",
        equipment = {
            weaponHash = "WEAPON_PISTOL",
            caliber = "ammo_9mm",
            defaultMagCapacity = 12,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_PI_SUPP_02" },
                scope  = { label = "Scope", componentHash = "" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_PI_FLSH" },
            }
        }
    },

    -- 5.56x45mm family
    ['rifle'] = {
        label = "Assault Rifle",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_rifle",
        image = "rifle.png",
        dropProp = "w_ar_assaultrifle",
        equipment = {
            weaponHash = "WEAPON_ASSAULTRIFLE",
            caliber = "ammo_556",
            defaultMagCapacity = 30,
            supportedAttachments = {
                muzzle = { label = "Muzzle", componentHash = "COMPONENT_AT_AR_SUPP_02" },
                scope  = { label = "Scope", componentHash = "COMPONENT_AT_SCOPE_MACRO_02" },
                grip   = { label = "Grip", componentHash = "COMPONENT_AT_AR_AFGRIP" },
                flashlight = { label = "Flashlight", componentHash = "COMPONENT_AT_AR_FLSH" },
                skin   = { label = "Skin", componentHash = "" },
            }
        }
    },

    -- 12 Gauge family
    ['shotgun'] = {
        label = "Pump Shotgun",
        weight = 3.5,
        size = { x = 4, y = 2 },
        type = "weapon_shotgun",
        image = "shotgun.png",
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
        image = "knife.png",
        equipment = {
            weaponHash = "WEAPON_KNIFE"
        }
    },

    -- ============================================================
    -- AMMUNITION (stackable, max 150)
    -- ============================================================
    ['ammo_9mm'] = {
        label = "9x19mm",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo_9mm.png",
        dropProp = "prop_ld_ammo_pack_01",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_9mm",
        }
    },
    ['ammo_556'] = {
        label = "5.56x45mm",
        weight = 0.01,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo_556.png",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_556",
        }
    },
    ['ammo_12gauge'] = {
        label = "12 Gauge Shell",
        weight = 0.03,
        size = { x = 1, y = 1 },
        type = "ammo",
        image = "ammo_12gauge.png",
        stackable = true,
        maxStack = 150,
        ammo = {
            caliber = "ammo_12gauge",
        }
    },

    -- ============================================================
    -- WEAPON ATTACHMENTS
    -- ============================================================
    ['suppressor_pistol'] = {
        label = "Pistol Suppressor",
        weight = 0.3,
        size = { x = 2, y = 1 },
        type = "attachment_muzzle",
        image = "suppressor.png",
        attachment = {
            slot = "muzzle",
            componentHash = "COMPONENT_AT_PI_SUPP_02",
        }
    },
    ['suppressor_rifle'] = {
        label = "Rifle Suppressor",
        weight = 0.4,
        size = { x = 2, y = 1 },
        type = "attachment_muzzle",
        image = "suppressor_rifle.png",
        attachment = {
            slot = "muzzle",
            componentHash = "COMPONENT_AT_AR_SUPP_02",
        }
    },
    ['flashlight'] = {
        label = "Tactical Flashlight",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "attachment_scope",
        image = "flashlight.png",
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
        image = "scope_holo.png",
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
        image = "grip.png",
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
        image = "helmet.png",
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
        image = "nvg.png",
        helmetAccessory = { slot = 'visor' }
    },
    ['thermal_monocle'] = {
        label = "Thermal Monocle",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "helmet_accessory",
        image = "thermal.png",
        helmetAccessory = { slot = 'visor' }
    },
    ['rig_st_tipo_4'] = {
        label        = "ST Tipo 4",
        weight       = 1.2,
        size         = { x = 3, y = 3 },
        expandedSize = { x = 3, y = 3 },
        foldedSize   = { x = 2, y = 2 },
        type         = "vest",
        image        = "vest_t4.png",
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
        image        = "backpack_luc.png",
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
    }
}

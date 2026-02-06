Config = {}

Config.Debug = true

-- Inventory Configuration
Config.Inventory = {
    Slots = { width = 6, height = 3 }, -- Player Main Inventory
    MaxWeight = 40.0                   -- kg
}

-- Item Definitions
Config.Items = {
    ['water'] = {
        label = "Water Bottle",
        weight = 0.5,
        size = { x = 1, y = 2 },
        type = "generic",
        image = "water.png"
    },
    ['bread'] = {
        label = "Bread",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "generic",
        image = "bread.png"
    },
    ['pistol'] = {
        label = "Pistol",
        weight = 1.5,
        size = { x = 2, y = 2 },
        type = "weapon_pistol",
        image = "pistol.png"
    },
    ['rifle'] = {
        label = "Assault Rifle",
        weight = 3.5,
        size = { x = 4, y = 2 }, -- Adjusted size to realistic rifle
        type = "weapon_primary",
        image = "rifle.png"
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
        image = "knife.png"
    },
    ['helmet'] = {
        label = "KSS Tactical Helmet",
        weight = 0.8,
        size = { x = 2, y = 2 },
        type = "helmet",
        image = "helmet.png"
    },
    ['armor'] = {
        label = "Heavy Armor",
        weight = 3.5,
        size = { x = 3, y = 3 },
        type = "armor",
        image = "armor.png"
    }
}

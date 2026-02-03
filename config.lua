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
        type = "item",
        image = "water.png"
    },
    ['bread'] = {
        label = "Bread",
        weight = 0.2,
        size = { x = 1, y = 1 },
        type = "item",
        image = "bread.png"
    },
    ['pistol'] = {
        label = "Pistol",
        weight = 1.5,
        size = { x = 2, y = 2 },
        type = "weapon",
        image = "pistol.png"
    },
    ['rifle'] = {
        label = "Assault Rifle",
        weight = 3.5,
        size = { x = 2, y = 5 },
        type = "weapon",
        image = "rifle.png"
    },
    ['medkit'] = {
        label = "Medkit",
        weight = 0.5,
        size = { x = 2, y = 2 },
        type = "item",
        image = "medkit.png"
    },
    ['knife'] = {
        label = "Combat Knife",
        weight = 0.3,
        size = { x = 1, y = 3 },
        type = "weapon",
        image = "knife.png"
    }
}

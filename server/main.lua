local ItemDefs = Config.Items
-- DB is global now (loaded from server/db.lua)

-- Initialize Database
Citizen.CreateThread(function()
    DB.Init()
end)

-- Helper: Calculate Weight
local function GetContainerWeight(items)
    local total = 0.0
    for _, item in ipairs(items) do
        local def = ItemDefs[item.name]
        if def and def.weight then
            total = total + (def.weight * item.count)
        end
    end
    return total
end

local Inventory = {}

-- Load Player Data
local function LoadPlayer(src)
    -- Use direct global call instead of export to avoid potential deadlocks/overhead
    local player = MX_GetPlayer(src)
    if not player then return end

    if not Inventory[src] then
        local dbData = DB.LoadPlayer(player.identifier)
        if not dbData or #dbData == 0 then
            -- Starter Kit
            Inventory[src] = {
                player = {
                    { name = 'water', count = 1, slot = { x = 1, y = 1 } },
                    { name = 'bread', count = 2, slot = { x = 2, y = 1 } }
                }
            }
        else
            Inventory[src] = { player = dbData }
        end
        print('^2[mx-inv] Loaded inventory for ' .. player.name .. '^0')
    end
end

-- Event: Player Joining
AddEventHandler('playerJoining', function()
    local src = source
    Citizen.CreateThread(function()
        -- Wait for DB to be ready
        while not DB.Ready do Wait(100) end
        LoadPlayer(src)
    end)
end)

-- Event: Resource Start (Load existing players)
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Citizen.CreateThread(function()
        while not DB.Ready do Wait(100) end
        local players = GetPlayers()
        for _, src in ipairs(players) do
            LoadPlayer(tonumber(src))
        end
    end)
end)

-- Open Inventory (Now instant)
RegisterNetEvent('mx-inv:server:openInventory', function()
    local src = source
    if not Inventory[src] then
        -- Try to load if missing (failsafe)
        LoadPlayer(src)
        if not Inventory[src] then return end
    end

    local containers = Inventory[src]
    local playerData = {
        id = 'player-inv',
        type = 'player',
        label = 'Player Inventory',
        size = Config.Inventory.Slots,
        items = containers.player or {},
        maxWeight = Config.Inventory.MaxWeight,
        weight = GetContainerWeight(containers.player or {})
    }

    -- Secondary Container (Test Backpack)
    local backpackData = {
        id = 'backpack-1',
        type = 'bag',
        label = 'Large Backpack',
        size = { width = 6, height = 5 },
        items = {},
        maxWeight = 20.0,
        weight = 0
    }

    TriggerClientEvent('mx-inv:client:openInventory', src, {
        player = playerData,
        secondary = backpackData,
        itemDefs = ItemDefs
    })
end)

-- Save on Drop
AddEventHandler('playerDropped', function(reason)
    local src = source
    if Inventory[src] then
        local player = exports['mx-inv']:GetPlayer(src)
        if player then
            DB.SavePlayer(player.identifier, Inventory[src].player)
            print('^2[mx-inv] Saved inventory for ' .. player.name .. '^0')
        end
        Inventory[src] = nil
    end
end)

RegisterNetEvent('mx-inv:server:moveItem', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local itemName = data.item
    local fromId = data.from
    local toId = data.to
    local targetSlot = data.slot

    local function GetItems(id)
        if id == 'player-inv' then return containerMap.player end
        return nil
    end

    local fromItems = GetItems(fromId)
    local toItems = GetItems(toId)

    if not fromItems or not toItems then return end

    -- Find Item
    local itemIndex = nil
    for i, item in ipairs(fromItems) do
        if item.name == itemName then
            itemIndex = i
            break
        end
    end

    if not itemIndex then return end
    local item = fromItems[itemIndex]

    -- Move Logic
    table.remove(fromItems, itemIndex)
    item.slot = targetSlot
    table.insert(toItems, item)

    -- Auto-Save
    local player = exports['mx-inv']:GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap.player)
    end
end)

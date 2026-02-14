local ItemDefs = Items -- data/items.lua loaded via fxmanifest

-- DB is global now (loaded from server/db.lua)

-- Initialize Database
Citizen.CreateThread(function()
    DB.Init()
end)

local Inventory = {}

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

-- Helper: Add Item to Player
local function AddItem(src, item, count)
    if not Inventory[src] then return false, "Inventory not loaded" end
    local def = ItemDefs[item]
    if not def then return false, "Invalid item" end

    local container = Inventory[src].player

    -- Find existing stack or empty slot
    local slot = nil

    -- Check for stacking (if generic/stackable)
    for _, invItem in ipairs(container) do
        if invItem.name == item then
            invItem.count = invItem.count + count
            return true, "Stacked"
        end
    end

    -- Find empty slot
    local takenSlots = {}
    for _, invItem in ipairs(container) do
        takenSlots[invItem.slot.x .. '-' .. invItem.slot.y] = true
    end

    for y = 1, Config.Inventory.Slots.height do
        for x = 1, Config.Inventory.Slots.width do
            if not takenSlots[x .. '-' .. y] then
                table.insert(container, {
                    name = item,
                    count = count,
                    slot = { x = x, y = y }
                })
                return true, "Added to slot " .. x .. "," .. y
            end
        end
    end

    return false, "Inventory full"
end

-- Load Player Data
local function LoadPlayer(src)
    -- Use direct global call instead of export to avoid potential deadlocks/overhead
    local player = MX_GetPlayer(src)
    if not player then return end

    if not Inventory[src] then
        local dbData = DB.LoadPlayer(player.identifier)

        Inventory[src] = {}

        if not dbData then
            -- Fresh Spawn
            Inventory[src].player = {}
        elseif dbData.player then
            -- New Format (Object)
            Inventory[src] = dbData
        else
            -- Old Format (Array)
            Inventory[src].player = dbData
        end

        -- Initialize/Sanitize Secondary Containers
        if not Inventory[src]['rig_st_tipo_4'] then Inventory[src]['rig_st_tipo_4'] = {} end
        if not Inventory[src]['mochila_tatica_expansivel_luc'] then Inventory[src]['mochila_tatica_expansivel_luc'] = {} end

        print('^2[mx-inv] Loaded inventory for ' .. player.name .. '^0')
    end
end

-- Open Inventory Function
local function OpenInventory(src)
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

    local vestData = {
        id = 'rig_st_tipo_4',
        type = 'vest',
        label = 'ST Tipo 4',
        size = { ["width"] = 4, ["height"] = 10 },
        items = containers['rig_st_tipo_4'] or {},
        weight = GetContainerWeight(containers['rig_st_tipo_4'] or {})
    }

    local bagData = {
        id = 'mochila_tatica_expansivel_luc',
        type = 'bag',
        label = 'Mochila TÃ¡tica ExpansÃ­vel Luc',
        size = { ["width"] = 5, ["height"] = 10 },
        items = containers['mochila_tatica_expansivel_luc'] or {},
        weight = GetContainerWeight(containers['mochila_tatica_expansivel_luc'] or {})
    }

    print('^3[mx-inv] Debug Open: Sending ' .. #playerData.items .. ' items to client.^0')

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
        vest = vestData,
        backpack = bagData,
        secondary = backpackData,
        itemDefs = ItemDefs
    })
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

-- Open Inventory Event (Now instant)
RegisterNetEvent('mx-inv:server:openInventory', function()
    OpenInventory(source)
end)

-- Save on Drop
AddEventHandler('playerDropped', function(reason)
    local src = source
    if Inventory[src] then
        local player = MX_GetPlayer(src)
        if player then
            DB.SavePlayer(player.identifier, Inventory[src])
            print('^2[mx-inv] Saved inventory for ' .. player.name .. '^0')
        end
        Inventory[src] = nil
    end
end)

-- Move Item Event
RegisterNetEvent('mx-inv:server:moveItem', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local itemName = data.item
    local fromId = data.from
    local toId = data.to
    local targetSlot = data.slot

    local function GetItems(id)
        if id == 'player-inv' then
            return containerMap.player
        elseif containerMap[id] then
            return containerMap[id]
        end
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

    if not itemIndex then
        print('^1[mx-inv] Move Failed: Item ' .. itemName .. ' not found in source container.^0')
        return
    end

    local item = fromItems[itemIndex]

    print('^3[mx-inv] Debug Move: Found ' ..
        itemName .. ' at index ' .. itemIndex .. '. Array size: ' .. #fromItems .. '^0')

    -- Move Logic
    table.remove(fromItems, itemIndex)
    print('^3[mx-inv] Debug Move: Removed. Array size: ' .. #fromItems .. '^0')

    item.slot = targetSlot
    table.insert(toItems, item)
    print('^3[mx-inv] Debug Move: Inserted. New Array size: ' .. #toItems .. '^0')

    -- Auto-Save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap) -- Save ALL containers
    end
end)

-- Command: Give Item
RegisterCommand('giveitem', function(source, args)
    local src = source
    if src == 0 then -- Console
        src = tonumber(args[1])
    else
        -- Check admin permission (TODO)
    end

    local targetId = tonumber(args[1])
    local itemName = args[2]
    local count = tonumber(args[3]) or 1

    if not targetId or not itemName then
        print('Usage: /giveitem [id] [item] [count]')
        return
    end

    if not Inventory[targetId] then
        print('Player inventory not loaded.')
        return
    end

    local success, msg = AddItem(targetId, itemName, count)
    if success then
        print('Given ' .. count .. 'x ' .. itemName .. ' to ' .. targetId)
        -- Auto-save
        local player = MX_GetPlayer(targetId)
        if player then DB.SavePlayer(player.identifier, Inventory[targetId]) end -- Save ALL containers

        OpenInventory(targetId)
    else
        print('Failed: ' .. msg)
    end
end)

-- Command: Clear Inventory
RegisterCommand('clearinv', function(source, args)
    local src = source
    if src == 0 then
        src = tonumber(args[1])
    end

    local targetId = tonumber(args[1]) or src
    if not targetId then
        print('Usage: /clearinv [id]')
        return
    end

    if Inventory[targetId] then
        Inventory[targetId].player = {}
        local player = MX_GetPlayer(targetId)
        if player then
            DB.SavePlayer(player.identifier, {})
            print('^2[mx-inv] Cleared inventory for ' .. player.name .. '^0')
        end
        -- Refresh Client
        OpenInventory(targetId)
    else
        print('Inventory not loaded for target.')
    end
end)

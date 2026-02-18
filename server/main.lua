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
    local player = MX_GetPlayer(src)
    if not player then return end

    if not Inventory[src] then
        print('^3[mx-inv] Loading player ' .. src .. ' from DB...^0')
        local dbData = DB.LoadPlayer(player.identifier)

        Inventory[src] = {}

        if not dbData then
            -- Fresh Spawn
            Inventory[src].player = {}
            print('^3[mx-inv] New player (no DB data).^0')
        elseif dbData.player then
            -- New Format (Object)
            Inventory[src] = dbData
            print('^3[mx-inv] Loaded DB data (Object format).^0')
        else
            -- Old Format (Array)
            Inventory[src].player = dbData
            print('^3[mx-inv] Loaded DB data (Array format).^0')
        end

        -- Initialize/Sanitize Secondary Containers
        if not Inventory[src]['rig_st_tipo_4'] then Inventory[src]['rig_st_tipo_4'] = {} end
        if not Inventory[src]['mochila_tatica_expansivel_luc'] then Inventory[src]['mochila_tatica_expansivel_luc'] = {} end

        -- Initialize Equipment
        if not Inventory[src].equipment then Inventory[src].equipment = {} end

        print('^3[mx-inv] Loaded Equipment for ' .. player.name .. ': ' .. json.encode(Inventory[src].equipment) .. '^0')
        print('^2[mx-inv] Init complete for ' .. player.name .. '^0')
    else
        print('^3[mx-inv] Player ' .. src .. ' already loaded in memory.^0')
    end
end

-- Open Inventory Function
local function OpenInventory(src)
    if not Inventory[src] then
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

    -- Debug: Print equipment being sent
    print('^3[mx-inv] Sending OpenInventory to ' .. src .. '. Equip: ' .. json.encode(containers.equipment) .. '^0')

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
        equipment = containers.equipment, -- Send actual equipment
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

-- Debug: Open Stash with Real Inventory
RegisterNetEvent('mx-inv:server:openStash', function()
    local src = source

    -- Ensure Loaded
    if not Inventory[src] then
        LoadPlayer(src)
        if not Inventory[src] then
            return
        end
    end

    local containers = Inventory[src]

    -- Debug Prints for Vest
    local vestItems = containers['rig_st_tipo_4'] or {}

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
        items = vestItems,
        weight = GetContainerWeight(vestItems)
    }

    local bagData = {
        id = 'mochila_tatica_expansivel_luc',
        type = 'bag',
        label = 'Mochila Tática Expansível Luc',
        size = { ["width"] = 5, ["height"] = 10 },
        items = containers['mochila_tatica_expansivel_luc'] or {},
        weight = GetContainerWeight(containers['mochila_tatica_expansivel_luc'] or {})
    }

    -- Add Debug Stash
    local stashData = {
        id = 'stash-debug',
        label = 'Debug Stash (Real Inv)',
        type = 'stash',
        size = { width = 7, height = 10 },
        items = {},
        weight = 0
    }

    TriggerClientEvent('mx-inv:client:openInventory', src, {
        player = playerData,
        vest = vestData,
        backpack = bagData,
        ['stash-debug'] = stashData,
        equipment = containers.equipment, -- Send actual equipment
        itemDefs = ItemDefs
    })
    print('^3[mx-inv] Debug OpenStash: Data sent to client.^0')
end)

-- Use Item Event
RegisterNetEvent('mx-inv:server:useItem', function(data)
    local src = source
    local containerId = data.container -- Item.tsx sends 'container'
    local slot = data.slot             -- Item.tsx sends 'slot' object
    local itemName = data.item

    print('^3[mx-inv] Debug UseItem: Request from ' ..
        src ..
        ' for ' ..
        tostring(itemName) ..
        ' in ' .. tostring(containerId) .. ' at slot ' .. tostring(slot.x) .. ',' .. tostring(slot.y) .. '^0')

    if not Inventory[src] then
        print('^1[mx-inv] Debug UseItem: Inventory not loaded.^0')
        return
    end

    -- Find Container
    local containerItems = nil
    if containerId == 'player-inv' or containerId == 'player' then
        containerItems = Inventory[src].player
    else
        containerItems = Inventory[src][containerId]
    end

    if not containerItems then
        print('^1[mx-inv] Debug UseItem: Container ' .. tostring(containerId) .. ' not found.^0')
        return
    end

    -- Find Item in Slot
    local itemIndex = nil
    for i, item in ipairs(containerItems) do
        -- Debug comparison
        print('Checking Item: ' ..
            item.name .. ' at ' .. item.slot.x .. ',' .. item.slot.y .. ' vs Target: ' .. slot.x .. ',' .. slot.y)

        -- Check slot (x,y)
        if item.slot.x == tonumber(slot.x) and item.slot.y == tonumber(slot.y) and item.name == itemName then
            itemIndex = i
            break
        end
    end

    if not itemIndex then
        print('^1[mx-inv] Debug UseItem: Item not found in slot.^0')
        return
    end

    local item = containerItems[itemIndex]
    local def = ItemDefs[itemName]

    if not def or not def.consume then
        print('^1[mx-inv] Debug UseItem: Item is not consumable.^0')
        return
    end

    -- Consume Logic: Remove 1
    if item.count > 1 then
        item.count = item.count - 1
    else
        table.remove(containerItems, itemIndex)
    end

    -- Save & Refresh
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, Inventory[src])
    end

    -- Trigger Client Animation/Status
    TriggerClientEvent('mx-inv:client:playAnim', src, def.consume)
    print('^2[mx-inv] Debug UseItem: Success. Consumed 1 ' .. itemName .. '^0')

    -- Refresh Inventory UI if open
    TriggerEvent('mx-inv:server:openInventory', src)
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

-- Move Item Event (Updated for Equipment)
RegisterNetEvent('mx-inv:server:moveItem', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local itemName = data.item
    local fromId = data.from
    local toId = data.to
    local targetSlot = data.slot or {}

    local targetX = targetSlot.x or 'N/A'
    local targetY = targetSlot.y or 'N/A'

    print('^3[mx-inv] Debug Move: Request from ' ..
        fromId .. ' to ' .. toId .. ' for ' .. itemName .. ' | Target: ' .. targetX .. ',' .. targetY .. '^0')

    local fromSlot = data.fromSlot

    -- Helper to resolve container & equipment slot
    local function GetContainerAndSlot(id)
        if id == 'player-inv' then return containerMap.player, nil end
        if string.sub(id, 1, 6) == 'equip-' then
            local equipSlotId = string.sub(id, 7)
            return containerMap.equipment, equipSlotId -- Return table, key
        end
        return containerMap[id], nil
    end

    local fromContainer, fromEquipKey = GetContainerAndSlot(fromId)
    local toContainer, toEquipKey = GetContainerAndSlot(toId)

    if not fromContainer then
        print('^1[mx-inv] Debug Move: Source ' .. fromId .. ' not found.^0')
        return
    end
    if not toContainer then
        print('^1[mx-inv] Debug Move: Target ' .. toId .. ' not found.^0')
        return
    end

    -- 1. Find Item in Source
    local itemIndex = nil
    local itemObj = nil

    if fromEquipKey then
        -- Source is Equipment Map
        print('^3[mx-inv] Debug Move: Searching source EQUIPMENT key: ' .. fromEquipKey .. '^0')
        itemObj = fromContainer[fromEquipKey]
        if itemObj then
            print('^3[mx-inv] Debug Move: Found item in equipment: ' .. itemObj.name .. '^0')
            -- Verify name matches if strict
            if itemObj.name == itemName then
                itemIndex = fromEquipKey
            else
                print('^1[mx-inv] Debug Move: Mismatch name in equipment. Expected ' ..
                    itemName .. ' got ' .. itemObj.name .. '^0')
            end
        else
            print('^1[mx-inv] Debug Move: Equipment key ' .. fromEquipKey .. ' is empty.^0')
        end
    else
        -- Source is Standard Array
        for i, item in ipairs(fromContainer) do
            if item.name == itemName then
                if fromSlot then
                    if item.slot.x == tonumber(fromSlot.x) and item.slot.y == tonumber(fromSlot.y) then
                        itemIndex = i
                        itemObj = item
                        break
                    end
                else
                    itemIndex = i
                    itemObj = item
                    break
                end
            end
        end
    end

    if not itemIndex or not itemObj then
        print('^1[mx-inv] Move Failed: Item ' .. itemName .. ' not found in source.^0')
        return
    end

    print('^3[mx-inv] Debug Move: Found ' ..
        itemName .. ' in ' .. (fromEquipKey and ('Equip:' .. fromEquipKey) or ('Array:' .. itemIndex)) .. '^0')

    -- 2. Validate Target
    if toEquipKey then
        -- Target is Equipment Slot
        print('^3[mx-inv] Debug Move: Target is EQUIPMENT key: ' .. toEquipKey .. '^0')
        if toContainer[toEquipKey] then
            print('^1[mx-inv] Warning: Equipment slot ' .. toEquipKey .. ' occupied. Swapping not implemented yet.^0')
            -- Keep simplified overwrite logic for now
        end
    else
        -- Target is Standard Array
        if targetSlot and targetSlot.x and targetSlot.y then
            for _, existingItem in ipairs(toContainer) do
                if existingItem.slot.x == tonumber(targetSlot.x) and existingItem.slot.y == tonumber(targetSlot.y) then
                    print('^3[mx-inv] Warning Move: Collision detected at ' ..
                        targetSlot.x .. ',' .. targetSlot.y .. '. Item will overlap!^0')
                end
            end
        end
    end

    -- 3. Execute Move

    -- REMOVE from Source
    if fromEquipKey then
        fromContainer[fromEquipKey] = nil
        TriggerClientEvent('mx-inv:client:updateEquipment', src, itemName, false)
        print('^3[mx-inv] Unequipped ' .. itemName .. ' from ' .. fromEquipKey .. '^0')
    else
        table.remove(fromContainer, itemIndex)
        print('^3[mx-inv] Debug Move: Removed from source array index ' .. itemIndex .. '^0')
    end

    -- ADD to Target
    if toEquipKey then
        toContainer[toEquipKey] = itemObj
        TriggerClientEvent('mx-inv:client:updateEquipment', src, itemName, true)
        print('^2[mx-inv] Equipped ' .. itemName .. ' to ' .. toEquipKey .. '^0')
        -- Log the new state of equipment
        print('^3[mx-inv] New Equipment State: ' .. json.encode(containerMap.equipment) .. '^0')
    else
        itemObj.slot = targetSlot
        table.insert(toContainer, itemObj)
        print('^3[mx-inv] Moved ' .. itemName .. ' to ' .. toId .. ' at ' .. targetSlot.x .. ',' .. targetSlot.y .. '^0')
    end

    -- Auto-Save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap) -- Save ALL containers
        print('^2[mx-inv] Auto-saved inventory for ' .. player.name .. '^0')
    end
end)

-- Swap Equipment Event (Equip-to-Equip)
RegisterNetEvent('mx-inv:server:swapEquipment', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end
    if not containerMap.equipment then return end

    local fromSlot = data.fromSlot
    local toSlot = data.toSlot

    print('^3[mx-inv] Swap Equipment: ' .. fromSlot .. ' <-> ' .. toSlot .. '^0')

    local fromItem = containerMap.equipment[fromSlot]
    local toItem = containerMap.equipment[toSlot] -- Can be nil

    -- Perform atomic swap
    containerMap.equipment[fromSlot] = toItem
    containerMap.equipment[toSlot] = fromItem

    -- Trigger visual updates for both items
    if fromItem then
        TriggerClientEvent('mx-inv:client:updateEquipment', src, fromItem.name, true) -- Still equipped (moved slot)
    end
    if toItem then
        TriggerClientEvent('mx-inv:client:updateEquipment', src, toItem.name, true) -- Still equipped (moved slot)
    end

    print('^2[mx-inv] Swap complete. New state: ' .. json.encode(containerMap.equipment) .. '^0')

    -- Auto-Save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved after swap for ' .. player.name .. '^0')
    end
end)

-- Debug Command: Clear ALL Inventory Data
RegisterCommand('clearallinv', function(source, args)
    if source ~= 0 then return end -- Console only for safety
    MySQL.query('TRUNCATE TABLE mx_inventory_players', {}, function(affectedRows)
        print('^1[mx-inv] WIPED ALL PLAYER INVENTORIES.^0')
    end)
    MySQL.query('TRUNCATE TABLE mx_inventory_stashes', {}, function(affectedRows)
        print('^1[mx-inv] WIPED ALL STASHES.^0')
    end)
    -- Clear memory
    Inventory = {}
end, true)

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
        LoadPlayer(targetId) -- Try to load
        if not Inventory[targetId] then return end
    end

    local success, msg = AddItem(targetId, itemName, count)
    if success then
        print('Given ' .. count .. 'x ' .. itemName .. ' to ' .. targetId)
        -- Auto-save
        local player = MX_GetPlayer(targetId)
        if player then DB.SavePlayer(player.identifier, Inventory[targetId]) end -- Save ALL containers

        -- If player is online, refresh
        TriggerEvent('mx-inv:server:openInventory', targetId)
    else
        print('Failed: ' .. msg)
    end
end, true) -- Admin only

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

-- Hotbar Shortcut Event
RegisterNetEvent('mx-inv:server:useHotbar', function(slotIndex)
    local src = source
    print('^3[mx-inv] Hotbar Request: ' .. slotIndex .. ' from ' .. src .. '^0')

    if not Inventory[src] then
        print('^1[mx-inv] Hotbar Error: Inventory not loaded for ' .. src .. '^0')
        return
    end

    if not Inventory[src].equipment then
        print('^1[mx-inv] Hotbar Error: Equipment table missing for ' .. src .. '^0')
        return
    end

    local slotMap = {
        [1] = 'primary',
        [2] = 'secondary',
        [3] = 'pistol',
        [4] = 'melee'
    }

    local equipKey = slotMap[slotIndex]
    if not equipKey then return end

    local item = Inventory[src].equipment[equipKey]
    if item then
        local def = ItemDefs[item.name]
        if def and def.equipment and def.equipment.weaponHash then
            print('^2[mx-inv] Hotbar: Setting active weapon for ' .. src .. ': ' .. def.equipment.weaponHash .. '^0')
            TriggerClientEvent('mx-inv:client:setActiveWeapon', src, def.equipment.weaponHash)
        end
    else
        print('^3[mx-inv] Hotbar: No item in slot ' ..
            equipKey .. '. Dump: ' .. json.encode(Inventory[src].equipment) .. '^0')
    end
end)

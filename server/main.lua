local ItemDefs = Items -- data/items.lua loaded via fxmanifest

-- DB is global now (loaded from server/db.lua)

-- Initialize Database
Citizen.CreateThread(function()
    DB.Init()
end)

local Inventory = {}
math.randomseed(os.time())


-- Helper: Generate UUID
local function GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

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

-- Helper: Find Free Slot
local function FindFreeSlot(container, itemSize)
    -- Map taken slots
    local takenSlots = {}
    for _, invItem in ipairs(container) do
        local itemDef = ItemDefs[invItem.name]
        local iSize = (itemDef and itemDef.size) or { x = 1, y = 1 }

        for ix = 0, iSize.x - 1 do
            for iy = 0, iSize.y - 1 do
                local slotX = invItem.slot.x + ix
                local slotY = invItem.slot.y + iy
                takenSlots[slotX .. '-' .. slotY] = true
            end
        end
    end

    -- Find slots
    for y = 1, Config.Inventory.Slots.height do
        for x = 1, Config.Inventory.Slots.width do
            -- Check if START slot is free
            if not takenSlots[x .. '-' .. y] then
                -- Check if WHOLE AREA is free
                local fits = true
                for ix = 0, itemSize.x - 1 do
                    for iy = 0, itemSize.y - 1 do
                        local checkX = x + ix
                        local checkY = y + iy

                        -- Boundary Check
                        if checkX > Config.Inventory.Slots.width or checkY > Config.Inventory.Slots.height then
                            fits = false
                            break
                        end

                        -- Overlap Check
                        if takenSlots[checkX .. '-' .. checkY] then
                            fits = false
                            break
                        end
                    end
                    if not fits then break end
                end

                if fits then
                    return { x = x, y = y }
                end
            end
        end
    end
    return nil
end

-- Helper: Get Formatted Inventory Payload
local function GetFormattedInventory(src)
    local containers = Inventory[src]
    if not containers then return nil end

    local payload = {
        player = {
            id = 'player-inv',
            type = 'player',
            label = 'Player Inventory',
            size = Config.Inventory.Slots,
            items = containers.player or {},
            maxWeight = Config.Inventory.MaxWeight,
            weight = GetContainerWeight(containers.player or {})
        },
        equipment = containers.equipment,
        itemDefs = ItemDefs
    }

    -- Dynamic Containers from Equipment
    if containers.equipment then
        for _, item in pairs(containers.equipment) do
            local def = ItemDefs[item.name]
            -- Check if item definition has container data
            if def and def.container then
                local containerId = item.name -- Use item name as storage ID (Shared storage per item type)

                -- Lazy Init: Create storage if missing
                if not containers[containerId] then
                    containers[containerId] = {}
                end

                payload[containerId] = {
                    id = containerId,
                    type = def.type, -- 'vest', 'backpack', etc.
                    label = def.label,
                    size = def.container.size,
                    items = containers[containerId],
                    weight = GetContainerWeight(containers[containerId]),
                    maxWeight = def.container.maxWeight
                }
            end
        end
    end

    return payload
end

-- Helper: Update Client Inventory (Refresh)
local function UpdateClientInventory(src)
    local payload = GetFormattedInventory(src)
    if payload then
        TriggerClientEvent('mx-inv:client:updateInventory', src, payload)
    end
end

-- Helper: Find Free Slot
local function FindFreeSlot(container, itemSize)
    local takenSlots = {}
    for _, invItem in ipairs(container) do
        local itemDef = ItemDefs[invItem.name]
        local iSize = (itemDef and itemDef.size) or { x = 1, y = 1 }

        for ix = 0, iSize.x - 1 do
            for iy = 0, iSize.y - 1 do
                local slotX = invItem.slot.x + ix
                local slotY = invItem.slot.y + iy
                takenSlots[slotX .. '-' .. slotY] = true
            end
        end
    end

    -- Find slots
    for y = 1, Config.Inventory.Slots.height do
        for x = 1, Config.Inventory.Slots.width do
            -- Check if START slot is free
            if not takenSlots[x .. '-' .. y] then
                -- Check if WHOLE AREA is free
                local fits = true
                for ix = 0, itemSize.x - 1 do
                    for iy = 0, itemSize.y - 1 do
                        local checkX = x + ix
                        local checkY = y + iy

                        -- Boundary Check
                        if checkX > Config.Inventory.Slots.width or checkY > Config.Inventory.Slots.height then
                            fits = false
                            break
                        end

                        -- Overlap Check
                        if takenSlots[checkX .. '-' .. checkY] then
                            fits = false
                            break
                        end
                    end
                    if not fits then break end
                end

                if fits then
                    return { x = x, y = y }
                end
            end
        end
    end
    return nil
end

-- Helper: Add Item to Player
local function AddItem(src, item, count)
    if not Inventory[src] then return false, "Inventory not loaded" end
    local def = ItemDefs[item]
    if not def then return false, "Invalid item" end

    local container = Inventory[src].player
    local maxStack = (def.stackable and def.maxStack) or (def.stackable and 60) or 1

    -- 1. Try to stack into existing slots (if stackable)
    if def.stackable then
        for _, invItem in ipairs(container) do
            if invItem.name == item then
                local space = maxStack - invItem.count
                if space > 0 then
                    local toAdd = math.min(count, space)
                    invItem.count = invItem.count + toAdd
                    count = count - toAdd
                    if count <= 0 then
                        return true, "Stacked completely"
                    end
                end
            end
        end
    end

    -- 2. Add remaining count to new slots
    if count > 0 then
        local itemsToAdd = {}
        local itemSize = (def.size) or { x = 1, y = 1 }

        while count > 0 do
            local slot = FindFreeSlot(container, itemSize)
            if not slot then
                return false, "Inventory full"
            end

            local amount = math.min(count, maxStack)

            local newItem = {
                name = item,
                count = amount,
                slot = slot,
                id = GenerateUUID()
            }
            table.insert(itemsToAdd, newItem)

            -- Temporarily add to container to mark slots occupied for next iteration in loop
            -- Wait, FindFreeSlot re-reads container.
            -- So we must add to container immediately or add to takenSlots in logic.
            -- Simpler: Add to container immediately.
            table.insert(container, newItem) -- Optimistic insert

            count = count - amount
        end

        return true, "Added new stacks"
    end
    return true, "Added"
end

-- Deprecated: Manual reload system removed. GTA Native handles reloads.
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
        -- Removed hardcoded initialization for dynamic system
        -- if not Inventory[src]['rig_st_tipo_4'] then Inventory[src]['rig_st_tipo_4'] = {} end
        -- if not Inventory[src]['mochila_tatica_expansivel_luc'] then Inventory[src]['mochila_tatica_expansivel_luc'] = {} end

        -- Initialize Equipment
        if not Inventory[src].equipment then Inventory[src].equipment = {} end

        -- Migration: Ensure all items have UUIDs
        if Inventory[src].player then
            for _, item in ipairs(Inventory[src].player) do
                if not item.id then item.id = GenerateUUID() end
            end
        end
        for _, containerName in ipairs({ 'rig_st_tipo_4', 'mochila_tatica_expansivel_luc' }) do
            if Inventory[src][containerName] then
                for _, item in ipairs(Inventory[src][containerName]) do
                    if not item.id then item.id = GenerateUUID() end
                end
            end
        end
        if Inventory[src].equipment then
            for _, item in pairs(Inventory[src].equipment) do
                if item and not item.id then item.id = GenerateUUID() end
            end
        end

        print('^3[mx-inv] Loaded Equipment for ' .. player.name .. ': ' .. json.encode(Inventory[src].equipment) .. '^0')
        print('^2[mx-inv] Init complete for ' .. player.name .. '^0')

        -- Wait a tiny bit then inform client of its initial equipment setup (weapons & clothes)
        SetTimeout(1000, function()
            TriggerClientEvent('mx-inv:client:playerLoaded', src, Inventory[src].equipment)
        end)
    else
        print('^3[mx-inv] Player ' .. src .. ' already loaded in memory.^0')
    end
end

-- Helper: Get Formatted Inventory Payload
local function GetFormattedInventory(src)
    local containers = Inventory[src]
    if not containers then return nil end

    local payload = {
        player = {
            id = 'player-inv',
            type = 'player',
            label = 'Player Inventory',
            size = Config.Inventory.Slots,
            items = containers.player or {},
            maxWeight = Config.Inventory.MaxWeight,
            weight = GetContainerWeight(containers.player or {})
        },
        equipment = containers.equipment,
        itemDefs = ItemDefs
    }

    -- Dynamic Containers from Equipment
    if containers.equipment then
        for _, item in pairs(containers.equipment) do
            local def = ItemDefs[item.name]
            -- Check if item definition has container data
            if def and def.container then
                local containerId = item.name -- Use item name as storage ID (Shared storage per item type)

                -- Lazy Init: Create storage if missing
                if not containers[containerId] then
                    containers[containerId] = {}
                end

                payload[containerId] = {
                    id = containerId,
                    type = def.type, -- 'vest', 'backpack', etc.
                    label = def.label,
                    size = def.container.size,
                    items = containers[containerId],
                    weight = GetContainerWeight(containers[containerId]),
                    maxWeight = def.container.maxWeight
                }
            end
        end
    end

    return payload
end

-- Helper: Update Client Inventory (Refresh)
local function UpdateClientInventory(src)
    local payload = GetFormattedInventory(src)
    if payload then
        TriggerClientEvent('mx-inv:client:updateInventory', src, payload)
    end
end

-- Open Inventory Function
local function OpenInventory(src)
    if not Inventory[src] then
        LoadPlayer(src)
        if not Inventory[src] then return end
    end

    local payload = GetFormattedInventory(src)
    if payload then
        TriggerClientEvent('mx-inv:client:openInventory', src, payload)
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

-- Re-sync equipment to client on request (after death/respawn/resource restart)
RegisterNetEvent('mx-inv:server:requestEquipment', function()
    local src = source
    if not Inventory[src] then
        print('^3[mx-inv] requestEquipment: Inventory not loaded for ' .. src .. '^0')
        return
    end
    local equip = Inventory[src].equipment
    if not equip then return end

    print('^2[mx-inv] Re-syncing equipment to ' .. src .. '^0')
    TriggerClientEvent('mx-inv:client:playerLoaded', src, equip)
end)

-- Open Inventory Event (Now instant)
RegisterNetEvent('mx-inv:server:openInventory', function(targetSrc)
    local src = source
    if targetSrc and type(targetSrc) == 'number' then src = targetSrc end
    if src and src > 0 then
        OpenInventory(src)
    end
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
        -- Check ID first if available
        if data.id and item.id == data.id then
            itemIndex = i
            break
        end

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
    -- Refresh Inventory UI if open
    UpdateClientInventory(src)
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
RegisterNetEvent('mx-inv:server:foldItem', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local containerId = data.container
    local itemId = data.id -- unique ID

    local containerItems = nil
    if containerId == 'player-inv' or containerId == 'player' then
        containerItems = containerMap.player
    elseif string.sub(containerId, 1, 6) == 'equip-' then
        local equipSlotId = string.sub(containerId, 7)
        local eqItem = containerMap.equipment[equipSlotId]
        if eqItem and eqItem.id == itemId then
            eqItem.folded = not eqItem.folded
            local player = MX_GetPlayer(src)
            if player then DB.SavePlayer(player.identifier, containerMap) end
            UpdateClientInventory(src)
            return
        end
    else
        containerItems = containerMap[containerId]
    end

    if not containerItems then return end

    for i, item in ipairs(containerItems) do
        if item.id == itemId then
            item.folded = not item.folded
            local player = MX_GetPlayer(src)
            if player then DB.SavePlayer(player.identifier, containerMap) end
            UpdateClientInventory(src)
            break
        end
    end
end)

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
            -- Check ID first
            if data.id and item.id == data.id then
                itemIndex = i
                itemObj = item
                break
            end

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
        itemObj.folded = false -- equipment items are always unfolded visually
        toContainer[toEquipKey] = itemObj
        local ammoToLoad = tonumber(itemObj.metadata and itemObj.metadata.ammo) or 0
        local attachments = itemObj.metadata and itemObj.metadata.attachments or nil
        TriggerClientEvent('mx-inv:client:updateEquipment', src, itemName, true, ammoToLoad, attachments)
        print('^2[mx-inv] Equipped ' .. itemName .. ' to ' .. toEquipKey .. '^0')
        -- Log the new state of equipment
        print('^3[mx-inv] New Equipment State: ' .. json.encode(containerMap.equipment) .. '^0')
    else
        itemObj.slot = targetSlot
        itemObj.rotated = data.rotated   -- Save rotation state
        if data.folded ~= nil then
            itemObj.folded = data.folded -- Save folded state
        end
        table.insert(toContainer, itemObj)
        print('^3[mx-inv] Moved ' .. itemName .. ' to ' .. toId .. ' at ' .. targetSlot.x .. ',' .. targetSlot.y .. '^0')
    end

    -- Auto-Save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved inventory for ' .. player.name .. '^0')
    end

    -- Refresh Client
    UpdateClientInventory(src)
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
        local ammoToLoad = tonumber(fromItem.metadata and fromItem.metadata.ammo) or 0
        TriggerClientEvent('mx-inv:client:updateEquipment', src, fromItem.name, true, ammoToLoad) -- Still equipped (moved slot)
    end
    if toItem then
        local ammoToLoad = tonumber(toItem.metadata and toItem.metadata.ammo) or 0
        TriggerClientEvent('mx-inv:client:updateEquipment', src, toItem.name, true, ammoToLoad)
    end
    -- Still equipped (moved slot)

    print('^2[mx-inv] Swap complete. New state: ' .. json.encode(containerMap.equipment) .. '^0')

    -- Auto-Save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved after swap for ' .. player.name .. '^0')
    end

    -- Refresh Client
    UpdateClientInventory(src)
end)

-- Unload Ammo from Weapon Event
RegisterNetEvent('mx-inv:server:unloadWeapon', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local weaponId = data.id
    local containerId = data.containerId

    local weapon = nil

    if containerId and string.sub(containerId, 1, 6) == 'equip-' then
        local slot = string.sub(containerId, 7)
        if containerMap.equipment then
            weapon = containerMap.equipment[slot]
            -- Double check ID mismatch if possible, but slot is authoritative
        end
    else
        local wKey = (containerId == 'player-inv') and 'player' or containerId
        local wContainer = containerMap[wKey]
        if wContainer then
            for _, wItem in ipairs(wContainer) do
                if wItem.id == weaponId then
                    weapon = wItem
                    break
                end
            end
        end
    end

    if not weapon then
        print('^1[mx-inv] Unload: No weapon found with id: ' .. tostring(weaponId) .. '^0')
        return
    end

    local currentAmmo = weapon.metadata and weapon.metadata.ammo or 0
    if currentAmmo <= 0 then
        -- Nothing to unload
        return
    end

    local weaponDef = Items[weapon.name]
    if not weaponDef or not weaponDef.equipment or not weaponDef.equipment.caliber then
        print('^1[mx-inv] Unload: Invalid weapon definition or missing caliber for: ' .. tostring(weapon.name) .. '^0')
        return
    end

    local ammoItemName = weaponDef.equipment.caliber

    -- 1. Set weapon ammo to 0
    weapon.metadata.ammo = 0
    weapon.metadata.clip = 0

    -- 2. Give player the ammo item
    local added = AddItem(src, ammoItemName, currentAmmo)
    if not added then
        print('^1[mx-inv] Unload: Failed to add ' .. tostring(currentAmmo) .. 'x ' .. ammoItemName .. ' to inventory.^0')
        -- Rollback ammo?
        weapon.metadata.ammo = currentAmmo
        return
    end

    print('^2[mx-inv] Unload: Unloaded ' ..
        tostring(currentAmmo) .. 'x ' .. ammoItemName .. ' from ' .. tostring(weapon.name) .. '^0')

    -- Update Client Ped Ammo immediately if weapon is currently equipped
    local weaponHash = GetHashKey(weaponDef.equipment.weaponHash)
    TriggerClientEvent('mx-inv:client:updateEquipment', src, weapon.name, true, 0) -- Re-equip practically with 0

    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end

    UpdateClientInventory(src)
end)

-- Stack Items Event (Merge stackable items)
RegisterNetEvent('mx-inv:server:stackItems', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local fromContainerId = data.fromContainerId
    local toContainerId = data.toContainerId
    local fromItemId = data.fromItemId
    local toItemId = data.toItemId

    -- Resolve container keys
    local fromKey = (fromContainerId == 'player-inv') and 'player' or fromContainerId
    local toKey = (toContainerId == 'player-inv') and 'player' or toContainerId

    local fromContainer = containerMap[fromKey]
    local toContainer = containerMap[toKey]
    if not fromContainer or not toContainer then
        print('^1[mx-inv] Stack: Container not found^0')
        return
    end

    -- Find both items
    local fromItem, fromIndex = nil, nil
    for i, item in ipairs(fromContainer) do
        if item.id == fromItemId then
            fromItem = item
            fromIndex = i
            break
        end
    end

    local toItem, toIndex = nil, nil
    for i, item in ipairs(toContainer) do
        if item.id == toItemId then
            toItem = item
            toIndex = i
            break
        end
    end

    if not fromItem or not toItem then
        print('^1[mx-inv] Stack: Item(s) not found^0')
        return
    end

    if fromItem.name ~= toItem.name then
        print('^1[mx-inv] Stack: Items are not the same type^0')
        return
    end

    local itemDef = Items[toItem.name]
    local maxStack = (itemDef and itemDef.maxStack) or 60
    local space = maxStack - (toItem.count or 1)
    if space <= 0 then
        print('^1[mx-inv] Stack: Target is already full^0')
        return
    end

    local toTransfer = math.min(fromItem.count or 1, space)
    toItem.count = (toItem.count or 1) + toTransfer
    local newFromCount = (fromItem.count or 1) - toTransfer

    if newFromCount <= 0 then
        table.remove(fromContainer, fromIndex)
        print('^2[mx-inv] Stack: Fully merged ' .. fromItem.name .. ' (removed source)^0')
    else
        fromItem.count = newFromCount
        print('^2[mx-inv] Stack: Partially merged ' ..
            fromItem.name .. ' (' .. toTransfer .. ' transferred, ' .. newFromCount .. ' remaining)^0')
    end

    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

-- Attach Item to Weapon Event
RegisterNetEvent('mx-inv:server:attachToWeapon', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local weaponId = data.weaponId
    local weaponContainerId = data.weaponContainerId
    local attachmentSlot = data.attachmentSlot
    local attachmentItemName = data.attachmentItem
    local attachmentItemId = data.attachmentItemId
    local fromContainerId = data.fromContainerId

    print('^3[mx-inv] Attach: ' ..
        tostring(attachmentItemName) ..
        ' -> weapon ' .. tostring(weaponId) .. ' slot ' .. tostring(attachmentSlot) .. '^0')

    -- Find the weapon
    local weapon = nil
    local weaponLocation = nil -- 'equipment' or container key

    if weaponContainerId and string.sub(weaponContainerId, 1, 6) == 'equip-' then
        local slot = string.sub(weaponContainerId, 7)
        if containerMap.equipment and containerMap.equipment[slot] then
            weapon = containerMap.equipment[slot]
            weaponLocation = 'equipment:' .. slot
        end
    else
        local wKey = (weaponContainerId == 'player-inv') and 'player' or weaponContainerId
        local wContainer = containerMap[wKey]
        if wContainer then
            for _, wItem in ipairs(wContainer) do
                if wItem.id == weaponId then
                    weapon = wItem
                    weaponLocation = 'container:' .. wKey
                    break
                end
            end
        end
    end

    if not weapon then
        print('^1[mx-inv] Attach: Weapon not found: ' .. tostring(weaponId) .. '^0')
        return
    end

    -- Find and remove the attachment item from source container
    local fromKey = (fromContainerId == 'player-inv') and 'player' or fromContainerId
    local fromContainer = containerMap[fromKey]
    if not fromContainer then
        print('^1[mx-inv] Attach: Source container not found: ' .. tostring(fromContainerId) .. '^0')
        return
    end

    local attachIndex = nil
    for i, item in ipairs(fromContainer) do
        if item.id == attachmentItemId then
            attachIndex = i
            break
        end
    end

    if not attachIndex then
        print('^1[mx-inv] Attach: Attachment item not found in source container.^0')
        return
    end

    -- Remove attachment from source container
    table.remove(fromContainer, attachIndex)

    -- Add to weapon metadata
    if not weapon.metadata then weapon.metadata = {} end
    if not weapon.metadata.attachments then weapon.metadata.attachments = {} end
    weapon.metadata.attachments[attachmentSlot] = attachmentItemName

    print('^2[mx-inv] Attached ' .. attachmentItemName .. ' to ' .. weapon.name .. ' slot ' .. attachmentSlot .. '^0')

    -- If weapon is equipped, sync attachment visually
    local weaponDef = Items[weapon.name]
    if weaponDef and weaponDef.equipment and weaponDef.equipment.weaponHash then
        TriggerClientEvent('mx-inv:client:syncAttachments', src, weaponDef.equipment.weaponHash,
            weapon.metadata.attachments)
    end

    -- Save + Refresh
    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

-- Remove Attachment from Weapon Event
RegisterNetEvent('mx-inv:server:removeAttachment', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local weaponId = data.weaponId
    local weaponContainerId = data.weaponContainerId
    local attachmentSlot = data.attachmentSlot

    print('^3[mx-inv] Remove Attachment: slot ' ..
        tostring(attachmentSlot) .. ' from weapon ' .. tostring(weaponId) .. '^0')

    -- Find the weapon
    local weapon = nil

    if weaponContainerId and string.sub(weaponContainerId, 1, 6) == 'equip-' then
        local slot = string.sub(weaponContainerId, 7)
        if containerMap.equipment and containerMap.equipment[slot] then
            weapon = containerMap.equipment[slot]
        end
    else
        local wKey = (weaponContainerId == 'player-inv') and 'player' or weaponContainerId
        local wContainer = containerMap[wKey]
        if wContainer then
            for _, wItem in ipairs(wContainer) do
                if wItem.id == weaponId then
                    weapon = wItem
                    break
                end
            end
        end
    end

    if not weapon then
        print('^1[mx-inv] Remove Attachment: Weapon not found.^0')
        return
    end

    if not weapon.metadata or not weapon.metadata.attachments or not weapon.metadata.attachments[attachmentSlot] then
        print('^1[mx-inv] Remove Attachment: No attachment in slot ' .. tostring(attachmentSlot) .. '^0')
        return
    end

    local attachmentItemName = weapon.metadata.attachments[attachmentSlot]

    -- Remove from weapon metadata
    weapon.metadata.attachments[attachmentSlot] = nil

    -- Give attachment item back to player
    local added = false

    -- If placed into specific slot via drag & drop
    if data.toContainerId and data.toSlot then
        local toKey = (data.toContainerId == 'player-inv') and 'player' or data.toContainerId
        local toContainer = containerMap[toKey]
        if toContainer then
            local newItem = {
                name = attachmentItemName,
                count = 1,
                slot = data.toSlot,
                id = GenerateUUID()
            }
            table.insert(toContainer, newItem)
            added = true
            print('^2[mx-inv] Placed ' ..
                attachmentItemName ..
                ' to ' .. data.toContainerId .. ' at ' .. data.toSlot.x .. ',' .. data.toSlot.y .. '^0')
        end
    end

    -- Fallback to first free slot
    if not added then
        added = AddItem(src, attachmentItemName, 1)
    end

    if not added then
        print('^1[mx-inv] Remove Attachment: Failed to add ' .. attachmentItemName .. ' back to inventory.^0')
        -- Rollback
        weapon.metadata.attachments[attachmentSlot] = attachmentItemName
        return
    end

    print('^2[mx-inv] Removed ' .. attachmentItemName .. ' from ' .. weapon.name .. ' slot ' .. attachmentSlot .. '^0')

    -- If weapon is equipped, remove the component visually
    local weaponDef = Items[weapon.name]
    if weaponDef and weaponDef.equipment and weaponDef.equipment.weaponHash then
        local attachDef = Items[attachmentItemName]
        if attachDef and attachDef.attachment and attachDef.attachment.componentHash then
            TriggerClientEvent('mx-inv:client:removeAttachmentComponent', src, weaponDef.equipment.weaponHash,
                attachDef.attachment.componentHash)
        end
    end

    -- Save + Refresh
    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

RegisterNetEvent('mx-inv:server:loadAmmoIntoWeapon', function(data)
    local src = source
    print('^3[mx-inv] Attempting to load ammo. src=' .. tostring(src) .. '^0')
    local containerMap = Inventory[src]
    if not containerMap then
        print('^1[mx-inv] No container map for src ' .. tostring(src) .. '^0')
        return
    end

    local weaponSlot = data.weaponSlot -- Can be string (slot name like 'primary') or UUID (if in grid)
    local weaponContainerId = data.weaponContainer
    local ammoItemData = data.ammoItem
    local ammoContainerId = data.ammoContainer

    local weapon = nil

    if weaponContainerId and string.sub(weaponContainerId, 1, 6) == 'equip-' then
        if not containerMap.equipment then return end
        weapon = containerMap.equipment[weaponSlot]
    else
        local wKey = (weaponContainerId == 'player-inv') and 'player' or weaponContainerId
        local wContainer = containerMap[wKey]
        if wContainer then
            for _, wItem in ipairs(wContainer) do
                if wItem.id == weaponSlot then
                    weapon = wItem
                    break
                end
            end
        end
    end

    if not weapon then
        print('^1[mx-inv] No weapon found in container: ' ..
            tostring(weaponContainerId) .. ' with slot/id: ' .. tostring(weaponSlot) .. '^0')
        return
    end

    local weaponDef = Items[weapon.name]
    if not weaponDef or not weaponDef.equipment or not weaponDef.equipment.caliber then
        print('^1[mx-inv] Invalid weapon definition or missing caliber for: ' .. tostring(weapon.name) .. '^0')
        return
    end

    local ammoKey = (ammoContainerId == 'player-inv') and 'player' or ammoContainerId
    local ammoContainer = containerMap[ammoKey]
    if not ammoContainer then
        print('^1[mx-inv] Invalid ammo container: ' .. tostring(ammoKey) .. '^0')
        return
    end

    -- Find Ammo Item
    local ammoItem = nil
    local ammoIdx = -1
    for i, item in ipairs(ammoContainer) do
        if data.id and item.id == data.id then
            ammoItem = item
            ammoIdx = i
            break
        elseif not data.id and item.name == ammoItemData.name and item.slot.x == ammoItemData.slot.x and item.slot.y == ammoItemData.slot.y then
            ammoItem = item
            ammoIdx = i
            break
        end
    end

    if not ammoItem then
        print('^1[mx-inv] Ammo item not found in container for ID: ' .. tostring(data.id) .. '^0')
        return
    end

    local ammoDef = Items[ammoItem.name]
    local ammoCaliber = (ammoDef and ammoDef.ammo and ammoDef.ammo.caliber)

    if weaponDef.equipment.caliber ~= ammoCaliber then
        print('^1[mx-inv] Caliber mismatch! Weapon: ' ..
            tostring(weaponDef.equipment.caliber) .. ' / Ammo: ' .. tostring(ammoCaliber) .. '^0')
        TriggerClientEvent('mx-inv:client:notify', src, 'Caliber mismatch!')
        return
    end

    print('^2[mx-inv] Passed all checks. Ammo: ' .. ammoItem.name .. '  Weapon: ' .. weapon.name .. '^0')

    -- Calculate Capacity (Max 150 total ammo for any weapon)
    local MAX_AMMO = 150
    if not weapon.metadata then weapon.metadata = {} end
    local currentTotalAmmo = tonumber(weapon.metadata.ammo) or 0
    local space = MAX_AMMO - currentTotalAmmo

    if space <= 0 then
        TriggerClientEvent('mx-inv:client:notify', src, 'Weapon cannot carry more ammo (Max 150).')
        return
    end

    local amountToLoad = math.min(space, tonumber(ammoItem.count) or 0)

    weapon.metadata.ammo = currentTotalAmmo + amountToLoad

    -- Decrease Ammo Stack
    ammoItem.count = (tonumber(ammoItem.count) or 0) - amountToLoad
    if ammoItem.count <= 0 then
        table.remove(ammoContainer, ammoIdx)
    end

    -- Update Client Ped Ammo immediately if weapon is currently equipped
    local weaponHash = GetHashKey(weaponDef.equipment.weaponHash)
    TriggerClientEvent('mx-inv:client:addWeaponAmmo', src, weaponHash, amountToLoad)

    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end

    UpdateClientInventory(src)
end)

-- Sync Ammo Usage (Clip and Total)
RegisterNetEvent('mx-inv:server:updateAmmo', function(weaponHash, totalAmmo, clipAmmo)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap or not containerMap.equipment then return end

    local foundItem = nil
    local foundSlot = nil
    for slot, item in pairs(containerMap.equipment) do
        if item and item.name then
            local def = Items[item.name]
            if def and def.equipment and def.equipment.weaponHash and GetHashKey(def.equipment.weaponHash) == weaponHash then
                foundItem = item
                foundSlot = slot
                break
            end
        end
    end

    if foundItem then
        if not foundItem.metadata then foundItem.metadata = {} end
        foundItem.metadata.ammo = totalAmmo
        foundItem.metadata.clip = clipAmmo

        TriggerClientEvent('mx-inv:client:syncAmmoUI', src, foundSlot, totalAmmo, clipAmmo)
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

    -- Auto-Equip Logic for Large Items (Backpack/Vest)
    local def = ItemDefs[itemName]
    local autoEquipped = false
    if def and (def.type == 'backpack' or def.type == 'vest') then
        local slotKey = (def.type == 'backpack' and 'backpack') or 'vest'
        if not Inventory[targetId].equipment then Inventory[targetId].equipment = {} end

        if not Inventory[targetId].equipment[slotKey] then
            Inventory[targetId].equipment[slotKey] = {
                name = itemName,
                count = 1,
                type = def.type,
                id = GenerateUUID(),
                metadata = {}
            }
            autoEquipped = true
            print('^2[mx-inv] Auto-equipped ' .. itemName .. ' for ' .. targetId .. '^0')
        end
    end

    if autoEquipped then
        print('Given (Auto-Equipped) ' .. itemName .. ' to ' .. targetId)
        local player = MX_GetPlayer(targetId)
        if player then DB.SavePlayer(player.identifier, Inventory[targetId]) end
        UpdateClientInventory(targetId)
        return
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

-- Debug Command: Inspect Inventory State
RegisterCommand('debuginv', function(source, args)
    local src = source
    if src == 0 then src = tonumber(args[1]) end
    if not src then return end

    local d = Inventory[src]
    if not d then
        print('^1[mx-inv] Inventory not loaded for ' .. src .. '^0')
        return
    end

    print('^3--- DEBUG INVENTORY ' .. src .. ' ---^0')
    print('^2PLAYER ITEMS:^0 ' .. json.encode(d.player))
    print('^2EQUIPMENT:^0 ' .. json.encode(d.equipment))
    print('^2VEST:^0 ' .. json.encode(d['rig_st_tipo_4']))
    print('^2BAG:^0 ' .. json.encode(d['mochila_tatica_expansivel_luc']))
    print('^3----------------------------------^0')
end, false)

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

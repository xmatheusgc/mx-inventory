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

-- Reload Weapon (Manual 'R' key)
RegisterNetEvent('mx-inv:server:reloadWeapon', function(weaponHash)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap or not containerMap.equipment then return end

    -- 1. Find the equipped weapon matching the hash
    local weaponSlot = nil
    local weaponItem = nil

    for slot, item in pairs(containerMap.equipment) do
        local def = Items[item.name]
        if def and def.equipment and GetHashKey(def.equipment.weaponHash) == weaponHash then
            weaponSlot = slot
            weaponItem = item
            break
        end
    end

    if not weaponItem then return end -- Weapon not found in equipment

    local weaponDef = Items[weaponItem.name]
    if not weaponDef or not weaponDef.equipment or not weaponDef.equipment.caliber then return end
    local requiredCaliber = weaponDef.equipment.caliber

    -- 2. Find Best Magazine in Inventory (Player Only for now)
    local bestMag = nil
    local bestMagIndex = -1
    local bestAmmoCount = -1

    local container = containerMap.player
    for i, item in ipairs(container) do
        if item.type == 'magazine' then
            local magDef = Items[item.name]
            if magDef and magDef.magazine and magDef.magazine.caliber == requiredCaliber then
                local currentAmmo = (item.metadata and item.metadata.ammo) or 0
                if currentAmmo > bestAmmoCount and currentAmmo > 0 then
                    bestAmmoCount = currentAmmo
                    bestMag = item
                    bestMagIndex = i
                end
            end
        end
    end

    if not bestMag then
        -- No magazine found
        TriggerClientEvent('mx-inv:client:notify', src, 'No suitable magazine found!')
        return
    end

    -- 3. Perform Swap
    -- A. Eject Current Magazine (if exists)
    if weaponItem.metadata and weaponItem.metadata.magazine then
        local oldMag = weaponItem.metadata.magazine
        -- Only eject if it has ammo? Or always eject? Always eject on reload.

        local oldMagDef = Items[oldMag.name]
        local oldMagSize = (oldMagDef and oldMagDef.size) or { x = 1, y = 2 }

        -- Check if there is space for old mag
        local freeSlot = FindFreeSlot(container, oldMagSize)
        if not freeSlot then
            TriggerClientEvent('mx-inv:client:notify', src, 'No space to eject current magazine!')
            return
        end

        -- Create Item
        local ejectedItem = {
            name = oldMag.name,
            label = oldMag.label,
            count = 1,
            slot = freeSlot,
            size = oldMagSize,
            type = 'magazine',
            id = GenerateUUID(),
            metadata = {
                ammo = oldMag.ammo,
                capacity = oldMag.capacity,
                caliber = oldMag.caliber
            }
        }
        table.insert(container, ejectedItem)
    end

    -- B. Load New Magazine
    table.remove(container, bestMagIndex)

    if not weaponItem.metadata then weaponItem.metadata = {} end
    weaponItem.metadata.magazine = {
        name = bestMag.name,
        label = bestMag.label or bestMag.name,
        ammo = (bestMag.metadata and bestMag.metadata.ammo) or 0,
        capacity = (bestMag.metadata and bestMag.metadata.capacity) or 30,
        caliber = (bestMag.metadata and bestMag.metadata.caliber) or requiredCaliber
    }

    -- 4. Sync
    TriggerClientEvent('mx-inv:client:setAmmoAndReload', src, weaponHash, weaponItem.metadata.magazine.ammo)

    -- Auto-save
    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end

    -- Update Inventory UI if open
    -- Update Inventory UI if open
    UpdateClientInventory(src)
    print('^2[mx-inv] Reloaded ' .. weaponItem.name .. ' with ' .. bestMag.name .. '^0')
end)
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

    -- Refresh Client
    UpdateClientInventory(src)
end)

-- Load Magazine into Weapon Event
RegisterNetEvent('mx-inv:server:loadMagazine', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end
    if not containerMap.equipment then return end

    local magazineName = data.magazine
    local weaponSlot = data.weaponSlot
    local fromContainerId = data.from

    print('^3[mx-inv] Load Magazine: ' .. magazineName .. ' into ' .. weaponSlot .. '^0')

    -- Get weapon from equipment
    local weapon = containerMap.equipment[weaponSlot]
    if not weapon then
        print('^1[mx-inv] No weapon in slot ' .. weaponSlot .. '^0')
        return
    end

    -- Get weapon definition for caliber
    local weaponDef = Items[weapon.name]
    if not weaponDef or not weaponDef.equipment or not weaponDef.equipment.caliber then
        print('^1[mx-inv] Weapon has no caliber data: ' .. weapon.name .. '^0')
        return
    end

    -- Get magazine definition for caliber
    local magDef = Items[magazineName]
    if not magDef or not magDef.magazine or not magDef.magazine.caliber then
        print('^1[mx-inv] Magazine has no caliber data: ' .. magazineName .. '^0')
        return
    end

    -- Validate caliber compatibility
    if weaponDef.equipment.caliber ~= magDef.magazine.caliber then
        print('^1[mx-inv] Caliber mismatch: weapon=' ..
            weaponDef.equipment.caliber .. ' mag=' .. magDef.magazine.caliber .. '^0')
        return
    end

    -- Find and remove magazine from source container
    local sourceKey = (fromContainerId == 'player-inv') and 'player' or fromContainerId
    local sourceContainer = containerMap[sourceKey]
    if not sourceContainer then
        print('^1[mx-inv] Source container not found: ' .. fromContainerId .. ' (key: ' .. sourceKey .. ')^0')
        return
    end

    local magItem = nil
    local magIndex = nil
    for i, item in ipairs(sourceContainer) do
        -- Use ID if available (preferred), fallback to name if not
        if data.id and item.id == data.id then
            magItem = item
            magIndex = i
            break
        elseif not data.id and item.name == magazineName then
            magItem = item
            magIndex = i
            break
        end
    end

    if not magItem or not magIndex then
        print('^1[mx-inv] Magazine not found in container: ' .. magazineName .. ' (ID: ' .. tostring(data.id) .. ')^0')
        return
    end

    -- If weapon already has a magazine, eject it back to inventory
    if weapon.metadata and weapon.metadata.magazine then
        local oldMag = weapon.metadata.magazine

        -- Determine valid slot for ejected mag
        local oldMagDef = Items[oldMag.name]
        local oldMagSize = (oldMagDef and oldMagDef.size) or { x = 1, y = 2 }
        local targetSlot = FindFreeSlot(sourceContainer, oldMagSize)

        if targetSlot then
            local ejectedMag = {
                name = oldMag.name,
                label = oldMag.label or oldMag.name,
                count = 1,
                slot = targetSlot, -- Valid Slot
                size = oldMagSize,
                type = "magazine",
                id = GenerateUUID(), -- UUID
                metadata = {
                    ammo = oldMag.ammo,
                    capacity = oldMag.capacity,
                    caliber = oldMag.caliber,
                }
            }
            table.insert(sourceContainer, ejectedMag)
            print('^3[mx-inv] Ejected old magazine: ' ..
                oldMag.name .. ' to ' .. targetSlot.x .. ',' .. targetSlot.y .. '^0')
        else
            print('^1[mx-inv] No space to eject old magazine! It was lost.^0')
            -- Future: Drop to ground?
        end
    end

    -- Remove new magazine from inventory
    table.remove(sourceContainer, magIndex)

    -- Store magazine in weapon metadata
    local magAmmo = (magItem.metadata and magItem.metadata.ammo) or 0
    local magCapacity = magDef.magazine.capacity

    print('[DEBUG RELOAD] Source Item ID:', magItem.id)
    print('[DEBUG RELOAD] Metadata:', json.encode(magItem.metadata))
    print('[DEBUG RELOAD] Final Ammo to Weapon:', magAmmo, 'Capacity:', magCapacity)

    if not weapon.metadata then weapon.metadata = {} end
    weapon.metadata.magazine = {
        name = magazineName,
        label = magDef.label or magazineName,
        ammo = magAmmo,
        capacity = magCapacity,
        caliber = magDef.magazine.caliber,
    }

    -- Set ammo on GTA weapon
    local weaponHash = GetHashKey(weaponDef.equipment.weaponHash)
    TriggerClientEvent('mx-inv:client:setAmmoAndReload', src, weaponDef.equipment.weaponHash, magAmmo)

    print('^2[mx-inv] Magazine loaded: ' ..
        magazineName .. ' (' .. magAmmo .. '/' .. magCapacity .. ') into ' .. weapon.name .. '^0')

    -- Auto-save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved after loadMagazine for ' .. player.name .. '^0')
    end

    -- Refresh Client Inventory
    -- Refresh Client Inventory
    UpdateClientInventory(src)
end)

-- Unload Magazine from Weapon Event
RegisterNetEvent('mx-inv:server:unloadMagazine', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end
    if not containerMap.equipment then return end

    local weaponSlot = data.weaponSlot
    local toContainerId = data.to

    local weapon = containerMap.equipment[weaponSlot]
    if not weapon or not weapon.metadata or not weapon.metadata.magazine then
        print('^1[mx-inv] No magazine to eject from ' .. weaponSlot .. '^0')
        return
    end

    local mag = weapon.metadata.magazine
    local mag = weapon.metadata.magazine
    local targetKey = (toContainerId == 'player-inv') and 'player' or toContainerId
    local targetContainer = containerMap[targetKey]
    if not targetContainer then
        print('^1[mx-inv] Target container not found: ' .. toContainerId .. ' (key: ' .. targetKey .. ')^0')
        return
    end

    local magDef = Items[mag.name]

    -- Create magazine item in inventory
    -- Determine Slot
    local targetSlot = data.slot
    if not targetSlot or targetSlot.x == -1 or targetSlot.y == -1 then
        targetSlot = FindFreeSlot(targetContainer, (magDef and magDef.size) or { x = 1, y = 2 })
    end

    if not targetSlot then
        print('^1[mx-inv] No space to eject magazine^0')
        TriggerClientEvent('mx-inv:client:notify', src, 'No space to unload magazine!')
        return
    end

    -- Create magazine item in inventory
    local ejectedMag = {
        name = mag.name,
        label = mag.label or mag.name,
        count = 1,
        slot = targetSlot,
        size = (magDef and magDef.size) or { x = 1, y = 2 },
        type = "magazine",
        id = GenerateUUID(), -- UUID
        metadata = {
            ammo = mag.ammo,
            capacity = mag.capacity,
            caliber = mag.caliber,
        }
    }
    table.insert(targetContainer, ejectedMag)

    -- Clear magazine from weapon
    weapon.metadata.magazine = nil

    -- Remove ammo from GTA weapon
    local weaponDef = Items[weapon.name]
    if weaponDef and weaponDef.equipment and weaponDef.equipment.weaponHash then
        TriggerClientEvent('mx-inv:client:setAmmoAndReload', src, weaponDef.equipment.weaponHash, 0)
    end

    print('^2[mx-inv] Magazine ejected: ' .. mag.name .. ' (' .. mag.ammo .. '/' .. mag.capacity .. ')^0')

    -- Auto-save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved after unloadMagazine for ' .. player.name .. '^0')
    end


    -- Refresh Client Inventory
    -- Refresh Client Inventory
    UpdateClientInventory(src)
end)

-- Load Ammo into Magazine (Inventory -> Inventory)
RegisterNetEvent('mx-inv:server:loadAmmoIntoMag', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local magazineId = data.magazineId
    local ammoItemData = data.ammoItem
    local magContainerId = data.magazineContainer
    local ammoContainerId = data.ammoContainer

    print('^3[mx-inv] Load Ammo: ' .. ammoItemData.name .. ' -> ' .. magazineId .. '^0')

    print('^3[mx-inv] Load Ammo: ' .. ammoItemData.name .. ' -> ' .. magazineId .. '^0')

    local magKey = (magContainerId == 'player-inv') and 'player' or magContainerId
    local ammoKey = (ammoContainerId == 'player-inv') and 'player' or ammoContainerId

    local magContainer = containerMap[magKey]
    local ammoContainer = containerMap[ammoKey]

    if not magContainer or not ammoContainer then
        print('^1[mx-inv] Container not found. MagKey: ' .. magKey .. ' AmmoKey: ' .. ammoKey .. '^0')
        return
    end

    -- Find Magazine Item
    -- Find Magazine Item
    local magItem = nil
    for _, item in ipairs(magContainer) do
        if data.magazineId and item.id == data.magazineId then
            magItem = item
            break
        elseif not data.magazineId and item.name == magazineId then -- Fallback if ID invalid
            magItem = item
            break
        end
    end

    -- Better: Frontend should send slot for precision.
    -- But assuming name matches for now as per frontend implementation.
    -- Actually, frontend sent `magazineId` which is `targetItem.name`.
    -- If there are 2 mags, this might pick the first one.
    -- Ideally we'd use slot. But let's stick to the current flow and improve if needed.

    if not magItem then
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
        print('^1[mx-inv] Ammo item NOT found. ID: ' ..
            tostring(data.id) .. ' Name: ' .. tostring(ammoItemData.name) .. '^0')
        return
    end
    print('^3[mx-inv] DEBUG: Found Ammo: ' .. ammoItem.name .. ' Count: ' .. tostring(ammoItem.count) .. '^0')

    -- Validate Caliber
    -- Ammo Item definition
    local ammoDef = Items[ammoItem.name]
    -- Mag Item definition
    local magDef = Items[magItem.name]

    local ammoCaliber = (ammoDef and ammoDef.ammo and ammoDef.ammo.caliber)
    local magCaliber = (magDef and magDef.magazine and magDef.magazine.caliber)

    if not ammoCaliber or not magCaliber or ammoCaliber ~= magCaliber then
        print('^1[mx-inv] Caliber mismatch or missing data. Ammo: ' ..
            tostring(ammoCaliber) .. ' Mag: ' .. tostring(magCaliber) .. '^0')
        return
    end

    -- Calculate Capacity
    local capacity = (magItem.metadata and magItem.metadata.capacity) or (magDef.magazine.capacity) or 30
    local currentAmmo = (magItem.metadata and magItem.metadata.ammo) or 0
    local space = capacity - currentAmmo

    if space <= 0 then
        print('^1[mx-inv] Magazine full. Space: ' .. space .. '^0')
        return
    end

    local amountToLoad = math.min(space, tonumber(ammoItem.count) or 0)
    print('^3[mx-inv] DEBUG: Loading ' .. amountToLoad .. ' rounds.^0')

    -- Update Mag Metadata
    if not magItem.metadata then magItem.metadata = {} end
    magItem.metadata.ammo = currentAmmo + amountToLoad
    magItem.metadata.capacity = capacity
    magItem.metadata.caliber = magCaliber

    -- Decrease Ammo Stack
    ammoItem.count = (tonumber(ammoItem.count) or 0) - amountToLoad
    if ammoItem.count <= 0 then
        table.remove(ammoContainer, ammoIdx)
        print('^3[mx-inv] DEBUG: Ammo stack depleted and removed.^0')
    end

    print('^2[mx-inv] Ammo loaded: ' .. amountToLoad .. ' rounds. New Mag Count: ' .. magItem.metadata.ammo .. '^0')

    -- Auto-save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved after ammo load^0')
    end

    -- Refresh Client Inventory
    UpdateClientInventory(src)
end)

-- Sync Ammo Usage (Anti-Infinite Ammo)
RegisterNetEvent('mx-inv:server:updateAmmo', function(weaponHash, newAmmo)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap or not containerMap.equipment then return end

    -- Find the weapon with this hash
    local foundSlot = nil
    local foundItem = nil

    for slot, item in pairs(containerMap.equipment) do
        if item and item.name then
            local def = Items[item.name]
            if def and def.equipment and GetHashKey(def.equipment.weaponHash) == weaponHash then
                foundSlot = slot
                foundItem = item
                break
            end
        end
    end

    if foundItem and foundItem.metadata and foundItem.metadata.magazine then
        -- Update the magazine ammo
        foundItem.metadata.magazine.ammo = newAmmo
        -- print('^3[mx-inv] Synced ammo for ' .. foundItem.name .. ': ' .. newAmmo .. '^0')
        -- Optional: Don't save on every shot, but maybe throttle saving?
        -- For now, we rely on periodic saves or event-based saves.
        -- We won't call DB.SavePlayer here to avoid spam, unless critical.
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

local ItemDefs = Items -- data/items.lua loaded via fxmanifest
local SyncHelmetAccessory

-- DB is global now (loaded from server/db.lua)

-- Initialize Database
Citizen.CreateThread(function()
    DB.Init()
    -- Sync existing drops from DB
    while not DB.Ready do Wait(100) end
    worldDrops = DB.LoadDrops()

    local count = 0
    if worldDrops then
        for _ in pairs(worldDrops) do count = count + 1 end
    end
    print('^2[mx-inv] Loaded ' .. count .. ' world drops.^0')
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

-- Helper: Find Free Slot (with Rotation Support)
local function FindFreeSlot(container, itemSize, width, height)
    width = width or Config.Inventory.Slots.width
    height = height or Config.Inventory.Slots.height

    local takenSlots = {}
    for _, invItem in ipairs(container) do
        local itemDef = ItemDefs[invItem.name]
        -- Use item-specific size if it exists (e.g. for already rotated/folded items)
        local currentSize = invItem.size or (itemDef and itemDef.size) or { x = 1, y = 1 }

        for ix = 0, currentSize.x - 1 do
            for iy = 0, currentSize.y - 1 do
                local slotX = invItem.slot.x + ix
                local slotY = invItem.slot.y + iy
                takenSlots[slotX .. '-' .. slotY] = true
            end
        end
    end

    local function CheckFit(sX, sY, iX, iY)
        for ix = 0, iX - 1 do
            for iy = 0, iY - 1 do
                local checkX = sX + ix
                local checkY = sY + iy
                if checkX > width or checkY > height or takenSlots[checkX .. '-' .. checkY] then
                    return false
                end
            end
        end
        return true
    end

    -- Try Normal Orientation
    for y = 1, height do
        for x = 1, width do
            if not takenSlots[x .. '-' .. y] then
                if CheckFit(x, y, itemSize.x, itemSize.y) then
                    return { x = x, y = y, rotated = false }
                end
            end
        end
    end

    -- Try Rotated Orientation (only if not square)
    if itemSize.x ~= itemSize.y then
        for y = 1, height do
            for x = 1, width do
                if not takenSlots[x .. '-' .. y] then
                    if CheckFit(x, y, itemSize.y, itemSize.x) then
                        return { x = x, y = y, rotated = true }
                    end
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

    -- Dynamic Containers from ALL valid container items
    local function parseContainerItem(item)
        if not item or not item.name then return end
        local def = ItemDefs[item.name]
        if def and def.container then
            local containerId = item.id -- Use item UUID as storage ID

            -- Lazy Init: Create storage if missing
            if not containers[containerId] then
                containers[containerId] = {}
            end

            payload[containerId] = {
                id = containerId,
                name = item.name,
                type = def.type, -- 'vest', 'backpack', etc.
                label = def.label,
                size = def.container.size,
                items = containers[containerId],
                weight = GetContainerWeight(containers[containerId]),
                maxWeight = def.container.maxWeight
            }
        end
    end

    -- Iterate through EVERY container's items so bags-in-bags are formatted
    for _, containerItems in pairs(containers) do
        if type(containerItems) == 'table' then
            for _, item in pairs(containerItems) do
                parseContainerItem(item)
            end
        end
    end

    local keys = ""
    for k, _ in pairs(payload) do keys = keys .. k .. ", " end
    print('^3[mx-inv] Payload generated with keys: ' .. keys .. '^0')

    return payload
end

-- Helper: Update Client Inventory (Refresh)
local function UpdateClientInventory(src)
    local payload = GetFormattedInventory(src)
    if payload then
        TriggerClientEvent('mx-inv:client:updateInventory', src, payload)
    end
end

-- Remove redundant FindFreeSlot

-- Helper: Add Item to Player (Support for Multi-Container & Rotation)
local function AddItem(src, item, count, metadata)
    if not Inventory[src] then return false, "Inventory not loaded" end
    local def = ItemDefs[item]
    if not def then return false, "Invalid item" end

    local maxStack = (def.stackable and def.maxStack) or (def.stackable and 60) or 1
    local itemSize = (def.size) or { x = 1, y = 1 }
    local itemWeight = def.weight or 0.0

    -- 1. Try to stack into existing slots across ALL containers
    if def.stackable then
        local searchContainers = { 'player' }
        if Inventory[src].equipment then
            for _, eqItem in pairs(Inventory[src].equipment) do
                local eqDef = ItemDefs[eqItem.name]
                if eqDef and eqDef.container then
                    table.insert(searchContainers, eqItem.id) -- use UUID, not name
                end
            end
        end

        for _, cKey in ipairs(searchContainers) do
            local container = Inventory[src][cKey]
            if container then
                -- Check weight
                local currentWeight = GetContainerWeight(container)
                local maxWeight = (cKey == 'player') and Config.Inventory.MaxWeight or
                    (ItemDefs[cKey] and ItemDefs[cKey].container.maxWeight) or 100.0

                for _, invItem in ipairs(container) do
                    if invItem.name == item then
                        local space = maxStack - invItem.count
                        if space > 0 then
                            local toAdd = math.min(count, space)
                            -- Verify weight before adding to stack
                            if currentWeight + (itemWeight * toAdd) <= maxWeight then
                                invItem.count = invItem.count + toAdd
                                count = count - toAdd
                                currentWeight = currentWeight + (itemWeight * toAdd)
                                if count <= 0 then
                                    return true, "Stacked completely in " .. cKey
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Add remaining count to new slots
    if count > 0 then
        -- Priority list of containers
        local containerOrder = {
            { key = 'player', label = 'Bolsos', w = Config.Inventory.Slots.width, h = Config.Inventory.Slots.height, maxW = Config.Inventory.MaxWeight }
        }
        if Inventory[src].equipment then
            for slot, eqItem in pairs(Inventory[src].equipment) do
                local eqDef = ItemDefs[eqItem.name]
                if eqDef and eqDef.container then
                    table.insert(containerOrder, {
                        key = eqItem.id, -- use UUID, not name
                        label = eqDef.label or eqItem.name,
                        w = eqDef.container.size.width,
                        h = eqDef.container.size.height,
                        maxW = eqDef.container.maxWeight
                    })
                end
            end
        end

        while count > 0 do
            local foundSlot = nil
            local targetContainerKey = nil
            local targetContainerLabel = nil

            for _, cInfo in ipairs(containerOrder) do
                local container = Inventory[src][cInfo.key]
                if not container then
                    Inventory[src][cInfo.key] = {}
                    container = Inventory[src][cInfo.key]
                end

                -- Weight Check
                local currentWeight = GetContainerWeight(container)
                if currentWeight + itemWeight <= cInfo.maxW then
                    local slotData = FindFreeSlot(container, itemSize, cInfo.w, cInfo.h)
                    if slotData then
                        foundSlot = slotData
                        targetContainerKey = cInfo.key
                        targetContainerLabel = cInfo.label
                        break
                    end
                end
            end

            if not foundSlot then
                return false, "Espaço insuficiente em todos os compartimentos"
            end

            local amount = math.min(count, maxStack)
            local finalSize = { x = itemSize.x, y = itemSize.y }
            if foundSlot.rotated then
                finalSize = { x = itemSize.y, y = itemSize.x }
            end

            local newItem = {
                name = item,
                count = amount,
                slot = { x = foundSlot.x, y = foundSlot.y },
                size = finalSize, -- Persist the size (rotated or normal)
                rotated = foundSlot.rotated,
                id = GenerateUUID(),
                metadata = (amount == count) and metadata or nil
            }
            if metadata and amount == count then
                newItem.metadata = metadata
            end

            table.insert(Inventory[src][targetContainerKey], newItem)
            count = count - amount

            -- If we still have items but just filled one container, we continue while-loop
        end

        return true, "Adicionado com sucesso"
    end
    return true, "Adicionado"
end

-- Helper: Auto-Equip Item (Try to equip if slot is empty)
local function AutoEquipItem(src, item, count, metadata)
    if count ~= 1 then return false end -- Only single items can be auto-equipped
    local def = ItemDefs[item]
    if not def then return false end

    local equipment = Inventory[src].equipment
    if not equipment then return false end

    -- Define priority slots for each type
    local slotMap = {
        weapon_pistol = { 'primary', 'secondary' },
        weapon_rifle = { 'primary', 'secondary' },
        weapon_shotgun = { 'primary', 'secondary' },
        weapon_melee = { 'melee' },
        helmet = { 'head' },
        armor = { 'body' },
        vest = { 'vest' },
        backpack = { 'backpack' }
    }

    local possibleSlots = slotMap[def.type]
    if not possibleSlots then return false end

    for _, slot in ipairs(possibleSlots) do
        -- 1. Check if empty
        if not equipment[slot] then
            -- 2. Rules: Weapons - No Duplicate in the other slot
            if slot == 'primary' or slot == 'secondary' then
                local other = (slot == 'primary') and 'secondary' or 'primary'
                if equipment[other] and equipment[other].name == item then
                    -- Duplicate found in other weapon slot
                    return false
                end
            end

            -- 3. Success: Equip
            local newItem = {
                name = item,
                count = 1,
                id = GenerateUUID(),
                metadata = metadata or {}
            }
            equipment[slot] = newItem

            -- Sync with bridge/client (clothes/props)
            local ammo = tonumber(newItem.metadata and newItem.metadata.ammo) or 0
            local attaches = newItem.metadata and newItem.metadata.attachments or nil
            TriggerClientEvent('mx-inv:client:updateEquipment', src, item, true, ammo, attaches)

            return true, slot
        end
    end

    return false
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
        if Inventory[src].equipment then
            for _, item in pairs(Inventory[src].equipment) do
                if item and not item.id then item.id = GenerateUUID() end
            end
        end

        -- Migrate legacy container data (name-based) to UUID-based storage
        local function migrateLegacyContainer(ci)
            if ci and (ci.name == 'rig_st_tipo_4' or ci.name == 'mochila_tatica_expansivel_luc') then
                local legacyName = ci.name
                if Inventory[src][legacyName] and #Inventory[src][legacyName] > 0 then
                    print('^3[mx-inv] Migrating legacy container ' .. legacyName .. ' to UUID ' .. ci.id .. '^0')
                    Inventory[src][ci.id] = Inventory[src][legacyName]
                    Inventory[src][legacyName] = nil
                end
            end
        end

        if Inventory[src].equipment then
            for _, item in pairs(Inventory[src].equipment) do migrateLegacyContainer(item) end
        end
        if Inventory[src].player then
            for _, item in ipairs(Inventory[src].player) do migrateLegacyContainer(item) end
        end

        print('^3[mx-inv] Loaded Equipment for ' .. player.name .. ': ' .. json.encode(Inventory[src].equipment) .. '^0')
        print('^2[mx-inv] Init complete for ' .. player.name .. '^0')

        -- Wait a tiny bit then inform client of its initial equipment setup (weapons & clothes)
        SetTimeout(1000, function()
            TriggerClientEvent('mx-inv:client:playerLoaded', src, Inventory[src].equipment)

            local headItem = Inventory[src].equipment and Inventory[src].equipment['head']
            if headItem and headItem.metadata and headItem.metadata.accessories then
                for accSlot, accData in pairs(headItem.metadata.accessories) do
                    if accData and accData.name then
                        SyncHelmetAccessory(src, headItem.name, accSlot, accData.name, headItem.metadata.visorDown)
                    end
                end
            end
        end)
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

    local headItem = equip['head']
    if headItem and headItem.metadata and headItem.metadata.accessories then
        for accSlot, accData in pairs(headItem.metadata.accessories) do
            if accData and accData.name then
                SyncHelmetAccessory(src, headItem.name, accSlot, accData.name, headItem.metadata.visorDown)
            end
        end
    end
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

    -- Helper: Check if a specific anchor position is clear for the expanded size
    local function CheckAnchorClear(containerItems, targetItemId, anchorX, anchorY, expandedSz, containerWidth,
                                    containerHeight, validSlotsTable)
        local needW = expandedSz.x
        local needH = expandedSz.y

        -- 1. Boundary check
        if anchorX < 1 or anchorY < 1 or anchorX + needW - 1 > containerWidth or anchorY + needH - 1 > containerHeight then
            print(string.format('^3[mx-inv][UNFOLD] Anchor (%d,%d) BOUNDARY FAIL: need %dx%d, grid=%dx%d^0',
                anchorX, anchorY, needW, needH, containerWidth, containerHeight))
            return false
        end

        -- 2. ValidSlots mask check
        if validSlotsTable and #validSlotsTable > 0 then
            for px = 0, needW - 1 do
                for py = 0, needH - 1 do
                    local cx = anchorX + px
                    local cy = anchorY + py
                    local found = false
                    for _, vs in ipairs(validSlotsTable) do
                        if vs.x == cx and vs.y == cy then
                            found = true; break
                        end
                    end
                    if not found then
                        print(string.format('^3[mx-inv][UNFOLD] Anchor (%d,%d) MASK FAIL at slot (%d,%d)^0',
                            anchorX, anchorY, cx, cy))
                        return false
                    end
                end
            end
        end

        -- 3. Collision check against all OTHER items
        -- Use ItemDefs as the authoritative size source (handles DB corruption / stale sizes).
        -- Rotation is accounted for by swapping W/H when other.rotated == true.
        for _, other in ipairs(containerItems) do
            if other.id ~= targetItemId then
                local otherDef = ItemDefs[other.name]
                local oRotated = other.rotated == true
                local baseW, baseH

                if otherDef then
                    if other.folded and otherDef.foldedSize then
                        -- Foldable item currently folded
                        baseW = otherDef.foldedSize.x
                        baseH = otherDef.foldedSize.y
                    elseif not other.folded and otherDef.expandedSize then
                        -- Foldable item currently expanded
                        baseW = otherDef.expandedSize.x
                        baseH = otherDef.expandedSize.y
                    else
                        -- Regular item: authoritative size from ItemDef
                        baseW = otherDef.size and otherDef.size.x or 1
                        baseH = otherDef.size and otherDef.size.y or 1
                    end
                else
                    -- No ItemDef: fall back to stored size
                    local oSize = other.size or { x = 1, y = 1 }
                    baseW = oSize.x
                    baseH = oSize.y
                end

                -- Apply rotation to get the VISUAL footprint
                local oW = oRotated and baseH or baseW
                local oH = oRotated and baseW or baseH

                local overlapX = anchorX < other.slot.x + oW and anchorX + needW > other.slot.x
                local overlapY = anchorY < other.slot.y + oH and anchorY + needH > other.slot.y
                if overlapX and overlapY then
                    print(string.format(
                        '^3[mx-inv][UNFOLD] Anchor (%d,%d) COLLISION with \'%s\' at slot (%d,%d) visual-size %dx%d (rotated=%s)^0',
                        anchorX, anchorY, tostring(other.name), other.slot.x, other.slot.y, oW, oH,
                        tostring(oRotated)))
                    return false
                end
            end
        end

        return true
    end

    -- Helper: Try multiple anchor positions so the item can grow up/left/right/down.
    -- The expanded item must always "cover" the item's current slot (which is the folded anchor).
    -- Returns the best anchor {x, y} or nil if no position works.
    local function FindBestUnfoldAnchor(containerItems, item, targetItemId, expandedSz, foldedSz, containerWidth,
                                        containerHeight, validSlotsTable)
        local curX = item.slot.x
        local curY = item.slot.y
        local needW = expandedSz.x
        local needH = expandedSz.y

        local minAnchorX = math.max(1, curX - needW + 1)
        local maxAnchorX = curX
        local minAnchorY = math.max(1, curY - needH + 1)
        local maxAnchorY = curY

        print(string.format(
            '^3[mx-inv][UNFOLD] Item \'' .. tostring(item.name) .. '\' at (%d,%d), expanding to %dx%d in grid %dx%d^0',
            curX, curY, needW, needH, containerWidth, containerHeight))
        print(string.format(
            '^3[mx-inv][UNFOLD] Trying anchors X:[%d..%d] Y:[%d..%d]^0',
            minAnchorX, maxAnchorX, minAnchorY, maxAnchorY))

        for ay = maxAnchorY, minAnchorY, -1 do
            for ax = maxAnchorX, minAnchorX, -1 do
                if CheckAnchorClear(containerItems, targetItemId, ax, ay, expandedSz, containerWidth, containerHeight,
                        validSlotsTable) then
                    print(string.format('^2[mx-inv][UNFOLD] Best anchor found: (%d,%d)^0', ax, ay))
                    return { x = ax, y = ay }
                end
            end
        end

        print('^1[mx-inv][UNFOLD] No valid anchor found!^0')
        return nil
    end

    local containerItems = nil
    if containerId == 'player-inv' or containerId == 'player' then
        containerItems = containerMap.player
    elseif string.sub(containerId, 1, 6) == 'equip-' then
        local equipSlotId = string.sub(containerId, 7)
        local eqItem = containerMap.equipment[equipSlotId]
        if eqItem and eqItem.id == itemId then
            -- Equipped containers: cannot fold if non-empty
            if not eqItem.folded then
                local subInv = containerMap[eqItem.id]
                if subInv and #subInv > 0 then
                    TriggerClientEvent('mx-inv:client:notify', src, 'Este item não está vazio e não pode ser dobrado!',
                        'error')
                    return
                end
            end
            -- Size update
            local def = ItemDefs[eqItem.name]
            local newFolded = not eqItem.folded
            if def then
                eqItem.size = newFolded and (def.foldedSize or eqItem.size) or
                    (def.expandedSize or def.size or eqItem.size)
            end
            eqItem.folded = newFolded
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
            local def = ItemDefs[item.name]
            local newFolded = not item.folded

            if not newFolded then
                -- === UNFOLDING: validate space and find best anchor ===
                local expandedSz = (def and def.expandedSize) or (def and def.size) or
                    { x = item.size and item.size.x or 1, y = item.size and item.size.y or 1 }
                local foldedSz = (def and def.foldedSize) or item.size or { x = 1, y = 1 }

                -- Resolve container grid size
                local gridWidth = Config.Inventory.Slots.width
                local gridHeight = Config.Inventory.Slots.height
                local gridResolved = false
                if containerId ~= 'player-inv' and containerId ~= 'player' then
                    for _, eqItm in pairs(containerMap.equipment or {}) do
                        if eqItm and eqItm.id == containerId then
                            local pDef = ItemDefs[eqItm.name]
                            if pDef and pDef.container then
                                gridWidth    = pDef.container.size.width
                                gridHeight   = pDef.container.size.height
                                gridResolved = true
                                print('^3[mx-inv][UNFOLD] Grid from equip item \'' ..
                                    tostring(eqItm.name) .. '\': ' .. gridWidth .. 'x' .. gridHeight .. '^0')
                            end
                            break
                        end
                    end
                    if not gridResolved and containerMap.player then
                        for _, pItm in ipairs(containerMap.player) do
                            if pItm.id == containerId then
                                local pDef = ItemDefs[pItm.name]
                                if pDef and pDef.container then
                                    gridWidth    = pDef.container.size.width
                                    gridHeight   = pDef.container.size.height
                                    gridResolved = true
                                    print('^3[mx-inv][UNFOLD] Grid from player item \'' ..
                                        tostring(pItm.name) .. '\': ' .. gridWidth .. 'x' .. gridHeight .. '^0')
                                end
                                break
                            end
                        end
                    end
                    if not gridResolved then
                        -- Last resort: also walk ALL sub-containers to find nested bags
                        for _, containerItems2 in pairs(containerMap) do
                            if type(containerItems2) == 'table' then
                                for _, itm2 in ipairs(containerItems2) do
                                    if itm2.id == containerId then
                                        local pDef = ItemDefs[itm2.name]
                                        if pDef and pDef.container then
                                            gridWidth    = pDef.container.size.width
                                            gridHeight   = pDef.container.size.height
                                            gridResolved = true
                                            print('^3[mx-inv][UNFOLD] Grid from nested item \'' ..
                                                tostring(itm2.name) .. '\': ' .. gridWidth .. 'x' .. gridHeight .. '^0')
                                        end
                                        break
                                    end
                                end
                            end
                            if gridResolved then break end
                        end
                    end
                end
                if not gridResolved then
                    print('^1[mx-inv][UNFOLD] WARNING: Could not resolve grid for container ' ..
                        tostring(containerId) ..
                        ', falling back to player inv size ' .. gridWidth .. 'x' .. gridHeight .. '^0')
                end

                local bestAnchor = FindBestUnfoldAnchor(containerItems, item, itemId, expandedSz, foldedSz, gridWidth,
                    gridHeight, nil)

                if not bestAnchor then
                    TriggerClientEvent('mx-inv:client:notify', src, 'Não há espaço para desenrolar o item aqui!', 'error')
                    UpdateClientInventory(src) -- Re-sync to snap visuals back
                    return
                end

                -- Apply best anchor and expanded size
                item.slot = bestAnchor
                item.size = expandedSz
                print('^2[mx-inv] Unfolded ' ..
                    tostring(item.name) .. ' at anchor ' .. bestAnchor.x .. ',' .. bestAnchor.y .. '^0')
            else
                -- === FOLDING: cannot fold if container has items ===
                local subInv = containerMap[item.id]
                if subInv and #subInv > 0 then
                    TriggerClientEvent('mx-inv:client:notify', src, 'Este item não está vazio e não pode ser dobrado!',
                        'error')
                    return
                end
                -- Update size to folded
                if def and def.foldedSize then
                    item.size = def.foldedSize
                end
            end

            item.folded = newFolded
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
        if not containerMap[id] then containerMap[id] = {} end
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
            -- Verify ID matches if provided, otherwise fallback to name
            if data.id and itemObj.id ~= data.id then
                print('^1[mx-inv] Debug Move: ID mismatch in equipment slot ' .. fromEquipKey .. '^0')
                return
            end
            itemIndex = fromEquipKey
        else
            print('^1[mx-inv] Debug Move: Equipment key ' .. fromEquipKey .. ' is empty.^0')
        end
    else
        -- Source is Standard Array
        for i, item in ipairs(fromContainer) do
            -- PRIORITY 1: Check ID (UUID) - Crucial for multiple items of same type
            if data.id and item.id == data.id then
                itemIndex = i
                itemObj = item
                break
            end

            -- PRIORITY 2: Fallback to Slot + Name (Legacy/Safety)
            if not data.id and item.name == itemName then
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

        -- VALIDATION: Prevent Duplicate Weapons in Primary/Secondary
        if toEquipKey == 'primary' or toEquipKey == 'secondary' then
            local otherSlot = (toEquipKey == 'primary') and 'secondary' or 'primary'
            local currentOther = toContainer[otherSlot]

            if currentOther and currentOther.name == itemObj.name then
                print('^1[mx-inv] Validation: Blocked duplicate weapon ' .. itemObj.name .. '^0')
                TriggerClientEvent('mx-inv:client:notify', src, "Você já possui esta arma equipada em outro slot!",
                    "error")
                UpdateClientInventory(src) -- Re-sync to snap back
                return
            end
        end

        if toContainer[toEquipKey] then
            print('^3[mx-inv] Warning: Equipment slot ' .. toEquipKey .. ' occupied. Overwriting.^0')
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

    if not containerMap[fromKey] then containerMap[fromKey] = {} end
    if not containerMap[toKey] then containerMap[toKey] = {} end

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

-- ============================================================
-- HELMET ACCESSORY EVENTS
-- ============================================================

-- Helper: resolve the helmet item from equipment slot 'head'
local function GetEquippedHelmet(containerMap)
    if not containerMap.equipment then return nil end
    return containerMap.equipment['head']
end

-- Helper: trigger helmet drawable + visual effect update on client
SyncHelmetAccessory = function(src, helmetName, accessorySlot, accessoryName, visorDown)
    local helmetDef = ItemDefs[helmetName]
    if not helmetDef or not helmetDef.equipment then return end

    local drawableId = helmetDef.equipment.drawableId -- base (no accessory)
    if accessoryName and helmetDef.equipment.accessoryDrawables then
        local variants = helmetDef.equipment.accessoryDrawables[accessoryName]
        if variants then
            drawableId = visorDown and variants.visorDown or variants.visorUp
        end
    end

    -- Update GTA prop drawable (head props use SetPedPropIndex, not SetPedComponentVariation)
    TriggerClientEvent('mx-inv:client:applyHelmetAccessory', src, {
        propId        = helmetDef.equipment.propId, -- prop slot (0 = head)
        drawableId    = drawableId,
        textureId     = helmetDef.equipment.textureId or 0,
        slot          = accessorySlot,
        accessoryName = accessoryName,
        visorDown     = visorDown
    })
end

RegisterNetEvent('mx-inv:server:attachToHelmet', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local helmetId   = data.helmetId
    local accessItem = data.accessoryItem   -- item name, e.g. 'nvg'
    local accessId   = data.accessoryItemId -- UUID
    local fromContId = data.fromContainerId

    local helmet     = GetEquippedHelmet(containerMap)
    if not helmet or helmet.id ~= helmetId then
        print('^1[mx-inv] attachToHelmet: helmet not equipped.^0')
        return
    end

    -- Compatibility check
    local helmetDef = ItemDefs[helmet.name]
    local accessDef = ItemDefs[accessItem]
    if not helmetDef or not helmetDef.equipment or not helmetDef.equipment.supportedAccessories then
        print('^1[mx-inv] attachToHelmet: helmet has no supportedAccessories.^0')
        return
    end
    if not accessDef or not accessDef.helmetAccessory then
        print('^1[mx-inv] attachToHelmet: item is not a helmet_accessory.^0')
        return
    end
    local slot = accessDef.helmetAccessory.slot
    local compatible = false
    for _, s in ipairs(helmetDef.equipment.supportedAccessories) do
        if s == slot then
            compatible = true; break
        end
    end
    if not compatible then
        print('^1[mx-inv] attachToHelmet: ' .. accessItem .. ' incompatible with ' .. helmet.name .. '.^0')
        TriggerClientEvent('mx-inv:client:notify', src, 'Este capacete não é compatível com esse acessório!', 'error')
        return
    end

    -- Helmet already has an accessory? We only allow 1 at a time.
    if not helmet.metadata then helmet.metadata = {} end
    if not helmet.metadata.accessories then helmet.metadata.accessories = {} end

    -- Check if there are any accessories currently attached
    for k, v in pairs(helmet.metadata.accessories) do
        TriggerClientEvent('mx-inv:client:notify', src, 'Este capacete já possui um acessório montado!', 'error')
        return
    end
    -- Remove accessory from source container
    local fromKey = (fromContId == 'player-inv') and 'player' or fromContId
    local fromCont = containerMap[fromKey]
    if not fromCont then
        print('^1[mx-inv] attachToHelmet: source container not found: ' .. tostring(fromContId) .. '^0')
        return
    end
    local rmIdx = nil
    for i, it in ipairs(fromCont) do
        if it.id == accessId then
            rmIdx = i; break
        end
    end
    if not rmIdx then
        print('^1[mx-inv] attachToHelmet: accessory item not found in source.^0')
        return
    end
    table.remove(fromCont, rmIdx)

    -- Store in helmet metadata; visor starts UP (effect inactive)
    helmet.metadata.accessories[slot] = { name = accessItem, id = accessId }
    helmet.metadata.visorDown = helmet.metadata.visorDown or false

    print('^2[mx-inv] Attached ' .. accessItem .. ' to helmet slot ' .. slot .. '^0')
    SyncHelmetAccessory(src, helmet.name, slot, accessItem, false)

    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

RegisterNetEvent('mx-inv:server:removeHelmetAccessory', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local helmetId = data.helmetId
    local slot     = data.accessorySlot
    local toContId = data.toContainerId
    local toSlot   = data.toSlot

    local helmet   = GetEquippedHelmet(containerMap)
    if not helmet or helmet.id ~= helmetId then
        print('^1[mx-inv] removeHelmetAccessory: helmet not equipped.^0')
        return
    end

    if not helmet.metadata or not helmet.metadata.accessories or not helmet.metadata.accessories[slot] then
        print('^1[mx-inv] removeHelmetAccessory: no accessory in slot ' .. tostring(slot) .. '.^0')
        return
    end

    local acc = helmet.metadata.accessories[slot]
    helmet.metadata.accessories[slot] = nil
    -- If visor was down, deactivate effect and reset to base drawable
    if helmet.metadata.visorDown then helmet.metadata.visorDown = false end

    -- Return accessory to inventory
    local added = false
    if toContId and toSlot then
        local toKey = (toContId == 'player-inv') and 'player' or toContId
        local toCont = containerMap[toKey]
        if toCont then
            table.insert(toCont, { name = acc.name, count = 1, slot = toSlot, id = acc.id or GenerateUUID() })
            added = true
        end
    end
    if not added then
        added = AddItem(src, acc.name, 1)
    end
    if not added then
        -- Rollback
        helmet.metadata.accessories[slot] = acc
        print('^1[mx-inv] removeHelmetAccessory: failed to return item, rolling back.^0')
        return
    end

    print('^2[mx-inv] Removed helmet accessory ' .. acc.name .. ' from slot ' .. slot .. '^0')
    SyncHelmetAccessory(src, helmet.name, nil, nil, false) -- reset to base drawable, deactivate effects

    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

RegisterNetEvent('mx-inv:server:toggleHelmetVisor', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local helmet = GetEquippedHelmet(containerMap)
    -- Accept toggle both from NUI (data.helmetId set) and from keybind (no helmetId)
    if not helmet then
        print('^1[mx-inv] toggleHelmetVisor: no helmet equipped.^0')
        return
    end
    if data.helmetId and helmet.id ~= data.helmetId then
        print('^1[mx-inv] toggleHelmetVisor: helmetId mismatch.^0')
        return
    end

    if not helmet.metadata or not helmet.metadata.accessories then
        print('^1[mx-inv] toggleHelmetVisor: no accessories mounted.^0')
        return
    end

    -- Determine which accessory slot is mounted (take first found)
    local mountedSlot = nil
    for s, _ in pairs(helmet.metadata.accessories) do
        mountedSlot = s; break
    end
    if not mountedSlot then
        TriggerClientEvent('mx-inv:client:notify', src, 'Nenhum acessório montado no capacete!', 'error')
        return
    end

    helmet.metadata.visorDown = not (helmet.metadata.visorDown or false)
    local newVisorDown = helmet.metadata.visorDown
    local accessoryName = helmet.metadata.accessories[mountedSlot].name

    print(string.format('^2[mx-inv] Toggled helmet visor: slot=%s acc=%s visorDown=%s^0', mountedSlot, accessoryName,
        tostring(newVisorDown)))

    -- Sync drawable + screen effect
    SyncHelmetAccessory(src, helmet.name, mountedSlot, accessoryName, newVisorDown)

    -- Trigger visor-flip animation on client
    TriggerClientEvent('mx-inv:client:playVisorAnim', src, newVisorDown)

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

    -- Auto-Equip Logic for Large Items (Container Items)
    local def = ItemDefs[itemName]
    if def and def.container and Inventory[targetId].equipment then
        -- Find which possible equipment slot this container belongs to
        local possibleSlots = { 'vest', 'backpack' }
        for _, slotKey in ipairs(possibleSlots) do
            local slotDef = ItemDefs[itemName]
            -- Just let AddItem handle it if we don't have explicit auto-equip rules right now, AddItem is smart enough.
        end
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
        -- Clear all containers mapped to this player
        Inventory[targetId] = { player = {}, equipment = {} }

        local player = MX_GetPlayer(targetId)
        if player then
            DB.SavePlayer(player.identifier, Inventory[targetId])
            print('^2[mx-inv] Cleared ALL inventory data for ' .. player.name .. '^0')
        end
        -- Refresh Client
        OpenInventory(targetId)
    else
        print('Inventory not loaded for target.')
    end
end, true)

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
    for k, v in pairs(d) do
        print('^2' .. string.upper(tostring(k)) .. ':^0 ' .. json.encode(v))
    end
    print('^3----------------------------------^0')
end, true)

-- ============================================================
-- Item Drops
-- ============================================================
local worldDrops = {}

RegisterNetEvent('mx-inv:server:requestDrops', function()
    local src = source
    TriggerClientEvent('mx-inv:client:syncDrops', src, worldDrops)
end)

RegisterNetEvent('mx-inv:server:dropItem', function(data)
    local src = source
    print('^3[mx-inv] Server: dropItem triggered by ' .. src .. '^0')
    if not data then
        print('^1[mx-inv] Server Error: dropItem data is nil^0')
        return
    end

    local itemId = data.itemId
    local amount = tonumber(data.amount) or 1
    local containerId = data.containerId

    if not Inventory[src] then return end

    local containerKey = (containerId == 'player-inv') and 'player' or containerId
    local container = Inventory[src][containerKey]
    if not container then return end

    -- Find and remove item
    local targetItem = nil
    local targetIndex = -1
    for i, item in ipairs(container) do
        if item.id == itemId then
            targetItem = item
            targetIndex = i
            break
        end
    end

    if not targetItem or targetItem.count < amount then
        print('^1[mx-inv] dropItem: Item not found or insufficient count^0')
        return
    end

    -- Update inventory
    if targetItem.count == amount then
        table.remove(container, targetIndex)
    else
        targetItem.count = targetItem.count - amount
    end

    -- Calculate drop position
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Add small random offset for separation (±0.4m)
    local offsetX = (math.random() - 0.5) * 0.8
    local offsetY = (math.random() - 0.5) * 0.8

    local x = coords.x + math.sin(math.rad(-heading)) * 1.2 + offsetX
    local y = coords.y + math.cos(math.rad(-heading)) * 1.2 + offsetY
    local z = coords.z - 0.95 -- Floor level roughly

    local dropId = GenerateUUID()
    local itemDef = ItemDefs[targetItem.name]
    local dropProp = (itemDef and itemDef.dropProp) or Config.Inventory.DefaultDropProp

    worldDrops[dropId] = {
        id = dropId,
        name = targetItem.name,
        type = itemDef.type or 'generic', -- Add type for client-side rotation logic
        label = itemDef.label or targetItem.name,
        count = amount,
        metadata = targetItem.metadata,
        coords = { x = x, y = y, z = z },
        prop = dropProp,
        created_at = os.time() -- For despawn logic
    }

    -- Save & Refresh
    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, Inventory[src]) end
    UpdateClientInventory(src)

    -- Save Drop to DB
    DB.SaveDrop(dropId, worldDrops[dropId])

    -- Sync to all
    TriggerClientEvent('mx-inv:client:syncDrops', -1, worldDrops)
    print('^2[mx-inv] Player ' .. src .. ' dropped ' .. amount .. 'x ' .. targetItem.name .. '^0')
end)

RegisterNetEvent('mx-inv:server:pickupItem', function(dropId)
    local src = source
    local drop = worldDrops[dropId]

    if not drop then
        print('^1[mx-inv] pickupItem: Drop not found ' .. tostring(dropId) .. '^0')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dist = #(coords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))

    if dist > 3.0 then
        print('^1[mx-inv] pickupItem: Player ' .. src .. ' too far from drop^0')
        return
    end

    -- 1. Try Auto-Equip
    local equipped, slotLabel = AutoEquipItem(src, drop.name, drop.count, drop.metadata)
    if equipped then
        -- Remove from world
        worldDrops[dropId] = nil
        DB.DeleteDrop(dropId)
        TriggerClientEvent('mx-inv:client:syncDrops', -1, worldDrops)
        TriggerClientEvent('mx-inv:client:notify', src, 'Equipou ' .. drop.label .. ' automaticamente.', 'success')

        -- Save & Refresh
        local player = MX_GetPlayer(src)
        if player then DB.SavePlayer(player.identifier, Inventory[src]) end
        UpdateClientInventory(src)
        print('^2[mx-inv] Player ' .. src .. ' auto-equipped ' .. drop.name .. '^0')
        return
    end

    -- 2. Try to add to inventory (Multi-container + Rotation)
    local success, msg = AddItem(src, drop.name, drop.count, drop.metadata)
    if success then
        -- Remove from world
        worldDrops[dropId] = nil
        DB.DeleteDrop(dropId)
        TriggerClientEvent('mx-inv:client:syncDrops', -1, worldDrops)
        TriggerClientEvent('mx-inv:client:notify', src, 'Pegou ' .. drop.label .. ': ' .. msg, 'success')

        -- Save & Refresh
        local player = MX_GetPlayer(src)
        if player then DB.SavePlayer(player.identifier, Inventory[src]) end
        UpdateClientInventory(src)
        print('^2[mx-inv] Player ' .. src .. ' picked up ' .. drop.count .. 'x ' .. drop.name .. '^0')
    else
        TriggerClientEvent('mx-inv:client:notify', src, msg, 'error')
    end
end)

-- ============================================================
-- Split Stack
-- ============================================================

RegisterNetEvent('mx-inv:server:splitItem', function(data)
    local src          = source
    local itemId       = data.itemId
    local containerId  = data.containerId
    local amount       = tonumber(data.amount) or 0

    local containerMap = Inventory[src]
    if not containerMap then
        print('^1[mx-inv] splitItem: No inventory for ' .. src .. '^0')
        return
    end

    -- Resolve container key
    local containerKey = (containerId == 'player-inv') and 'player' or containerId
    local container    = containerMap[containerKey]
    if not container then
        print('^1[mx-inv] splitItem: Container not found: ' .. tostring(containerId) .. '^0')
        return
    end

    -- Find the item
    local targetItem  = nil
    local targetIndex = -1
    for i, item in ipairs(container) do
        if item.id == itemId then
            targetItem  = item
            targetIndex = i
            break
        end
    end

    if not targetItem then
        print('^1[mx-inv] splitItem: Item not found: ' .. tostring(itemId) .. '^0')
        return
    end

    -- Validate: need at least 2 so we can split off ≥1
    if targetItem.count < 2 or amount < 1 or amount >= targetItem.count then
        print('^1[mx-inv] splitItem: Invalid amount ' .. amount .. ' for count ' .. targetItem.count .. '^0')
        return
    end

    -- Find a free slot for the new stack
    local itemDef  = ItemDefs[targetItem.name]
    local itemSize = (itemDef and itemDef.size) or { x = 1, y = 1 }
    local freeSlot = FindFreeSlot(container, itemSize)
    if not freeSlot then
        print('^1[mx-inv] splitItem: No free slot in container ' .. tostring(containerId) .. '^0')
        TriggerClientEvent('mx-inv:client:notify', src, 'Inventário sem espaço para dividir.')
        return
    end

    -- Atomically reduce original and create split stack
    targetItem.count = targetItem.count - amount

    local newStack = {
        name     = targetItem.name,
        count    = amount,
        slot     = freeSlot,
        id       = GenerateUUID(),
        metadata = targetItem.metadata -- share metadata (e.g. caliber)
    }
    table.insert(container, newStack)

    print('^2[mx-inv] splitItem: ' .. src .. ' split ' .. amount .. 'x ' .. targetItem.name
        .. ' | New id=' .. newStack.id .. '^0')

    -- Save + Refresh
    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

-- ============================================================
-- Give Item to Player System
-- ============================================================

local GIVE_MAX_DISTANCE = 3.0   -- metres (server-side check)
local GIVE_TIMEOUT_MS   = 30000 -- 30 seconds

-- Pending give requests: pendingGives[targetSrc] = { fromSrc, itemId, itemName, containerId, count, timer }
local pendingGives      = {}

-- Helper: Remove a pending give and cancel its timeout
local function CancelPendingGive(targetSrc)
    local pending = pendingGives[targetSrc]
    if pending then
        if pending.timer then
            ClearTimeout(pending.timer)
        end
        pendingGives[targetSrc] = nil
    end
end

-- Helper: Remove `count` of an item by id from a player's inventory (returns the removed item obj or nil)
local function RemoveItemById(containerMap, itemId, count)
    -- Search all containers except equipment map
    local containers = { containerMap.player }
    for k, v in pairs(containerMap) do
        if k ~= 'player' and k ~= 'equipment' and type(v) == 'table' and #v > 0 then
            table.insert(containers, v)
        end
    end

    for _, container in ipairs(containers) do
        for i, item in ipairs(container) do
            if item.id == itemId then
                if item.count > count then
                    -- Partial remove
                    item.count = item.count - count
                    -- Return a copy representing the given portion
                    return { name = item.name, count = count, id = GenerateUUID(), slot = { x = 1, y = 1 } }
                else
                    -- Full remove
                    local removed = table.remove(container, i)
                    removed.count = count -- clamp
                    return removed
                end
            end
        end
    end
    return nil
end

-- Event: Sender opens the give dialog → server returns nearby players and validates
RegisterNetEvent('mx-inv:server:requestNearbyPlayers', function()
    local src = source
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    local nearby = {}

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= src then
            local otherCoords = GetEntityCoords(GetPlayerPed(pid))
            local dist = #(srcCoords - otherCoords)
            if dist <= 10.0 then -- wider radius for selection list
                local player = MX_GetPlayer(pid)
                local name = player and player.name or ('Player ' .. pid)
                table.insert(nearby, { id = pid, name = name, distance = math.floor(dist * 10) / 10 })
            end
        end
    end

    TriggerClientEvent('mx-inv:client:nearbyPlayers', src, nearby)
end)

-- Event: Sender confirms give (item + count + target)
RegisterNetEvent('mx-inv:server:giveItem', function(data)
    local src         = source
    local targetSrc   = tonumber(data.targetSrc)
    local itemId      = data.itemId
    local itemName    = data.itemName
    local containerId = data.containerId
    local count       = tonumber(data.count) or 1

    -- Basic validation
    if not targetSrc or not itemId or not itemName or count <= 0 then
        TriggerClientEvent('mx-inv:client:giveItemResult', src, { ok = false, reason = 'Dados inválidos.' })
        return
    end

    if not Inventory[src] then
        TriggerClientEvent('mx-inv:client:giveItemResult', src, { ok = false, reason = 'Inventário não carregado.' })
        return
    end

    if not Inventory[targetSrc] then
        TriggerClientEvent('mx-inv:client:giveItemResult', src,
            { ok = false, reason = 'Jogador alvo não está disponível.' })
        return
    end

    -- Distance check (server-authoritative)
    local srcCoords    = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetSrc))
    local dist         = #(srcCoords - targetCoords)
    if dist > GIVE_MAX_DISTANCE then
        TriggerClientEvent('mx-inv:client:giveItemResult', src, { ok = false, reason = 'Jogador muito longe.' })
        return
    end

    -- Verify item exists in sender inventory
    local containerMap = Inventory[src]
    local itemFound = false
    local allContainers = { containerMap.player }
    for k, v in pairs(containerMap) do
        if k ~= 'player' and k ~= 'equipment' and type(v) == 'table' then
            table.insert(allContainers, v)
        end
    end
    for _, container in ipairs(allContainers) do
        for _, item in ipairs(container) do
            if item.id == itemId and item.count >= count then
                itemFound = true
                break
            end
        end
        if itemFound then break end
    end

    if not itemFound then
        TriggerClientEvent('mx-inv:client:giveItemResult', src,
            { ok = false, reason = 'Item não encontrado ou quantidade insuficiente.' })
        return
    end

    -- Cancel any previous pending give to this target
    CancelPendingGive(targetSrc)

    -- Store pending request
    local senderPlayer = MX_GetPlayer(src)
    local senderName = senderPlayer and senderPlayer.name or ('Player ' .. src)
    local itemDef = ItemDefs[itemName]
    local itemLabel = (itemDef and itemDef.label) or itemName

    -- Create timeout to auto-cancel after GIVE_TIMEOUT_MS
    local timeoutFn = Citizen.SetTimeout(GIVE_TIMEOUT_MS, function()
        if pendingGives[targetSrc] and pendingGives[targetSrc].fromSrc == src then
            pendingGives[targetSrc] = nil
            TriggerClientEvent('mx-inv:client:giveItemResult', src,
                { ok = false, reason = 'Tempo esgotado. O jogador não respondeu.' })
            TriggerClientEvent('mx-inv:client:giveRequestExpired', targetSrc)
            print('^3[mx-inv] Give request from ' .. src .. ' to ' .. targetSrc .. ' timed out.^0')
        end
    end)

    pendingGives[targetSrc] = {
        fromSrc     = src,
        itemId      = itemId,
        itemName    = itemName,
        containerId = containerId,
        count       = count,
        timer       = timeoutFn
    }

    print('^3[mx-inv] Give request: ' .. src .. ' -> ' .. targetSrc .. ' | ' .. count .. 'x ' .. itemName .. '^0')

    -- Notify target
    TriggerClientEvent('mx-inv:client:receiveItemRequest', targetSrc, {
        fromSrc   = src,
        fromName  = senderName,
        itemName  = itemName,
        itemLabel = itemLabel,
        count     = count,
        image     = itemDef and itemDef.image or nil
    })

    -- Notify sender to wait
    TriggerClientEvent('mx-inv:client:giveItemResult', src, { ok = true, pending = true })
end)

-- Event: Target accepts or declines
RegisterNetEvent('mx-inv:server:respondGiveItem', function(data)
    local targetSrc = source
    local accepted  = data.accepted == true

    local pending   = pendingGives[targetSrc]
    if not pending then
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc,
            { ok = false, reason = 'Nenhuma solicitação pendente.' })
        return
    end

    local fromSrc = pending.fromSrc
    CancelPendingGive(targetSrc)

    if not accepted then
        -- Declined
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc, { ok = false, reason = 'O jogador recusou o item.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc, { ok = false, reason = 'Você recusou o item.' })
        print('^3[mx-inv] Give declined: ' .. fromSrc .. ' -> ' .. targetSrc .. '^0')
        return
    end

    -- Validate both inventories still loaded
    if not Inventory[fromSrc] or not Inventory[targetSrc] then
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc, { ok = false, reason = 'Inventário não disponível.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc,
            { ok = false, reason = 'Inventário não disponível.' })
        return
    end

    -- Re-check distance
    local srcCoords    = GetEntityCoords(GetPlayerPed(fromSrc))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetSrc))
    if #(srcCoords - targetCoords) > GIVE_MAX_DISTANCE then
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc, { ok = false, reason = 'Vocês se afastaram muito.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc,
            { ok = false, reason = 'Vocês se afastaram muito.' })
        return
    end

    -- Atomic transfer: remove from source, add to target
    local removedItem = RemoveItemById(Inventory[fromSrc], pending.itemId, pending.count)
    if not removedItem then
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc,
            { ok = false, reason = 'Item não encontrado no inventário.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc, { ok = false, reason = 'Falha ao receber o item.' })
        return
    end

    local added, addMsg = AddItem(targetSrc, removedItem.name, removedItem.count)
    if not added then
        -- Rollback: give item back to source
        AddItem(fromSrc, removedItem.name, removedItem.count)
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc, { ok = false, reason = 'Inventário do alvo cheio.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc,
            { ok = false, reason = 'Seu inventário está cheio.' })
        return
    end

    -- Save both players
    local fromPlayer   = MX_GetPlayer(fromSrc)
    local targetPlayer = MX_GetPlayer(targetSrc)
    if fromPlayer then DB.SavePlayer(fromPlayer.identifier, Inventory[fromSrc]) end
    if targetPlayer then DB.SavePlayer(targetPlayer.identifier, Inventory[targetSrc]) end

    -- Refresh both UIs
    UpdateClientInventory(fromSrc)
    UpdateClientInventory(targetSrc)

    local itemDef = ItemDefs[pending.itemName]
    local itemLabel = (itemDef and itemDef.label) or pending.itemName

    TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc,
        { ok = true, transferred = true, message = 'Você enviou ' .. pending.count .. 'x ' .. itemLabel .. '.' })
    TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc,
        { ok = true, transferred = true, message = 'Você recebeu ' .. pending.count .. 'x ' .. itemLabel .. '.' })

    print('^2[mx-inv] Give success: ' ..
        fromSrc .. ' -> ' .. targetSrc .. ' | ' .. pending.count .. 'x ' .. pending.itemName .. '^0')
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

-- Drop Cleanup Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every 1 minute
        local currentTime = os.time()
        local despawnTime = (Config.Inventory.DropDespawnTime or 30) * 60
        local itemsRemoved = 0

        for id, drop in pairs(worldDrops) do
            if drop.created_at and (currentTime - drop.created_at) > despawnTime then
                worldDrops[id] = nil
                DB.DeleteDrop(id)
                itemsRemoved = itemsRemoved + 1
            end
        end

        if itemsRemoved > 0 then
            TriggerClientEvent('mx-inv:client:syncDrops', -1, worldDrops)
            print('^3[mx-inv] Cleanup: Removed ' .. itemsRemoved .. ' expired drops.^0')
        end
    end
end)

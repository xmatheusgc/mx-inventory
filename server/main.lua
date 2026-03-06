local ItemDefs = Items -- data/items.lua loaded via fxmanifest

-- Modules are loaded globally via fxmanifest.lua
-- InventoryAPI, MovementEngine, DropAPI, EquipmentAPI are now globally available

-- DB is global now (loaded from server/db.lua)

-- Initialize Database and Drops
Citizen.CreateThread(function()
    DB.Init()
end)

DropAPI.InitDrops()
DropAPI.StartCleanupThread()


Inventory = {}
InventoryAPI.InventoryMap = Inventory
ActiveStashes = StashAPI.ActiveStashes
PlayerOpenStash = StashAPI.PlayerOpenStash
math.randomseed(os.time())


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
            weight = InventoryAPI.GetContainerWeight(containers.player or {})
        },
        equipment = containers.equipment,
        itemDefs = ItemDefs
    }

    InventoryAPI.FormatPayloadContainers(containers, payload)

    local keys = ""
    for k, _ in pairs(payload) do keys = keys .. k .. ", " end

    -- IMPORTANT: Inject Open Stash if the player has one Active
    -- This prevents the stash from disappearing on moveItem/UpdateClientInventory
    if PlayerOpenStash then
        local stashId = PlayerOpenStash[src]
        if stashId and ActiveStashes and ActiveStashes[stashId] then
            local stash = ActiveStashes[stashId]
            -- Double check we haven't already added it (shouldn't be, since it's filtered from saves)
            payload[stashId] = {
                id = stashId,
                type = 'container',
                label = stash.label,
                size = stash.size,
                items = stash.items,
                weight = InventoryAPI.GetContainerWeight(stash.items),
                maxWeight = 999.0
            }
            keys = keys .. stashId .. "(STASH), "
        end
    end

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

-- Helper: Add Item to Player (Support for Multi-Container, Rotation & Specific Slot)
local function AddItem(src, item, count, metadata, targetSlot, targetContainerId, rotated, folded)
    if not Inventory[src] then return false, "Inventory not loaded" end
    local def = ItemDefs[item]
    if not def then return false, "Invalid item" end

    local maxStack = (def.stackable and def.maxStack) or (def.stackable and 60) or 1
    local itemSize = (def.size) or { x = 1, y = 1 }
    local itemWeight = def.weight or 0.0

    -- 0. SPECIFIC SLOT PLACEMENT (Used for Drag & Drop removals/moves)
    if targetSlot and targetContainerId then
        local tKey = (targetContainerId == 'player-inv') and 'player' or targetContainerId
        local container = Inventory[src][tKey]
        if container then
            -- Resolve Properties
            local props = InventoryAPI.GetContainerProperties(targetContainerId, Inventory[src])
            local currentWeight = InventoryAPI.GetContainerWeight(container)
            
            if currentWeight + (itemWeight * count) <= props.maxWeight then
                -- Use MovementEngine for robust CheckFit
                local success, err = MovementEngine.CheckFit(container, itemSize, tonumber(targetSlot.x), tonumber(targetSlot.y), props.width, props.height, nil, props.layout)

                if success then
                    local newItem = {
                        name = item,
                        count = count,
                        slot = { x = targetSlot.x, y = targetSlot.y },
                        size = { x = itemSize.x, y = itemSize.y },
                        rotated = rotated or false,
                        folded = folded or false,
                        id = InventoryAPI.GenerateUUID(),
                        metadata = metadata
                    }
                    table.insert(container, newItem)
                    print('^2[mx-inv] AddItem: Placed ' .. item .. ' into ' .. targetContainerId .. ' at ' .. targetSlot.x .. ',' .. targetSlot.y .. '^0')
                    return true, "Adicionado no slot específico", newItem.id
                else
                    print('^1[mx-inv] AddItem Failed: ' .. (err or "Invalid slot") .. '^0')
                end
            end
        end
        -- Fall back to auto-search if specific slot is occupied or failed weight or container not found
    end

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
                local currentWeight = InventoryAPI.GetContainerWeight(container)
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
                                    return true, "Stacked completely in " .. cKey, invItem.id
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
            { key = 'player', label = 'Bolsos', w = Config.Inventory.Slots.width, h = Config.Inventory.Slots.height, maxW = Config.Inventory.MaxWeight, layout = Config.Inventory.Slots.layout }
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
                        maxW = eqDef.container.maxWeight,
                        layout = eqDef.container.layout
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

                local currentWeight = InventoryAPI.GetContainerWeight(container)
                if currentWeight + itemWeight <= cInfo.maxW then
                    local slotData = MovementEngine.FindFreeSlot(container, itemSize, cInfo.w, cInfo.h, cInfo.layout)
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
            -- CRITICAL: Persist the BASE size (unrotated). The logic will rotate it based on the flag.
            local baseSizeToSave = { x = itemSize.x, y = itemSize.y }

            local newItem = {
                name = item,
                count = amount,
                slot = { x = foundSlot.x, y = foundSlot.y },
                size = baseSizeToSave,
                rotated = foundSlot.rotated,
                folded = folded or false,
                id = InventoryAPI.GenerateUUID(),
                metadata = (amount == count) and metadata or nil
            }
            if metadata and amount == count then
                newItem.metadata = metadata
            end

            table.insert(Inventory[src][targetContainerKey], newItem)
            count = count - amount

            -- If we still have items but just filled one container, we continue while-loop
            if count <= 0 then
                return true, "Adicionado com sucesso", newItem.id
            end
        end

        return true, "Adicionado com múltiplos slots"
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

    -- Define priority slots for each type (Fallback for AutoEquip)
    local slotPriority = {
        weapon_pistol = { 'pistol', 'primary', 'secondary' },
        weapon_rifle = { 'primary', 'secondary' },
        weapon_shotgun = { 'primary', 'secondary' },
        weapon_smg = { 'primary', 'secondary' },
        weapon_sniper = { 'primary', 'secondary' },
        weapon_melee = { 'melee' },
        helmet = { 'head' },
        armor = { 'body' },
        vest = { 'vest' },
        backpack = { 'backpack' }
    }

    local possibleSlots = slotPriority[def.type or itemObj.type]
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
                id = InventoryAPI.GenerateUUID(),
                metadata = metadata or {}
            }
            equipment[slot] = newItem

            -- Sync with bridge/client (clothes/props)
            local ammo = tonumber(newItem.metadata and newItem.metadata.ammo) or 0
            local attaches = newItem.metadata and newItem.metadata.attachments or nil
            TriggerClientEvent('mx-inv:client:updateEquipment', src, item, true, ammo, attaches)

            return true, slot, newItem.id
        end
    end

    return false
end

local function SanitizeInventory(inv)
    if not inv then return end
    local function sanitizeList(list)
        if not list then return end
        for _, item in pairs(list) do
            if item and item.name then
                local def = ItemDefs[item.name]
                if def then
                    -- Force correct base size from definition
                    item.size = { x = def.size.x, y = def.size.y }
                end
            end
        end
    end

    sanitizeList(inv.player)
    if inv.equipment then
        sanitizeList(inv.equipment)
    end
    -- Sanitizing secondary containers
    for k, v in pairs(inv) do
        if k ~= 'player' and k ~= 'equipment' and type(v) == 'table' then
            sanitizeList(v)
        end
    end
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
            Inventory[src].player = dbData
            print('^3[mx-inv] Loaded DB data (Array format).^0')
        end

        -- Call Sanitizer to fix any "dirty" sizes from previous bugs
        SanitizeInventory(Inventory[src])

        -- Initialize/Sanitize Secondary Containers
        -- Removed hardcoded initialization for dynamic system
        -- if not Inventory[src]['rig_st_tipo_4'] then Inventory[src]['rig_st_tipo_4'] = {} end
        -- if not Inventory[src]['mochila_tatica_expansivel_luc'] then Inventory[src]['mochila_tatica_expansivel_luc'] = {} end

        -- Initialize Equipment
        if not Inventory[src].equipment then Inventory[src].equipment = {} end

        -- Migration: Ensure all items have UUIDs
        if Inventory[src].player then
            for _, item in ipairs(Inventory[src].player) do
                if not item.id then item.id = InventoryAPI.GenerateUUID() end
            end
        end
        if Inventory[src].equipment then
            for _, item in pairs(Inventory[src].equipment) do
                if item and not item.id then item.id = InventoryAPI.GenerateUUID() end
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
                        EquipmentAPI.SyncHelmetAccessory(src, headItem.name, accSlot, accData.name, headItem.metadata.visorDown)
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
                EquipmentAPI.SyncHelmetAccessory(src, headItem.name, accSlot, accData.name, headItem.metadata.visorDown)
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
        weight = InventoryAPI.GetContainerWeight(containers.player or {})
    }

    local vestData = {
        id = 'rig_st_tipo_4',
        type = 'vest',
        label = 'ST Tipo 4',
        size = { ["width"] = 4, ["height"] = 10 },
        items = vestItems,
        weight = InventoryAPI.GetContainerWeight(vestItems)
    }

    local bagData = {
        id = 'mochila_tatica_expansivel_luc',
        type = 'bag',
        label = 'Mochila Tática Expansível Luc',
        size = { ["width"] = 5, ["height"] = 10 },
        items = containers['mochila_tatica_expansivel_luc'] or {},
        weight = InventoryAPI.GetContainerWeight(containers['mochila_tatica_expansivel_luc'] or {})
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

    -- Notify mx-survival-core about item consumption (non-breaking: no-op if survival not running)
    TriggerEvent('mx-survival:server:onItemConsumed', src, itemName, def.consume)

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
    elseif containerId and string.sub(containerId, 1, 6) == 'equip-' then
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
                -- === UNFOLDING ===
                local expandedSz = (def and def.expandedSize) or (def and def.size) or
                    { x = item.size and item.size.x or 1, y = item.size and item.size.y or 1 }

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
                                end
                                break
                            end
                        end
                    end
                    if not gridResolved then
                        for _, containerItems2 in pairs(containerMap) do
                            if type(containerItems2) == 'table' then
                                for _, itm2 in ipairs(containerItems2) do
                                    if itm2.id == containerId then
                                        local pDef = ItemDefs[itm2.name]
                                        if pDef and pDef.container then
                                            gridWidth    = pDef.container.size.width
                                            gridHeight   = pDef.container.size.height
                                            gridResolved = true
                                        end
                                        break
                                    end
                                end
                            end
                            if gridResolved then break end
                        end
                    end
                end

                -- Use Movement Engine to validate the unfold
                local success, err = MovementEngine.CheckFit(containerItems, expandedSz, item.slot.x, item.slot.y, gridWidth, gridHeight, item.id)
                local bestAnchor = success and { x = item.slot.x, y = item.slot.y, rotated = false } or nil

                if not bestAnchor then
                    -- Try finding another free slot
                    bestAnchor = MovementEngine.FindFreeSlot(containerItems, expandedSz, gridWidth, gridHeight)
                end

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
        if not id then return nil, nil end
        if id == 'player-inv' or id == 'player' then return containerMap.player, nil end
        
        if string.sub(id, 1, 6) == 'equip-' then
            local equipSlotId = string.sub(id, 7)
            if not containerMap.equipment then containerMap.equipment = {} end
            return containerMap.equipment, equipSlotId -- Return table, key
        end

        -- SECURITY VALIDATION: Prevent accessing closed stashes
        if string.sub(id, 1, 6) == 'stash_' then
            if PlayerOpenStash[src] == id and ActiveStashes[id] then
                return ActiveStashes[id].items, nil
            end
            print('^1[mx-inv] Security Alert: Player ' .. src .. ' attempted to access closed stash ' .. id .. '^0')
            return nil, nil
        end

        -- SECURITY VALIDATION: Prevent accessing closed drops
        if string.sub(id, 1, 5) == 'drop-' then
            if PlayerOpenDrop and PlayerOpenDrop[src] == id then
                if containerMap[id] then return containerMap[id], nil end
            end
            print('^1[mx-inv] Security Alert: Player ' .. src .. ' attempted to access closed drop ' .. id .. '^0')
            return nil, nil
        end

        -- Bag UUID (or other direct container ID)
        if containerMap[id] then
            return containerMap[id], nil
        end

        -- Fallback: Check if it's a UUID of an equipped item that IS a container
        if containerMap.equipment then
            for _, eqItem in pairs(containerMap.equipment) do
                if eqItem and eqItem.id == id then
                    local def = ItemDefs[eqItem.name]
                    if def and def.container then
                        containerMap[id] = {} -- Auto-initialize
                        return containerMap[id], nil
                    end
                end
            end
        end

        -- Check player pockets for the container item
        if containerMap.player then
            for _, pItem in ipairs(containerMap.player) do
                if pItem and pItem.id == id then
                    local def = ItemDefs[pItem.name]
                    if def and def.container then
                        containerMap[id] = {} -- Auto-initialize
                        return containerMap[id], nil
                    end
                end
            end
        end

        return nil, nil
    end

    local fromContainer, fromEquipKey = GetContainerAndSlot(fromId)
    local toContainer, toEquipKey = GetContainerAndSlot(toId)

    if not fromContainer then
        print('^1[mx-inv] Debug Move: Source ' .. tostring(fromId) .. ' not found.^0')
        UpdateClientInventory(src)
        return
    end
    if not toContainer and not toEquipKey then
        print('^1[mx-inv] Debug Move: Target ' .. tostring(toId) .. ' not found.^0')
        UpdateClientInventory(src)
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

    -- 2. Validate Target Weight & Position/Size
    if toEquipKey then
        -- Target is Equipment Slot
        print('^3[mx-inv] Debug Move: Target is EQUIPMENT key: ' .. toEquipKey .. '^0')

        -- VALIDATION: Check Slot Compatibility
        local itemDef = ItemDefs[itemObj.name]
        local itemType = (itemDef and itemDef.type) or itemObj.type or 'generic'
        local allowedTypes = Config.EquipmentSlots[toEquipKey]
        local isAllowed = false

        if allowedTypes then
            print('^3[mx-inv] Validation: checking compatibility for ' .. itemObj.name .. ' (type: ' .. tostring(itemType) .. ') against allowed: ' .. json.encode(allowedTypes) .. '^0')
            for _, allowedType in ipairs(allowedTypes) do
                if itemType == allowedType then
                    isAllowed = true
                    break
                end
            end
        else
            print('^3[mx-inv] Validation Warning: No restrictions defined for slot ' .. toEquipKey .. '. Fallback to ALLOW.^0')
            isAllowed = true -- If not defined, allow everything (fallback)
        end

        if not isAllowed then
            print('^1[mx-inv] Validation CRITICAL: Blocked item ' ..
                itemObj.name .. ' (type: ' .. tostring(itemType) .. ') in slot ' .. toEquipKey .. '^0')
            TriggerClientEvent('mx-inv:client:notify', src, "Este item não pode ser equipado neste slot!", "error")
            UpdateClientInventory(src)
            return -- STOP EXECUTION HERE
        end

        -- VALIDATION: Prevent Duplicate Weapons in Primary/Secondary
        if toEquipKey == 'primary' or toEquipKey == 'secondary' then
            local otherSlot = (toEquipKey == 'primary') and 'secondary' or 'primary'
            local currentOther = toContainer[otherSlot]

            if currentOther and currentOther.name == itemObj.name then
                print('^1[mx-inv] Validation: Blocked duplicate weapon ' .. itemObj.name .. '^0')
                TriggerClientEvent('mx-inv:client:notify', src, "Você já possui esta arma equipada em outro slot!", "error")
                UpdateClientInventory(src) -- Re-sync to snap back
                return
            end
        end

        if toContainer[toEquipKey] then
            local existingItem = toContainer[toEquipKey]
            print('^3[mx-inv] Equipment replacement: moving existing ' .. existingItem.name .. ' to source container ^0')
            
            -- Move existing item to where the new one was
            existingItem.slot = { x = itemObj.slot.x, y = itemObj.slot.y }
            existingItem.isEquipment = false
            table.insert(fromContainer, existingItem)
        end
    else
        -- Target is Standard Array
        
        -- Determine incoming item size (respecting its current or requested rotation/fold)
        local def = ItemDefs[itemObj.name]
        local baseSize = (def and def.size) or itemObj.size or { x = 1, y = 1 }
        local currentFold = (data.folded ~= nil) and data.folded or itemObj.folded
        if currentFold and def and def.foldedSize then
            baseSize = def.foldedSize
        end

        local testSize = { x = baseSize.x, y = baseSize.y }
        if data.rotated then
            testSize = { x = baseSize.y, y = baseSize.x }
        end
        local itemWeight = (def and def.weight) or 0.0

        if targetSlot and targetSlot.x and targetSlot.y then
            -- SPECIFIC SLOT REQUEST (Drag & Drop)
            local targetProps = InventoryAPI.GetContainerProperties(toId, containerMap)
            local gridWidth = targetProps.width
            local gridHeight = targetProps.height
            local toMaxWeight = targetProps.maxWeight
            local toLayout = targetProps.layout

            local currentToWeight = InventoryAPI.GetContainerWeight(toContainer)
            if Config.Debug then
                print('^3[mx-inv] moveItem DND: target=' .. toId .. ' resolved layout=' .. tostring(toLayout) .. '^0')
            end
            print('^3[mx-inv] Validation DND: target=' .. toId .. ' weight=' .. currentToWeight .. '/' .. toMaxWeight .. ' grid=' .. gridWidth .. 'x' .. gridHeight .. '^0')

            -- STRICT VALIDATION: Check Fit
            local success, err = MovementEngine.CheckFit(toContainer, testSize, tonumber(targetSlot.x), tonumber(targetSlot.y), gridWidth, gridHeight, itemObj.id, toLayout)
            
            -- SMART FALLBACK: If dragging to 'player-inv' and it doesn't fit or is too heavy, try finding ANY slot in any bag
            if not success or (currentToWeight + itemWeight > toMaxWeight) then
                if toId == 'player-inv' or toId == 'player' then
                    print('^3[mx-inv] Smart Fallback: Item did not fit in pockets, searching bags...^0')
                    local freeSlot = nil
                    local finalTargetContainerId = toId
                    
                    local containerOrder = {}
                    if containerMap.equipment then
                        for slot, eqItem in pairs(containerMap.equipment) do
                            local eqDef = ItemDefs[eqItem.name]
                            if eqDef and eqDef.container then
                                table.insert(containerOrder, {
                                    key = eqItem.id,
                                    w = eqDef.container.size.width,
                                    h = eqDef.container.size.height,
                                    maxW = eqDef.container.maxWeight,
                                    layout = eqDef.container.layout
                                })
                            end
                        end
                    end

                    for _, cInfo in ipairs(containerOrder) do
                        if cInfo.key == itemObj.id then
                            print('^3[mx-inv] Skipping ' .. cInfo.key .. ' (recursion check in fallback)^0')
                        else
                            local tgtContainer = containerMap[cInfo.key] or {}
                            containerMap[cInfo.key] = tgtContainer -- Ensure it exists in main map
                            
                            local currentWeight = InventoryAPI.GetContainerWeight(tgtContainer)
                            if currentWeight + itemWeight <= cInfo.maxW then
                                freeSlot = MovementEngine.FindFreeSlot(tgtContainer, testSize, cInfo.w, cInfo.h, cInfo.layout)
                                if freeSlot then
                                    toContainer = tgtContainer
                                    finalTargetContainerId = cInfo.key
                                    targetSlot = { x = freeSlot.x, y = freeSlot.y }
                                    data.rotated = freeSlot.rotated
                                    toId = finalTargetContainerId
                                    success = true
                                    print('^2[mx-inv] Smart Fallback Success: Found slot in bag ' .. toId .. '^0')
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if not success then
                print('^1[mx-inv] Move Failed: ' .. (err or "No space") .. '^0')
                TriggerClientEvent('mx-inv:client:notify', src, "O item não cabe ou o compartimento está cheio!", "error")
                UpdateClientInventory(src)
                return
            end
            
            -- Final Weight check for the resolved container (could be the original or the fallback)
            if InventoryAPI.GetContainerWeight(toContainer) + itemWeight > toMaxWeight then
                TriggerClientEvent('mx-inv:client:notify', src, "O compartimento de destino não aguenta esse peso!", "error")
                UpdateClientInventory(src)
                return
            end
        else
            -- AUTO-FIND SLOT (Common for "Remove" from context menu)
            local freeSlot = nil
            local finalTargetContainerId = toId
            
            print('^3[mx-inv] Validation Auto-Find: target=' .. toId .. '^0')

            -- If targeting 'player-inv' implicitly without coordinates, fallback to ALL containers
            if toId == 'player-inv' or toId == 'player' then
                -- PRIORITY: RIG (Vest) -> BAG (Backpack) -> PLAYER POCKETS
                local containerOrder = {}
                
                -- 1. Identify Rigs and Bags from equipment
                local rigContainer = nil
                local bagContainer = nil
                
                if containerMap.equipment then
                    for slot, eqItem in pairs(containerMap.equipment) do
                        local eqDef = ItemDefs[eqItem.name]
                        if eqDef and eqDef.container then
                            local cInfo = {
                                key = eqItem.id,
                                slot = slot, -- used for priority
                                w = eqDef.container.size.width,
                                h = eqDef.container.size.height,
                                maxW = eqDef.container.maxWeight,
                                layout = eqDef.container.layout
                            }
                            if slot == 'vest' then
                                rigContainer = cInfo
                            elseif slot == 'backpack' then
                                bagContainer = cInfo
                            else
                                -- Other containers (maybe pockets if they were containers)
                                table.insert(containerOrder, cInfo)
                            end
                        end
                    end
                end

                -- Assemble the priority list
                local sortedContainers = {}
                -- 1. Player pockets come FIRST
                table.insert(sortedContainers, { 
                    key = 'player', 
                    w = Config.Inventory.Slots.width, 
                    h = Config.Inventory.Slots.height, 
                    maxW = Config.Inventory.MaxWeight 
                })
                -- 2. RIG (Vest) comes second
                if rigContainer then table.insert(sortedContainers, rigContainer) end
                -- 3. BAG (Backpack) comes third
                if bagContainer then table.insert(sortedContainers, bagContainer) end
                -- 4. Any others
                for _, other in ipairs(containerOrder) do table.insert(sortedContainers, other) end

                for _, cInfo in ipairs(sortedContainers) do
                    -- RECURSION CHECK: Don't put a container inside itself!
                    if cInfo.key == itemObj.id then
                        print('^3[mx-inv] Skipping ' .. cInfo.key .. ' (recursion check)^0')
                    else
                        local tgtContainer = containerMap[cInfo.key] or {}
                        containerMap[cInfo.key] = tgtContainer
                    
                    local currentWeight = InventoryAPI.GetContainerWeight(tgtContainer)
                    print('^3[mx-inv] Checking auto-find slot for ' .. itemObj.name .. ' (' .. testSize.x .. 'x' .. testSize.y .. ') in ' .. cInfo.key .. ' Weight: ' .. currentWeight .. '/' .. cInfo.maxW .. '^0')
                    
                    if currentWeight + itemWeight <= cInfo.maxW then
                        freeSlot = MovementEngine.FindFreeSlot(tgtContainer, testSize, cInfo.w, cInfo.h, cInfo.layout)
                        if freeSlot then
                            toContainer = tgtContainer
                            finalTargetContainerId = cInfo.key
                            print('^2[mx-inv] Auto-found slot in ' .. cInfo.key .. '^0')
                            break
                        end
                    end
                end
            end
            else
                -- Auto-find in a specific non-player container (e.g. stash or specific bag)
                local targetProps = InventoryAPI.GetContainerProperties(toId, containerMap)
                local gridWidth = targetProps.width
                local gridHeight = targetProps.height
                local toMaxWeight = targetProps.maxWeight
                local specificLayout = targetProps.layout

                if InventoryAPI.GetContainerWeight(toContainer) + itemWeight <= toMaxWeight then
                    freeSlot = MovementEngine.FindFreeSlot(toContainer, testSize, gridWidth, gridHeight, specificLayout)
                else
                    TriggerClientEvent('mx-inv:client:notify', src, "O compartimento de destino não aguenta esse peso!", "error")
                    UpdateClientInventory(src)
                    return
                end
            end

            if not freeSlot then
                print('^1[mx-inv] Move Failed: No free slot in ' .. toId .. ' or connected bags^0')
                TriggerClientEvent('mx-inv:client:notify', src, "Não há espaço no inventário de destino!", "error")
                UpdateClientInventory(src)
                return
            end
            
            targetSlot = { x = freeSlot.x, y = freeSlot.y }
            data.rotated = freeSlot.rotated
            
            -- IMPORTANT: Refresh the toContainer reference in case it changed in the loop
            toContainer, _ = GetContainerAndSlot(finalTargetContainerId)
            toId = finalTargetContainerId
            print('^3[mx-inv] Auto-found slot for ' .. itemName .. ' at ' .. targetSlot.x .. ',' .. targetSlot.y .. ' in ' .. toId .. '^0')
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
        local accessories = itemObj.metadata and itemObj.metadata.accessories or nil
        local visorDown = itemObj.metadata and itemObj.metadata.visorDown or false
        TriggerClientEvent('mx-inv:client:updateEquipment', src, itemName, true, ammoToLoad, attachments, accessories, visorDown)
        print('^2[mx-inv] Equipped ' .. itemName .. ' to ' .. toEquipKey .. '^0')
        -- Log the new state of equipment
        print('^3[mx-inv] New Equipment State: ' .. json.encode(containerMap.equipment) .. '^0')
    else
        itemObj.slot = targetSlot
        itemObj.rotated = data.rotated   -- Save rotation state
        -- CRITICAL: Always persist BASE size (unrotated definition)
        local baseDef = ItemDefs[itemObj.name]
        if baseDef then
            itemObj.size = { x = baseDef.size.x, y = baseDef.size.y }
        end
        if data.folded ~= nil then
            itemObj.folded = data.folded -- Save folded state
        end
        table.insert(toContainer, itemObj)
        local statusX = (targetSlot and targetSlot.x) or '?'
        local statusY = (targetSlot and targetSlot.y) or '?'
        print('^3[mx-inv] Moved ' .. itemName .. ' to ' .. toId .. ' at ' .. statusX .. ',' .. statusY .. '^0')
    end

    -- Auto-Save
    local player = MX_GetPlayer(src)
    if player then
        DB.SavePlayer(player.identifier, containerMap)
        print('^2[mx-inv] Auto-saved inventory for ' .. player.name .. '^0')
    end

    -- Refresh Client
    UpdateClientInventory(src)

    -- Auto-save stash if one is open after move
    StashAPI.SaveActiveStashForPlayer(src)
end)

RegisterNetEvent('mx-inv:server:swapEquipment', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap or not containerMap.equipment then return end

    -- Handle both 'from' (standard) and 'fromSlot' (old) keys
    local fromSlot = (data.from or data.fromSlot or ""):gsub('equip%-', '')
    local toSlot = (data.slot or data.toSlot or ""):gsub('equip%-', '')

    if fromSlot == "" or toSlot == "" then
        print('^1[mx-inv] Swap Failed: Invalid slots. From: ' .. tostring(fromSlot) .. ' To: ' .. tostring(toSlot) .. '^0')
        return
    end

    EquipmentAPI.SwapEquipment(src, containerMap, fromSlot, toSlot)

    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, containerMap) end
    UpdateClientInventory(src)
end)

RegisterNetEvent('mx-inv:server:unloadWeapon', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    EquipmentAPI.UnloadWeapon(src, containerMap, data.id, data.containerId, AddItem)

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

    -- Validation: Check caliber compatibility
    local attachDef = Items[attachmentItemName]
    local weaponDef = Items[weapon.name]
    if attachDef and weaponDef and attachDef.attachment and attachDef.attachment.caliber then
        local weaponCaliber = weaponDef.equipment and weaponDef.equipment.caliber
        if weaponCaliber and attachDef.attachment.caliber ~= weaponCaliber then
            print('^1[mx-inv] Attach: Caliber mismatch! ' ..
                tostring(attachDef.attachment.caliber) .. ' vs ' .. tostring(weaponCaliber) .. '^0')
            TriggerClientEvent('mx-inv:client:notify', src, "Este acessório não é compatível com o calibre desta arma!",
                "error")
            UpdateClientInventory(src)
            return
        end
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
-- Attach Accessory to Helmet Event
RegisterNetEvent('mx-inv:server:attachHelmetAccessory', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local helmetId = data.helmetId
    local helmetContainerId = data.helmetContainerId
    local accessorySlot = data.accessorySlot
    local accessoryItemName = data.accessoryItem
    local accessoryItemId = data.accessoryItemId
    local fromContainerId = data.fromContainerId

    print('^3[mx-inv] Attach Accessory: ' ..
        tostring(accessoryItemName) ..
        ' -> helmet ' .. tostring(helmetId) .. ' slot ' .. tostring(accessorySlot) .. '^0')

    -- Find and remove the accessory item from source container
    local fromKey = (fromContainerId == 'player-inv') and 'player' or fromContainerId
    local fromContainer = containerMap[fromKey]
    if not fromContainer then return end

    local accIndex = nil
    for i, item in ipairs(fromContainer) do
        if item.id == accessoryItemId then
            accIndex = i
            break
        end
    end

    if not accIndex then return end

    -- Remove accessory from source
    table.remove(fromContainer, accIndex)

    -- Attach via API
    local success = EquipmentAPI.AttachToHelmet(src, helmetId, helmetContainerId, accessorySlot, accessoryItemName, fromContainerId, containerMap)

    if success then
        local player = MX_GetPlayer(src)
        if player then DB.SavePlayer(player.identifier, containerMap) end
        UpdateClientInventory(src)
    else
        -- Refund item if failed (shouldn't happen with frontend validation)
        -- table.insert(fromContainer, { ... }) 
        UpdateClientInventory(src)
    end
end)

-- Remove Accessory from Helmet Event
RegisterNetEvent('mx-inv:server:removeHelmetAccessory', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local helmetId = data.helmetId
    local helmetContainerId = data.helmetContainerId
    local accessorySlot = data.accessorySlot
    local toContainerId = data.toContainerId
    local toSlot = data.toSlot

    print('^3[mx-inv] Remove Accessory: slot ' ..
        tostring(accessorySlot) .. ' from helmet ' .. tostring(helmetId) .. '^0')

    -- Remove via API
    local itemName = EquipmentAPI.RemoveHelmetAccessory(src, helmetId, helmetContainerId, accessorySlot, containerMap)

    if itemName then
        -- Add back to target container
        local added = AddItem(src, itemName, 1, nil, toSlot, toContainerId, data.rotated, data.folded)
        if not added then
            -- Fallback: already handled by AddItem (will auto-find space or fail)
        end

        local player = MX_GetPlayer(src)
        if player then DB.SavePlayer(player.identifier, containerMap) end
        UpdateClientInventory(src)
    end
end)

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
            local def = ItemDefs[attachmentItemName]
            local baseSize = def and def.size or {x=1, y=1}
            local currentFold = data.folded or false
            if currentFold and def and def.foldedSize then baseSize = def.foldedSize end

            local newItem = {
                name = attachmentItemName,
                count = 1,
                slot = data.toSlot,
                rotated = data.rotated or false,
                folded = currentFold,
                size = { x = baseSize.x, y = baseSize.y },
                id = InventoryAPI.GenerateUUID()
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
-- All helmet/attachment events are handled above near line 1435 and 1527.
-- Removing extra duplicates to avoid confusion and state desync.

RegisterNetEvent('mx-inv:server:toggleHelmetVisor', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local helmet = EquipmentAPI.GetEquippedHelmet(containerMap)

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
    EquipmentAPI.SyncHelmetAccessory(src, helmet.name, mountedSlot, accessoryName, newVisorDown)

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
        
        -- SECURITY: Prevent ammo injection from mod menus
        local currentServerAmmo = tonumber(foundItem.metadata.ammo) or 0
        local ammoDelta = totalAmmo - currentServerAmmo

        -- The client should only ever report a *decrease* or *same* ammo from shooting.
        if ammoDelta > 0 then
            print('^1[mx-inv] SECURITY ALERT: Player ' .. src .. ' attempted to inject ' .. ammoDelta .. ' ammo into weapon ' .. weaponHash .. '^0')
            -- Force client to sync back to the server's authoritative value
            TriggerClientEvent('mx-inv:client:syncAmmoUI', src, foundSlot, currentServerAmmo, foundItem.metadata.clip or 0)
            return
        end
        
        -- Prevent negative ammo tracking
        if totalAmmo < 0 then totalAmmo = 0 end

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
RegisterNetEvent('mx-inv:server:requestDrops', function()
    local src = source
    DropAPI.SyncDrops(src)
end)

RegisterNetEvent('mx-inv:server:dropItem', function(data)
    local src = source
    print('^3[mx-inv] Server: dropItem triggered by ' .. src .. '^0')
    if not data then return end

    local itemId = data.itemId
    local amount = tonumber(data.amount) or 1
    local containerId = data.containerId

    -- SECURITY: Prevent negative or zero amounts (Item Duplication Exploit)
    if amount <= 0 then
        print('^1[mx-inv] SECURITY ALERT: Player ' .. src .. ' attempted to drop invalid amount: ' .. amount .. '^0')
        return
    end

    if not Inventory[src] then return end

    local targetItem = nil
    local targetIndex = -1
    local isEquipment = false
    local equipSlot = nil

    if string.sub(containerId, 1, 6) == 'equip-' then
        equipSlot = string.sub(containerId, 7)
        if Inventory[src].equipment and Inventory[src].equipment[equipSlot] and Inventory[src].equipment[equipSlot].id == itemId then
            targetItem = Inventory[src].equipment[equipSlot]
            isEquipment = true
        end
    else
        local containerKey = (containerId == 'player-inv') and 'player' or containerId
        local container = Inventory[src][containerKey]
        if container then
            for i, item in ipairs(container) do
                if item.id == itemId then
                    targetItem = item
                    targetIndex = i
                    break
                end
            end
        end
    end

    if not targetItem or targetItem.count < amount then return end

    -- Update inventory
    if targetItem.count == amount then
        if isEquipment then
            Inventory[src].equipment[equipSlot] = nil
            TriggerClientEvent('mx-inv:client:updateEquipment', src, targetItem.name, false)
        else
            local containerKey = (containerId == 'player-inv') and 'player' or containerId
            table.remove(Inventory[src][containerKey], targetIndex)
        end
    else
        targetItem.count = targetItem.count - amount
    end

    -- Store container items in metadata to preserve them during drop
    if Inventory[src][targetItem.id] then
        if not targetItem.metadata then targetItem.metadata = {} end
        targetItem.metadata.containerItems = Inventory[src][targetItem.id]
        Inventory[src][targetItem.id] = nil
    end

    -- Calculate drop position
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local offsetX = (math.random() - 0.5) * 0.8
    local offsetY = (math.random() - 0.5) * 0.8
    local x = coords.x + math.sin(math.rad(-heading)) * 1.2 + offsetX
    local y = coords.y + math.cos(math.rad(-heading)) * 1.2 + offsetY
    local z = coords.z - 0.95

    local dropId = InventoryAPI.GenerateUUID()
    
    DropAPI.AddDrop(dropId, targetItem, { x = x, y = y, z = z }, amount)

    -- Save & Refresh
    local player = MX_GetPlayer(src)
    if player then DB.SavePlayer(player.identifier, Inventory[src]) end
    UpdateClientInventory(src)

    print('^2[mx-inv] Player ' .. src .. ' dropped ' .. amount .. 'x ' .. targetItem.name .. '^0')
end)

RegisterNetEvent('mx-inv:server:pickupItem', function(dropId)
    local src = source
    local drop = DropAPI.GetDrops()[dropId]

    if not drop then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dist = #(coords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))

    if dist > 3.0 then
        print('^1[mx-inv] pickupItem: Player ' .. src .. ' too far from drop^0')
        return
    end

    -- 1. Try Auto-Equip
    local equipped, slotLabel, newUuid = AutoEquipItem(src, drop.name, drop.count, drop.metadata)
    if equipped then
        if drop.metadata and drop.metadata.containerItems and newUuid then
            Inventory[src][newUuid] = drop.metadata.containerItems
        end
        DropAPI.DeleteDrop(dropId)
        DropAPI.SyncDrops(-1)
        TriggerClientEvent('mx-inv:client:notify', src, 'Equipou ' .. drop.label .. ' automaticamente.', 'success')

        local player = MX_GetPlayer(src)
        if player then DB.SavePlayer(player.identifier, Inventory[src]) end
        UpdateClientInventory(src)
        return
    end

    -- 2. Try to add to inventory
    local success, msg, newUuid = AddItem(src, drop.name, drop.count, drop.metadata)
    if success then
        if drop.metadata and drop.metadata.containerItems and newUuid then
            Inventory[src][newUuid] = drop.metadata.containerItems
        end
        DropAPI.DeleteDrop(dropId)
        DropAPI.SyncDrops(-1)
        TriggerClientEvent('mx-inv:client:notify', src, 'Pegou ' .. drop.label .. ': ' .. msg, 'success')

        local player = MX_GetPlayer(src)
        if player then DB.SavePlayer(player.identifier, Inventory[src]) end
        UpdateClientInventory(src)
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
    -- Determine grid dimensions for split target
    local gridWidth, gridHeight = Config.Inventory.Slots.x, Config.Inventory.Slots.y
    if containerId ~= 'player-inv' and containerId ~= 'player' and string.sub(containerId, 1, 6) ~= 'equip-' and string.sub(containerId, 1, 6) ~= 'stash_' then
        for _, pItm in ipairs(containerMap.player or {}) do
            if pItm.id == containerId then
                local pDef = ItemDefs[pItm.name]
                if pDef and pDef.container then
                    gridWidth = pDef.container.size.width
                    gridHeight = pDef.container.size.height
                end
                break
            end
        end
    elseif string.sub(containerId, 1, 6) == 'stash_' then
        local stash = ActiveStashes[containerId]
        if stash and stash.size then
            gridWidth = stash.size.width
            gridHeight = stash.size.height
        end
    end

    local itemDef  = ItemDefs[targetItem.name]
    local itemSize = (itemDef and itemDef.size) or { x = 1, y = 1 }
    local freeSlot = MovementEngine.FindFreeSlot(container, itemSize, gridWidth, gridHeight)
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
        id       = InventoryAPI.GenerateUUID(),
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
                    return { name = item.name, count = count, id = InventoryAPI.GenerateUUID(), slot = { x = 1, y = 1 } }
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
    local containerContents = Inventory[fromSrc][pending.itemId]
    
    local removedItem = RemoveItemById(Inventory[fromSrc], pending.itemId, pending.count)
    if not removedItem then
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc,
            { ok = false, reason = 'Item não encontrado no inventário.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc, { ok = false, reason = 'Falha ao receber o item.' })
        return
    end

    if containerContents then
        if not removedItem.metadata then removedItem.metadata = {} end
        removedItem.metadata.containerItems = containerContents
        Inventory[fromSrc][pending.itemId] = nil
    end

    local added, addMsg, newUuid = AddItem(targetSrc, removedItem.name, removedItem.count, removedItem.metadata)
    if not added then
        -- Rollback: give item back to source
        local rbAdded, rbMsg, rbUuid = AddItem(fromSrc, removedItem.name, removedItem.count, removedItem.metadata)
        if rbAdded and containerContents and rbUuid then
            Inventory[fromSrc][rbUuid] = containerContents
        end
        TriggerClientEvent('mx-inv:client:giveItemResult', fromSrc, { ok = false, reason = 'Inventário do alvo cheio.' })
        TriggerClientEvent('mx-inv:client:giveItemResult', targetSrc,
            { ok = false, reason = 'Seu inventário está cheio.' })
        return
    end

    if added and containerContents and newUuid then
        Inventory[targetSrc][newUuid] = containerContents
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
        [3] = 'holster',
        [4] = 'melee'
    }

    local equipKey = slotMap[slotIndex]
    if not equipKey then return end

    local item = Inventory[src].equipment[equipKey]
    if item then
        local def = ItemDefs[item.name]
        if def and def.equipment and def.equipment.weaponHash then
            local specificAmmo = tonumber(item.metadata and item.metadata.ammo) or 0
            local attachments = item.metadata and item.metadata.attachments or nil
            print('^2[mx-inv] Hotbar: Setting active weapon for ' .. src .. ': ' .. def.equipment.weaponHash .. ' with ' .. specificAmmo .. ' ammo.^0')
            TriggerClientEvent('mx-inv:client:setActiveWeapon', src, def.equipment.weaponHash, specificAmmo, attachments, item.name)
        end
    else
        print('^3[mx-inv] Hotbar: No item in slot ' ..
            equipKey .. '. Dump: ' .. json.encode(Inventory[src].equipment) .. '^0')
    end
end)



-- Initialize Stash API
-- StashAPI is already loaded globally

exports('RegisterStash', StashAPI.RegisterStash)
exports('OpenStash', function(src, stashId, label, size)
    StashAPI.OpenStashForPlayer(src, stashId, label, size, GetFormattedInventory)
end)
exports('CloseStash', StashAPI.CloseStashForPlayer)
exports('DeleteStash', StashAPI.DeleteStashById)

RegisterNetEvent('mx-inv:server:closeInventory', function()
    local src = source
    StashAPI.CloseStashForPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    StashAPI.CloseStashForPlayer(src)
end)

-- Filter stash keys from player save data
local _originalSavePlayer = DB.SavePlayer
DB.SavePlayer = function(identifier, inventoryData)
    local filtered = {}
    for k, v in pairs(inventoryData) do
        if type(k) ~= 'string' or (string.sub(k, 1, 6) ~= 'stash_' and string.sub(k, 1, 6) ~= 'stash-') then
            filtered[k] = v
        end
    end
    return _originalSavePlayer(identifier, filtered)
end

RegisterNetEvent('mx-inv:server:onMoveComplete', function()
    local src = source
    StashAPI.SaveActiveStashForPlayer(src)
end)


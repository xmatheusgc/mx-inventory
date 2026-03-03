-- server/modules/stash.lua
-- Persistent Stash System API

-- InventoryAPI is globally available

StashAPI = {}

-- Store global stash state
StashAPI.ActiveStashes = {}
StashAPI.PlayerOpenStash = {}

--- Register a stash with pre-generated items (does NOT open it)
function StashAPI.RegisterStash(stashId, label, size, items)
    if not stashId or not label or not size then
        print('^1[mx-inv] RegisterStash: Invalid parameters^0')
        return false
    end

    StashAPI.ActiveStashes[stashId] = {
        items = items or {},
        size = size,
        label = label
    }

    print('^2[mx-inv] Registered stash: ' .. stashId .. ' (' .. #(items or {}) .. ' items)^0')
    return true
end

--- Open a stash for a player (sends combined inventory + stash payload)
function StashAPI.OpenStashForPlayer(src, stashId, label, size, getFormattedInventoryFunc)
    if not src or not stashId then return end

    local Inventory = InventoryAPI.GetPlayerInventory(src)

    -- Ensure player inventory is loaded
    if not Inventory then
        print('^1[mx-inv] OpenStash: Inventory not loaded for ' .. src .. '^0')
        return
    end

    -- Create stash if it doesn't exist
    if not StashAPI.ActiveStashes[stashId] then
        -- Try loading from DB
        local dbItems = DB.LoadStash(stashId)
        StashAPI.ActiveStashes[stashId] = {
            items = dbItems or {},
            size = size or { width = 4, height = 3 },
            label = label or 'Stash'
        }
    end

    local stash = StashAPI.ActiveStashes[stashId]

    -- Bind stash to player inventory map so moveItem resolver works
    Inventory[stashId] = stash.items

    -- Track which stash is open
    StashAPI.PlayerOpenStash[src] = stashId

    -- Build payload with player inventory + stash
    local payload = getFormattedInventoryFunc(src)
    if not payload then return end

    TriggerClientEvent('mx-inv:client:openInventory', src, payload)
    print('^2[mx-inv] Opened stash ' .. stashId .. ' for player ' .. src .. '^0')
end

--- Close stash for a player (unbind from inventory, save to DB)
function StashAPI.CloseStashForPlayer(src)
    local stashId = StashAPI.PlayerOpenStash[src]
    if not stashId then return end

    -- Save stash to DB
    local stash = StashAPI.ActiveStashes[stashId]
    if stash then
        DB.SaveStash(stashId, stash.items)
    end

    -- Unbind from player inventory
    local Inventory = InventoryAPI.GetPlayerInventory(src)
    if Inventory then
        Inventory[stashId] = nil
    end

    StashAPI.PlayerOpenStash[src] = nil
    print('^3[mx-inv] Closed stash ' .. stashId .. ' for player ' .. src .. '^0')
end

--- Delete a stash entirely (cleanup)
function StashAPI.DeleteStashById(stashId)
    if not stashId then return false end

    -- Unbind from any player who has it open
    for src, openId in pairs(StashAPI.PlayerOpenStash) do
        if openId == stashId then
            local Inventory = InventoryAPI.GetPlayerInventory(src)
            if Inventory then
                Inventory[stashId] = nil
            end
            StashAPI.PlayerOpenStash[src] = nil
        end
    end

    StashAPI.ActiveStashes[stashId] = nil

    -- Delete from DB
    Citizen.CreateThread(function()
        MySQL.prepare.await('DELETE FROM mx_inventory_stashes WHERE name = ?', { stashId })
    end)

    print('^3[mx-inv] Deleted stash: ' .. stashId .. '^0')
    return true
end

-- Auto-save stash when moveItem involves a stash container
function StashAPI.SaveActiveStashForPlayer(src)
    local stashId = StashAPI.PlayerOpenStash[src]
    if not stashId or not StashAPI.ActiveStashes[stashId] then return end

    Citizen.CreateThread(function()
        DB.SaveStash(stashId, StashAPI.ActiveStashes[stashId].items)
    end)
end

return StashAPI

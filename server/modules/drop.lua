-- server/modules/drop.lua
-- Persistent World Drops system

-- InventoryAPI is globally available

DropAPI = {}
DropAPI.worldDrops = {}

--- Initialize Drops from DB
function DropAPI.InitDrops()
    Citizen.CreateThread(function()
        while not DB.Ready do Wait(100) end
        DropAPI.worldDrops = DB.LoadDrops() or {}
        local count = 0
        for _ in pairs(DropAPI.worldDrops) do count = count + 1 end
        print('^2[mx-inv] Loaded ' .. count .. ' world drops.^0')
    end)
end

--- Start drop cleanup thread
function DropAPI.StartCleanupThread()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Check every 1 minute
            local currentTime = os.time()
            local despawnTime = (Config.Inventory.DropDespawnTime or 30) * 60
            local itemsRemoved = 0

            for id, drop in pairs(DropAPI.worldDrops) do
                if drop.created_at and (currentTime - drop.created_at) > despawnTime then
                    DropAPI.worldDrops[id] = nil
                    DB.DeleteDrop(id)
                    itemsRemoved = itemsRemoved + 1
                end
            end

            if itemsRemoved > 0 then
                TriggerClientEvent('mx-inv:client:syncDrops', -1, DropAPI.worldDrops)
                print('^3[mx-inv] Cleanup: Removed ' .. itemsRemoved .. ' expired drops.^0')
            end
        end
    end)
end

--- Get all drops
function DropAPI.GetDrops()
    return DropAPI.worldDrops
end

--- Delete a drop by ID
function DropAPI.DeleteDrop(dropId)
    if DropAPI.worldDrops[dropId] then
        DropAPI.worldDrops[dropId] = nil
        DB.DeleteDrop(dropId)
        return true
    end
    return false
end

--- Sync drops to specific player or everyone (-1)
function DropAPI.SyncDrops(src)
    TriggerClientEvent('mx-inv:client:syncDrops', src, DropAPI.worldDrops)
end

--- Add a drop to the world
function DropAPI.AddDrop(dropId, itemObj, coords, amount)
    local itemDef = Items[itemObj.name]
    local dropProp = (itemDef and itemDef.dropProp) or Config.Inventory.DefaultDropProp

    DropAPI.worldDrops[dropId] = {
        id = dropId,
        name = itemObj.name,
        type = itemDef and itemDef.type or 'generic',
        label = itemDef and itemDef.label or itemObj.name,
        count = amount,
        metadata = itemObj.metadata,
        coords = coords,
        prop = dropProp,
        created_at = os.time()
    }

    DB.SaveDrop(dropId, DropAPI.worldDrops[dropId])
    DropAPI.SyncDrops(-1)
end

return DropAPI

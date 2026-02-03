local ItemDefs = {
    water = { label = 'Bottle of Water', size = { x = 1, y = 2 }, image = 'items/water.png', weight = 0.5 },
    bread = { label = 'Bread', size = { x = 1, y = 1 }, image = 'items/bread.png', weight = 0.2 },
    pistol = { label = 'Pistol', size = { x = 2, y = 2 }, image = 'items/pistol.png', weight = 1.5 },
    medkit = { label = 'Medkit', size = { x = 2, y = 2 }, image = 'items/medkit.png', weight = 1.0 },
    knife = { label = 'Combat Knife', size = { x = 1, y = 2 }, image = 'items/knife.png', weight = 0.8 },
    rifle = { label = 'Assault Rifle', size = { x = 3, y = 6 }, image = 'items/rifle.png', weight = 4.5 },
    bandage = { label = 'Bandage', size = { x = 1, y = 1 }, image = 'items/bandage.png', weight = 0.1 }
}

-- Calculate total weight of a list of items
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

local function CreateStarterInventory()
    return {
        player = {
            { name = 'water',  count = 1, slot = { x = 1, y = 1 } },
            { name = 'bread',  count = 2, slot = { x = 2, y = 1 } },
            { name = 'pistol', count = 1, slot = { x = 3, y = 1 } }
        },
        backpack = {
            { name = 'bandage', count = 2, slot = { x = 1, y = 7 } }, -- In Pocket 1
            { name = 'knife',   count = 1, slot = { x = 3, y = 7 } }, -- In Pocket 2
            { name = 'medkit',  count = 1, slot = { x = 5, y = 7 } }  -- In Pocket 3
        }
    }
end

local Inventory = {}

RegisterNetEvent('mx-inv:server:openInventory', function()
    local src = source
    if not Inventory[src] then
        Inventory[src] = CreateStarterInventory()
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

    -- "Backpack" Layout:
    -- Main Compartment: 6x5
    -- Gap: Row 6 (Empty)
    -- Pockets: Row 7-8 (3 pockets of 2x2)
    --  Pocket 1: x:1-2
    --  Pocket 2: x:3-4
    --  Pocket 3: x:5-6

    local backpackSlots = {}
    -- Main Compartment (Rows 1-5, Cols 1-6)
    for y = 1, 5 do
        for x = 1, 6 do
            table.insert(backpackSlots, { x = x, y = y })
        end
    end
    -- Pockets (Rows 7-8)
    for y = 7, 8 do
        -- Pocket 1
        table.insert(backpackSlots, { x = 1, y = y })
        table.insert(backpackSlots, { x = 2, y = y })
        -- Pocket 2
        table.insert(backpackSlots, { x = 3, y = y })
        table.insert(backpackSlots, { x = 4, y = y })
        -- Pocket 3
        table.insert(backpackSlots, { x = 5, y = y })
        table.insert(backpackSlots, { x = 6, y = y })
    end

    local backpackData = {
        id = 'backpack-1',
        type = 'bag',
        label = 'Large Backpack',
        size = { width = 6, height = 8 },
        items = containers.backpack or {},
        validSlots = backpackSlots,
        maxWeight = 20.0,
        weight = GetContainerWeight(containers.backpack or {})
    }

    TriggerClientEvent('mx-inv:client:openInventory', src, {
        player = playerData,
        secondary = backpackData,
        itemDefs = ItemDefs
    })
end)

RegisterNetEvent('mx-inv:server:moveItem', function(data)
    local src = source
    local containerMap = Inventory[src]
    if not containerMap then return end

    local itemName = data.item
    local fromId = data.from
    local toId = data.to
    local targetSlot = data.slot

    local function GetContainerKey(id)
        if id == 'player-inv' then return 'player' end
        if id == 'backpack-1' then return 'backpack' end
        return nil
    end

    local fromKey = GetContainerKey(fromId)
    local toKey = GetContainerKey(toId)

    if not fromKey or not toKey then return end

    local fromItems = containerMap[fromKey]
    local toItems = containerMap[toKey]

    local itemIndex = nil
    for i, item in ipairs(fromItems) do
        if item.name == itemName then
            itemIndex = i
            break
        end
    end

    if not itemIndex then return end
    local item = fromItems[itemIndex]

    -- Validate Move Weight if changing containers
    if fromKey ~= toKey then
        local itemDef = ItemDefs[item.name]
        if itemDef and itemDef.weight then
            local currentWeight = GetContainerWeight(toItems)
            if (currentWeight + (itemDef.weight * item.count)) > (toKey == 'player' and 40.0 or 20.0) then
                -- Overweight!
                --Ideally prevent move and notify client.
                --For now, simple return to cancel server side. UI might need rollback or check before sending.
                return
            end
        end
    end

    -- Remove from old
    table.remove(fromItems, itemIndex)
    item.slot = targetSlot
    table.insert(toItems, item)

    -- Ideally send back the new weights to client to stay in sync
    TriggerClientEvent('mx-inv:client:updateWeights', src, {
        [fromKey] = GetContainerWeight(fromItems),
        [toKey] = GetContainerWeight(toItems)
    })
end)

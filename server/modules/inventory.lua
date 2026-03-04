-- server/modules/inventory.lua
-- Core Inventory Utilities

local ItemDefs = Items -- from data/items.lua

InventoryAPI = {}

--- Generate UUID for newly spawned items or containers
function InventoryAPI.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

--- Calculate Weight of a list of items
function InventoryAPI.GetContainerWeight(items)
    local total = 0.0
    for _, item in ipairs(items) do
        local def = ItemDefs[item.name]
        if def and def.weight then
            total = total + (def.weight * item.count)
        end
    end
    return total
end

--- Get a player's raw Inventory block
function InventoryAPI.GetPlayerInventory(src)
    return Inventory[src]
end

--- Extract all active Sub-Containers (Backpacks, Vests)
function InventoryAPI.FormatPayloadContainers(containers, payload)
    local function parseContainerItem(item)
        if not item or not item.name then return end
        local def = ItemDefs[item.name]
        if def and def.container then
            local containerId = item.id

            if not containers[containerId] then
                containers[containerId] = {}
            end

            payload[containerId] = {
                id = containerId,
                name = item.name,
                type = def.type,
                label = def.label,
                size = def.container.size,
                items = containers[containerId],
                weight = InventoryAPI.GetContainerWeight(containers[containerId]),
                maxWeight = def.container.maxWeight,
                layout = def.container.layout
            }
        end
    end

    for _, containerItems in pairs(containers) do
        if type(containerItems) == 'table' then
            for _, item in pairs(containerItems) do
                parseContainerItem(item)
            end
        end
    end
end

--- Resolves properties (size, maxWeight, layout) for any container ID
function InventoryAPI.GetContainerProperties(containerId, containerMap)
    local props = {
        width = Config.Inventory.Slots.width,
        height = Config.Inventory.Slots.height,
        maxWeight = Config.Inventory.MaxWeight,
        layout = nil
    }

    if containerId == 'player-inv' or containerId == 'player' then
        return props
    end

    if containerId:sub(1, 6) == 'stash_' then
        local stash = ActiveStashes[containerId]
        if stash then
            props.width = stash.size.width
            props.height = stash.size.height
            props.maxWeight = stash.maxWeight or 999.0
            props.layout = stash.layout
            if Config.Debug then
                print('^3[mx-inv] GetContainerProperties: Resolved Stash ' .. containerId .. ' Layout: ' .. tostring(props.layout) .. '^0')
            end
            return props
        end
    end

    -- Search for item UUID in inventory or equipment
    local item = nil
    local found = false

    -- Search equipment first (most common for open bags)
    if containerMap.equipment then
        for _, eqItm in pairs(containerMap.equipment) do
            if eqItm and eqItm.id == containerId then
                item = eqItm
                found = true
                break
            end
        end
    end

    -- If not in equipment, search player pockets
    if not found and containerMap.player then
        for _, pItm in ipairs(containerMap.player) do
            if pItm.id == containerId then
                item = pItm
                found = true
                break
            end
        end
    end

    if found and item then
        local def = ItemDefs[item.name]
        if def and def.container then
            props.width = def.container.size.width
            props.height = def.container.size.height
            props.maxWeight = def.container.maxWeight
            props.layout = def.container.layout
            if Config.Debug then
                print('^3[mx-inv] GetContainerProperties: Resolved Item UUID ' .. containerId .. ' (' .. item.name .. ') Layout: ' .. tostring(props.layout) .. '^0')
            end
        end
    end

    return props
end

return InventoryAPI

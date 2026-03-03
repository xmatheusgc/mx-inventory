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
                maxWeight = def.container.maxWeight
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

return InventoryAPI

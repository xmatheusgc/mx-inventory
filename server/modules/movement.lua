-- server/modules/movement.lua
-- Centralized Movement Engine

local ItemDefs = Items

MovementEngine = {}

--- Verifies if an item of specific size fits at x,y ignoring specific ignored item IDs
function MovementEngine.CheckFit(container, itemSize, targetX, targetY, gridWidth, gridHeight, ignoreItemId)
    -- 1. Check Global Boundaries
    if targetX < 1 or targetY < 1 or (targetX + itemSize.x - 1) > gridWidth or (targetY + itemSize.y - 1) > gridHeight then
        return false, "Fora dos limites do contêiner"
    end

    -- 2. Check Overlaps
    for _, existingItem in ipairs(container) do
        if existingItem.id ~= ignoreItemId then
            local eX = existingItem.slot.x
            local eY = existingItem.slot.y
            local eDef = ItemDefs[existingItem.name]
            
            -- Resolve size taking folding and rotation into account
            -- TODO: In standard main.lua logic, .size is stored on the item object directly.
            local eSize = existingItem.size or (eDef and eDef.size) or {x=1, y=1}
            local eW = existingItem.rotated and eSize.y or eSize.x
            local eH = existingItem.rotated and eSize.x or eSize.y

            local iW = itemSize.x
            local iH = itemSize.y

            local overlapX = targetX <= (eX + eW - 1) and (targetX + iW - 1) >= eX
            local overlapY = targetY <= (eY + eH - 1) and (targetY + iH - 1) >= eY

            if overlapX and overlapY then
                return false, "Colisão detectada"
            end
        end
    end

    return true, "OK"
end

--- Generic Find Free Slot based on CheckFit
function MovementEngine.FindFreeSlot(container, itemSize, gridWidth, gridHeight)
    -- Try Normal
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            local fits = MovementEngine.CheckFit(container, itemSize, x, y, gridWidth, gridHeight, nil)
            if fits then return {x=x, y=y, rotated=false} end
        end
    end

    -- Try Rotated
    if itemSize.x ~= itemSize.y then
        local rotatedSize = {x=itemSize.y, y=itemSize.x}
        for y = 1, gridHeight do
            for x = 1, gridWidth do
                local fits = MovementEngine.CheckFit(container, rotatedSize, x, y, gridWidth, gridHeight, nil)
                if fits then return {x=x, y=y, rotated=true} end
            end
        end
    end

    return nil
end

return MovementEngine

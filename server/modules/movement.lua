-- server/modules/movement.lua
-- Centralized Movement Engine

local ItemDefs = Items

MovementEngine = {}

--- Verifies if an item of specific size fits at x,y ignoring specific ignored item IDs
function MovementEngine.CheckFit(container, itemSize, targetX, targetY, gridWidth, gridHeight, ignoreItemId, layout)
    -- 1. Check Global Boundaries
    if targetX < 1 or targetY < 1 or (targetX + itemSize.x - 1) > gridWidth or (targetY + itemSize.y - 1) > gridHeight then
        return false, "Fora dos limites do contêiner"
    end

    -- 2. Check Layout Mask (if applicable)
    if layout and Config.ContainerLayouts and Config.ContainerLayouts[layout] then
        local layoutDef = Config.ContainerLayouts[layout]
        local fitsInPocket = false
        
        print('^3[mx-inv] Layout Check: ' .. layout .. ' ItemSize: ' .. itemSize.x .. 'x' .. itemSize.y .. ' Target: ' .. targetX .. ',' .. targetY .. '^0')

        for i, pocket in ipairs(layoutDef.pockets) do
            local pocketMaxX = pocket.x + pocket.width - 1
            local pocketMaxY = pocket.y + pocket.height - 1
            
            local itemMaxX = targetX + itemSize.x - 1
            local itemMaxY = targetY + itemSize.y - 1

            if targetX >= pocket.x and targetY >= pocket.y and 
               itemMaxX <= pocketMaxX and
               itemMaxY <= pocketMaxY then
                fitsInPocket = true
                print('^2[mx-inv] Pocket Fit SUCCESS: Pocket #' .. i .. ' (' .. pocket.width .. 'x' .. pocket.height .. ') covers Item (' .. itemSize.x .. 'x' .. itemSize.y .. ') at ' .. targetX .. ',' .. targetY .. '^0')
                break
            end
        end

        if not fitsInPocket then
            return false, "O item não cabe nos compartimentos deste contêiner"
        end
    end

    -- 3. Check Overlaps
    for _, existingItem in pairs(container) do
        if existingItem.id ~= ignoreItemId then
            local eX = existingItem.slot.x
            local eY = existingItem.slot.y
            -- Resolve size taking folding and rotation into account
            local eDef = ItemDefs[existingItem.name]
            local eBaseSize = (eDef and (existingItem.folded and eDef.foldedSize or eDef.size)) or existingItem.size or {x=1, y=1}
            local eW = existingItem.rotated and eBaseSize.y or eBaseSize.x
            local eH = existingItem.rotated and eBaseSize.x or eBaseSize.y

            local iW = itemSize.x
            local iH = itemSize.y

            local overlapX = targetX <= (eX + eW - 1) and (targetX + iW - 1) >= eX
            local overlapY = targetY <= (eY + eH - 1) and (targetY + iH - 1) >= eY

            if overlapX and overlapY then
                print('^1[mx-inv] Collision Detected: New(' .. targetX .. ',' .. targetY .. ' ' .. iW .. 'x' .. iH .. ') vs Existing(' .. eX .. ',' .. eY .. ' ' .. eW .. 'x' .. eH .. ')^0')
                return false, "Colisão detectada"
            end
        end
    end

    return true, "OK"
end

--- Generic Find Free Slot based on CheckFit
function MovementEngine.FindFreeSlot(container, itemSize, gridWidth, gridHeight, layout)
    -- Try Normal
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            local fits = MovementEngine.CheckFit(container, itemSize, x, y, gridWidth, gridHeight, nil, layout)
            if fits then return {x=x, y=y, rotated=false} end
        end
    end

    -- Try Rotated
    if itemSize.x ~= itemSize.y then
        local rotatedSize = {x=itemSize.y, y=itemSize.x}
        for y = 1, gridHeight do
            for x = 1, gridWidth do
                local fits = MovementEngine.CheckFit(container, rotatedSize, x, y, gridWidth, gridHeight, nil, layout)
                if fits then return {x=x, y=y, rotated=true} end
            end
        end
    end

    return nil
end

return MovementEngine

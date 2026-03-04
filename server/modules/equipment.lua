-- server/modules/equipment.lua
-- Equipment and Attachments API

-- InventoryAPI is globally available

EquipmentAPI = {}

--- Swap equipment slots (e.g. primary to secondary)
function EquipmentAPI.SwapEquipment(src, InventoryMap, fromSlot, toSlot)
    local fromItem = InventoryMap.equipment[fromSlot]
    local toItem = InventoryMap.equipment[toSlot]

    InventoryMap.equipment[fromSlot] = toItem
    InventoryMap.equipment[toSlot] = fromItem

    if fromItem then
        local ammoToLoad = tonumber(fromItem.metadata and fromItem.metadata.ammo) or 0
        local attachments = fromItem.metadata and fromItem.metadata.attachments or nil
        local accessories = fromItem.metadata and fromItem.metadata.accessories or nil
        local visorDown = fromItem.metadata and fromItem.metadata.visorDown or false
        TriggerClientEvent('mx-inv:client:updateEquipment', src, fromItem.name, true, ammoToLoad, attachments, accessories, visorDown)
    end
    if toItem then
        local ammoToLoad = tonumber(toItem.metadata and toItem.metadata.ammo) or 0
        local attachments = toItem.metadata and toItem.metadata.attachments or nil
        local accessories = toItem.metadata and toItem.metadata.accessories or nil
        local visorDown = toItem.metadata and toItem.metadata.visorDown or false
        TriggerClientEvent('mx-inv:client:updateEquipment', src, toItem.name, true, ammoToLoad, attachments, accessories, visorDown)
    end
    print('^2[mx-inv] Swap complete. New state: ' .. json.encode(InventoryMap.equipment) .. '^0')
end

--- Unload ammo from equipped weapon
function EquipmentAPI.UnloadWeapon(src, InventoryMap, weaponId, containerId, AddItemFunc)
    local weapon = nil
    if containerId and string.sub(containerId, 1, 6) == 'equip-' then
        local slot = string.sub(containerId, 7)
        if InventoryMap.equipment then
            weapon = InventoryMap.equipment[slot]
        end
    else
        local wKey = (containerId == 'player-inv') and 'player' or containerId
        local wContainer = InventoryMap[wKey]
        if wContainer then
            for _, wItem in ipairs(wContainer) do
                if wItem.id == weaponId then
                    weapon = wItem
                    break
                end
            end
        end
    end

    if not weapon then return end

    local currentAmmo = weapon.metadata and weapon.metadata.ammo or 0
    if currentAmmo <= 0 then return end

    local weaponDef = Items[weapon.name]
    if not weaponDef or not weaponDef.equipment or not weaponDef.equipment.caliber then return end

    local ammoItemName = weaponDef.equipment.caliber

    weapon.metadata.ammo = 0
    weapon.metadata.clip = 0

    local added = AddItemFunc(src, ammoItemName, currentAmmo)
    if not added then
        weapon.metadata.ammo = currentAmmo
        return
    end

    print('^2[mx-inv] Unload: Unloaded ' .. tostring(currentAmmo) .. 'x ' .. ammoItemName .. ' from ' .. tostring(weapon.name) .. '^0')

    local weaponHash = GetHashKey(weaponDef.equipment.weaponHash)
    local accessories = weapon.metadata and weapon.metadata.accessories or nil
    local visorDown = weapon.metadata and weapon.metadata.visorDown or false
    TriggerClientEvent('mx-inv:client:updateEquipment', src, weapon.name, true, 0, weapon.metadata and weapon.metadata.attachments, accessories, visorDown)
end

--- Resolve a helmet from the equipment mapping
function EquipmentAPI.GetEquippedHelmet(containerMap)
    if not containerMap.equipment then return nil end
    return containerMap.equipment['head']
end

--- Synchronize visual accessory onto a helmet
function EquipmentAPI.SyncHelmetAccessory(src, helmetName, accessorySlot, accessoryName, visorDown)
    local helmetDef = Items[helmetName]
    if not helmetDef or not helmetDef.equipment then return end

    local drawableId = helmetDef.equipment.drawableId
    if accessoryName and helmetDef.equipment.accessoryDrawables then
        local variants = helmetDef.equipment.accessoryDrawables[accessoryName]
        if variants then
            drawableId = visorDown and variants.visorDown or variants.visorUp
        end
    end

    TriggerClientEvent('mx-inv:client:applyHelmetAccessory', src, {
        propId        = helmetDef.equipment.propId,
        drawableId    = drawableId,
        textureId     = helmetDef.equipment.textureId or 0,
        slot          = accessorySlot,
        accessoryName = accessoryName,
        visorDown     = visorDown
    })
end

--- Attach an item to a weapon
function EquipmentAPI.AttachToWeapon(src, weaponId, weaponContainerId, attachmentSlot, attachmentItemName, fromContainerId, InventoryMap)
    print('^3[mx-inv] EquipmentAPI: AttachToWeapon - ' .. weaponId .. ' slot: ' .. attachmentSlot .. '^0')
    
    local weapon = nil
    if string.sub(weaponContainerId, 1, 6) == 'equip-' then
        local slot = string.sub(weaponContainerId, 7)
        weapon = InventoryMap.equipment[slot]
    else
        local wKey = (weaponContainerId == 'player-inv') and 'player' or weaponContainerId
        local wContainer = InventoryMap[wKey]
        if wContainer then
            for _, item in ipairs(wContainer) do
                if item.id == weaponId then
                    weapon = item
                    break
                end
            end
        end
    end

    if not weapon then 
        print('^1[mx-inv] Attach Failed: Weapon not found.^0')
        return false 
    end

    -- 1. Initialize metadata if missing
    if not weapon.metadata then weapon.metadata = {} end
    if not weapon.metadata.attachments then weapon.metadata.attachments = {} end

    -- 2. Set attachment
    weapon.metadata.attachments[attachmentSlot] = attachmentItemName

    print('^2[mx-inv] Attached ' .. attachmentItemName .. ' to ' .. weapon.name .. ' in slot ' .. attachmentSlot .. '^0')
    return true
end

--- Remove an attachment from a weapon
function EquipmentAPI.RemoveAttachment(src, weaponId, weaponContainerId, attachmentSlot, InventoryMap)
    local weapon = nil
    if string.sub(weaponContainerId, 1, 6) == 'equip-' then
        local slot = string.sub(weaponContainerId, 7)
        weapon = InventoryMap.equipment[slot]
    else
        local wKey = (weaponContainerId == 'player-inv') and 'player' or weaponContainerId
        local wContainer = InventoryMap[wKey]
        if wContainer then
            for _, item in ipairs(wContainer) do
                if item.id == weaponId then
                    weapon = item
                    break
                end
            end
        end
    end

    if not weapon or not weapon.metadata or not weapon.metadata.attachments then return nil end
    
    local attachmentName = weapon.metadata.attachments[attachmentSlot]
    weapon.metadata.attachments[attachmentSlot] = nil
    
    print('^2[mx-inv] Removed attachment ' .. tostring(attachmentName) .. ' from ' .. weapon.name .. '^0')
    return attachmentName
end

--- Attach an accessory to a helmet
function EquipmentAPI.AttachToHelmet(src, helmetId, helmetContainerId, accessorySlot, accessoryItemName, fromContainerId, InventoryMap)
    local helmet = nil
    if string.sub(helmetContainerId, 1, 6) == 'equip-' then
        local slot = string.sub(helmetContainerId, 7)
        helmet = InventoryMap.equipment[slot]
    else
        local hKey = (helmetContainerId == 'player-inv') and 'player' or helmetContainerId
        local hContainer = InventoryMap[hKey]
        if hContainer then
            for _, item in ipairs(hContainer) do
                if item.id == helmetId then
                    helmet = item
                    break
                end
            end
        end
    end

    if not helmet then return false end

    if not helmet.metadata then helmet.metadata = {} end
    if not helmet.metadata.accessories then helmet.metadata.accessories = {} end

    helmet.metadata.accessories[accessorySlot] = { name = accessoryItemName, id = InventoryAPI.GenerateUUID() }

    print('^2[mx-inv] Attached accessory ' .. accessoryItemName .. ' to ' .. helmet.name .. '^0')
    
    -- Sync visually!
    if helmetContainerId == 'equip-head' then
        EquipmentAPI.SyncHelmetAccessory(src, helmet.name, accessorySlot, accessoryItemName, helmet.metadata.visorDown)
    end
    
    return true
end

--- Remove an accessory from a helmet
function EquipmentAPI.RemoveHelmetAccessory(src, helmetId, helmetContainerId, accessorySlot, InventoryMap)
    local helmet = nil
    if helmetContainerId and string.sub(helmetContainerId, 1, 6) == 'equip-' then
        local slot = string.sub(helmetContainerId, 7)
        helmet = InventoryMap.equipment[slot]
    elseif helmetContainerId then
        local hKey = (helmetContainerId == 'player-inv') and 'player' or helmetContainerId
        local hContainer = InventoryMap[hKey]
        if hContainer then
            for _, item in ipairs(hContainer) do
                if item.id == helmetId then
                    helmet = item
                    break
                end
            end
        end
    end

    if not helmet or not helmet.metadata or not helmet.metadata.accessories then 
        print('^1[mx-inv] RemoveHelmetAccessory Failed: Helmet or Accessories metadata not found.^0')
        return nil 
    end

    local accData = helmet.metadata.accessories[accessorySlot]
    helmet.metadata.accessories[accessorySlot] = nil

    print('^2[mx-inv] Removed helmet accessory ' .. tostring(accData and accData.name or "N/A") .. ' from ' .. helmet.name .. '^0')
    
    -- Sync visually!
    if helmetContainerId == 'equip-head' then
        EquipmentAPI.SyncHelmetAccessory(src, helmet.name, accessorySlot, nil, helmet.metadata.visorDown)
    end

    return accData and accData.name or nil
end

return EquipmentAPI

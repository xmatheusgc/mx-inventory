-- client/modules/equipment.lua
-- Centralized visual and behavior updates for equipment (weapons, clothing, hats)

local lastAmmoCache = {}

-- Play Animation (Consume)
RegisterNetEvent('mx-inv:client:playAnim', function(data)
    local ped = PlayerPedId()
    local animDict = data.animDict
    local animName = data.anim
    local propModel = data.prop
    local duration = 5000

    if not animDict or not animName then return end

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end

    local propObj = nil
    if propModel then
        local hash = GetHashKey(propModel)
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end

        local coords = GetEntityCoords(ped)
        propObj = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, true)
        local boneIndex = GetPedBoneIndex(ped, 18905)
        AttachEntityToEntity(propObj, ped, boneIndex, 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1, true)
    end

    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, duration, 49, 0, false, false, false)
    Wait(duration)
    StopAnimTask(ped, animDict, animName, 1.0)
    if propObj then DeleteObject(propObj) end
end)

-- Update Equipment Visuals (Give weapon, apply clothing, apply attachments)
RegisterNetEvent('mx-inv:client:updateEquipment', function(itemName, isEquipping, ammoToLoad, attachments, accessories, visorDown)
    local ped = PlayerPedId()
    local def = Items and Items[itemName]
    if not def or not def.equipment then return end

    local eq = def.equipment

    -- Weapon Logic
    if eq.weaponHash then
        local hash = GetHashKey(eq.weaponHash)
        -- STRICT 1:1 WEAPON ARCHITECTURE: We no longer grant weapons in the background.
        -- updateEquipment only handles visual props/clothing. Weapons are handled physically only in setActiveWeapon.
        if not isEquipping then
            RemoveWeaponFromPed(ped, hash)
            if _G.CurrentActiveWeaponHash == hash then
                _G.CurrentActiveWeaponHash = GetHashKey("WEAPON_UNARMED")
            end
        end
    end

    -- Clothing / Prop Logic
    if eq.propId ~= nil and eq.drawableId then
        if isEquipping then
            local finalDrawableId = eq.drawableId
            local finalTextureId = eq.textureId or 0

            -- HELMET ACCESSORY LOGIC:
            if def.type == 'helmet' and accessories then
                for slot, accData in pairs(accessories) do
                    if accData and accData.name then
                        local variants = eq.accessoryDrawables and eq.accessoryDrawables[accData.name]
                        if variants then
                            finalDrawableId = visorDown and variants.visorDown or variants.visorUp
                            -- Sync screen effects
                            TriggerEvent('mx-inv:client:applyHelmetAccessory', {
                                propId = eq.propId,
                                drawableId = finalDrawableId,
                                textureId = finalTextureId,
                                accessoryName = accData.name,
                                visorDown = visorDown
                            })
                        end
                    end
                end
            end

            SetPedPropIndex(ped, eq.propId, finalDrawableId, finalTextureId, true)
        else
            ClearPedProp(ped, eq.propId)
            -- Clear effects
            SetNightvision(false)
            SetSeethrough(false)
        end
    elseif eq.componentId and eq.drawableId then
        if isEquipping then
            SetPedComponentVariation(ped, eq.componentId, eq.drawableId, eq.textureId or 0, 2)
        else
            SetPedComponentVariation(ped, eq.componentId, 0, 0, 2)
        end
    end
end)

-- Set Active Weapon (Hotbar)
RegisterNetEvent('mx-inv:client:setActiveWeapon', function(weaponHash, specificAmmo, attachments, itemName)
    local ped = PlayerPedId()
    if weaponHash then
        local hash = (type(weaponHash) == 'string') and GetHashKey(weaponHash) or weaponHash
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon == hash then
            SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
            RemoveWeaponFromPed(ped, hash)
            _G.CurrentActiveWeaponHash = GetHashKey("WEAPON_UNARMED")
        else
            if _G.CurrentActiveWeaponHash and _G.CurrentActiveWeaponHash ~= GetHashKey("WEAPON_UNARMED") then
                RemoveWeaponFromPed(ped, _G.CurrentActiveWeaponHash)
            end
            GiveWeaponToPed(ped, hash, 0, false, true)
            SetCurrentPedWeapon(ped, hash, true)
            _G.CurrentActiveWeaponHash = hash
            if specificAmmo ~= nil then
                SetPedAmmo(ped, hash, specificAmmo)
            end
            
            if attachments and itemName then
                local def = Items[itemName]
                if def and def.equipment then
                    local eq = def.equipment
                    for slot, attachName in pairs(attachments) do
                        if attachName then
                            local attachDef = Items[attachName]
                            if attachDef and attachDef.attachment then
                                local compHashStr = (eq.supportedAttachments and eq.supportedAttachments[slot] and eq.supportedAttachments[slot].componentHash) or attachDef.attachment.componentHash
                                if compHashStr and compHashStr ~= "" then
                                    local compHash = GetHashKey(compHashStr)
                                    if compHash ~= 0 then GiveWeaponComponentToPed(ped, hash, compHash) end
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
        if _G.CurrentActiveWeaponHash and _G.CurrentActiveWeaponHash ~= GetHashKey("WEAPON_UNARMED") then
            RemoveWeaponFromPed(ped, _G.CurrentActiveWeaponHash)
        end
        _G.CurrentActiveWeaponHash = GetHashKey("WEAPON_UNARMED")
    end
end)

-- Set Ammo & Play Reload Animation
RegisterNetEvent('mx-inv:client:setAmmoAndReload', function(weaponHashName, ammoCount)
    local ped = PlayerPedId()
    local hash = (type(weaponHashName) == 'string') and GetHashKey(weaponHashName) or weaponHashName

    if not HasPedGotWeapon(ped, hash, false) then return end

    local selectedWeapon = GetSelectedPedWeapon(ped)
    if selectedWeapon ~= hash then
        SetPedAmmo(ped, hash, ammoCount)
        return
    end

    SetPedAmmo(ped, hash, ammoCount)
    lastAmmoCache[hash] = ammoCount
    if ammoCount > 0 then MakePedReload(ped) end
end)

-- Sync attachments on equipped weapon
RegisterNetEvent('mx-inv:client:syncAttachments', function(weaponHashName, attachments)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponHashName)
    if not HasPedGotWeapon(ped, hash, false) then return end

    if attachments then
        -- RESOLVE weaponDef:
        -- Search if it's the item name or the weapon hash string
        local weaponDef = Items[weaponHashName]
        if not weaponDef then
            for name, def in pairs(Items) do
                if def.equipment and (def.equipment.weaponHash == weaponHashName or GetHashKey(def.equipment.weaponHash) == hash) then
                    weaponDef = def
                    break
                end
            end
        end

        local eq = weaponDef and weaponDef.equipment

        for slot, attachName in pairs(attachments) do
            if attachName then
                local attachDef = Items[attachName]
                if attachDef and attachDef.attachment then
                    -- INTELLIGENT LOOKUP:
                    local compHashStr = (eq and eq.supportedAttachments and eq.supportedAttachments[slot] and eq.supportedAttachments[slot].componentHash) or attachDef.attachment.componentHash
                    
                    if compHashStr and compHashStr ~= "" then
                        local compHash = GetHashKey(compHashStr)
                        if compHash ~= 0 then GiveWeaponComponentToPed(ped, hash, compHash) end
                    end
                end
            end
        end
    end
end)

-- Remove a specific attachment component from weapon
RegisterNetEvent('mx-inv:client:removeAttachmentComponent', function(weaponHashName, componentHashName)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponHashName)
    if not HasPedGotWeapon(ped, hash, false) then return end

    local compHash = GetHashKey(componentHashName)
    if compHash ~= 0 then RemoveWeaponComponentFromPed(ped, hash, compHash) end
end)

-- Apply drawable and screen effect for helmet accessory
RegisterNetEvent('mx-inv:client:applyHelmetAccessory', function(payload)
    local ped = PlayerPedId()
    local propSlot = payload.propId or payload.componentId or 0
    SetPedPropIndex(ped, propSlot, payload.drawableId, payload.textureId or 0, true)

    local accessoryName = payload.accessoryName
    local active = payload.visorDown == true

    if accessoryName == 'nvg' then
        SetNightvision(active)
        SetSeethrough(false)
    elseif accessoryName == 'thermal_monocle' then
        SetSeethrough(active)
        SetNightvision(false)
    else
        SetNightvision(false)
        SetSeethrough(false)
    end
end)

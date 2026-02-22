local isInventoryOpen = false
local lastAmmoCache = {}

RegisterCommand('inventory', function()
    if not isInventoryOpen then
        local ped = PlayerPedId()
        local selectedWeapon = GetSelectedPedWeapon(ped)
        if selectedWeapon ~= GetHashKey("WEAPON_UNARMED") then
            local currentTotalAmmo = GetAmmoInPedWeapon(ped, selectedWeapon)
            local _, currentClipAmmo = GetAmmoInClip(ped, selectedWeapon)
            local cacheKey = tostring(currentTotalAmmo) .. "_" .. tostring(currentClipAmmo)
            if lastAmmoCache[selectedWeapon] ~= cacheKey then
                TriggerServerEvent('mx-inv:server:updateAmmo', selectedWeapon, currentTotalAmmo, currentClipAmmo)
                lastAmmoCache[selectedWeapon] = cacheKey
            end
        end

        TriggerServerEvent('mx-inv:server:openInventory')
    else
        CloseInventory()
    end
end, false)

RegisterKeyMapping('inventory', 'Open Inventory', 'keyboard', 'TAB')

local currentClone = nil
local rotationOffset = 0.0
local screenPosition = { x = 0.2, y = 0.5 } -- Default

local function CleanUpPed()
    if currentClone then
        DeleteEntity(currentClone)
        currentClone = nil
    end
    -- Reset Pause Menu State
    GivePedToPauseMenu(0, 0)
    SetPauseMenuPedLighting(false)
    SetPauseMenuPedSleepState(false)
    SetFrontendActive(false)
    ReplaceHudColourWithRgba(117, 0, 0, 0, 0) -- Reset
end

local function SetupPed(initialIndex)
    CleanUpPed()
    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)

    -- Make background transparent (Index 117 is PAUSE_MAP_TINT)
    ReplaceHudColourWithRgba(117, 0, 0, 0, 0)

    -- Activate Frontend (Empty Version)
    SetFrontendActive(true)
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_EMPTY"), false, -1)
    Wait(100)

    SetMouseCursorVisibleInMenus(false)

    currentClone = ClonePed(ped, heading, false, false)

    local x, y, z = table.unpack(GetEntityCoords(currentClone))
    SetEntityCoords(currentClone, x, y, z - 100.0, false, false, false, true)
    FreezeEntityPosition(currentClone, true)
    SetEntityVisible(currentClone, false, false)
    NetworkSetEntityInvisibleToNetwork(currentClone, true)

    Wait(200)

    SetPedAsNoLongerNeeded(currentClone)

    -- 0=Left, 1=Center (Default to Center if nil)
    local idx = initialIndex or 1
    GivePedToPauseMenu(currentClone, idx)
    SetPauseMenuPedLighting(true)
    SetPauseMenuPedSleepState(true)
end

RegisterNUICallback('movePedToSide', function(data, cb)
    if currentClone then
        -- 0: Left, 1: Center
        local posIndex = data.align == 'left' and 0 or 1
        GivePedToPauseMenu(currentClone, posIndex)
    end
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:useItem', data)
    cb('ok')
end)

RegisterNetEvent('mx-inv:client:openInventory', function(data)
    if isInventoryOpen then return end
    isInventoryOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = data
    })

    local hasStash = false
    if data then
        for k, _ in pairs(data) do
            -- Check for stash identifiers in keys
            if string.find(k, 'stash') or string.find(k, 'drop') then
                hasStash = true
                break
            end
        end
    end

    SetupPed(hasStash and 0 or 1)

    -- Disable Idle Camera
    Citizen.CreateThread(function()
        while isInventoryOpen do
            InvalidateIdleCam()
            InvalidateVehicleIdleCam()
            Wait(1000) -- Check every second is usually enough for idle cam reset
        end
    end)
end)

RegisterNetEvent('mx-inv:client:updateInventory', function(data)
    if not isInventoryOpen then return end
    SendNUIMessage({
        action = 'update',
        data = data
    })
end)

function CloseInventory()
    isInventoryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
    CleanUpPed()
end

RegisterNUICallback('close', function(_, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    -- data: { item, from, to, slot: {x,y} }
    TriggerServerEvent('mx-inv:server:moveItem', data)
    cb('ok')
end)

RegisterNUICallback('foldItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:foldItem', data)
    cb('ok')
end)

RegisterCommand('openstash', function()
    if isInventoryOpen then
        CloseInventory()
        return
    end
    TriggerServerEvent('mx-inv:server:openStash')
end, false)

-- Play Animation (Consume)
RegisterNetEvent('mx-inv:client:playAnim', function(data)
    local ped = PlayerPedId()
    local animDict = data.animDict
    local animName = data.anim
    local propModel = data.prop
    local duration = 5000 -- Fixed duration for now

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
        local boneIndex = GetPedBoneIndex(ped, 18905) -- Left Hand usually, or 60309 Right Hand
        -- Adjust logic based on animation. Most eating anims use Right Hand (60309) or Left (18905)
        AttachEntityToEntity(propObj, ped, boneIndex, 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1,
            true)
    end

    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, duration, 49, 0, false, false, false)

    Wait(duration)

    StopAnimTask(ped, animDict, animName, 1.0)
    if propObj then
        DeleteObject(propObj)
    end
end)

-- Weapon Wheel Disable & Shortcuts
Citizen.CreateThread(function()
    while true do
        Wait(0)
        -- Disable Weapon Wheel (TAB) and 1-5 Selection
        DisableControlAction(0, 37, true)  -- TAB (Weapon Wheel)
        DisableControlAction(0, 157, true) -- 1
        DisableControlAction(0, 158, true) -- 2
        DisableControlAction(0, 160, true) -- 3
        DisableControlAction(0, 164, true) -- 4
        DisableControlAction(0, 165, true) -- 5

        -- Shortcuts
        if IsDisabledControlJustPressed(0, 157) then TriggerServerEvent('mx-inv:server:useHotbar', 1) end -- Primary
        if IsDisabledControlJustPressed(0, 158) then TriggerServerEvent('mx-inv:server:useHotbar', 2) end -- Secondary
        if IsDisabledControlJustPressed(0, 160) then TriggerServerEvent('mx-inv:server:useHotbar', 3) end -- Pistol
        if IsDisabledControlJustPressed(0, 164) then TriggerServerEvent('mx-inv:server:useHotbar', 4) end -- Melee
    end
end)

-- Update Equipment Visuals
RegisterNetEvent('mx-inv:client:updateEquipment', function(itemName, isEquipping, ammoToLoad, attachments)
    print('[mx-inv] Debug Equip: Updating ' ..
        tostring(itemName) .. ' | Equipping: ' .. tostring(isEquipping) .. ' | Ammo: ' .. tostring(ammoToLoad))

    local ped = PlayerPedId()
    local def = Items[itemName]
    if not def then
        print('[mx-inv] Debug Equip: Item definition not found for ' .. tostring(itemName))
        return
    end
    if not def.equipment then
        print('[mx-inv] Debug Equip: Item has no equipment data.')
        return
    end

    local eq = def.equipment

    -- Weapon Logic
    if eq.weaponHash then
        local hash = GetHashKey(eq.weaponHash)
        print('[mx-inv] Debug Equip: Weapon Hash: ' .. hash)
        if isEquipping then
            GiveWeaponToPed(ped, hash, 0, false, false)
            SetPedAmmo(ped, hash, ammoToLoad or 0)

            -- Apply Attachments
            if attachments then
                for slot, attachName in pairs(attachments) do
                    if attachName then
                        local attachDef = Items[attachName]
                        if attachDef and attachDef.attachment and attachDef.attachment.componentHash then
                            local compHash = GetHashKey(attachDef.attachment.componentHash)
                            if compHash ~= 0 then
                                GiveWeaponComponentToPed(ped, hash, compHash)
                                print('[mx-inv] Applied attachment: ' .. attachDef.attachment.componentHash)
                            end
                        end
                    end
                end
            end
        else
            RemoveWeaponFromPed(ped, hash)
        end
    end

    -- Clothing Logic (Vest/Bag/Helmet)
    if eq.componentId and eq.drawableId then
        if isEquipping then
            SetPedComponentVariation(ped, eq.componentId, eq.drawableId, eq.textureId or 0, 2)
        else
            -- Reset to default/skin?
            -- For simplicity, we set to 0 (empty) for vests/bags.
            -- But for heads/legs this might mean 'naked'.
            -- Ideally we save the 'previous' state, but for this task stripping to 0 for vest(9)/bag(5) is usually 'safe-ish'.
            SetPedComponentVariation(ped, eq.componentId, 0, 0, 2)
        end
    end
end)

-- Set Active Weapon (Hotbar)
RegisterNetEvent('mx-inv:client:setActiveWeapon', function(weaponHash)
    local ped = PlayerPedId()
    if weaponHash then
        local hash = (type(weaponHash) == 'string') and GetHashKey(weaponHash) or weaponHash
        local currentWeapon = GetSelectedPedWeapon(ped)

        if currentWeapon == hash then
            SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
        else
            SetCurrentPedWeapon(ped, hash, true)
        end
    else
        SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
    end
end)

-- Handle Equipping Item (From NUI)
RegisterNUICallback('equipItem', function(data, cb)
    print('[mx-inv] Debug Client: Requesting Equip Item: ' .. data.item .. ' to slot: ' .. data.slot)
    TriggerServerEvent('mx-inv:server:moveItem', {
        item = data.item,
        from = data.from,
        to = 'equip-' .. data.slot,
        slot = {} -- Not needed for equip
    })
    cb('ok')
end)

-- Handle Unequipping Item (From NUI)
RegisterNUICallback('unequipItem', function(data, cb)
    print('[mx-inv] Debug Client: Requesting Unequip Item: ' .. data.item .. ' from slot: ' .. data.fromSlot)
    TriggerServerEvent('mx-inv:server:moveItem', {
        item = data.item,
        from = 'equip-' .. data.fromSlot,
        to = data.to,
        slot = data.slot,    -- Target slot in inventory
        folded = data.folded -- Forward fold state so server persists it correctly
    })
    cb('ok')
end)

-- Handle Swap Equipment (From NUI)
RegisterNUICallback('swapEquipment', function(data, cb)
    print('[mx-inv] Debug Client: Requesting Swap Equipment: ' ..
        data.item .. ' from ' .. data.fromSlot .. ' to ' .. data.toSlot)
    TriggerServerEvent('mx-inv:server:swapEquipment', {
        item = data.item,
        fromSlot = data.fromSlot,
        toSlot = data.toSlot
    })
    cb('ok')
end)

-- Handle Load Ammo into Weapon (From NUI)
RegisterNUICallback('loadAmmoIntoWeapon', function(data, cb)
    print('[mx-inv] Debug Client: Loading Ammo into Weapon: ' ..
        tostring(data.ammoItem.name) .. ' into ' .. tostring(data.weaponSlot))
    TriggerServerEvent('mx-inv:server:loadAmmoIntoWeapon', {
        id = data.id,
        ammoItem = data.ammoItem,
        weaponSlot = data.weaponSlot,
        weaponContainer = data.weaponContainer,
        ammoContainer = data.ammoContainer
    })
    cb('ok')
end)

-- Handle Stack Items (Merge stackable items)
RegisterNUICallback('stackItems', function(data, cb)
    print('[mx-inv] Debug Client: Stacking items ' .. tostring(data.fromItemId) .. ' -> ' .. tostring(data.toItemId))
    TriggerServerEvent('mx-inv:server:stackItems', {
        fromItemId = data.fromItemId,
        fromContainerId = data.fromContainerId,
        toItemId = data.toItemId,
        toContainerId = data.toContainerId
    })
    cb('ok')
end)

-- Handle Unload Weapon (From NUI Context Menu)
RegisterNUICallback('unloadItem', function(data, cb)
    print('[mx-inv] Debug Client: Requesting Unload Item: ' ..
        tostring(data.name) .. ' from container ' .. tostring(data.containerId))
    TriggerServerEvent('mx-inv:server:unloadWeapon', {
        id = data.id,
        name = data.name,
        containerId = data.containerId,
        slot = data.slot
    })
    cb('ok')
end)

-- Handle Attach Item to Weapon (From NUI Drag-and-Drop)
RegisterNUICallback('attachToWeapon', function(data, cb)
    print('[mx-inv] Debug Client: Attaching ' ..
        tostring(data.attachmentItem) ..
        ' to weapon ' .. tostring(data.weaponId) .. ' slot ' .. tostring(data.attachmentSlot))
    TriggerServerEvent('mx-inv:server:attachToWeapon', {
        weaponId = data.weaponId,
        weaponContainerId = data.weaponContainerId,
        attachmentSlot = data.attachmentSlot,
        attachmentItem = data.attachmentItem,
        attachmentItemId = data.attachmentItemId,
        fromContainerId = data.fromContainerId
    })
    cb('ok')
end)

-- Handle Remove Attachment from Weapon (From NUI Context Menu)
RegisterNUICallback('removeAttachment', function(data, cb)
    print('[mx-inv] Debug Client: Removing attachment from slot ' ..
        tostring(data.attachmentSlot) .. ' on weapon ' .. tostring(data.weaponId))
    TriggerServerEvent('mx-inv:server:removeAttachment', {
        weaponId = data.weaponId,
        weaponContainerId = data.weaponContainerId,
        attachmentSlot = data.attachmentSlot,
        attachmentItem = data.attachmentItem,
        toContainerId = data.toContainerId,
        toSlot = data.toSlot
    })
    cb('ok')
end)

-- Sync attachments on equipped weapon (add/remove GTA components)
RegisterNetEvent('mx-inv:client:syncAttachments', function(weaponHashName, attachments)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponHashName)
    if not HasPedGotWeapon(ped, hash, false) then return end

    -- Apply each attachment component
    if attachments then
        for slot, attachName in pairs(attachments) do
            if attachName then
                local attachDef = Items[attachName]
                if attachDef and attachDef.attachment and attachDef.attachment.componentHash then
                    local compHash = GetHashKey(attachDef.attachment.componentHash)
                    if compHash ~= 0 then
                        GiveWeaponComponentToPed(ped, hash, compHash)
                        print('[mx-inv] Applied component: ' ..
                            attachDef.attachment.componentHash .. ' to ' .. weaponHashName)
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
    if compHash ~= 0 then
        RemoveWeaponComponentFromPed(ped, hash, compHash)
        print('[mx-inv] Removed component: ' .. componentHashName .. ' from ' .. weaponHashName)
    end
end)

-- Set Ammo & Play Reload Animation (Native Feel)
RegisterNetEvent('mx-inv:client:setAmmoAndReload', function(weaponHashName, ammoCount)
    local ped = PlayerPedId()
    local hash = (type(weaponHashName) == 'string') and GetHashKey(weaponHashName) or weaponHashName

    print('[mx-inv] SetAmmoAndReload: weapon=' .. tostring(weaponHashName) .. ' ammo=' .. tostring(ammoCount))

    -- Ensure player has the weapon
    if not HasPedGotWeapon(ped, hash, false) then
        return
    end

    -- Check if player is HOLDING this weapon
    local selectedWeapon = GetSelectedPedWeapon(ped)
    if selectedWeapon ~= hash then
        -- Just set ammo without animation
        SetPedAmmo(ped, hash, ammoCount)
        return
    end

    -- Set the ammo count
    SetPedAmmo(ped, hash, ammoCount)
    lastAmmoCache[hash] = ammoCount

    -- Trigger native reload animation
    -- Logic: Ensure weapon is ready to reload
    if ammoCount > 0 then
        -- Force reload task
        MakePedReload(ped)
        -- ClearTask(ped) ? No.
    end
end)

RegisterNetEvent('mx-inv:client:addWeaponAmmo', function(weaponHash, amountToAdd)
    local ped = PlayerPedId()
    if HasPedGotWeapon(ped, weaponHash, false) then
        local currentAmmo = GetAmmoInPedWeapon(ped, weaponHash)
        -- The server already calculated the total ammo and updated DB.
        -- We just add to the ped here.
        AddAmmoToPed(ped, weaponHash, amountToAdd)

        -- Force a reload if we have no clip
        local _, clipAmmo = GetAmmoInClip(ped, weaponHash)
        if clipAmmo == 0 then
            MakePedReload(ped)
        end
    end
end)

-- Ammo Sync Loop (Total and Clip)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- Check every 500ms for ammo changes
        local ped = PlayerPedId()
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            local selectedWeapon = GetSelectedPedWeapon(ped)
            if selectedWeapon ~= GetHashKey("WEAPON_UNARMED") then
                local currentTotalAmmo = GetAmmoInPedWeapon(ped, selectedWeapon)
                local _, currentClipAmmo = GetAmmoInClip(ped, selectedWeapon)

                local cacheKey = tostring(currentTotalAmmo) .. "_" .. tostring(currentClipAmmo)

                -- Initialize cache if nil
                if lastAmmoCache[selectedWeapon] == nil then
                    lastAmmoCache[selectedWeapon] = cacheKey
                    TriggerServerEvent('mx-inv:server:updateAmmo', selectedWeapon, currentTotalAmmo, currentClipAmmo)
                end

                -- Sync if changed
                if lastAmmoCache[selectedWeapon] ~= cacheKey then
                    TriggerServerEvent('mx-inv:server:updateAmmo', selectedWeapon, currentTotalAmmo, currentClipAmmo)
                    lastAmmoCache[selectedWeapon] = cacheKey
                end
            end
        end
    end
end)

-- Receive precise ammo updates from server and update UI in real-time
RegisterNetEvent('mx-inv:client:syncAmmoUI', function(weaponSlot, totalAmmo, clipAmmo)
    SendNUIMessage({
        action = 'updateWeaponAmmo',
        data = {
            weaponSlot = weaponSlot,
            totalAmmo = totalAmmo,
            clipAmmo = clipAmmo
        }
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    print('[mx-inv] Resource stopping. Cleaning up UI and Peds.')
    CloseInventory()
    -- Ensure NUI focus is released (CloseInventory does it, but double check)
    SetNuiFocus(false, false)
end)

-- Handle Player Loaded (Initial sync of equipped gear)
RegisterNetEvent('mx-inv:client:playerLoaded', function(equipment)
    print('[mx-inv] Received initial equipment state, syncing visuals...')
    if equipment then
        for slot, item in pairs(equipment) do
            if item and item.name then
                local ammoToLoad = tonumber(item.metadata and item.metadata.ammo) or 0
                local attachments = item.metadata and item.metadata.attachments or nil
                TriggerEvent('mx-inv:client:updateEquipment', item.name, true, ammoToLoad, attachments)
            end
        end
    end
end)

-- Re-apply equipment after resource restart (script hot-reload)
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Wait for the game to be ready before re-giving weapons
    SetTimeout(2000, function()
        print('[mx-inv] Resource restarted. Requesting equipment re-sync...')
        TriggerServerEvent('mx-inv:server:requestEquipment')
    end)
end)

-- Re-apply equipment when player spawns (works with spawn managers: spawnmanager, qb-spawn, etc.)
AddEventHandler('playerSpawned', function()
    print('[mx-inv] playerSpawned detected. Requesting equipment re-sync...')
    SetTimeout(1000, function()
        TriggerServerEvent('mx-inv:server:requestEquipment')
    end)
end)

-- Death detection: re-apply equipment when player respawns after dying
local wasDead = false
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local isDead = IsEntityDead(ped) or IsPedFatallyInjured(ped)
            if isDead then
                -- Mark as dead, wait for respawn
                wasDead = true
            elseif wasDead then
                -- Player just respawned
                wasDead = false
                print('[mx-inv] Player respawned. Requesting equipment re-sync...')
                -- Small delay to let GTA finish respawn routines before giving weapons
                SetTimeout(2000, function()
                    TriggerServerEvent('mx-inv:server:requestEquipment')
                end)
            end
        end
    end
end)

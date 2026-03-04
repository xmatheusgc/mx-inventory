local isInventoryOpen = false
local lastAmmoCache = {}
local currentClone = nil

-- Modules are loaded globally via fxmanifest.lua

-- Helper: Play Animation
local function PlayInventoryAnim(type)
    local anim = Config.Inventory.Animations[type]
    if not anim then return end

    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(0) end

    if not HasAnimDictLoaded(anim.dict) then
        print('[mx-inv] Error: Could not load anim dict: ' .. tostring(anim.dict))
        return
    end

    TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, -8.0, 2000, 48, 0, false, false, false)
end

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



RegisterNetEvent('mx-inv:client:openInventory', function(data)
    if isInventoryOpen then return end
    isInventoryOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = data,
        config = {
            equipmentSlots = Config.EquipmentSlots
        }
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

    -- Capture position when opening (for distance checks)
    local openPos = GetEntityCoords(PlayerPedId())

    -- Disable Idle Camera and handle distance auto-close
    Citizen.CreateThread(function()
        while isInventoryOpen do
            -- Idle Cam
            InvalidateIdleCam()
            InvalidateVehicleIdleCam()

            -- Auto-close if moved too far from a stash/drop
            if hasStash then
                local currentPos = GetEntityCoords(PlayerPedId())
                if #(currentPos - openPos) > 2.0 then
                    CloseInventory()
                end
            end

            Wait(500) -- Check every 500ms
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
    -- Notify server to save/unbind any open stash
    TriggerServerEvent('mx-inv:server:closeInventory')
    TriggerEvent('mx-inv:client:closed')
end

RegisterCommand('openstash', function()
    if isInventoryOpen then
        CloseInventory()
        return
    end
    TriggerServerEvent('mx-inv:server:openStash')
end, false)



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

-- ── Visor Toggle Keybind (Hold N) ─────────────────────────────────────
local visorKeyPressedAt    = nil
local visorActionTriggered = false
local visorKeybindThread   = false
local VISOR_HOLD_MS        = 300 -- milliseconds to hold before triggering

local function PlayVisorEffects()
    Citizen.CreateThread(function()
        local ped = PlayerPedId()

        -- Figure out if visor is currently up or down by checking current prop
        -- Based on items.lua: 118 (NVG down), 120 (Thermal down)
        -- 119 (NVG up), 121 (Thermal up)
        local currDrawable = GetPedPropIndex(ped, 0)

        local isCurrentlyDown = false
        local animDict = 'anim@mp_helmets@on_foot'
        local animName = 'visor_down'

        local found = false
        if Items then
            for _, itemDef in pairs(Items) do
                if itemDef.type == 'helmet' and itemDef.equipment and itemDef.equipment.accessoryDrawables then
                    for _, accData in pairs(itemDef.equipment.accessoryDrawables) do
                        if currDrawable == accData.visorDown then
                            isCurrentlyDown = true
                            animDict = accData.animDict or 'anim@mp_helmets@on_foot'
                            animName = accData.animUp or 'visor_up'
                            found = true
                            break
                        elseif currDrawable == accData.visorUp then
                            isCurrentlyDown = false
                            animDict = accData.animDict or 'anim@mp_helmets@on_foot'
                            animName = accData.animDown or 'visor_down'
                            found = true
                            break
                        end
                    end
                end
                if found then break end
            end
        end

        if not found then
            local isGoggles = (currDrawable >= 115 and currDrawable <= 119)
            -- Down states for NVG/Thermal based on items.lua (116 = NVG down, 118 = Thermal down).
            -- Also handling common female down states (115, 117) and other common down visors (120, 122)
            if currDrawable == 115 or currDrawable == 116 or currDrawable == 117 or currDrawable == 118 or currDrawable == 120 or currDrawable == 122 then
                isCurrentlyDown = true
            end

            if isGoggles then
                animName = isCurrentlyDown and 'goggles_up' or 'goggles_down'
            else
                animName = isCurrentlyDown and 'visor_up' or 'visor_down'
            end
        end

        if GetFollowPedCamViewMode() == 4 then
            animName = animName:gsub('goggles', 'visor')
            animName = 'pov_' .. animName
        end
        RequestAnimDict(animDict)
        local t = 0
        while not HasAnimDictLoaded(animDict) and t < 20 do
            Wait(50)
            t = t + 1
        end

        if HasAnimDictLoaded(animDict) then
            -- Full upper-body animation (48), play speed 8.0, blend out 1.0, duration -1
            TaskPlayAnim(ped, animDict, animName, 8.0, 1.0, -1, 48, 0, false, false, false)

            -- Wait until animation reaches exactly 39% (when hand touches visor or grabs it)
            local timeout = GetGameTimer()
            while GetEntityAnimCurrentTime(ped, animDict, animName) < 0.39 do
                Wait(0)
                if GetGameTimer() - timeout > 1000 then break end
            end

            -- Exactly here is where the prop changes and sound plays
            PlaySoundFrontend(-1, 'HELMET_ON', 'GTAO_FM_Events_Soundset', true)
            TriggerServerEvent('mx-inv:server:toggleHelmetVisor', {})

            -- Let animation finish (stop after a brief moment)
            Wait(500)
            StopAnimTask(ped, animDict, animName, 1.0)
            RemoveAnimDict(animDict)
        else
            -- Fallback if anim fails
            TriggerServerEvent('mx-inv:server:toggleHelmetVisor', {})
        end
    end)
end

RegisterCommand('+toggleVisor', function()
    if visorKeybindThread then return end
    visorKeyPressedAt = GetGameTimer()
    visorActionTriggered = false
    visorKeybindThread = true

    Citizen.CreateThread(function()
        while visorKeyPressedAt do
            Wait(0)
            if visorKeyPressedAt and not visorActionTriggered and (GetGameTimer() - visorKeyPressedAt) >= VISOR_HOLD_MS then
                visorActionTriggered = true
                PlayVisorEffects()
            end
        end
        visorKeybindThread = false
    end)
end, false)

RegisterCommand('-toggleVisor', function()
    visorKeyPressedAt = nil
end, false)

RegisterKeyMapping('+toggleVisor', 'Abaixar/Levantar Viseira do Capacete', 'keyboard', 'n')

-- Server fires this back after a successful visor toggle (no sound/anim here anymore)
RegisterNetEvent('mx-inv:client:playVisorAnim', function(visorDown)
    print(string.format('[mx-inv] playVisorAnim received: visorDown=%s', tostring(visorDown)))
end)





-- Generic Notification
RegisterNetEvent('mx-inv:client:notify', function(msg, type, duration)
    -- Internal UI Notification
    SendNUIMessage({
        action = 'notify',
        data = {
            message = msg,
            type = type or 'info',
            duration = duration or 3000
        }
    })

    -- If no bridge notification, use chat (optional fallback)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "Sistema", msg }
    })
end)





-- ============================================================
-- HELMET ACCESSORY CLIENT HANDLERS
-- ============================================================

-- NUI: Attach accessory to equipped helmet
RegisterNUICallback('attachToHelmet', function(data, cb)
    TriggerServerEvent('mx-inv:server:attachToHelmet', {
        helmetId        = data.helmetId,
        accessoryItem   = data.accessoryItem,
        accessoryItemId = data.accessoryItemId,
        fromContainerId = data.fromContainerId
    })
    cb('ok')
end)

-- NUI: Remove accessory from equipped helmet
RegisterNUICallback('removeHelmetAccessory', function(data, cb)
    TriggerServerEvent('mx-inv:server:removeHelmetAccessory', {
        helmetId      = data.helmetId,
        accessorySlot = data.accessorySlot,
        toContainerId = data.toContainerId,
        toSlot        = data.toSlot
    })
    cb('ok')
end)

-- NUI: Toggle helmet visor (activate / deactivate accessory effect)
RegisterNUICallback('toggleHelmetVisor', function(data, cb)
    TriggerServerEvent('mx-inv:server:toggleHelmetVisor', {
        helmetId = data.helmetId
    })
    cb('ok')
end)

-- Server → Client: Apply drawable and screen effect for helmet accessory
RegisterNetEvent('mx-inv:client:applyHelmetAccessory', function(payload)
    local ped = PlayerPedId()

    -- Change helmet prop drawable (prop slot 0 = head hat/helmet)
    -- propId should be 0 for head props; falls back to componentId for backwards compat
    local propSlot = payload.propId or payload.componentId or 0
    SetPedPropIndex(ped, propSlot, payload.drawableId, payload.textureId or 0, true)

    -- Activate / deactivate screen effects based on accessory type and visor state
    local slot = payload.slot
    local accessoryName = payload.accessoryName
    local active = payload.visorDown == true

    if accessoryName == 'nvg' then
        SetNightvision(active)
        SetSeethrough(false)
    elseif accessoryName == 'thermal_monocle' then
        SetSeethrough(active)
        SetNightvision(false)
    else
        -- No accessory (removed) or unrecognized: ensure effects are off
        SetNightvision(false)
        SetSeethrough(false)
    end

    print(string.format('[mx-inv] Helmet accessory sync: slot=%s drawable=%d visorDown=%s',
        tostring(slot), payload.drawableId or -1, tostring(payload.visorDown)))
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
                local accessories = item.metadata and item.metadata.accessories or nil
                local visorDown = item.metadata and item.metadata.visorDown or false
                TriggerEvent('mx-inv:client:updateEquipment', item.name, true, ammoToLoad, attachments, accessories, visorDown)
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

-- ============================================================
-- Give Item to Player - Client Handlers
-- ============================================================

-- NUI: Sender opens give modal → request nearby player list from server
RegisterNUICallback('requestNearbyPlayers', function(_, cb)
    TriggerServerEvent('mx-inv:server:requestNearbyPlayers')
    cb('ok')
end)

-- NUI: Sender confirms give
RegisterNUICallback('giveItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:giveItem', data)
    cb('ok')
end)

-- NUI: Player splits a stack
RegisterNUICallback('splitItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:splitItem', data)
    cb('ok')
end)

-- NUI: Player drops an item
RegisterNUICallback('dropItem', function(data, cb)
    cb('ok')
    print('[mx-inv] NUI Callback: dropItem triggered for ' .. tostring(data.name or data.item))

    Citizen.CreateThread(function()
        PlayInventoryAnim('Drop')
    end)

    TriggerServerEvent('mx-inv:server:dropItem', data)
end)


-- Server → Client: world drops sync
local worldDrops = {}
RegisterNetEvent('mx-inv:client:syncDrops', function(drops)
    worldDrops = drops
end)

-- Request initial drops on start
TriggerServerEvent('mx-inv:server:requestDrops')


-- Server → Client: nearby players list (reply to requestNearbyPlayers)
RegisterNetEvent('mx-inv:client:nearbyPlayers', function(players)
    SendNUIMessage({ action = 'nearbyPlayers', data = players })
end)


-- Tracks whether WE opened NUI focus just for the give popup (so we don't close inventory's focus)
local givePopupHasFocus = false

local function OpenGivePopupFocus()
    if not isInventoryOpen then
        SetNuiFocus(true, true)
        givePopupHasFocus = true
    end
end

local function CloseGivePopupFocus()
    if givePopupHasFocus then
        givePopupHasFocus = false
        if not isInventoryOpen then
            SetNuiFocus(false, false)
        end
    end
end
-- Helper: Draw 3D Text
local function DrawText3D(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

-- World Drops Management
local localProps = {} -- dropId -> entity

-- Thread: Spawn/Despawn props based on distance
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for id, drop in pairs(worldDrops) do
            local dist = #(coords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))

            if dist < 20.0 and not localProps[id] then
                -- Spawn local prop
                local model = GetHashKey(drop.prop)

                -- Check if model is valid before requesting
                if not IsModelInCdimage(model) or not IsModelValid(model) then
                    model = GetHashKey('v_ret_gc_box1')
                end

                RequestModel(model)
                local timeout = GetGameTimer() + 2000
                while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end

                -- Fallback if the model timed out and didn't load
                if not HasModelLoaded(model) then
                    model = GetHashKey('v_ret_gc_box1')
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end
                end

                local prop = CreateObject(model, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false)

                if prop and prop ~= 0 then
                    SetEntityCollision(prop, false, false)
                    PlaceObjectOnGroundProperly(prop)

                    -- Rotate weapons to lie flat
                    if drop.type and (string.match(drop.type, 'weapon_') or drop.type == 'weapon') and drop.type ~= 'weapon_melee' then
                        SetEntityRotation(prop, 90.0, 0.0, GetEntityHeading(prop), 2, true)
                    end

                    FreezeEntityPosition(prop, true)
                    localProps[id] = prop
                end
            elseif dist > 20.0 and localProps[id] then
                -- Despawn
                DeleteObject(localProps[id])
                localProps[id] = nil
            end
        end

        -- Cleanup untracked props (removed from worldDrops)
        for id, prop in pairs(localProps) do
            if not worldDrops[id] then
                DeleteObject(prop)
                localProps[id] = nil
            end
        end

        Wait(1000)
    end
end)

-- Thread: Interaction & Pickup
local isProcessingPickup = false
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for id, drop in pairs(worldDrops) do
            local dist = #(coords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))

            if dist < 2.0 then
                sleep = 0
                DrawText3D(drop.coords, "[" .. drop.count .. "x] " .. drop.label .. " ~n~~g~[E]~w~ Pegar")

                if IsControlJustPressed(0, 38) and not isProcessingPickup then -- E key
                    isProcessingPickup = true
                    PlayInventoryAnim('Pickup')
                    Wait(500)
                    TriggerServerEvent('mx-inv:server:pickupItem', id)

                    -- Small delay to prevent spamming picks
                    Citizen.CreateThread(function()
                        Wait(1000)
                        isProcessingPickup = false
                    end)
                end
            end
        end

        Wait(sleep)
    end
end)

-- Server → Client: incoming give request (receiver side)
RegisterNetEvent('mx-inv:client:receiveItemRequest', function(data)
    OpenGivePopupFocus()
    SendNUIMessage({ action = 'receiveItemRequest', data = data })
end)

-- Server → Client: request expired (auto-dismiss receiver modal)
RegisterNetEvent('mx-inv:client:giveRequestExpired', function()
    CloseGivePopupFocus()
    SendNUIMessage({ action = 'giveRequestExpired' })
end)

-- Server → Client: result/feedback for both sender and receiver
RegisterNetEvent('mx-inv:client:giveItemResult', function(data)
    -- Release focus when result arrives for the receiver (transferred or failed)
    if data and (data.transferred or (not data.ok and not data.pending)) then
        CloseGivePopupFocus()
    end
    SendNUIMessage({ action = 'giveItemResult', data = data })
end)

-- NUI: Target responds (accept/decline) — also close popup focus
RegisterNUICallback('respondGiveItem', function(data, cb)
    CloseGivePopupFocus()
    TriggerServerEvent('mx-inv:server:respondGiveItem', data)
    cb('ok')
end)

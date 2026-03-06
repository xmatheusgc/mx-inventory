-- client/modules/nui.lua
-- Centralized handler for all React NUI interactions

RegisterNUICallback('movePedToSide', function(data, cb)
    if currentClone then
        local posIndex = data.align == 'left' and 0 or 1
        GivePedToPauseMenu(currentClone, posIndex)
    end
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:useItem', data)
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:moveItem', data)
    cb('ok')
end)

RegisterNUICallback('foldItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:foldItem', data)
    cb('ok')
end)

RegisterNUICallback('equipItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:moveItem', {
        item = data.item,
        id = data.id,
        from = data.from,
        to = 'equip-' .. data.slot,
        slot = {}
    })
    cb('ok')
end)

RegisterNUICallback('unequipItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:moveItem', {
        item = data.item,
        id = data.id,
        from = 'equip-' .. data.fromSlot,
        to = data.to,
        slot = data.slot,
        rotated = data.rotated,
        folded = data.folded
    })
    cb('ok')
end)

RegisterNUICallback('swapEquipment', function(data, cb)
    TriggerServerEvent('mx-inv:server:swapEquipment', {
        item = data.item,
        fromSlot = data.fromSlot,
        toSlot = data.toSlot
    })
    cb('ok')
end)

RegisterNUICallback('loadAmmoIntoWeapon', function(data, cb)
    TriggerServerEvent('mx-inv:server:loadAmmoIntoWeapon', {
        id = data.id,
        ammoItem = data.ammoItem,
        weaponSlot = data.weaponSlot,
        weaponContainer = data.weaponContainer,
        ammoContainer = data.ammoContainer
    })
    cb('ok')
end)

RegisterNUICallback('stackItems', function(data, cb)
    TriggerServerEvent('mx-inv:server:stackItems', {
        fromItemId = data.fromItemId,
        fromContainerId = data.fromContainerId,
        toItemId = data.toItemId,
        toContainerId = data.toContainerId
    })
    cb('ok')
end)

RegisterNUICallback('unloadItem', function(data, cb)
    TriggerServerEvent('mx-inv:server:unloadWeapon', {
        id = data.id,
        name = data.name,
        containerId = data.containerId,
        slot = data.slot
    })
    cb('ok')
end)

RegisterNUICallback('attachToWeapon', function(data, cb)
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

RegisterNUICallback('removeAttachment', function(data, cb)
    TriggerServerEvent('mx-inv:server:removeAttachment', {
        weaponId = data.weaponId,
        weaponContainerId = data.weaponContainerId,
        attachmentSlot = data.attachmentSlot,
        attachmentItem = data.attachmentItem,
        toContainerId = data.toContainerId,
        toSlot = data.toSlot,
        rotated = data.rotated,
        folded = data.folded
    })
    cb('ok')
end)

RegisterNUICallback('attachHelmetAccessory', function(data, cb)
    TriggerServerEvent('mx-inv:server:attachHelmetAccessory', {
        helmetId = data.helmetId,
        helmetContainerId = data.helmetContainerId,
        accessorySlot = data.accessorySlot,
        accessoryItem = data.accessoryItem,
        accessoryItemId = data.accessoryItemId,
        fromContainerId = data.fromContainerId
    })
    cb('ok')
end)

RegisterNUICallback('removeHelmetAccessory', function(data, cb)
    TriggerServerEvent('mx-inv:server:removeHelmetAccessory', {
        helmetId = data.helmetId,
        helmetContainerId = data.helmetContainerId,
        accessorySlot = data.accessorySlot,
        accessoryItem = data.accessoryItem,
        toContainerId = data.toContainerId,
        toSlot = data.toSlot,
        rotated = data.rotated,
        folded = data.folded
    })
    cb('ok')
end)

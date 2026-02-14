-- server/bridge/standalone.lua
local db = exports[GetCurrentResourceName()]

local standalone = {}

function standalone.GetIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.find(id, "license:") then
            return id -- Returns "license:xxxxxxxx"
        end
    end
    return nil
end

function standalone.GetPlayerName(source)
    return GetPlayerName(source)
end

function standalone.GetPlayer(source)
    local id = standalone.GetIdentifier(source)
    if not id then return nil end

    return {
        source = source,
        identifier = id,
        name = GetPlayerName(source),
        -- Standalone specific data can go here
    }
end

MX_Bridge_Standalone = standalone

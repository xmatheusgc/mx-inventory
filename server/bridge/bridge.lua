-- server/bridge/bridge.lua
local Framework = Config.Framework or 'standalone'

local bridge = {}

if Framework == 'qb' then
    -- Load QB
elseif Framework == 'esx' then
    -- Load ESX
else
    -- Standalone (Default)
    print('^3[mx-inv] Loading Standalone Bridge...^0')
    bridge = MX_Bridge_Standalone
end

-- Export Common Functions
function MX_GetPlayer(source)
    return bridge.GetPlayer(source)
end

function MX_GetIdentifier(source)
    return bridge.GetIdentifier(source)
end

function MX_GetPlayerName(source)
    return bridge.GetPlayerName(source)
end

-- Export global
exports('GetPlayer', MX_GetPlayer)
exports('GetIdentifier', MX_GetIdentifier)
exports('GetPlayerName', MX_GetPlayerName)

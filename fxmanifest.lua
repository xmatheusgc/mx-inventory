fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'Grid-Based Inventory System'
version '1.0.0'

dependencies {
    'oxmysql',
}

shared_scripts {
    'config.lua',
    'data/items.lua'
}

client_scripts {
    'client/modules/nui.lua',
    'client/modules/equipment.lua',
    'client/main.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/modules/inventory.lua',
    'server/modules/movement.lua',
    'server/modules/drop.lua',
    'server/modules/equipment.lua',
    'server/modules/stash.lua',
    'server/bridge/standalone.lua', -- Load implementations first
    'server/bridge/bridge.lua',     -- Load controller last
    'server/main.lua'
}

ui_page 'web/dist/index.html'

server_exports {
    'RegisterStash',
    'OpenStash',
    'CloseStash',
    'DeleteStash'
}

files {
    'web/dist/index.html',
    'web/dist/assets/*',
    'server/modules/*.lua',
    'client/modules/*.lua'
}

fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Grid-Based Inventory System'
version '1.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*'
}

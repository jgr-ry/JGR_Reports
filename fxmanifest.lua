fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'JGR Studio'
description 'Sistema de reportes multi-framework (QBCore / Qbox / ESX / Standalone)'
version '1.1.0'
jgr_version_key 'JGR_Reports'
repository 'https://github.com/jgr-ry/JGR_Reports'

shared_scripts {
    'locales/en.lua',
    'locales/es.lua',
    'config.lua',
    'locale_shared.lua',
    'bridge/sh_bridge.lua',
}

client_scripts {
    'bridge/cl_bridge.lua',
    'client/client.lua',
}

server_scripts {
    'server/init.lua',
    'server/version_check.lua',
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_bridge.lua',
    'server/server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
    'install.sql',
}

escrow_ignore {
    'config.lua',
    'locales/en.lua',
    'locales/es.lua',
    'locale_shared.lua',
    'bridge/sh_bridge.lua',
    'bridge/cl_bridge.lua',
    'bridge/sv_bridge.lua',
}

dependencies {
    'oxmysql',
}

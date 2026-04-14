fx_version 'cerulean'
game 'gta5'

author 'JGR Studio'
description 'Sistema de reportes multi-framework (QB / Qbox / ESX / Standalone)'
version '1.0.0'

shared_scripts {
    'locales/en.lua',
    'locales/es.lua',
    'config.lua',
    'locale_shared.lua',
}

client_scripts {
    'bridge/cl_bridge.lua',
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/version_check.lua',
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
    'bridge/cl_bridge.lua',
    'bridge/sv_bridge.lua',
}

dependencies {
    'oxmysql',
}

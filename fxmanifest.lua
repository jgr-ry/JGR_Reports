fx_version 'cerulean'
game 'gta5'

author 'JGR Reports'
description 'Sistema Avanzado de Reportes'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
    'install.sql'
}

escrow_ignore {
    'config.lua'
}
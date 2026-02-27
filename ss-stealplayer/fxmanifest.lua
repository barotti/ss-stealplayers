fx_version 'cerulean'
game 'gta5'

author 'Seifer'
description 'ss-stealplayer - Perquisire giocatori con le mani alzate'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'wasabi_ambulance',
}

fx_version 'cerulean'
game 'gta5'

author '@allroundjonu'
description 'Advanced Drug System for FiveM'
version 'v1.2.4'

shared_script 'bridge/init.lua'

shared_scripts {
    'shared/config.lua',
    'locales/en.lua',
    'locales/*.lua',
    '@ox_lib/init.lua',
    'bridge/**/shared.lua',
    -- '@es_extended/imports.lua',
}

client_scripts {

    'bridge/**/client.lua',

    'client/cl_admin.lua',
    'client/cl_menus.lua',
    'client/cl_dealer.lua',
    'client/cl_planting.lua',
    'client/cl_lamps.lua',
    'client/cl_pots.lua',
    'client/cl_dryingracks.lua',
    'client/cl_waterpoints.lua',
    'client/cl_processing.lua',
    'client/cl_selling.lua',
    'client/cl_target.lua',
    'client/cl_plant_targets.lua',
    'client/cl_using.lua',
    'client/cl_blips.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'bridge/**/server.lua',
    
    'server/sv_admin.lua',
    'server/sv_dealer.lua',
    'server/sv_planting.lua',
    'server/sv_lamps.lua',
    'server/sv_pots.lua',
    'server/sv_dryingracks.lua',
    'server/sv_waterpoints.lua',
    'server/sv_processing.lua',
    'server/sv_selling.lua',
    'server/sv_usableitems.lua',
    'server/sv_versioncheck.lua',
    'server/sv_webhooks.lua',
    'server/database/sv_setupdatabase.lua'
}

files = {
    'server/database/drug_plants.sql',
    'server/database/drug_processing.sql',
    'server/database/drug_lamps.sql',
    'server/database/drug_pots.sql',
    'server/database/drug_dryingracks.sql',
    'server/database/drug_waterpoints.sql',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'lunar_drugscreator_props', -- custom coca plant props (elm_coca_*), precisa estar rodando antes
    'MakitaPot', -- vaso de plantio de verdade (bzzz_growing_freepot_*), precisa estar rodando antes
    'bzzz_lights_and_lamps', -- lâmpadas com cor de luz de verdade (bzzz_world_of_lamps_*/bzzz_dream_of_lights_*), precisa estar rodando antes
    'nextgen_weedprops', -- 7 variedades novas de planta de maconha (ng_prop_weed_*), precisa estar rodando antes
    'tesouras_do_makita', -- tesoura 3D usada como "cursor" no minigame de colheita (client/cl_planting.lua), precisa estar rodando antes
    'bzzz_cutting_weed' -- foice (prop bzzz_prop_sickle_a + anim bzzz_cutting_sickle) usada pra cortar a planta inteira, precisa estar rodando antes
}

lua54 'yes'
usefxv2oal 'yes'
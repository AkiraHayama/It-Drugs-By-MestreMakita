-- O it-drugs (client/cl_fans.lua) manda tocar por aqui:
--   TriggerEvent('itdrugs_som:play', 'fanVolume', volume) -> som do ventilador em loop (0 = para)
--   TriggerEvent('itdrugs_som:play', 'fanClick', volume)  -> clique de ligar/desligar
AddEventHandler('itdrugs_som:play', function(kind, volume)
    SendNUIMessage({ type = kind, volume = volume })
end)

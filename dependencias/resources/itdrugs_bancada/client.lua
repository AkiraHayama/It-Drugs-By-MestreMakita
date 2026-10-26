-- Só a tela; a lógica da bancada fica no it-drugs (client/cl_bench.lua), que manda por aqui:
--   TriggerEvent('itdrugs_bancada:open', items, help) -> mostra a barra de itens e pega o mouse
--   TriggerEvent('itdrugs_bancada:items', items)      -> atualiza a barra
--   TriggerEvent('itdrugs_bancada:close')             -> esconde e devolve o mouse pro jogo
--   TriggerEvent('itdrugs_bancada:hover', info)       -> caixinha { label, count } perto do mouse (nil esconde)
-- items = { { name, label, count, disabled, fallback } }; help = dicas separadas por '|'.
-- A tela responde com TriggerEvent('itdrugs_bancada:mouse', data):
--   { type = 'down' | 'move' | 'up', x, y }, { type = 'remove', x, y } (botão direito),
--   { type = 'drop', item, x, y } (soltou um item da barra), { type = 'exit' } (Backspace/ESC)
--   x, y de 0 a 1 (fração da tela, igual GetScreenCoordFromWorldCoord)
AddEventHandler('itdrugs_bancada:open', function(items, help)
    SendNUIMessage({ type = 'open', items = items, help = help })
    SetNuiFocus(true, true)
end)

AddEventHandler('itdrugs_bancada:items', function(items)
    SendNUIMessage({ type = 'items', items = items })
end)

-- mouse em cima de um item da mesa: { label, count } (nil esconde a caixinha)
AddEventHandler('itdrugs_bancada:hover', function(info)
    SendNUIMessage({ type = 'hover', info = info })
end)

local function close()
    SendNUIMessage({ type = 'close' })
    SetNuiFocus(false, false)
end
AddEventHandler('itdrugs_bancada:close', close)

-- se o it-drugs reiniciar com a bancada aberta, não deixa o mouse preso na tela
AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'it-drugs' then close() end
end)

RegisterNUICallback('mouse', function(data, cb)
    TriggerEvent('itdrugs_bancada:mouse', data)
    cb(1)
end)

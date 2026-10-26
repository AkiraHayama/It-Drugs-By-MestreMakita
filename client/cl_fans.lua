if not Config.EnableFans then return end

local placeFan = function(item, coords, rotation)
    if it.playAnimatedProgress(_U('PROGRESSBAR__PLACE__FAN'), 3000) then
        TriggerServerEvent('it-drugs:server:createNewFan', coords, item, rotation)
    end
end

RegisterNetEvent('it-drugs:client:placeFan', function(item)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local fanConfig = Config.Fans[item]
    local ok, hashModel = it.requestModel(fanConfig.model, 'Config.Fans.' .. item .. '.model errado')
    if not ok then
        ShowNotification(nil, 'Modelo do ventilador não carregou (Config.Fans.' .. item .. '.model errado)', "error")
        return
    end

    it.placeObjectWithRotation(hashModel, "fan", function(coords, rotation)
        placeFan(item, coords, rotation)
    end, fanConfig.range) -- segurando ALT mostra a área que ele ventila
end)

-- Alvo (cl_target.lua) dá o handle LOCAL; o servidor trabalha com o handle dele, que vem do callback
RegisterNetEvent('it-drugs:client:toggleFan', function(args)
    lib.callback('it-drugs:server:getFanData', false, function(result)
        if not result then return end
        TriggerServerEvent('it-drugs:server:toggleFan', { entity = result.entity })
    end, NetworkGetNetworkIdFromEntity(args.entity))
end)

RegisterNetEvent('it-drugs:client:takeFan', function(args)
    lib.callback('it-drugs:server:getFanData', false, function(result)
        if not result then return end

        local ped = PlayerPedId()
        TaskTurnPedToFaceEntity(ped, args.entity, 1.0)
        Wait(200)

        if it.playAnimatedProgress(_U('PROGRESSBAR__TAKE__FAN'), 3000) then
            TriggerServerEvent('it-drugs:server:takeFan', { entity = result.entity })
        end
    end, NetworkGetNetworkIdFromEntity(args.entity))
end)

-- ┌────────────────────────────────────────────────────────┐
-- │ Ligado/desligado: ALT, texto em cima e som              │
-- └────────────────────────────────────────────────────────┘
-- O servidor manda a lista de ventiladores (coords + ligado) sempre que algo muda (sv_fans.lua:
-- syncFans). O prop não gira, então o estado aparece em texto a até FAN_TEXT_DISTANCE metros, e o
-- ligado faz barulho (volume cai com a distância até sumir em FAN_SOUND_DISTANCE). Ligar/desligar
-- toca o clique pra quem estiver perto. Quem toca é o resource `itdrugs_som` (página própria): a
-- página dentro do it-drugs nunca carregou no jogo (nem o painel do dealer no outro servidor).
local FAN_TEXT_DISTANCE = 5.0
local FAN_SOUND_DISTANCE = 10.0
local FAN_SOUND_VOLUME = 0.12 -- volume máximo do ventilador (0-1), colado nele - bem baixinho, pedido dele
local FAN_CLICK_VOLUME = 0.25
local fans = {} -- { coords, isOn, item } de todos os ventiladores
local fanTop = {} -- item -> altura (m) do texto acima do pé do ventilador

local closenessTo = function(coords, playerCoords)
    return 1 - #(coords - playerCoords) / FAN_SOUND_DISTANCE
end

--- @param kind 'fanVolume'|'fanClick'
local playSound = function(kind, volume)
    TriggerEvent('itdrugs_som:play', kind, volume)
end

RegisterNetEvent('it-drugs:client:syncFans', function(list, clickCoords)
    fans = list or {}
    if clickCoords then
        local closeness = closenessTo(clickCoords, GetEntityCoords(PlayerPedId()))
        if closeness > 0 then playSound('fanClick', closeness * FAN_CLICK_VOLUME) end
    end
end)

CreateThread(function()
    fans = lib.callback.await('it-drugs:server:getFans', false) or {}
end)

--- Ventilador ligado nessa entidade? (ALT Ligar/Desligar em cl_target.lua)
function IsFanOnAt(entity)
    local coords = GetEntityCoords(entity)
    for _, fan in ipairs(fans) do
        if #(fan.coords - coords) < 0.5 then return fan.isOn end
    end
    return false
end

local getFanTop = function(item)
    if not fanTop[item] then
        local _, max = GetModelDimensions(GetHashKey(Config.Fans[item].model))
        fanTop[item] = max.z > 0.1 and max.z + 0.15 or 1.3 -- 1.3 se o model ainda não carregou
    end
    return fanTop[item]
end

local drawText3D = function(coords, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Texto: só desenha a cada frame quando tem ventilador perto
CreateThread(function()
    while true do
        local playerCoords, near = GetEntityCoords(PlayerPedId()), false
        for _, fan in ipairs(fans) do
            if #(fan.coords - playerCoords) < FAN_TEXT_DISTANCE then
                near = true
                local text = not fan.isOn and ('~r~○ ' .. _U('TEXT__FAN__OFF'))
                    or fan.powered == false and ('~o~● ' .. _U('TEXT__FAN__NO__POWER')) -- ligado, mas sem gerador/gasolina
                    or ('~g~● ' .. _U('TEXT__FAN__ON'))
                drawText3D(fan.coords + vector3(0.0, 0.0, getFanTop(fan.item)), text)
            end
        end
        Wait(near and 0 or 500)
    end
end)

-- Som: o ventilador ligado mais perto decide o volume (o itdrugs_som só toca/pausa e ajusta)
CreateThread(function()
    local lastVolume = 0
    while true do
        local volume, playerCoords = 0, GetEntityCoords(PlayerPedId())
        for _, fan in ipairs(fans) do
            if fan.isOn and fan.powered ~= false then volume = math.max(volume, closenessTo(fan.coords, playerCoords) * FAN_SOUND_VOLUME) end
        end
        if volume ~= lastVolume and (volume == 0 or math.abs(volume - lastVolume) > 0.005) then
            playSound('fanVolume', volume)
            lastVolume = volume
        end
        Wait(200)
    end
end)

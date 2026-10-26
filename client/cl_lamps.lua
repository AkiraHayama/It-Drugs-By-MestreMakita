if not Config.EnableLamps then return end

local placeLamp = function(item, coords, rotation)
    if it.playAnimatedProgress(_U('PROGRESSBAR__PLACE__LAMP'), 5000) then
        TriggerServerEvent('it-drugs:server:createNewLamp', coords, item, rotation)
    end
end

RegisterNetEvent('it-drugs:client:placeLamp', function(item)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local lampConfig = Config.Lamps[item]
    local ok, hashModel = it.requestModel(lampConfig.model, 'Config.Lamps.' .. item .. '.model errado')
    if not ok then
        ShowNotification(nil, 'Modelo da lâmpada não carregou (Config.Lamps.' .. item .. '.model errado)', "error")
        return
    end

    it.placeObjectWithRotation(hashModel, "lightbulb", function(coords, rotation)
        placeLamp(item, coords, rotation)
    end, lampConfig.range) -- segurando ALT mostra a área que a lâmpada ilumina
end)

RegisterNetEvent('it-drugs:client:takeLamp', function(args)
    local netId = NetworkGetNetworkIdFromEntity(args.entity)

    lib.callback('it-drugs:server:getLampData', false, function(result)
        if not result then return end

        local entity = result.entity
        local ped = PlayerPedId()
        TaskTurnPedToFaceEntity(ped, entity, 1.0)
        Wait(200)

        if it.playAnimatedProgress(_U('PROGRESSBAR__TAKE__LAMP'), 3000) then
            TriggerServerEvent('it-drugs:server:takeLamp', {entity = entity})
        end
    end, netId)
end)

-- Perto de uma lâmpada: texto de energia em cima dela (precisa de extensão num gerador com gasolina) e, segurando
-- ALT, o círculo da área que ela ilumina (Config.Lamps[..].range)
local lampByModel = {}
for _, cfg in pairs(Config.Lamps) do lampByModel[joaat(cfg.model)] = cfg end

local function lampText(at, text)
    SetDrawOrigin(at.x, at.y, at.z, 0)
    SetTextScale(0.0, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    local nearby, nextScan = {}, 0
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if GetGameTimer() > nextScan then -- procura as lâmpadas perto 1x por segundo
            nearby, nextScan = {}, GetGameTimer() + 1000
            for _, obj in ipairs(GetGamePool('CObject')) do
                local cfg = lampByModel[GetEntityModel(obj)]
                if cfg and NetworkGetEntityIsNetworked(obj) and #(GetEntityCoords(obj) - pos) < 8.0 then
                    local _, mx = GetModelDimensions(GetEntityModel(obj))
                    nearby[#nearby + 1] = { obj = obj, cfg = cfg, top = mx.z + 0.25 }
                end
            end
        end
        if #nearby == 0 then
            Wait(500)
        else
            local alt = IsControlPressed(0, 19)
            for _, lamp in ipairs(nearby) do
                if DoesEntityExist(lamp.obj) then
                    local c = GetEntityCoords(lamp.obj)
                    local power = DevicePower and DevicePower(lamp.obj) or 'none'
                    if Entity(lamp.obj).state.lampOn == false then power = 'lampoff' end
                    lampText(c + vector3(0.0, 0.0, lamp.top), (power == 'lampoff' and ('~r~● ' .. _U('TEXT__LAMP__OFF')))
                        or (power == 'on' and ('~g~● ' .. _U('TEXT__LAMP__ON')))
                        or (power == 'nofuel' and ('~o~● ' .. _U('TEXT__LAMP__NO__FUEL')))
                        or (power == 'off' and ('~o~● ' .. _U('TEXT__LAMP__GEN__OFF')))
                        or ('~r~● ' .. _U('TEXT__LAMP__NO__POWER')))
                    if alt then
                        local r = lamp.cfg.range or 10.0
                        DrawMarker(1, c.x, c.y, c.z - 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2.0, r * 2.0, 0.15, 255, 215, 90, 90, false, false, 2, false, nil, nil, false)
                    end
                end
            end
            Wait(0)
        end
    end
end)

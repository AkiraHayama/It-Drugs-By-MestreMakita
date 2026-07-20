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
    end)
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

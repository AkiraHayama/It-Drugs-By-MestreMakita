if not Config.EnableDryingRacks then return end

local placeDryingRack = function(item, coords, rotation)
    if it.playAnimatedProgress(_U('PROGRESSBAR__PLACE__DRYINGRACK'), 5000) then
        TriggerServerEvent('it-drugs:server:createNewDryingRack', coords, item, rotation)
    end
end

RegisterNetEvent('it-drugs:client:placeDryingRack', function(item)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local rackConfig = Config.DryingRacks[item]
    local ok, hashModel = it.requestModel(rackConfig.model, 'Config.DryingRacks.' .. item .. '.model errado')
    if not ok then
        ShowNotification(nil, 'Modelo do secador não carregou (Config.DryingRacks.' .. item .. '.model errado)', "error")
        return
    end

    it.placeObjectWithRotation(hashModel, "trowel", function(coords, rotation)
        placeDryingRack(item, coords, rotation)
    end)
end)

RegisterNetEvent('it-drugs:client:checkDryingRack', function(args)
    local netId = NetworkGetNetworkIdFromEntity(args.entity)

    lib.callback('it-drugs:server:getDryingRackData', false, function(result)
        if not result then return end
        TriggerEvent('it-drugs:client:showDryingRackMenu', result)
    end, netId)
end)

RegisterNetEvent('it-drugs:client:startDrying', function(args)
    local entity = args.entity
    local rawItem = args.rawItem

    if not it.hasItem(rawItem, 1) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    local rackConfig = Config.DryingRacks[args.item]
    local input = lib.inputDialog(_U('INPUT__AMOUNT__HEADER'), {
        {type = 'number', text = _U('INPUT__AMOUNT__TEXT'), desciption = _U('INPUT__AMOUNT__DESCRIPTION'), require = true, min = 1, max = rackConfig.capacity}
    })

    if not input then
        ShowNotification(nil, _U('NOTIFICATION__NO__AMOUNT'), "error")
        return
    end

    local amount = tonumber(input[1])
    if not amount or amount < 1 then return end

    if not it.hasItem(rawItem, amount) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__DRYINGRACK__HANG'), 3000) then
        TriggerServerEvent('it-drugs:server:startDrying', { entity = entity, rawItem = rawItem, amount = amount })
    end
end)

RegisterNetEvent('it-drugs:client:collectDrying', function(args)
    local entity = args.entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__DRYINGRACK__COLLECT'), 3000) then
        TriggerServerEvent('it-drugs:server:collectDrying', { entity = entity })
    end
end)

RegisterNetEvent('it-drugs:client:takeDryingRack', function(args)
    local entity = args.entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__TAKE__DRYINGRACK'), 3000) then
        TriggerServerEvent('it-drugs:server:takeDryingRack', { entity = entity })
    end
end)

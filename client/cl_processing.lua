if not Config.EnableProcessing then return end

local proccessing = false

local placeProcessingTable = function(tableItem, coords, rotation, metadata)
    if it.playAnimatedProgress(_U('PROGRESSBAR__PLACE__TABLE'), 5000) then
        TriggerServerEvent('it-drugs:server:createNewTable', coords, tableItem, rotation, metadata)
    end
end

RegisterNetEvent('it-drugs:client:placeProcessingTable', function(tableItem, metadata)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local tableConfig = Config.ProcessingTables[tableItem]
    -- Único dos 4 placements (vaso/lâmpada/secador/mesa) sem timeout no load do model - travava o
    -- thread do cliente pra sempre em silêncio se o model fosse inválido, sem aviso nenhum.
    local ok, hashModel = it.requestModel(tableConfig.model, 'Config.ProcessingTables.' .. tableItem .. '.model errado')
    if not ok then
        ShowNotification(nil, 'Modelo da mesa não carregou (Config.ProcessingTables.' .. tableItem .. '.model errado)', "error")
        return
    end

    it.placeObjectWithRotation(hashModel, "spoon", function(coords, rotation)
        placeProcessingTable(tableItem, coords, rotation, metadata)
    end)
end)

RegisterNetEvent('it-drugs:client:useTable', function(data)
    local netId = NetworkGetNetworkIdFromEntity(data.entity)
    lib.callback('it-drugs:server:getTableData', false, function(result)
        if not result then return end
        TriggerEvent('it-drugs:client:showRecipesMenu', result)
    end, netId)
end)

RegisterNetEvent('it-drugs:client:processDrugs', function(args)
    local entity = args.entity
    local type = args.type
    local recipe = Config.ProcessingTables[type].recipes[args.recipe]
    if proccessing then return end

    local input = lib.inputDialog(_U('INPUT__AMOUNT__HEADER'), {
        {type = 'number', text = _U('INPUT__AMOUNT__TEXT'), desciption = _U('INPUT__AMOUNT__DESCRIPTION'), require = true, min = 1}
    })

    if not input then
        ShowNotification(nil, _U('NOTIFICATION__NO__AMOUNT'), 'error')
        return
    end

    local amount = tonumber(input[1])
    for item, itemAmount in pairs(recipe.ingrediants) do
        if not it.hasItem(item, itemAmount * amount) then
            ShowNotification(nil, _U('NOTIFICATION__MISSING__INGIDIANT'), 'error')
            proccessing = false
            return
        end
    end

    if recipe.tools then
        for item, itemAmount in pairs(recipe.tools) do
            if not it.hasItem(item, itemAmount) then
                ShowNotification(nil, _U('NOTIFICATION__MISSING__TOOL'), 'error')
                proccessing = false
                return
            end
        end
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    proccessing = true

    RequestAnimDict(recipe.animation.dict)
    while not HasAnimDictLoaded(recipe.animation.dict) do 
        Wait(0)
    end
    TaskPlayAnim(ped, recipe.animation.dict, recipe.animation.anim, 8.0, 8.0, -1, 1, 0, false, false, false)
    if Config.ProcessingSkillCheck then
        for i = 1, amount, 1 do
            local success = lib.skillCheck(Config.SkillCheck.difficulty, Config.SkillCheck.keys)
            if success then
                ShowNotification(nil, _U('NOTIFICATION__SKILL__SUCCESS'), 'success')
                TriggerServerEvent('it-drugs:server:processDrugs', entity, args.recipe)
            else
                proccessing = false
                ShowNotification(nil, _U('NOTIFICATION__SKILL__ERROR'), 'error')
                ClearPedTasks(ped)
                RemoveAnimDict(recipe.animation.dict)
                return
            end
            Wait(1000)
        end
        proccessing = false
        ClearPedTasks(ped)
        RemoveAnimDict(recipe.animation.dict)
    else
        for i = 1, amount, 1 do
            if lib.progressBar({
                duration = recipe.processTime * 1000,
                label = _U('PROGRESSBAR__PROCESS__DRUG'),
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                },
            }) then
                TriggerServerEvent('it-drugs:server:processDrugs', entity, args.recipe)
            else
                ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
                ClearPedTasks(ped)
                RemoveAnimDict(recipe.animation.dict)
            end
            Wait(1000)
        end
        proccessing = false
        ClearPedTasks(ped)
        RemoveAnimDict(recipe.animation.dict)
    end
end)

RegisterNetEvent('it-drugs:client:removeTable', function(args)
    local entity = args.entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__REMOVE__TABLE'), 5000) then
        TriggerServerEvent('it-drugs:server:removeTable', {entity = entity})
    end
end)
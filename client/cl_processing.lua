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
    end, nil, tableConfig.front)
end)

RegisterNetEvent('it-drugs:client:useTable', function(data)
    local netId = NetworkGetNetworkIdFromEntity(data.entity)
    lib.callback('it-drugs:server:getTableData', false, function(result)
        if not result then return end
        TriggerEvent('it-drugs:client:showRecipesMenu', result)
    end, netId)
end)

-- Opções do E da mesa (cl_target.lua, sem painel): pegam o handle do servidor e seguem o fluxo de sempre
RegisterNetEvent('it-drugs:client:tableRecipe', function(args)
    local result = lib.callback.await('it-drugs:server:getTableData', false, NetworkGetNetworkIdFromEntity(args.entity))
    if not result then return end
    TriggerEvent('it-drugs:client:processDrugs', { entity = result.entity, object = args.entity, type = args.type, recipe = args.recipe })
end)

RegisterNetEvent('it-drugs:client:tableTake', function(args)
    local result = lib.callback.await('it-drugs:server:getTableData', false, NetworkGetNetworkIdFromEntity(args.entity))
    if not result then return end
    if result.notEmpty then return ShowNotification(nil, _U('NOTIFICATION__TABLE__NOT__EMPTY'), 'error') end
    TriggerEvent('it-drugs:client:removeTable', { entity = result.entity })
end)

RegisterNetEvent('it-drugs:client:processDrugs', function(args)
    local entity = args.entity
    local object = args.object -- handle do client (entity é o do servidor); só vem pelo E
    local type = args.type
    local recipe = Config.ProcessingTables[type].recipes[args.recipe]
    if proccessing then return end

    -- máximo de vezes = o que os ingredientes do inventário dão (o servidor confere de novo a cada vez)
    local max = math.huge
    for item, itemAmount in pairs(recipe.ingrediants) do
        max = math.min(max, math.floor((tonumber(it.getItemCount(item)) or 0) / itemAmount))
    end
    if max < 1 then
        ShowNotification(nil, _U('NOTIFICATION__MISSING__INGIDIANT'), 'error')
        return
    end

    local input = lib.inputDialog(recipe.label, {
        { type = 'number', label = _U('INPUT__AMOUNT__TEXT'), description = _U('INPUT__PROCESS__DESC'):format(max), required = true, min = 1, max = max, default = max },
        { type = 'checkbox', label = _U('INPUT__DRYINGRACK__MAX'):format(max) },
    })

    if not input then
        ShowNotification(nil, _U('NOTIFICATION__NO__AMOUNT'), 'error')
        return
    end

    local amount = input[2] and max or math.min(math.floor(tonumber(input[1]) or 0), max)
    if amount < 1 then return end
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
    if recipe.animation and recipe.animation.walkTo and object and DoesEntityExist(object) then
        it.walkToPlace(GetEntityCoords(object)) -- chega perto e vira pra mesa
    elseif object then
        TaskTurnPedToFaceEntity(ped, object, 1.0)
    end
    Wait(200)

    proccessing = true

    -- receita sem animation = só a barra de progresso
    local anim = recipe.animation
    if anim then
        RequestAnimDict(anim.dict)
        while not HasAnimDictLoaded(anim.dict) do
            Wait(0)
        end
        TaskPlayAnim(ped, anim.dict, anim.anim, 8.0, 8.0, -1, 1, 0, false, false, false)
    end
    local function stopAnim()
        if anim then RemoveAnimDict(anim.dict) end
    end
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
                stopAnim()
                return
            end
            Wait(1000)
        end
        proccessing = false
        ClearPedTasks(ped)
        stopAnim()
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
                stopAnim()
            end
            Wait(1000)
        end
        proccessing = false
        ClearPedTasks(ped)
        stopAnim()
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


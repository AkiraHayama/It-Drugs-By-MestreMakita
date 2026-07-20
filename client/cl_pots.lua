if not Config.EnablePots then return end

-- Base sunlight for the zone, reduced by whatever is blocking the sky above (roof, tree, etc.)
-- `ignoreEntity` (opcional) exclui uma entidade do teste - PRECISA passar o próprio vaso aqui
-- (tem colisão sólida de verdade, ver "Usar Vaso"/addModel) senão o raio bate na parede/borda do
-- vaso antes de sair pra cima e a planta é sempre detectada como "fechada", mesmo a céu aberto.
local calculateSunlight = function(coords, ignoreEntity)
    local baseSunlight = Config.SunlightZones[GetZoneAtCoords(coords.x, coords.y, coords.z)] or Config.DefaultSunlight
    baseSunlight = math.max(50, math.min(100, baseSunlight + (math.random() * 10 - 5)))

    -- Qualquer teto/cobertura acima (não importa a altura) já conta como "fechado" - sol direto só
    -- existe a céu aberto de verdade. Antes isso era proporcional à distância do teto (um teto alto
    -- ainda dava luz parcial), o que deixava lugar fechado (tipo estacionamento) nascendo com 40%+
    -- de luz mesmo sem lâmpada nenhuma por perto - errado, luz indoor tem que vir só da lâmpada.
    local skyCoords = vector3(coords.x, coords.y, coords.z + 50.0)
    local ray = StartShapeTestRay(coords.x, coords.y, coords.z, skyCoords.x, skyCoords.y, skyCoords.z, 273, ignoreEntity or 0, 0)
    local _, hit = GetShapeTestResult(ray)
    local skyFactor = hit == 1 and 0.0 or 1.0

    return math.max(0, math.min(100, baseSunlight * skyFactor))
end

local placePot = function(item, coords, rotation)
    if it.playAnimatedProgress(_U('PROGRESSBAR__PLACE__POT'), 5000) then
        TriggerServerEvent('it-drugs:server:createNewPot', coords, item, rotation)
    end
end

RegisterNetEvent('it-drugs:client:placePot', function(item)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local potConfig = Config.Pots[item]
    local ok, hashModel = it.requestModel(potConfig.model, 'Config.Pots.' .. item .. '.model errado')
    if not ok then
        ShowNotification(nil, 'Modelo do vaso não carregou (Config.Pots.' .. item .. '.model errado)', "error")
        return
    end

    it.placeObjectWithRotation(hashModel, "trowel", function(coords, rotation)
        placePot(item, coords, rotation)
    end)
end)

RegisterNetEvent('it-drugs:client:checkPot', function(args)
    local netId = NetworkGetNetworkIdFromEntity(args.entity)

    lib.callback('it-drugs:server:getPotData', false, function(result)
        if not result then return end
        TriggerEvent('it-drugs:client:showPotMenu', result)
    end, netId)
end)

local moveVaso = function(entity, coords, rotation)
    if it.playAnimatedProgress(_U('PROGRESSBAR__MOVE__POT'), 3000) then
        TriggerServerEvent('it-drugs:server:movePot', { entity = entity, coords = coords, rotation = rotation })
    end
end

RegisterNetEvent('it-drugs:client:movePot', function(args)
    local entity = args.entity
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local potConfig = Config.Pots[args.item]
    local model = (args.hasSoil and potConfig.soilModel) or potConfig.model
    local ok, hashModel = it.requestModel(model, 'Config.Pots.' .. args.item .. '.model/.soilModel errado')
    if not ok then
        ShowNotification(nil, 'Modelo do vaso não carregou (Config.Pots.' .. args.item .. '.model/.soilModel errado)', "error")
        return
    end

    it.placeObjectWithRotation(hashModel, "up-down-left-right", function(coords, rotation)
        moveVaso(entity, coords, rotation)
    end)
end)

RegisterNetEvent('it-drugs:client:addSoil', function(args)
    local entity = args.entity
    local soilItem = args.soilItem

    if not soilItem or not it.hasItem(soilItem, 1) then
        ShowNotification(nil, _U('NOTIFICATION__NO__SOIL'), "error")
        return
    end

    -- Objeto criado e anexado na mão do ped (confirmado aparecendo certo pelo usuário). Partícula
    -- trocada pra 'ent_dst_rocks' (dict 'core') - achado num script de terceiro já usado nesse
    -- pacote (jim-mining, client.lua) que comprovadamente usa esse nome pra poeira/terra em produção,
    -- em vez de continuar chutando nomes contra listas externas que não bateram nas tentativas
    -- anteriores. jim-mining dispara ele repetido (não-loop) em vez de usar a native de loop, então
    -- seguindo o mesmo padrão aqui: dispara a cada 150ms num thread à parte enquanto a barra roda.
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = 'bkr_prop_weed_bigbag_01a'
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)
    RequestModel(model)
    RequestNamedPtfxAsset('core')
    while not HasModelLoaded(model) or not HasNamedPtfxAssetLoaded('core') do Wait(0) end
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.4, 0.1, 0.0, 90.0, 180.0, 0.0, true, true, false, true, 1, true)

    local playingEffect = true
    CreateThread(function()
        while playingEffect do
            SetPtfxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntity('bul_dirt', created_object, 0.35, 0.0, 0.25, 0.0, 0.0, 0.0, 0.6, false, false, false)
            Wait(90)
        end
    end)

    if lib.progressBar({
        duration = 3000,
        label = _U('PROGRESSBAR__ADD__SOIL'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'weapon@w_sp_jerrycan',
            clip = 'fire',
        },
    }) then
        TriggerServerEvent('it-drugs:server:addSoil', { entity = entity })
        ClearPedTasks(ped)
        DeleteEntity(created_object)
    else
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
        ClearPedTasks(ped)
        DeleteEntity(created_object)
    end
    playingEffect = false
end)

RegisterNetEvent('it-drugs:client:plantInPot', function(args)
    local entity = args.entity
    local seed = args.seed

    if not it.hasItem(seed, 1) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    -- `entity` aqui é o handle do lado do SERVER (ecoado de volta por getPotData, ver
    -- sv_pots.lua) - não é um entity handle válido nesse client, então não pode ser usado em
    -- native nenhuma local (GetEntityCoords, raycast, TaskTurnPedToFaceEntity etc.), senão
    -- resolve pra (0,0,0)/entidade errada. O handle LOCAL de verdade precisa ser resolvido de
    -- novo a partir do netId (era exatamente esse o bug do sol não pegar em vaso a céu aberto:
    -- calculateSunlight rodava em cima das coords erradas, quase sempre dando "fechado").
    -- CUIDADO: NetworkGetEntityFromNetworkId retorna 0 quando não acha o objeto - e em Lua `0` é
    -- verdadeiro, então `(netId and NetworkGetEntityFromNetworkId(netId)) or entity` NUNCA cai no
    -- fallback quando a resolução falha (`0 or entity` avalia pra `0`) - precisa checar `~= 0`.
    local resolvedEntity = args.netId and NetworkGetEntityFromNetworkId(args.netId)
    local localEntity = (resolvedEntity and resolvedEntity ~= 0) and resolvedEntity or entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, localEntity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__SPAWN__PLANT'), Config.Plants[seed].time) then
        local sunlight = calculateSunlight(GetEntityCoords(localEntity), localEntity)
        TriggerServerEvent('it-drugs:server:plantInPot', { entity = entity, seed = seed, sunlight = sunlight })
    end
end)

RegisterNetEvent('it-drugs:client:takePot', function(args)
    local entity = args.entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__TAKE__POT'), 3000) then
        TriggerServerEvent('it-drugs:server:takePot', { entity = entity })
    end
end)

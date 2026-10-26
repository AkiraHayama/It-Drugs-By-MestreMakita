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

    -- "tem teto?" de novo ao abrir: rede secando que ganhou ventilador depois de pendurar vira cura (sv_dryingracks.lua)
    local indoor
    local model = GetEntityModel(args.entity)
    for _, rackConfig in pairs(Config.DryingRacks) do
        if GetHashKey(rackConfig.model) == model then
            indoor = it.isIndoors(GetEntityCoords(args.entity), rackConfig.roofCheckHeight)
        end
    end

    lib.callback('it-drugs:server:getDryingRackData', false, function(result)
        if not result then return end
        TriggerEvent('it-drugs:client:showDryingRackMenu', result)
    end, netId, indoor)
end)

RegisterNetEvent('it-drugs:client:startDrying', function(args)
    local entity = args.entity
    local rawItem = args.rawItem

    if not it.hasItem(rawItem, 1) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    local rackConfig = Config.DryingRacks[args.item]
    -- máximo = o que a rede aguenta ou o que tem no inventário, o que for menor
    local max = math.min(rackConfig.capacity, tonumber(it.getItemCount(rawItem)) or 0)
    if max < 1 then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end
    local input = lib.inputDialog(_U('INPUT__DRYINGRACK__HEADER'), {
        { type = 'number', label = _U('INPUT__AMOUNT__TEXT'), description = _U('INPUT__DRYINGRACK__DESC'):format(max), required = true, min = 1, max = max, default = max },
        { type = 'checkbox', label = _U('INPUT__DRYINGRACK__MAX'):format(max) },
    })

    if not input then
        ShowNotification(nil, _U('NOTIFICATION__NO__AMOUNT'), "error")
        return
    end

    local amount = input[2] and max or math.min(math.floor(tonumber(input[1]) or 0), max)
    if amount < 1 then return end

    if not it.hasItem(rawItem, amount) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__DRYINGRACK__HANG'), 3000) then
        -- `indoor` decide se a rede cura (Config.DryingRacks[x].cures) - servidor não tem raycast
        local indoor = it.isIndoors(args.coords, rackConfig.roofCheckHeight)
        TriggerServerEvent('it-drugs:server:startDrying', { entity = entity, rawItem = rawItem, amount = amount, indoor = indoor })
    end
end)

RegisterNetEvent('it-drugs:client:collectDrying', function(args)
    local entity = args.entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__DRYINGRACK__COLLECT'), 3000) then
        local indoor = it.isIndoors(args.coords, Config.DryingRacks[args.item].roofCheckHeight)
        TriggerServerEvent('it-drugs:server:collectDrying', { entity = entity, indoor = indoor })
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

-- ┌────────────────────────────────────────────────────────┐
-- │ Buds nas bandejas da rede enquanto secam                │
-- └────────────────────────────────────────────────────────┘
-- Props LOCAIS (cada client desenha os seus) - 48 objetos de rede por secador estourariam o limite
-- de entidades. Layout em Config.DryingRacks[x].buds; só desenha perto do jogador.
local BUDS_DRAW_DISTANCE = 50.0
local STATUS_TEXT_DISTANCE = 4.0
local racksState = {} -- netId da rede -> estado vindo do servidor (+ deadline local) de TODAS as redes
local spawnedBuds = {} -- netId da rede -> handles dos props locais
local indoorSent = {} -- netId -> já mandou o "tem teto?" dessa rede nessa sessão

local clearBuds = function(netId)
    for _, obj in ipairs(spawnedBuds[netId] or {}) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawnedBuds[netId] = nil
end

local spawnBuds = function(netId, rackEntity, rack)
    local layout = Config.DryingRacks[rack.item] and Config.DryingRacks[rack.item].buds
    if not layout then return end
    local ok, hashModel = it.requestModel(layout.prop, 'Config.DryingRacks.' .. rack.item .. '.buds.prop errado')
    if not ok then return end

    local buds = {}
    for i = 0, math.min(rack.amount, #layout.levels * layout.perLevel) - 1 do
        -- enche de baixo pra cima, perLevel buds em volta do poste por bandeja
        local level = layout.levels[math.floor(i / layout.perLevel) + 1]
        local angle = math.rad((i % layout.perLevel + 0.5) * 360 / layout.perLevel)
        local pos = GetOffsetFromEntityInWorldCoords(rackEntity, math.cos(angle) * layout.radius, math.sin(angle) * layout.radius, level + layout.zOffset)
        local obj = CreateObjectNoOffset(hashModel, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(obj, math.random(0, 359))
        SetEntityCollision(obj, false, false)
        FreezeEntityPosition(obj, true)
        buds[#buds + 1] = obj
    end
    SetModelAsNoLongerNeeded(hashModel)
    spawnedBuds[netId] = buds
end

-- Chamado no início e sempre que algo muda numa rede (pendurar/recolher/energia: servidor manda syncDryingRackBuds)
local refreshRackList = function()
    local list = lib.callback.await('it-drugs:server:getDryingRackBuds', false)
    for netId in pairs(spawnedBuds) do clearBuds(netId) end -- redesenha as buds no próximo tick
    racksState = {}
    for _, rack in ipairs(list or {}) do
        if rack.dryingItem then rack.deadline = GetGameTimer() + (rack.left or 0) * 1000 end
        racksState[rack.netId] = rack
    end
end

RegisterNetEvent('it-drugs:client:syncDryingRackBuds', refreshRackList)

local localRack = function(netId)
    return NetworkDoesEntityExistWithNetworkId(netId) and NetworkGetEntityFromNetworkId(netId) or 0
end

--- Estado da rede dessa entidade pras opções do E (cl_target.lua): 'empty' | 'busy' | 'ready', + o estado completo
function GetDryingRackState(entity)
    if not NetworkGetEntityIsNetworked(entity) then return 'empty' end
    local rack = racksState[NetworkGetNetworkIdFromEntity(entity)]
    if not rack or not rack.dryingItem then return 'empty', rack end
    if rack.ready or GetGameTimer() >= rack.deadline then return 'ready', rack end
    return 'busy', rack
end

CreateThread(function()
    refreshRackList()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for netId, rack in pairs(racksState) do
            local entity = localRack(netId)
            local distance = entity ~= 0 and #(GetEntityCoords(entity) - playerCoords) or math.huge
            local near = rack.dryingItem and distance < BUDS_DRAW_DISTANCE
            if near and not spawnedBuds[netId] then
                spawnBuds(netId, entity, rack)
            elseif not near and spawnedBuds[netId] then
                clearBuds(netId)
            end
            -- chegou perto: confere "tem teto?" 1x (rede secando que ganhou ventilador vira cura no servidor)
            if distance < 10.0 and not indoorSent[netId] then
                indoorSent[netId] = true
                TriggerServerEvent('it-drugs:server:rackIndoor', netId, it.isIndoors(GetEntityCoords(entity), Config.DryingRacks[rack.item].roofCheckHeight))
            end
        end
        Wait(1000)
    end
end)

-- Status em cima da rede (o E só tem as ações; o texto mostra se está secando, curando, pronta...)
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

local statusText = function(entity)
    local state, rack = GetDryingRackState(entity)
    if state == 'empty' then return '~w~' .. _U('TEXT__DRYINGRACK__EMPTY') end
    if state == 'ready' then return '~g~' .. _U(rack.curing and 'TEXT__DRYINGRACK__READY__CURED' or 'TEXT__DRYINGRACK__READY') end
    local minutes = math.max(1, math.ceil((rack.deadline - GetGameTimer()) / 60000))
    local label = rack.slow and 'TEXT__DRYINGRACK__CURING__SLOW' or rack.curing and 'TEXT__DRYINGRACK__CURING' or 'TEXT__DRYINGRACK__DRYING'
    return (rack.slow and '~o~' or rack.curing and '~b~' or '~y~') .. _U(label):format(minutes)
end

CreateThread(function()
    while true do
        local playerCoords, near = GetEntityCoords(PlayerPedId()), false
        for netId in pairs(racksState) do
            local entity = localRack(netId)
            if entity ~= 0 and #(GetEntityCoords(entity) - playerCoords) < STATUS_TEXT_DISTANCE then
                near = true
                drawText3D(GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, 2.0), statusText(entity))
            end
        end
        Wait(near and 0 or 500)
    end
end)

-- Opções do E (cl_target.lua): pegam os dados da rede no servidor e seguem o fluxo de sempre
local withRackData = function(entity, cb)
    local data = lib.callback.await('it-drugs:server:getDryingRackData', false, NetworkGetNetworkIdFromEntity(entity))
    if data then cb(data) end
end

RegisterNetEvent('it-drugs:client:rackHang', function(args)
    withRackData(args.entity, function(data)
        TriggerEvent('it-drugs:client:startDrying', { entity = data.entity, item = data.item, rawItem = args.rawItem, coords = data.coords })
    end)
end)

RegisterNetEvent('it-drugs:client:rackCollect', function(args)
    withRackData(args.entity, function(data)
        TriggerEvent('it-drugs:client:collectDrying', { entity = data.entity, item = data.item, coords = data.coords })
    end)
end)

RegisterNetEvent('it-drugs:client:rackTake', function(args)
    withRackData(args.entity, function(data)
        TriggerEvent('it-drugs:client:takeDryingRack', { entity = data.entity })
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for netId in pairs(spawnedBuds) do clearBuds(netId) end
end)

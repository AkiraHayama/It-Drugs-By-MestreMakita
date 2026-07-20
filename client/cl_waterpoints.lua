if not Config.EnableWaterPoints then return end

-- Registra a categoria no menu de Gerenciamento do F10 (mri_Qbox), se esse resource estiver
-- rodando - integração opcional via export, sem declarar mri_Qbox como dependency (mesmo
-- padrão de integração opcional já usado pra ps-dispatch em shared/config.lua).
CreateThread(function()
    if GetResourceState('mri_Qbox') ~= 'started' then return end

    exports['mri_Qbox']:AddManageMenu({
        title = 'Pontos de Água (Regador)',
        description = 'Crie ou gerencie os pontos de encher o regador do it-drugs.',
        icon = 'faucet-drip',
        iconAnimation = 'fade',
        arrow = true,
        onSelectFunction = function()
            TriggerEvent('it-drugs:client:showMainAdminMenu', {menuType = 'waterpoints'})
        end,
    })
end)

local zones = {} -- pointId -> zone handle (ox_target zone id / qb-target zone name)

local refillWateringCan = function(id)
    if not it.hasItem('watering_can', 1) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    local ped = PlayerPedId()

    if lib.progressBar({
        duration = 3000,
        label = _U('PROGRESSBAR__REFILL__WATERINGCAN'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
    }) then
        TriggerServerEvent('it-drugs:server:refillWateringCan', id)
    else
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
    end
end

local registerWaterPointZone = function(point)
    if zones[point.id] then return end

    if Config.Target == 'qb-target' then
        local name = 'it-drugs-waterpoint-' .. point.id
        exports['qb-target']:AddCircleZone(name, point.coords, Config.WaterPointRadius, {
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    icon = 'fas fa-faucet-drip',
                    label = _U('TARGET__WATERPOINT__LABEL'),
                    action = function()
                        refillWateringCan(point.id)
                    end
                }
            },
            distance = Config.WaterPointRadius + 1.0,
        })
        zones[point.id] = name
    elseif Config.Target == 'ox_target' then
        if not exports.ox_target then return end
        local zoneId = exports.ox_target:addSphereZone({
            coords = point.coords,
            radius = Config.WaterPointRadius,
            options = {
                {
                    name = 'it-drugs-refill-wateringcan-' .. point.id,
                    icon = 'fas fa-faucet-drip',
                    label = _U('TARGET__WATERPOINT__LABEL'),
                    onSelect = function()
                        refillWateringCan(point.id)
                    end,
                    distance = Config.WaterPointRadius + 1.0,
                }
            }
        })
        zones[point.id] = zoneId
    end
end

local removeWaterPointZone = function(id)
    local zone = zones[id]
    if not zone then return end

    if Config.Target == 'qb-target' then
        exports['qb-target']:RemoveZone(zone)
    elseif Config.Target == 'ox_target' then
        if exports.ox_target then
            exports.ox_target:removeZone(zone)
        end
    end
    zones[id] = nil
end

CreateThread(function()
    -- DatabaseSetuped só existe no server (globals não são compartilhados entre client/server) -
    -- usar isso aqui travava pra sempre e os pontos já existentes nunca registravam o alvo pra
    -- quem entrava/reconectava. lib.callback.await já bloqueia até o server responder de qualquer jeito.
    local points = lib.callback.await('it-drugs:server:getWaterPoints', false)
    for _, point in pairs(points or {}) do
        registerWaterPointZone(point)
    end
end)

RegisterNetEvent('it-drugs:client:addWaterPointZone', function(point)
    registerWaterPointZone(point)
end)

RegisterNetEvent('it-drugs:client:removeWaterPointZone', function(id)
    removeWaterPointZone(id)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id, _ in pairs(zones) do
        removeWaterPointZone(id)
    end
end)

-- ┌────────────────────────────────────────────┐
-- │ Admin: placing a new water point            │
-- └────────────────────────────────────────────┘

-- Raycast próprio (máscara 1, só mundo/mapa - diferente do it.rayCastCamera usado pros outros
-- placements) já que aqui é só pra marcar um ponto no chão, sem objeto fantasma nem colisão de prop.
local RayCastCamera = function(dist)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local dir = it.rotationToDirection(camRot)
    local dest = camPos + (dir * dist)
    local ray = StartShapeTestRay(camPos, dest, 1, -1, 0)
    local _, hit, endPos = GetShapeTestResult(ray)
    if hit == 0 then endPos = dest end
    return hit, endPos
end

RegisterNetEvent('it-drugs:client:placeWaterPoint', function()
    lib.showTextUI(_U('INTERACTION__PLACING__TEXT'), {
        position = "left-center",
        icon = "faucet-drip",
    })

    local placed = false
    local finalCoords = nil

    while not placed do
        Wait(0)
        local hit, dest = RayCastCamera(Config.rayCastingDistance)

        if hit == 1 then
            DrawMarker(28, dest.x, dest.y, dest.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 150, 255, 200, false, true, 2, false, nil, nil, false)

            if IsControlJustPressed(0, 38) then
                placed = true
                finalCoords = dest
            end
        end

        if IsControlJustPressed(0, 47) then
            placed = true
        end
    end

    lib.hideTextUI()

    if not finalCoords then
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
        return
    end

    local input = lib.inputDialog(_U('INPUT__WATERPOINT__HEADER'), {
        { type = 'input', label = _U('INPUT__WATERPOINT__LABEL'), required = false }
    })

    local label = input and input[1]
    if not label or label == '' then label = nil end

    TriggerServerEvent('it-drugs:server:createWaterPoint', finalCoords, label)
end)

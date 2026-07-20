if not Config.Target then return end

-- ┌────────────────────────────────────────────────────────┐
-- │ Plant Target (por zona/coordenada, não por model)       │
-- └────────────────────────────────────────────────────────┘
-- Alvo por model (cl_target.lua antigo) dependia da COLISÃO do prop pra funcionar. Os props
-- customizados do nextgen_weedprops (7 variedades novas) renderizam normal mas não têm colisão
-- de verdade, então o alvo por model nunca detectava eles - só funcionava pras plantas nativas do
-- GTA (bkr_prop_weed_*) e as do lunar_drugscreator_props (coca). Trocado por zona na coordenada
-- exata da planta (salva no servidor), que não depende de colisão nenhuma - funciona igual pra
-- qualquer prop, customizado ou não.

local zones = {} -- plant id -> zone handle (ox_target zone id / qb-target zone name)

local openPlantMenu = function(plantId)
    lib.callback('it-drugs:server:getPlantDataWithId', false, function(result)
        if not result then return end
        TriggerEvent('it-drugs:client:showPlantMenu', result)
    end, plantId)
end

local registerPlantZone = function(plant)
    if not plant or not plant.id or zones[plant.id] then return end

    -- Centro da zona levantado (Config.PlantTargetZone.heightOffset) pra ficar dentro da folhagem
    -- da planta, longe da colisão sólida do vaso que fica bem perto de plant.coords (ver comentário
    -- em shared/config.lua) - senão a colisão do vaso sempre ganha da mira antes da zona.
    local zoneCoords = plant.coords + vector3(0, 0, Config.PlantTargetZone.heightOffset)

    -- Planta grande (estágio 3) precisa de raio/distância maiores que uma pequena (estágio 1) -
    -- ver Config.PlantTargetZone.radiusByStage/distanceByStage em shared/config.lua.
    local stage = plant.stage or 1
    local zoneRadius = Config.PlantTargetZone.radius + ((Config.PlantTargetZone.radiusByStage and Config.PlantTargetZone.radiusByStage[stage]) or 0)
    local zoneDistance = Config.PlantTargetZone.distance + ((Config.PlantTargetZone.distanceByStage and Config.PlantTargetZone.distanceByStage[stage]) or 0)

    if Config.Target == 'qb-target' then
        local name = 'it-drugs-plant-' .. plant.id
        exports['qb-target']:AddCircleZone(name, zoneCoords, zoneRadius, {
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    icon = 'fas fa-eye',
                    label = _U('TARGET__PLANT__LABEL'),
                    action = function()
                        openPlantMenu(plant.id)
                    end
                }
            },
            distance = zoneDistance,
        })
        zones[plant.id] = name
    elseif Config.Target == 'ox_target' then
        if not exports.ox_target then return end
        local zoneId = exports.ox_target:addSphereZone({
            coords = zoneCoords,
            radius = zoneRadius,
            options = {
                {
                    name = 'it-drugs-check-plant-' .. plant.id,
                    icon = 'fas fa-eye',
                    label = _U('TARGET__PLANT__LABEL'),
                    onSelect = function()
                        openPlantMenu(plant.id)
                    end,
                    distance = zoneDistance
                }
            }
        })
        zones[plant.id] = zoneId
    end
end

local removeAllPlantZones = function()
    for id, zone in pairs(zones) do
        if Config.Target == 'qb-target' then
            exports['qb-target']:RemoveZone(zone)
        elseif Config.Target == 'ox_target' and exports.ox_target then
            exports.ox_target:removeZone(zone)
        end
    end
    zones = {}
end

--- Recarrega TODAS as zonas do zero a partir da lista atual de plantas do servidor - chamado no
--- início e sempre que uma planta é criada/colhida/destruída/movida (it-drugs:client:syncPlantList)
local syncAllPlantZones = function()
    removeAllPlantZones()
    local allPlants = lib.callback.await('it-drugs:server:getPlants', false)
    for _, plant in pairs(allPlants or {}) do
        registerPlantZone(plant)
    end
end

CreateThread(function()
    syncAllPlantZones()
end)

RegisterNetEvent('it-drugs:client:syncPlantList', syncAllPlantZones)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeAllPlantZones()
end)

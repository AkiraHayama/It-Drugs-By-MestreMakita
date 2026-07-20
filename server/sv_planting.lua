local plants = {}

--- How many minutes to shave off a plant's growtime given its current fertilizer%,
--- interpolating between the two anchor points in Config.FertilizerGrowTimeReduction
--- @param fertilizer number - current fertilizer level [0-100]
--- @return number - minutes to subtract from growtime
local function getFertilizerGrowTimeReduction(fertilizer)
    local at50 = Config.FertilizerGrowTimeReduction[50]
    local at100 = Config.FertilizerGrowTimeReduction[100]

    if fertilizer <= 50 then
        return (at50 / 50) * fertilizer
    else
        return at50 + ((at100 - at50) / 50) * (fertilizer - 50)
    end
end

-- Method to calculate the health percentage for a given WeedPlants index
--- @param k number - WeedPlants table index
--- @return health number - health index [0-100]
local calcHealth = function(k)
    if not plants[k] then return 0 end
    local health = plants[k].health

    -- Só água e luz mantêm a planta viva - fertilizante só afeta a colheita (ver harvestPlant)
    local water_amount = plants[k].water
    local light_amount = math.min((plants[k].sunlight or 0) + (plants[k].addedLight or 0), 100)

    if water_amount == 0 or light_amount == 0 then
        health -= math.random(Config.HealthBaseDecay[1], Config.HealthBaseDecay[2])
    elseif water_amount < Config.WaterThreshold or light_amount < Config.LightThreshold then
        health -= math.random(Config.HealthBaseDecay[1], Config.HealthBaseDecay[2])
    end

    plants[k].health = math.max(health, 0.0)
    return math.max(health, 0.0)
end

--- Method to compute how much artificial light a coordinate receives from nearby grow lamps
--- @param coords vector3 - coords of the plant
--- @param lamps table - lamps table as returned by GetLamps()
--- @return number - added light% [0-100]
local calculateAddedLight = function(coords, lampsTable)
    local totalLight = 0

    for _, lamp in pairs(lampsTable or {}) do
        local lampConfig = Config.Lamps[lamp.item]

        if lampConfig and lampConfig.range and lampConfig.range > 0 then
            local distance = #(lamp.coords - coords)

            if distance <= lampConfig.range then
                totalLight = totalLight + (lampConfig.light * (1 - (distance / lampConfig.range)))
            end
        end
    end

    return math.min(totalLight, 100)
end

--- Recalculates the addedLight TARGET for every plant, called whenever a grow lamp is placed/taken
--- (also on resource start). Doesn't set addedLight directly anymore - that only ramps up gradually
--- towards this target in updatePlantNeeds (Config.LampLightRampStep per tick), EXCEPT losing the
--- lamp entirely (target drops to 0) which cuts the light instantly, same as unplugging it.
--- @param lampsTable table - lamps table as returned by GetLamps()
--- @return nil
function RecalculatePlantsLight(lampsTable)
    for k, v in pairs(plants) do
        local target = calculateAddedLight(v.coords, lampsTable)
        plants[k].targetAddedLight = target

        if target == 0 and (v.addedLight or 0) > 0 then
            plants[k].addedLight = 0
            MySQL.update('UPDATE drug_plants SET addedLight = 0 WHERE id = (:id)', {
                ['id'] = v.id,
            })
        end
    end
end

--- Whether a given plant pot already has a plant growing in it (used by sv_pots.lua)
--- @param potId number
--- @return boolean
function PlantExistsInPot(potId)
    for _, plant in pairs(plants) do
        if plant.potId == potId then
            return true
        end
    end

    return false
end

--- The per-stage Z offset in Config.PlantTypes is tuned for ground planting (raycast placement).
--- Pot-planted plants use Config.Plants[seed].potHeightOffset instead (set once, at plant time),
--- so this offset must NOT also apply to them or the two stack and the plant sinks too far.
--- @param plantType string
--- @param stage number
--- @param potId number|nil
--- @return number
local function getGroundOffset(plantType, stage, potId)
    if potId then return 0 end
    return (Config.PlantTypes[plantType][stage] and Config.PlantTypes[plantType][stage][2]) or 0
end

--- Method to calculate the growth stage of a weedplant for a given growth index
--- @param growth number - growth index [0-99]
--- @return stage number - growth stage number [1-3]
local calcStage = function(growth)
    local stage = math.floor(growth / 33) + 1
    if stage > 3 then stage = 3 end
    return stage
end

--- Method to setup all the weedplants, fetched from the database
--- @return nil
local setupPlants = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_plants')

    for k, v in pairs(result) do

        if not Config.Plants[v.type] then
            MySQL.query('DELETE from drug_plants WHERE id = :id', {
                ['id'] = v.id
            }, function()
                lib.print.info('PLANT ID: '.. v.id ..' has an invalid plant type, deleting it from the database')
            end)
        elseif v.owner == nil then
            MySQL.query('DELETE from drug_plants WHERE id = :id', {
                ['id'] = v.id
            }, function()
                lib.print.info('PLANT ID: '.. v.id ..' has no owner, deleting it from the database')
            end)
        else
            local plantType = Config.Plants[v.type].plantType

            local growth = v.growth or 0
            local stage = calcStage(growth)
            local modelHash = Config.PlantTypes[plantType][stage][1]
            local coords = json.decode(v.coords)
            local plant = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z + getGroundOffset(plantType, stage, v.potId), true, true, false)
            FreezeEntityPosition(plant, true)
            plants[plant] = {
                id = v.id,
                owner = v.owner,
                coords = vector3(coords.x, coords.y, coords.z),
                time = v.time,
                type = v.type,
                entity = plant,
                fertilizer = v.fertilizer,
                water = v.water,
                growtime = v.growtime,
                health = v.health,
                growth = growth,
                sunlight = v.sunlight or Config.DefaultSunlight,
                addedLight = v.addedLight or 0,
                potId = v.potId,
                stage = stage,
                budsHarvested = v.budsHarvested == 1
            }
        end
    end
end

--- Method to delete all cached weed plants and their entities
--- @return nil
local destroyAllPlants = function()    
    for k, v in pairs(plants) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
            plants[k] = nil
        end
    end
end

--- Method to update a plant object, removing the existing one and placing a new object
--- @param k number - WeedPlants table index
--- @param stage number - Stage number
--- @return nil
local updatePlantProp = function(k, stage)
    if not plants[k] then return end
    if not DoesEntityExist(k) then return end
    if plants[k].health <= 0 then return end

    local plantType = Config.Plants[plants[k].type].plantType

    local modelHash = Config.PlantTypes[plantType][stage][1]
    DeleteEntity(k)
    local plant = CreateObjectNoOffset(modelHash, plants[k].coords.x, plants[k].coords.y, plants[k].coords.z + getGroundOffset(plantType, stage, plants[k].potId), true, true, false)
    FreezeEntityPosition(plant, true)
    plants[plant] = plants[k]
    plants[plant].entity = plant
    plants[k] = nil
end

updatePlantNeeds = function ()
    -- Junta todas as trocas de estágio desse tick numa única broadcast no final, em vez de uma
    -- por planta (evita disparar vários resyncs de zona seguidos se várias plantas crescerem de
    -- estágio no mesmo tick).
    local anyStageChanged = false

    for k, v in pairs(plants) do
        local fertilizer = v.fertilizer
        local water = v.water

        local time = os.time()
        local planted = v.time

        local elapsed = os.difftime(time, planted)
        if elapsed >= Config.GrowthTickInterval then
            if fertilizer - Config.FertilizerDecay >= 0 then
                plants[k].fertilizer = it.round(fertilizer - Config.FertilizerDecay, 2)
            else
                plants[k].fertilizer = 0
            end
    
            if water - Config.WaterDecay >= 0 then
                plants[k].water = it.round(water - Config.WaterDecay, 2)
            else
                plants[k].water = 0
            end
            -- Luz de lâmpada sobe aos poucos em direção ao alvo (Config.LampLightRampStep por
            -- tick, ver RecalculatePlantsLight) - perder a lâmpada já zera na hora lá, aqui só trata o ganho.
            local targetLight = plants[k].targetAddedLight or 0
            local currentLight = plants[k].addedLight or 0
            if currentLight < targetLight then
                plants[k].addedLight = math.min(currentLight + Config.LampLightRampStep, targetLight, 100)
            end

            local health = calcHealth(k)

            -- Growth ticks automatically while alive (health > 0) - fertilizer only shortens the total time, see getFertilizerGrowTimeReduction
            if health > 0 and (plants[k].growth or 0) < 100 then
                local reduction = getFertilizerGrowTimeReduction(plants[k].fertilizer or 0)
                local effectiveGrowTime = math.max((plants[k].growtime or Config.GlobalGrowTime) - reduction, 1)
                local ticksToFinish = (effectiveGrowTime * 60) / Config.GrowthTickInterval
                local growthStep = 100 / ticksToFinish
                plants[k].growth = math.min((plants[k].growth or 0) + growthStep, 100)
            end

            MySQL.update('UPDATE drug_plants SET water = (:water), fertilizer = (:fertilizer), health = (:health), growth = (:growth), addedLight = (:addedLight) WHERE id = (:id)', {
                ['water'] = v.water,
                ['fertilizer'] = v.fertilizer,
                ['health'] = health,
                ['growth'] = v.growth,
                ['addedLight'] = v.addedLight,
                ['id'] = v.id,
            })
        end

        if not DoesEntityExist(k) then
            lib.print.info('Plant ID: '.. v.id ..' does not exist, respawning it coords:', v.coords.x)
            -- Respawn the plant
            local modelHash = Config.PlantTypes[Config.Plants[v.type].plantType][v.stage][1]
            local plant = CreateObjectNoOffset(modelHash, v.coords.x, v.coords.y, v.coords.z + Config.PlantTypes[Config.Plants[v.type].plantType][v.stage][2], true, true, false)
            FreezeEntityPosition(plant, true)
            plants[plant] = plants[k]
            plants[plant].entity = plant
            plants[k] = nil
            v = plants[plant]

            local stage = calcStage(v.growth or 0)
            if stage ~= v.stage then
                plants[plant].stage = stage
                updatePlantProp(plant, stage)
                anyStageChanged = true
            end
        else
            local stage = calcStage(v.growth or 0)
            if stage ~= v.stage then
                plants[k].stage = stage
                updatePlantProp(k, stage)
                anyStageChanged = true
            end
        end
    end

    -- Sem isso, o alvo da planta (client/cl_plant_targets.lua) nunca sabia que a planta cresceu
    -- de estágio - a zona só era (re)criada ao plantar/colher/destruir/mover, então uma planta que
    -- vira "grande" só pelo crescimento natural ficava com a zona de tamanho de quando era pequena
    -- pra sempre (o raio/distância que compensam a folhagem sem colisão é por estágio, ver
    -- Config.PlantTargetZone.radiusByStage/distanceByStage em shared/config.lua).
    if anyStageChanged then
        TriggerClientEvent('it-drugs:client:syncPlantList', -1)
    end

    SetTimeout(Config.GrowthTickInterval * 1000, updatePlantNeeds)
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    while not DatabaseSetuped do
        lib.print.info('Waiting for Database to be setup')
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setup Plants') end
    setupPlants()
    if Config.ClearOnStartup then
        Wait(5000) -- Wait 5 seconds to allow all functions to be executed on startup
        for k, v in pairs(plants) do
            if plants[k].health == 0 then
                DeleteEntity(k)
                MySQL.query('DELETE from drug_plants WHERE id = :id', {
                    ['id'] = plants[k].id
                })
                plants[k] = nil
            end
        end
    end
    TriggerClientEvent('it-drugs:client:syncPlantList', -1)
    SendToWebhook(0, 'message', nil, 'Started '..GetCurrentResourceName()..' logger')

end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- MySQL.update é "dispara e esquece" (assíncrono, sem esperar resposta) - o FXServer não
    -- espera esse tipo de query terminar antes de derrubar o resource, então numa planta (ou
    -- várias) a query podia nem chegar a sair pro banco antes do Lua ser destruído. Trocado pra
    -- MySQL.Sync.execute (bloqueante, usa Citizen.Await por baixo) - isso SIM faz o FXServer
    -- esperar cada UPDATE terminar de verdade antes do handler retornar e o resource parar,
    -- então a última leitura no banco sempre reflete o estado real no momento do restart/parada.
    for k, v in pairs(plants) do
        MySQL.Sync.execute('UPDATE drug_plants SET water = (:water), fertilizer = (:fertilizer), health = (:health), growth = (:growth) WHERE id = (:id)', {
            ['water'] = v.water,
            ['fertilizer'] = v.fertilizer,
            ['health'] = v.health,
            ['growth'] = v.growth,
            ['id'] = v.id,
        })
    end

    destroyAllPlants()

end)

--- Events

-- DEBUG/teste: força a planta pra 100% de crescimento (e saúde cheia) na hora, pra poder testar
-- colheita sem esperar o tempo de crescimento normal. Só admin (mesma ACE dos outros comandos de
-- admin do it-drugs) - acessível pelo menu de admin da planta e pelo próprio menu de "checar
-- planta" (só visível pra admin nesse segundo caso, ver client/cl_menus.lua).
-- Busca por ID (não por entity) pelo mesmo motivo do harvestPlant acima - handle capturado
-- quando o menu foi aberto pode ficar velho se a planta for "reencarnada" nesse meio tempo.
RegisterNetEvent('it-drugs:server:forceGrowPlant', function(args)
    local src = source
    if not IsPlayerAceAllowed(src, 'admin') then return end

    local plantId = args.id
    local entity
    for k, v in pairs(plants) do
        if v.id == plantId then
            entity = k
            break
        end
    end
    local plant = entity and plants[entity]
    if not plant then return end

    plant.growth = 100
    plant.health = 100

    -- Sempre troca o prop pro modelo do estágio 3, mesmo se `plant.stage` já disser 3 - não dá
    -- pra confiar só nesse campo aqui: se ele já estiver (mesmo que erroneamente) marcado como 3
    -- sem o prop de verdade ter sido trocado antes, a comparação `stage ~= plant.stage` nunca
    -- detecta diferença e o modelo visual fica preso no estágio antigo pra sempre (era exatamente
    -- esse o sintoma: "prop não fica no último estágio").
    local stage = calcStage(plant.growth)
    plant.stage = stage
    updatePlantProp(entity, stage)

    MySQL.update('UPDATE drug_plants SET growth = (:growth), health = (:health) WHERE id = (:id)', {
        ['growth'] = plant.growth,
        ['health'] = plant.health,
        ['id'] = plant.id,
    })

    TriggerClientEvent('it-drugs:client:syncPlantList', -1)
    ShowNotification(src, _U('NOTIFICATION__PLANT__FORCED_GROWTH'), 'success')
end)

RegisterNetEvent('it-drugs:server:destroyPlant', function(args)
    local entity = args.entity
    if not plants[entity] then return end
    
    if args.extra == nil then
        if #(GetEntityCoords(GetPlayerPed(source)) - plants[entity].coords) > 10 then return end
    end
    SendToWebhook(source, 'plant', 'destroy', plants[entity])

    if Config.Debug then lib.print.info('Does Entity Exists:', DoesEntityExist(entity)) end
    if DoesEntityExist(entity) then
        MySQL.query('DELETE from drug_plants WHERE id = :id', {
            ['id'] = plants[entity].id
        })

        TriggerClientEvent('it-drugs:client:startPlantFire', -1, plants[entity].coords, stage)
        Wait(Config.FireTime / 2)
        DeleteEntity(entity)

        plants[entity] = nil
        TriggerClientEvent('it-drugs:client:syncPlantList', -1)
    end
end)

RegisterNetEvent('it-drugs:server:harvestPlant', function(plantId)
    local src = source
    local player = it.getPlayer(src)
    if not player then return end

    -- Busca a planta pelo ID (nunca muda) em vez de aceitar um entity handle direto - o minigame
    -- de colheita pode demorar bastante (clicar em vários brotos, um por um), e nesse tempo a
    -- planta pode ter sido "reencarnada" no servidor (troca de estágio, respawn por hiccup de
    -- rede - ver updatePlantNeeds). Um entity handle capturado lá atrás (quando o menu foi aberto)
    -- nunca mais bate em plants[entity] depois disso, e o handler recusava tudo em silêncio (nem
    -- item nem remoção), mesmo com o client achando que colheu certo (planta "fantasma" ficava
    -- visível pra sempre, já que nunca era deletada de verdade).
    local entity
    for k, v in pairs(plants) do
        if v.id == plantId then
            entity = k
            break
        end
    end
    if not entity then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - plants[entity].coords) > 10 then return end
    if (plants[entity].growth or 0) < 100 then return end
    if plants[entity].budsHarvested then return end -- já colheu os brotos dessa planta, não dá pra repetir

    if DoesEntityExist(entity) then
        local fertilizerFactor = (plants[entity].fertilizer or 0) / 100 -- 0 = colhe o mínimo, 100 = colhe o máximo

        for k, v in pairs(Config.Plants[plants[entity].type].products) do
            local product = k
            local minAmount = v.min
            local maxAmount = v.max
            local amount = math.floor(minAmount + ((maxAmount - minAmount) * fertilizerFactor) + 0.5)
            it.giveItem(src, product, amount)
        end
        if math.random(1, 100) <= Config.Plants[plants[entity].type].seed.chance then
            local seed = plants[entity].type

            if Config.Plants[plants[entity].type].seed.max > 1 then
                local seedAmount = math.random(Config.Plants[seed].seed.min, Config.Plants[seed].seed.max)
                it.giveItem(src, seed, seedAmount)
            end
        end

        -- A planta NÃO é mais destruída aqui (era o comportamento antigo) - só marca que os brotos
        -- já foram colhidos e persiste isso. A planta continua parada, 100% crescida, esperando
        -- alguém cortar ela inteira com a foice (it-drugs:server:cutWholePlant abaixo) pro
        -- "prensado" - só ESSA ação remove a planta de verdade agora.
        plants[entity].budsHarvested = true
        SendToWebhook(src, 'plant', 'harvest', plants[entity])

        MySQL.update('UPDATE drug_plants SET budsHarvested = 1 WHERE id = (:id)', {
            ['id'] = plants[entity].id,
        })
        TriggerClientEvent('it-drugs:client:syncPlantList', -1)
    end
end)

-- Corta a planta INTEIRA com a foice (bzzz_cutting_weed) - só depois de já ter colhido os brotos
-- (budsHarvested). Dá MAIS do produto CRU da própria variedade (bônus, mesmo item que colher os
-- brotos já dá - Config.Plants[type].products), não um "prensado" direto - o prensado de verdade
-- só sai depois de secar + processar (mesma mesa/receita nova, ver shared/config.lua). SÓ AQUI a
-- planta é removida de verdade (era o it-drugs:server:harvestPlant que fazia isso antes).
RegisterNetEvent('it-drugs:server:cutWholePlant', function(plantId)
    local src = source
    local player = it.getPlayer(src)
    if not player then return end

    -- Foice precisa estar no inventário de verdade (ferramenta, nunca é gasta) - nunca confia só
    -- na checagem do client, o servidor confere de novo aqui.
    if not it.hasItem(src, Config.HarvestMinigame.sickleItem, 1) then
        ShowNotification(src, _U('NOTIFICATION__MISSING__TOOL'), 'error')
        return
    end

    -- Mesmo esquema de busca por ID do harvestPlant acima (não confia em entity handle direto).
    local entity
    for k, v in pairs(plants) do
        if v.id == plantId then
            entity = k
            break
        end
    end
    if not entity then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - plants[entity].coords) > 10 then return end
    if (plants[entity].growth or 0) < 100 then return end
    if not plants[entity].budsHarvested then return end -- precisa ter colhido os brotos primeiro

    if DoesEntityExist(entity) then
        local fertilizerFactor = (plants[entity].fertilizer or 0) / 100
        local mult = Config.HarvestMinigame.wholePlantMultiplier

        for k, v in pairs(Config.Plants[plants[entity].type].products) do
            local minAmount = v.min * mult
            local maxAmount = v.max * mult
            local amount = math.floor(minAmount + ((maxAmount - minAmount) * fertilizerFactor) + 0.5)
            it.giveItem(src, k, amount)
        end

        DeleteEntity(entity)
        SendToWebhook(src, 'plant', 'cutWholePlant', plants[entity])

        MySQL.query('DELETE from drug_plants WHERE id = :id', {
            ['id'] = plants[entity].id
        })
        plants[entity] = nil
        TriggerClientEvent('it-drugs:client:syncPlantList', -1)
    end
end)


RegisterNetEvent('it-drugs:server:plantTakeCare', function(entity, item)

    if not plants[entity] then return end
    local src = source
    local player = it.getPlayer(src)
    if not player then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - plants[entity].coords) > 10 then return end

    local itemData = Config.Items[item]
    local consumed

    if itemData.charges then
        -- Item de cargas limitadas (regador): não é removido do inventário, só perde 1 carga
        -- (metadata do ox_inventory) até zerar - precisa reabastecer num Config.WaterPoints.
        if it.inventory ~= 'ox' then return end

        local slotData = exports.ox_inventory:GetSlotWithItem(src, item)
        if not slotData then return end

        local currentCharges = (slotData.metadata and slotData.metadata.charges) or Config.WateringCanMaxCharges
        if currentCharges <= 0 then
            ShowNotification(src, _U('NOTIFICATION__WATERINGCAN__EMPTY'), 'error')
            return
        end

        local metadata = slotData.metadata or {}
        metadata.charges = currentCharges - 1
        metadata.durability = (metadata.charges / Config.WateringCanMaxCharges) * 100 -- barra visual no ícone do inventário (nativa do ox_inventory)
        exports.ox_inventory:SetMetadata(src, slotData.slot, metadata)
        consumed = true
    else
        consumed = it.removeItem(src, item, 1)
    end

    if consumed then
        if itemData.water ~= 0 then
            local itemStrength = itemData.water
            local currentWater = plants[entity].water
            if currentWater + itemStrength >= 100 then
                plants[entity].water = 100
            else
                plants[entity].water = currentWater + itemStrength
            end

            MySQL.update('UPDATE drug_plants SET water = (:water) WHERE id = (:id)', {
                ['water'] = json.encode(plants[entity].water),
                ['id'] = plants[entity].id,
            })
            SendToWebhook(src, 'plant', 'water', plants[entity])
        end

        if itemData.fertilizer ~= 0 then
            local itemStrength = itemData.fertilizer
            local currentFertilizer = plants[entity].fertilizer
            if currentFertilizer + itemStrength >= 100 then
                plants[entity].fertilizer = 100
            else
                plants[entity].fertilizer = currentFertilizer + itemStrength
            end

            MySQL.update('UPDATE drug_plants SET fertilizer = (:fertilizer) WHERE id = (:id)', {
                ['fertilizer'] = json.encode(plants[entity].fertilizer),
                ['id'] = plants[entity].id,
            })
            SendToWebhook(src, 'plant', 'fertilize', plants[entity])
        end
        if itemData.itemBack ~= nil then
            it.giveItem(src, itemData.itemBack, 1)
        end
    end
end)

RegisterNetEvent('it-drugs:server:giveWater', function(entity, item)
    if not plants[entity] then return end
    local src = source
    local player = it.getPlayer(src)
    if not player then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - plants[entity].coords) > 10 then return end

    if it.removeItem(src, item, 1) then

        SendToWebhook(src, 'plant', 'water', plants[entity])

        local itemStrength = Config.Items[item].water
        local currentWater = plants[entity].water
        if currentWater + itemStrength >= 100 then
            plants[entity].water = 100
        else
            plants[entity].water = currentWater + itemStrength
        end

        MySQL.update('UPDATE drug_plants SET water = (:water) WHERE id = (:id)', {
            ['water'] = json.encode(plants[entity].water),
            ['id'] = plants[entity].id,
        })
    end
end)

RegisterNetEvent('it-drugs:server:giveFertilizer', function(entity, item)
    if not plants[entity] then return end
    local src = source
    local player = it.getPlayer(src)
    if not player then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - plants[entity].coords) > 10 then return end

    if it.removeItem(src, item, 1) then
        SendToWebhook(src, 'plant', 'fertilize', plants[entity])
        
        local itemStrength = Config.Items[item].fertilizer
        local currentFertilizer = plants[entity].fertilizer
        if currentFertilizer + itemStrength >= 100 then
            plants[entity].fertilizer = 100
        else
            plants[entity].fertilizer = currentFertilizer + itemStrength
        end
        
        MySQL.update('UPDATE drug_plants SET fertilizer = (:fertilizer) WHERE id = (:id)', {
            ['fertilizer'] = json.encode(plants[entity].fertilizer),
            ['id'] = plants[entity].id,
        })
    end
end)

RegisterNetEvent('it-drugs:server:createNewPlant', function(coords, plantItem, zone, metadata, sunlight)
    local src = source
    local player = it.getPlayer(src)
    local plantInfos = Config.Plants[plantItem]

    if not player then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.rayCastingDistance + 10 then return end

    if it.removeItem(src, plantItem, 1, metadata) then
        local modelHash = GetHashKey(Config.PlantTypes[plantInfos.plantType][1][1])
        local plant = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z + Config.PlantTypes[plantInfos.plantType][1][2], true, true, false)
        FreezeEntityPosition(plant, true)
        local time = os.time()
        local owner = it.getCitizenId(src)

        local growTime = Config.GlobalGrowTime
        if plantInfos.growthTime then
            growTime = plantInfos.growthTime
        end
        if Config.Zones[zone] ~= nil and Config.Zones[zone].growMultiplier then
            growTime = (growTime / Config.Zones[zone].growMultiplier)
        end

        sunlight = tonumber(sunlight) or Config.DefaultSunlight
        -- Nasce com addedLight = 0 (escuro) mesmo já tendo lâmpada por perto - a luz sobe aos
        -- poucos (Config.LampLightRampStep) em updatePlantNeeds até chegar em targetAddedLight.
        local targetAddedLight = GetLamps and calculateAddedLight(coords, GetLamps()) or 0

        MySQL.insert('INSERT INTO `drug_plants` (owner, coords, time, type, water, fertilizer, health, growtime, growth, sunlight, addedLight) VALUES (:owner, :coords, :time, :type, :water, :fertilizer, :health, :growtime, :growth, :sunlight, :addedLight)', {
            ['owner'] = owner,
            ['coords'] = json.encode(coords),
            ['time'] = time,
            ['type'] = plantItem,
            ['water'] = 0.0,
            ['fertilizer'] = 0.0,
            ['health'] = 100.0,
            ['growtime'] = growTime,
            ['growth'] = 0.0,
            ['sunlight'] = sunlight,
            ['addedLight'] = 0.0,
        }, function(id)
            plants[plant] = {
                id = id,
                owner = owner,
                coords = coords,
                time = time,
                type = plantItem,
                water = 0.0,
                fertilizer = 0.0,
                health = 100.0,
                growtime = growTime,
                growth = 0.0,
                sunlight = sunlight,
                addedLight = 0.0,
                targetAddedLight = targetAddedLight,
                entity = plant,
                stage = 1,
                budsHarvested = false
            }
            TriggerClientEvent('it-drugs:client:syncPlantList', -1)
            SendToWebhook(src, 'plant', 'plant', plants[plant])
        end)
    end
end)

-- Plants a seed directly inside a pot (client/cl_pots.lua), skipping the raycast
-- placement/ground-type checks entirely since the pot is the growing surface.
RegisterNetEvent('it-drugs:server:plantInPot', function(args)
    local src = source
    local player = it.getPlayer(src)
    local entity = args.entity
    local seedItem = args.seed
    local plantInfos = Config.Plants[seedItem]

    if not player or not plantInfos then return end

    local potData = GetPotData and GetPotData(entity)
    if not potData then return end
    if PlantExistsInPot(potData.id) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - potData.coords) > 10 then return end
    if not potData.hasSoil then return end
    if not it.hasItem(src, seedItem, 1) then return end

    if it.removeItem(src, seedItem, 1) then
        local potConfig = Config.Pots[potData.item]
        local heightOffset = ((potConfig and potConfig.heightOffset) or 0) + ((potConfig and potConfig.plantHeightOffset) or 0) -- altura do vaso + ajuste fino só da planta
        local coords = vector3(potData.coords.x, potData.coords.y, potData.coords.z + heightOffset)
        local modelHash = GetHashKey(Config.PlantTypes[plantInfos.plantType][1][1])
        -- No ground offset here on purpose - potHeightOffset alone controls height in a pot.
        local plant = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, false)
        FreezeEntityPosition(plant, true)
        local time = os.time()
        local owner = it.getCitizenId(src)
        local growTime = plantInfos.growthTime or Config.GlobalGrowTime

        local sunlight = tonumber(args.sunlight) or Config.DefaultSunlight
        -- Nasce com addedLight = 0 (escuro) mesmo já tendo lâmpada por perto - a luz sobe aos
        -- poucos (Config.LampLightRampStep) em updatePlantNeeds até chegar em targetAddedLight.
        local targetAddedLight = GetLamps and calculateAddedLight(coords, GetLamps()) or 0

        MySQL.insert('INSERT INTO `drug_plants` (owner, coords, time, type, water, fertilizer, health, growtime, growth, sunlight, addedLight, potId) VALUES (:owner, :coords, :time, :type, :water, :fertilizer, :health, :growtime, :growth, :sunlight, :addedLight, :potId)', {
            ['owner'] = owner,
            ['coords'] = json.encode(coords),
            ['time'] = time,
            ['type'] = seedItem,
            ['water'] = 0.0,
            ['fertilizer'] = 0.0,
            ['health'] = 100.0,
            ['growtime'] = growTime,
            ['growth'] = 0.0,
            ['sunlight'] = sunlight,
            ['addedLight'] = 0.0,
            ['potId'] = potData.id,
        }, function(id)
            plants[plant] = {
                id = id,
                owner = owner,
                coords = coords,
                time = time,
                type = seedItem,
                water = 0.0,
                fertilizer = 0.0,
                health = 100.0,
                growtime = growTime,
                growth = 0.0,
                sunlight = sunlight,
                addedLight = 0.0,
                targetAddedLight = targetAddedLight,
                potId = potData.id,
                entity = plant,
                stage = 1,
                budsHarvested = false
            }
            TriggerClientEvent('it-drugs:client:syncPlantList', -1)
            SendToWebhook(src, 'plant', 'plant', plants[plant])
        end)
    end
end)

--- Full plant data (same shape as getPlantData) for the plant growing in a given pot, or nil.
--- Used by the vaso's own menu (cl_menus.lua:showPotMenu) to show water/fertilizer/harvest
--- controls directly on the pot, without needing to target the plant separately.
--- @param potId number
function GetPlantInPot(potId)
    for entity, plant in pairs(plants) do
        if plant.potId == potId then
            return {
                id = plant.id,
                owner = plant.owner,
                coords = plant.coords,
                time = plant.time,
                type = plant.type,
                fertilizer = plant.fertilizer,
                water = plant.water,
                stage = calcStage(plant.growth or 0),
                health = plant.health,
                growth = plant.growth or 0,
                sunlight = plant.sunlight or Config.DefaultSunlight,
                addedLight = plant.addedLight or 0,
                budsHarvested = plant.budsHarvested or false,
                entity = entity, -- handle do SERVER (só serve pra ecoar de volta em TriggerServerEvent, nunca usar em native local no client)
                netId = NetworkGetNetworkIdFromEntity(entity) -- pra client resolver o handle LOCAL de verdade quando precisar (ex.: câmera do minigame de colheita)
            }
        end
    end

    return nil
end

--- Moves the plant growing in a given pot to new coords (used when the pot itself is
--- relocated via server/sv_pots.lua:movePot) - deletes and respawns the plant entity at the
--- new spot, keeping id/growth/health/water/fertilizer untouched, same trick as updatePlantProp.
--- @param potId number
--- @param newCoords vector3
--- @param potConfig table - Config.Pots[x] entry, for heightOffset/plantHeightOffset
function MovePlantForPot(potId, newCoords, potConfig)
    for entity, plant in pairs(plants) do
        if plant.potId == potId then
            local plantType = Config.Plants[plant.type].plantType
            local stage = calcStage(plant.growth or 0)
            local modelHash = Config.PlantTypes[plantType][stage][1]
            local heightOffset = ((potConfig and potConfig.heightOffset) or 0) + ((potConfig and potConfig.plantHeightOffset) or 0)
            local coords = vector3(newCoords.x, newCoords.y, newCoords.z + heightOffset)

            DeleteEntity(entity)
            local newPlant = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, false)
            FreezeEntityPosition(newPlant, true)

            plants[newPlant] = plant
            plants[newPlant].coords = coords
            plants[newPlant].entity = newPlant
            plants[entity] = nil

            MySQL.update('UPDATE drug_plants SET coords = (:coords) WHERE id = (:id)', {
                ['coords'] = json.encode(coords),
                ['id'] = plant.id,
            })

            TriggerClientEvent('it-drugs:client:syncPlantList', -1)
            return
        end
    end
end

-- Callbacks
lib.callback.register('it-drugs:server:getPlantDataByPot', function(source, potId)
    return GetPlantInPot(potId)
end)

lib.callback.register('it-drugs:server:getPlantData', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not plants[entity] then return nil end
    if Config.Debug then lib.print.info('Get Plant Data:', entity) end
    local temp = {
        id = plants[entity].id,
        owner = plants[entity].owner,
        coords = plants[entity].coords,
        time = plants[entity].time,
        type = plants[entity].type,
        fertilizer = plants[entity].fertilizer,
        water = plants[entity].water,
        stage = calcStage(plants[entity].growth or 0),
        health = plants[entity].health,
        growth = plants[entity].growth or 0,
        sunlight = plants[entity].sunlight or Config.DefaultSunlight,
        addedLight = plants[entity].addedLight or 0,
        budsHarvested = plants[entity].budsHarvested or false,
        entity = entity, -- handle do SERVER (só serve pra ecoar de volta em TriggerServerEvent, nunca usar em native local no client)
        netId = netId -- já veio como parâmetro - client resolve o handle LOCAL de verdade a partir dele quando precisar
    }
    if Config.Debug then lib.print.info('Plant Data', temp) end
    return temp
end)

lib.callback.register('it-drugs:server:getPlantDataWithId', function(source, plantId)
    lib.print.info('Plant ID:', plantId)
    for k, v in pairs(plants) do
        if v.id == plantId then
            local entity = k
            local temp = {
                id = v.id,
                owner = v.owner,
                coords = v.coords,
                time = v.time,
                type = v.type,
                fertilizer = v.fertilizer,
                water = v.water,
                stage = calcStage(v.growth or 0),
                health = v.health,
                growth = v.growth or 0,
                sunlight = v.sunlight or Config.DefaultSunlight,
                addedLight = v.addedLight or 0,
                budsHarvested = v.budsHarvested or false,
                entity = entity, -- handle do SERVER (só serve pra ecoar de volta em TriggerServerEvent, nunca usar em native local no client)
                netId = NetworkGetNetworkIdFromEntity(entity) -- pra client resolver o handle LOCAL de verdade quando precisar (ex.: câmera do minigame de colheita)
            }
            if Config.Debug then lib.print.info('Plant Data', temp) end
            return temp
        end
    end
end)

lib.callback.register('it-drugs:server:getPlantsOwned', function(source)
    local src = source
    local citId = it.getCitizenId(src)
    local temp = {}
    for k, v in pairs(plants) do
        if v.owner == citId then
            table.insert(temp, {
                id = v.id,
                owner = v.owner,
            })
        end
    end
    if Config.Debug then lib.print.info('Plants Owned:', temp) end
    if #temp == 0 then return nil end
    return temp
end)

lib.callback.register('it-drugs:server:getPlants', function(source)
    return plants
end)

--- Threads
CreateThread(function()
    Wait(1000) -- Wait 5 seconds to allow all functions to be executed on startup
    updatePlantNeeds()
end)
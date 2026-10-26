if not Config.EnablePots then return end
local pots = {}

--- Method to setup all the plant pots, fetched from the database
--- @return nil
local setupPots = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_pots')

    for k, v in pairs(result) do
        local potConfig = Config.Pots[v.item]
        if potConfig then
            local hasSoil = v.hasSoil == 1
            local model = (hasSoil and potConfig.soilModel) or potConfig.model
            local modelHash = GetHashKey(model)
            local coords = json.decode(v.coords)
            local heightOffset = potConfig.heightOffset or 0
            local pot = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z + heightOffset, true, true, false)
            SetEntityHeading(pot, v.rotation + .0)
            Wait(50)
            FreezeEntityPosition(pot, true)
            pots[pot] = {
                id = v.id,
                coords = vector3(coords.x, coords.y, coords.z),
                item = v.item,
                rot = v.rotation + .0,
                entity = pot,
                hasSoil = hasSoil,
                needsFertilizer = v.soilNeedsFertilizer == 1, -- planta cortada: precisa adubar antes de plantar de novo
                burnt = v.soilBurnt == 1, -- planta queimada: terra imprópria, tem que remover e pôr terra nova
            }
        end
    end
end

--- Method to delete all cached pots and their entities
--- @return nil
local destroyAllPots = function()
    for k, v in pairs(pots) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
            pots[k] = nil
        end
    end
end

--- Returns {id, coords, item, hasSoil} for a pot entity, used by sv_planting.lua when planting into a pot
--- @param entity number
function GetPotData(entity)
    local pot = pots[entity]
    if not pot then return nil end

    return { id = pot.id, coords = pot.coords, item = pot.item, hasSoil = pot.hasSoil, needsFertilizer = pot.needsFertilizer, burnt = pot.burnt }
end

local findPotById = function(potId)
    for entity, pot in pairs(pots) do
        if pot.id == potId then return entity, pot end
    end
end

-- Troca o prop do vaso (vazio <-> com terra), mesmo esquema de updatePlantProp em sv_planting.lua
local swapPotModel = function(entity, pot, withSoil)
    local potConfig = Config.Pots[pot.item]
    local modelHash = GetHashKey(withSoil and (potConfig.soilModel or potConfig.model) or potConfig.model)
    DeleteEntity(entity)
    local newPot = CreateObjectNoOffset(modelHash, pot.coords.x, pot.coords.y, pot.coords.z + (potConfig.heightOffset or 0), true, true, false)
    SetEntityHeading(newPot, pot.rot)
    FreezeEntityPosition(newPot, true)
    pot.entity = newPot
    pots[newPot] = pot
    pots[entity] = nil
end

--- Planta cortada no vaso (sv_planting.lua): a terra fica, mas precisa adubar antes de plantar de novo
--- @param potId number
function SetPotSoilAfterCut(potId)
    local _, pot = findPotById(potId)
    if not pot then return end
    pot.needsFertilizer = true
    MySQL.update('UPDATE drug_pots SET soilNeedsFertilizer = 1 WHERE id = (:id)', { ['id'] = potId })
end

--- Planta queimada no vaso (sv_planting.lua): a terra FICA, mas imprópria - tem que "Remover Terra" e pôr terra nova
--- @param potId number
function BurnPotSoil(potId)
    local _, pot = findPotById(potId)
    if not pot then return end
    pot.burnt, pot.needsFertilizer = true, false
    MySQL.update('UPDATE drug_pots SET soilBurnt = 1, soilNeedsFertilizer = 0 WHERE id = (:id)', { ['id'] = potId })
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setting up Plant Pots') end
    setupPots()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- "Colocar Terra"/mover vaso salvam via MySQL.update, que é assíncrono ("dispara e esquece",
    -- sem esperar resposta) - o FXServer NÃO espera esse tipo de query terminar antes de derrubar
    -- o resource, então se o restart acontecer logo depois de mexer no vaso (ex.: testando e dando
    -- restart rápido em seguida), a query podia nem sair pro banco a tempo - o vaso voltava sem
    -- terra mesmo tendo colocado. Snapshot final SÍNCRONO (MySQL.Sync.execute, espera de verdade)
    -- de hasSoil/coords/rotation de todo vaso conhecido, mesmo esquema aplicado nas plantas acima.
    for k, v in pairs(pots) do
        MySQL.Sync.execute('UPDATE drug_pots SET hasSoil = (:hasSoil), soilNeedsFertilizer = (:needsFertilizer), soilBurnt = (:burnt), coords = (:coords), rotation = (:rotation) WHERE id = (:id)', {
            ['hasSoil'] = v.hasSoil and 1 or 0,
            ['needsFertilizer'] = v.needsFertilizer and 1 or 0,
            ['burnt'] = v.burnt and 1 or 0,
            ['coords'] = json.encode(v.coords),
            ['rotation'] = v.rot,
            ['id'] = v.id,
        })
    end

    destroyAllPots()
end)

RegisterNetEvent('it-drugs:server:createNewPot', function(coords, item, rotation)
    local src = source
    local player = it.getPlayer(src)
    local potConfig = Config.Pots[item]

    if not player or not potConfig then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco (Config.PlaceMaxDistance + folga)

    if it.removeItem(src, item, 1) then
        local modelHash = GetHashKey(potConfig.model)
        local heightOffset = potConfig.heightOffset or 0
        local pot = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z + heightOffset, true, true, false)
        SetEntityHeading(pot, rotation)
        FreezeEntityPosition(pot, true)

        MySQL.insert('INSERT INTO `drug_pots` (coords, item, rotation) VALUES (:coords, :item, :rotation)', {
            ['coords'] = json.encode(coords),
            ['item'] = item,
            ['rotation'] = rotation
        }, function(id)
            pots[pot] = {
                id = id,
                coords = coords,
                item = item,
                rot = rotation,
                entity = pot,
                hasSoil = false
            }
        end)
    end
end)

RegisterNetEvent('it-drugs:server:addSoil', function(args)
    local src = source
    local entity = args.entity
    local pot = pots[entity]
    local potConfig = pot and Config.Pots[pot.item]
    local soilItem = potConfig and potConfig.soilItem

    if not pot or not soilItem then return end
    if pot.hasSoil then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - pot.coords) > 10 then return end

    if it.removeItem(src, soilItem, 1) then
        MySQL.update('UPDATE drug_pots SET hasSoil = 1 WHERE id = (:id)', { ['id'] = pot.id })

        pot.hasSoil, pot.needsFertilizer = true, false
        swapPotModel(entity, pot, true) -- troca o prop de verdade pro modelo "com terra"
    end
end)

-- Remover a terra (queimada ou não): vaso volta vazio. Precisa disso pra pôr terra nova ou recolher o vaso
RegisterNetEvent('it-drugs:server:removeSoil', function(args)
    local src = source
    local pot = pots[args.entity]
    if not pot or not pot.hasSoil then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - pot.coords) > 10 then return end
    if PlantExistsInPot and PlantExistsInPot(pot.id) then return end

    pot.hasSoil, pot.needsFertilizer, pot.burnt = false, false, false
    MySQL.update('UPDATE drug_pots SET hasSoil = 0, soilNeedsFertilizer = 0, soilBurnt = 0 WHERE id = (:id)', { ['id'] = pot.id })
    swapPotModel(args.entity, pot, false)
    ShowNotification(src, _U('NOTIFICATION__POT__SOIL__REMOVED'), 'success')
end)

-- Adubar a terra depois de cortar a planta (Config.Pots[x].fertilizeItem, gasta 1)
RegisterNetEvent('it-drugs:server:fertilizeSoil', function(args)
    local src = source
    local pot = pots[args.entity]
    if not pot or not pot.hasSoil or not pot.needsFertilizer or pot.burnt then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - pot.coords) > 10 then return end

    if not it.removeItem(src, Config.Pots[pot.item].fertilizeItem, 1) then
        ShowNotification(src, _U('NOTIFICATION__POT__NO__FERTILIZER'), 'error')
        return
    end
    pot.needsFertilizer = false
    MySQL.update('UPDATE drug_pots SET soilNeedsFertilizer = 0 WHERE id = (:id)', { ['id'] = pot.id })
    ShowNotification(src, _U('NOTIFICATION__POT__FERTILIZED'), 'success')
end)

RegisterNetEvent('it-drugs:server:movePot', function(args)
    local src = source
    local entity = args.entity
    local newCoords = args.coords
    local newRotation = args.rotation
    local pot = pots[entity]
    local potConfig = pot and Config.Pots[pot.item]

    if not pot or not potConfig then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - pot.coords) > 10 then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - newCoords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco (Config.PlaceMaxDistance + folga)

    local model = (pot.hasSoil and potConfig.soilModel) or potConfig.model
    local modelHash = GetHashKey(model)
    local heightOffset = potConfig.heightOffset or 0

    DeleteEntity(entity)
    local newPot = CreateObjectNoOffset(modelHash, newCoords.x, newCoords.y, newCoords.z + heightOffset, true, true, false)
    SetEntityHeading(newPot, newRotation)
    FreezeEntityPosition(newPot, true)

    pot.coords = newCoords
    pot.rot = newRotation
    pot.entity = newPot
    pots[newPot] = pot
    pots[entity] = nil

    MySQL.update('UPDATE drug_pots SET coords = (:coords), rotation = (:rotation) WHERE id = (:id)', {
        ['coords'] = json.encode(newCoords),
        ['rotation'] = newRotation,
        ['id'] = pot.id,
    })

    if MovePlantForPot then
        MovePlantForPot(pot.id, newCoords, potConfig)
    end

    ShowNotification(src, _U('NOTIFICATION__POT__MOVED'), 'success')
end)

RegisterNetEvent('it-drugs:server:takePot', function(args)
    local entity = args.entity
    local pot = pots[entity]

    if not pot then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - pot.coords) > 10 then return end
    if PlantExistsInPot and PlantExistsInPot(pot.id) then return end
    if pot.hasSoil then -- recolher o vaso só sem terra ("Remover Terra" antes)
        ShowNotification(source, _U('NOTIFICATION__POT__REMOVE__SOIL__FIRST'), 'error')
        return
    end

    it.giveItem(source, pot.item, 1)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        MySQL.query('DELETE from drug_pots WHERE id = :id', { ['id'] = pot.id })
        pots[entity] = nil
    end
end)

-- Callbacks
lib.callback.register('it-drugs:server:getPotData', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local pot = pots[entity]

    if not pot then return nil end

    return {
        id = pot.id,
        coords = pot.coords,
        item = pot.item,
        hasPlant = PlantExistsInPot and PlantExistsInPot(pot.id) or false,
        hasSoil = pot.hasSoil,
        needsFertilizer = pot.needsFertilizer or false,
        burnt = pot.burnt or false,
        entity = entity, -- handle do SERVER (só serve pra ecoar de volta em TriggerServerEvent, nunca usar em native local no client)
        netId = netId -- pra client resolver o handle LOCAL de verdade via NetworkGetEntityFromNetworkId quando precisar (ex.: cl_pots.lua:plantInPot)
    }
end)

if not Config.EnableLamps then return end
local lamps = {}

--- Method to setup all the grow lamps, fetched from the database
--- @return nil
local setupLamps = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_lamps')

    for k, v in pairs(result) do
        local lampConfig = Config.Lamps[v.item]
        if lampConfig then
            local modelHash = GetHashKey(lampConfig.model)
            local coords = json.decode(v.coords)
            local lamp = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, false)
            SetEntityHeading(lamp, v.rotation + .0)
            Wait(50)
            FreezeEntityPosition(lamp, true)
            lamps[lamp] = {
                id = v.id,
                coords = vector3(coords.x, coords.y, coords.z),
                item = v.item,
                rot = v.rotation + .0,
                entity = lamp
            }
        end
    end
end

--- Method to delete all cached grow lamps and their entities
--- @return nil
local destroyAllLamps = function()
    for k, v in pairs(lamps) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
            lamps[k] = nil
        end
    end
end

function GetLamps()
    return lamps
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setting up Grow Lamps') end
    setupLamps()
    RecalculatePlantsLight(lamps)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyAllLamps()
end)

RegisterNetEvent('it-drugs:server:createNewLamp', function(coords, item, rotation)
    local src = source
    local player = it.getPlayer(src)
    local lampConfig = Config.Lamps[item]

    if not player or not lampConfig then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.rayCastingDistance + 10 then return end

    if it.removeItem(src, item, 1) then
        local modelHash = GetHashKey(lampConfig.model)
        local lamp = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(lamp, rotation)
        FreezeEntityPosition(lamp, true)

        MySQL.insert('INSERT INTO `drug_lamps` (coords, item, rotation) VALUES (:coords, :item, :rotation)', {
            ['coords'] = json.encode(coords),
            ['item'] = item,
            ['rotation'] = rotation
        }, function(id)
            lamps[lamp] = {
                id = id,
                coords = coords,
                item = item,
                rot = rotation,
                entity = lamp
            }
            RecalculatePlantsLight(lamps)
        end)
    end
end)

RegisterNetEvent('it-drugs:server:takeLamp', function(args)
    local entity = args.entity
    if not lamps[entity] then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - lamps[entity].coords) > 10 then return end

    it.giveItem(source, lamps[entity].item, 1)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        MySQL.query('DELETE from drug_lamps WHERE id = :id', {
            ['id'] = lamps[entity].id
        })
        lamps[entity] = nil
        RecalculatePlantsLight(lamps)
    end
end)

-- Callbacks
lib.callback.register('it-drugs:server:getLampData', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not lamps[entity] then return nil end
    return {
        id = lamps[entity].id,
        coords = lamps[entity].coords,
        item = lamps[entity].item,
        entity = entity
    }
end)

lib.callback.register('it-drugs:server:getLamps', function(source)
    return lamps
end)

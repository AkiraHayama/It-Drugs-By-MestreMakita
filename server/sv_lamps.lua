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
                entity = lamp,
                generatorId = v.generatorId,
                isOn = v.isOn == nil or v.isOn == true or tonumber(v.isOn) == 1,
            }
            SetLampState(lamps[lamp])
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

--- Liga/desliga visível pra todo mundo (texto em cima da lâmpada, opção do E): statebag lampOn da entidade
function SetLampState(lamp)
    if Entity and DoesEntityExist(lamp.entity) then Entity(lamp.entity).state:set('lampOn', lamp.isOn ~= false, true) end
end

-- Energia (sv_generators.lua): lâmpada só ilumina ligada (isOn) e por extensão num gerador ligado e com gasolina.
-- Sem o sistema de gerador (Config.EnableGenerators = false), toda lâmpada ilumina.
function GetPoweredLamps()
    local list = {}
    for entity, lamp in pairs(lamps) do
        if lamp.isOn ~= false and (not IsDevicePowered or IsDevicePowered(lamp.generatorId)) then list[entity] = lamp end
    end
    return list
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setting up Grow Lamps') end
    setupLamps()
    RecalculatePlantsLight(GetPoweredLamps())
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
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco (Config.PlaceMaxDistance + folga)

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
                entity = lamp,
                isOn = true,
            }
            SetLampState(lamps[lamp])
            RecalculatePlantsLight(GetPoweredLamps())
        end)
    end
end)

RegisterNetEvent('it-drugs:server:takeLamp', function(args)
    local entity = args.entity
    if not lamps[entity] then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - lamps[entity].coords) > 10 then return end

    if BeforeDeviceChange then BeforeDeviceChange(lamps[entity].generatorId) end -- fecha a gasolina gasta até agora
    it.giveItem(source, lamps[entity].item, 1)
    if lamps[entity].generatorId then it.giveItem(source, Config.ExtensionItem, 1) end -- devolve a extensão que estava ligada

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        MySQL.query('DELETE from drug_lamps WHERE id = :id', {
            ['id'] = lamps[entity].id
        })
        lamps[entity] = nil
        RecalculatePlantsLight(GetPoweredLamps())
        if SyncGenerators then SyncGenerators() end
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

-- Liga/desliga a lâmpada (E). Desligada: não ilumina e não gasta a gasolina do gerador.
RegisterNetEvent('it-drugs:server:toggleLamp', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local lamp = lamps[entity]
    if not lamp then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - lamp.coords) > 10 then return end
    if BeforeDeviceChange then BeforeDeviceChange(lamp.generatorId) end -- fecha a gasolina gasta até agora
    lamp.isOn = lamp.isOn == false
    MySQL.update('UPDATE drug_lamps SET isOn = ? WHERE id = ?', { lamp.isOn and 1 or 0, lamp.id })
    SetLampState(lamp)
    RecalculatePlantsLight(GetPoweredLamps())
    if SyncGenerators then SyncGenerators() end
    ShowNotification(src, _U(lamp.isOn and 'NOTIFICATION__LAMP__ON' or 'NOTIFICATION__LAMP__OFF'), 'success')
end)

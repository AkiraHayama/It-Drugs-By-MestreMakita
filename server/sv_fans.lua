if not Config.EnableFans then return end
local fans = {}

-- Energia (sv_generators.lua): ventilador só funciona ligado por extensão num gerador com gasolina.
-- Sem o sistema de gerador (Config.EnableGenerators = false), todo ventilador tem energia.
local powered = function(fan)
    return not IsDevicePowered or IsDevicePowered(fan.generatorId)
end

-- Lista que os clients usam pro ALT (Ligar/Desligar), o texto de ligado/desligado, o som e a extensão (cl_fans.lua, cl_generators.lua)
local getFanList = function()
    local list = {}
    for entity, fan in pairs(fans) do
        list[#list + 1] = {
            coords = fan.coords, isOn = fan.isOn, item = fan.item, powered = powered(fan),
            netId = NetworkGetNetworkIdFromEntity(entity), generatorId = fan.generatorId,
        }
    end
    return list
end

--- @param clickCoords vector3? - ventilador que acabou de ligar/desligar (toca o clique pra quem está perto)
local syncFans = function(clickCoords)
    TriggerClientEvent('it-drugs:client:syncFans', -1, getFanList(), clickCoords)
end

-- usados pelo sv_generators.lua (conectar extensão, gasolina acabou, abasteceu)
SyncFans = syncFans
function GetFans()
    return fans
end

--- Method to setup all the fans, fetched from the database (mesmo esquema de sv_lamps.lua)
--- @return nil
local setupFans = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_fans')

    for k, v in pairs(result) do
        local fanConfig = Config.Fans[v.item]
        if fanConfig then
            local coords = json.decode(v.coords)
            local fan = CreateObjectNoOffset(GetHashKey(fanConfig.model), coords.x, coords.y, coords.z, true, true, false)
            SetEntityHeading(fan, v.rotation + .0)
            Wait(50)
            FreezeEntityPosition(fan, true)
            fans[fan] = {
                id = v.id,
                coords = vector3(coords.x, coords.y, coords.z),
                item = v.item,
                rot = v.rotation + .0,
                entity = fan,
                isOn = v.isOn == 1 or v.isOn == true,
                generatorId = v.generatorId,
            }
        end
    end
    syncFans()
end

local destroyAllFans = function()
    for k, v in pairs(fans) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
            fans[k] = nil
        end
    end
end

--- Tem ventilador LIGADO e COM ENERGIA a até Config.Fans[x].range dessas coords? Usado pela rede pra decidir se cura
--- @param coords vector3
--- @return boolean
function IsFanOnNear(coords)
    for _, fan in pairs(fans) do
        if fan.isOn and powered(fan) and #(fan.coords - coords) <= Config.Fans[fan.item].range then return true end
    end
    return false
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    setupFans()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyAllFans()
end)

RegisterNetEvent('it-drugs:server:createNewFan', function(coords, item, rotation)
    local src = source
    local player = it.getPlayer(src)
    local fanConfig = Config.Fans[item]

    if not player or not fanConfig then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco (Config.PlaceMaxDistance + folga)

    if it.removeItem(src, item, 1) then
        local fan = CreateObjectNoOffset(GetHashKey(fanConfig.model), coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(fan, rotation)
        FreezeEntityPosition(fan, true)

        MySQL.insert('INSERT INTO `drug_fans` (coords, item, rotation) VALUES (:coords, :item, :rotation)', {
            ['coords'] = json.encode(coords),
            ['item'] = item,
            ['rotation'] = rotation
        }, function(id)
            fans[fan] = {
                id = id,
                coords = coords,
                item = item,
                rot = rotation,
                entity = fan,
                isOn = false,
            }
            syncFans()
        end)
    end
end)

-- Antes de mudar algo que mexe na cura/gasolina: fecha o progresso das redes curando e a gasolina gasta até agora
local beforeChange = function(fan)
    if BeforeDeviceChange then BeforeDeviceChange(fan.generatorId)
    elseif UpdateCuringRacks then UpdateCuringRacks() end
end

RegisterNetEvent('it-drugs:server:toggleFan', function(args)
    local src = source
    local fan = fans[args.entity]
    if not fan then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - fan.coords) > 10 then return end
    if not fan.isOn and not powered(fan) then -- sem extensão num gerador com gasolina, não liga
        ShowNotification(src, _U('NOTIFICATION__FAN__NO__POWER'), 'error')
        return
    end

    beforeChange(fan)
    fan.isOn = not fan.isOn
    syncFans(fan.coords)
    if SyncGenerators then SyncGenerators() end -- ligado/desligado muda o gasto do gerador
    if RefreshCuringRacks then RefreshCuringRacks() end -- rede secando em lugar fechado perto vira cura
    MySQL.update('UPDATE drug_fans SET isOn = (:isOn) WHERE id = (:id)', {
        ['isOn'] = fan.isOn and 1 or 0,
        ['id'] = fan.id,
    })
    ShowNotification(src, _U(fan.isOn and 'NOTIFICATION__FAN__ON' or 'NOTIFICATION__FAN__OFF'), 'success')
end)

RegisterNetEvent('it-drugs:server:takeFan', function(args)
    local entity = args.entity
    local fan = fans[entity]
    if not fan then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - fan.coords) > 10 then return end

    beforeChange(fan)
    it.giveItem(source, fan.item, 1)
    if fan.generatorId then it.giveItem(source, Config.ExtensionItem, 1) end -- devolve a extensão que estava ligada

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        MySQL.query('DELETE from drug_fans WHERE id = :id', {
            ['id'] = fan.id
        })
        fans[entity] = nil
        syncFans()
        if SyncGenerators then SyncGenerators() end
    end
end)

-- Callbacks
lib.callback.register('it-drugs:server:getFans', function(source)
    return getFanList()
end)

lib.callback.register('it-drugs:server:getFanData', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not fans[entity] then return nil end
    return {
        id = fans[entity].id,
        coords = fans[entity].coords,
        item = fans[entity].item,
        isOn = fans[entity].isOn,
        entity = entity
    }
end)

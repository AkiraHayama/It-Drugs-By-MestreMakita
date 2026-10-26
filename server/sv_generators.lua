if not Config.EnableGenerators then return end
local generators = {} -- entity -> { id, coords, item, rot, entity, fuel, fuelTick }

local FUEL_TICK = 60 -- segundos: confere se algum gerador secou e atualiza o combustível dos clients

local getGeneratorById = function(id)
    for _, gen in pairs(generators) do
        if gen.id == id then return gen end
    end
end

-- Aparelho (ventilador ou lâmpada) dessa entidade: tipo, dados e tabela do banco
local findDevice = function(entity)
    local fans, lamps = GetFans and GetFans() or {}, GetLamps and GetLamps() or {}
    if fans[entity] then return fans[entity], 'drug_fans' end
    if lamps[entity] then return lamps[entity], 'drug_lamps' end
end

--- Aparelhos ligados por extensão nesse gerador: todos, e só os funcionando (gastam gasolina)
local countDevices = function(id)
    local connected, active = 0, 0
    for _, fan in pairs(GetFans and GetFans() or {}) do
        if fan.generatorId == id then
            connected = connected + 1
            if fan.isOn then active = active + 1 end
        end
    end
    for _, lamp in pairs(GetLamps and GetLamps() or {}) do
        if lamp.generatorId == id then
            connected = connected + 1
            if lamp.isOn ~= false then active = active + 1 end -- lâmpada desligada não gasta
        end
    end
    return connected, active
end

local fuelRate = function(gen) -- litros por segundo agora (desligado não gasta)
    if not gen.isOn then return 0 end
    local _, active = countDevices(gen.id)
    return Config.Generators[gen.item].litersPerHour * active / 3600
end

-- Desconta a gasolina gasta desde o último registro, no gasto de agora
local advanceFuel = function(gen)
    local now = os.time()
    gen.fuel = math.max(0, gen.fuel - math.max(0, now - gen.fuelTick) * fuelRate(gen)) -- relógio voltando não "devolve" gasolina
    gen.fuelTick = now
end

local saveFuel = function(gen)
    MySQL.update('UPDATE drug_generators SET fuel = (:fuel), fuelTick = (:tick) WHERE id = (:id)', { ['fuel'] = gen.fuel, ['tick'] = gen.fuelTick, ['id'] = gen.id })
end

--- Aparelho ligado nesse gerador tem energia? (gerador existe, está ligado e tem gasolina)
--- @param generatorId number?
function IsDevicePowered(generatorId)
    local gen = generatorId and getGeneratorById(generatorId)
    return gen ~= nil and gen.isOn and gen.fuel > 0
end

--- Antes de qualquer mudança que mexe em energia/gasto: fecha a cura das redes e a gasolina gasta até agora
--- @param generatorId number?
function BeforeDeviceChange(generatorId)
    if UpdateCuringRacks then UpdateCuringRacks() end
    local gen = generatorId and getGeneratorById(generatorId)
    if gen then
        advanceFuel(gen)
        saveFuel(gen)
    end
end

local getList = function()
    local list, connections = {}, {}
    for entity, gen in pairs(generators) do
        local connected, active = countDevices(gen.id)
        list[#list + 1] = {
            id = gen.id, netId = NetworkGetNetworkIdFromEntity(entity), coords = gen.coords, item = gen.item,
            fuel = gen.fuel, tank = Config.Generators[gen.item].tank, connected = connected, active = active, isOn = gen.isOn,
            maxDevices = Config.Generators[gen.item].maxDevices,
        }
    end
    for _, devices in ipairs({ GetFans and GetFans() or {}, GetLamps and GetLamps() or {} }) do
        for entity, device in pairs(devices) do
            local gen = device.generatorId and getGeneratorById(device.generatorId)
            if gen then
                connections[#connections + 1] = { genNetId = NetworkGetNetworkIdFromEntity(gen.entity), devNetId = NetworkGetNetworkIdFromEntity(entity) }
            end
        end
    end
    return { generators = list, connections = connections }
end

-- Pros clients: combustível em cima do gerador, cabos das extensões, "Desconectar extensão" (cl_generators.lua)
function SyncGenerators()
    TriggerClientEvent('it-drugs:client:syncGenerators', -1, getList())
end

-- Energia mudou: luz das plantas, ventiladores (som/texto/cura) e geradores
local afterPowerChange = function()
    if RecalculatePlantsLight and GetPoweredLamps then RecalculatePlantsLight(GetPoweredLamps()) end
    if SyncFans then SyncFans() end
    SyncGenerators()
    if RefreshCuringRacks then RefreshCuringRacks() end -- rede secando em lugar fechado que ganhou energia vira cura
end

local setupGenerators = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_generators')
    local now = os.time()
    for _, v in pairs(result) do
        local genConfig = Config.Generators[v.item]
        if genConfig then
            local coords = json.decode(v.coords)
            local gen = CreateObjectNoOffset(GetHashKey(genConfig.model), coords.x, coords.y, coords.z, true, true, false)
            SetEntityHeading(gen, v.rotation + .0)
            Wait(50)
            FreezeEntityPosition(gen, true)
            generators[gen] = {
                id = v.id, coords = vector3(coords.x, coords.y, coords.z), item = v.item, rot = v.rotation + .0,
                entity = gen, fuel = v.fuel or 0.0, fuelTick = v.fuelTick or now,
                isOn = v.isOn == nil or v.isOn == true or tonumber(v.isOn) == 1, -- os de antes do botão ficam ligados
            }
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    while not DatabaseSetuped do Wait(100) end
    setupGenerators()
    Wait(2000) -- ventiladores e lâmpadas sobem junto; espera eles pra recalcular a energia
    afterPowerChange()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for entity, gen in pairs(generators) do
        advanceFuel(gen)
        saveFuel(gen)
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    generators = {}
end)

-- Gasolina acabando: confere 1x por minuto e corta a energia de quem secou
CreateThread(function()
    while true do
        Wait(FUEL_TICK * 1000)
        local now, ranOut = os.time(), false
        for _, gen in pairs(generators) do
            if gen.fuel > 0 and gen.fuel - (now - gen.fuelTick) * fuelRate(gen) <= 0 then ranOut = true end
        end
        if ranOut and UpdateCuringRacks then UpdateCuringRacks() end -- fecha a cura rápida antes de cortar a energia
        for _, gen in pairs(generators) do
            advanceFuel(gen)
            saveFuel(gen)
        end
        if ranOut then afterPowerChange() else SyncGenerators() end
    end
end)

RegisterNetEvent('it-drugs:server:createNewGenerator', function(coords, item, rotation)
    local src = source
    local genConfig = Config.Generators[item]
    if not it.getPlayer(src) or not genConfig then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco

    if it.removeItem(src, item, 1) then
        local gen = CreateObjectNoOffset(GetHashKey(genConfig.model), coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(gen, rotation)
        FreezeEntityPosition(gen, true)
        local now = os.time()
        MySQL.insert('INSERT INTO `drug_generators` (coords, item, rotation, fuel, fuelTick, isOn) VALUES (:coords, :item, :rotation, 0, :tick, 0)', {
            ['coords'] = json.encode(coords), ['item'] = item, ['rotation'] = rotation, ['tick'] = now,
        }, function(id)
            generators[gen] = { id = id, coords = coords, item = item, rot = rotation, entity = gen, fuel = 0.0, fuelTick = now, isOn = false }
            SyncGenerators()
        end)
    end
end)

RegisterNetEvent('it-drugs:server:takeGenerator', function(args)
    local src = source
    local gen = generators[args.entity]
    if not gen then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - gen.coords) > 10 then return end
    if countDevices(gen.id) > 0 then
        ShowNotification(src, _U('NOTIFICATION__GENERATOR__HAS__DEVICES'), 'error')
        return
    end

    it.giveItem(src, gen.item, 1) -- shortcut: a gasolina que sobrou no tanque se perde ao recolher; guardar no metadata do item se reclamarem
    if DoesEntityExist(args.entity) then DeleteEntity(args.entity) end
    MySQL.query('DELETE from drug_generators WHERE id = :id', { ['id'] = gen.id })
    generators[args.entity] = nil
    SyncGenerators()
end)

-- Abastecer: despeja os litros do galão (metadata cdn_fuel do cdn-fuel) até encher o tanque
RegisterNetEvent('it-drugs:server:refuelGenerator', function(args)
    local src = source
    local gen = generators[args.entity]
    if not gen or it.inventory ~= 'ox' then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - gen.coords) > 10 then return end

    local best
    for _, slot in ipairs(exports.ox_inventory:Search(src, 'slots', Config.FuelItem) or {}) do
        local liters = tonumber(slot.metadata and slot.metadata.cdn_fuel) or 0
        if liters > 0 and (not best or liters > best.liters) then best = { slot = slot, liters = liters } end
    end
    if not best then
        ShowNotification(src, _U('NOTIFICATION__GENERATOR__NO__FUEL'), 'error')
        return
    end

    BeforeDeviceChange(gen.id)
    local space = Config.Generators[gen.item].tank - gen.fuel
    if space < 0.1 then
        ShowNotification(src, _U('NOTIFICATION__GENERATOR__FULL'), 'error')
        return
    end

    local liters = math.min(best.liters, space)
    local metadata = best.slot.metadata
    metadata.cdn_fuel = tostring(math.floor((best.liters - liters) * 10 + 0.5) / 10)
    exports.ox_inventory:SetMetadata(src, best.slot.slot, metadata)

    local wasEmpty = gen.fuel <= 0
    gen.fuel = gen.fuel + liters
    saveFuel(gen)
    if wasEmpty then afterPowerChange() else SyncGenerators() end
    ShowNotification(src, _U('NOTIFICATION__GENERATOR__REFUELED'):format(('%.1f'):format(liters)), 'success')
end)

-- Extensão: o client escolheu o gerador e o aparelho (cl_generators.lua); tudo é conferido de novo aqui
RegisterNetEvent('it-drugs:server:connectExtension', function(genNetId, devNetId)
    local src = source
    local genEntity, devEntity = NetworkGetEntityFromNetworkId(genNetId), NetworkGetEntityFromNetworkId(devNetId)
    local gen = generators[genEntity]
    local device, tableName = findDevice(devEntity)
    if not gen or not device then return end

    local genConfig = Config.Generators[gen.item]
    if #(GetEntityCoords(GetPlayerPed(src)) - device.coords) > 10 then return end
    if device.generatorId then
        ShowNotification(src, _U('NOTIFICATION__EXTENSION__ALREADY'), 'error')
        return
    end
    if #(gen.coords - device.coords) > genConfig.cableLength then
        ShowNotification(src, _U('NOTIFICATION__EXTENSION__TOO__FAR'):format(genConfig.cableLength), 'error')
        return
    end
    if countDevices(gen.id) >= genConfig.maxDevices then
        ShowNotification(src, _U('NOTIFICATION__GENERATOR__FULL__DEVICES'):format(genConfig.maxDevices), 'error')
        return
    end
    if not it.removeItem(src, Config.ExtensionItem, 1) then
        ShowNotification(src, _U('NOTIFICATION__EXTENSION__MISSING'), 'error')
        return
    end

    BeforeDeviceChange(gen.id)
    device.generatorId = gen.id
    MySQL.update(('UPDATE %s SET generatorId = (:gen) WHERE id = (:id)'):format(tableName), { ['gen'] = gen.id, ['id'] = device.id })
    afterPowerChange()
    ShowNotification(src, _U('NOTIFICATION__EXTENSION__CONNECTED'), 'success')
end)

RegisterNetEvent('it-drugs:server:disconnectExtension', function(devNetId)
    local src = source
    local device, tableName = findDevice(NetworkGetEntityFromNetworkId(devNetId))
    if not device or not device.generatorId then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - device.coords) > 10 then return end

    BeforeDeviceChange(device.generatorId)
    device.generatorId = nil
    MySQL.update(('UPDATE %s SET generatorId = NULL WHERE id = (:id)'):format(tableName), { ['id'] = device.id })
    it.giveItem(src, Config.ExtensionItem, 1)
    afterPowerChange()
    ShowNotification(src, _U('NOTIFICATION__EXTENSION__DISCONNECTED'), 'success')
end)

-- Callbacks
lib.callback.register('it-drugs:server:getGenerators', function()
    return getList()
end)

lib.callback.register('it-drugs:server:getGeneratorData', function(_, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local gen = generators[entity]
    if not gen then return nil end
    advanceFuel(gen)
    local connected, active = countDevices(gen.id)
    local genConfig = Config.Generators[gen.item]
    return {
        entity = entity, item = gen.item, fuel = gen.fuel, tank = genConfig.tank,
        connected = connected, active = active, maxDevices = genConfig.maxDevices,
    }
end)

-- Liga/desliga (E do gerador). Desligado: sem energia pros aparelhos e sem gastar gasolina.
RegisterNetEvent('it-drugs:server:toggleGenerator', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local gen = generators[entity]
    if not gen then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - gen.coords) > 10 then return end
    BeforeDeviceChange(gen.id) -- fecha a gasolina gasta e a cura das redes até agora
    gen.isOn = not gen.isOn
    MySQL.update('UPDATE drug_generators SET isOn = ? WHERE id = ?', { gen.isOn and 1 or 0, gen.id })
    afterPowerChange()
    if gen.isOn and gen.fuel <= 0 then
        ShowNotification(src, _U('NOTIFICATION__GENERATOR__ON__NO__FUEL'), 'error')
    else
        ShowNotification(src, _U(gen.isOn and 'NOTIFICATION__GENERATOR__ON' or 'NOTIFICATION__GENERATOR__OFF'), 'success')
    end
end)

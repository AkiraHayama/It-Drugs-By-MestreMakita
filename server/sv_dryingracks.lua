if not Config.EnableDryingRacks then return end
local racks = {}

--- Method to setup all the drying racks, fetched from the database
--- @return nil
local setupRacks = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_dryingracks')

    for k, v in pairs(result) do
        local rackConfig = Config.DryingRacks[v.item]
        if rackConfig then
            local modelHash = GetHashKey(rackConfig.model)
            local coords = json.decode(v.coords)
            local heightOffset = rackConfig.heightOffset or 0
            local rack = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z + heightOffset, true, true, false)
            SetEntityHeading(rack, v.rotation + .0)
            Wait(50)
            FreezeEntityPosition(rack, true)
            racks[rack] = {
                id = v.id,
                coords = vector3(coords.x, coords.y, coords.z),
                item = v.item,
                rot = v.rotation + .0,
                entity = rack,
                dryingItem = v.dryingItem,
                dryingAmount = v.dryingAmount,
                startedAt = v.startedAt,
                dryingPurity = v.dryingPurity,
                curing = v.curing == 1 or v.curing == true,
                cureProgress = v.cureProgress or 0,
                cureTick = v.cureTick or v.startedAt,
                indoor = v.indoor == 1 or v.indoor == true or nil,
            }
        end
    end
end

--- Method to delete all cached drying racks and their entities
--- @return nil
local destroyAllRacks = function()
    for k, v in pairs(racks) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
            racks[k] = nil
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setting up Drying Racks') end
    setupRacks()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyAllRacks()
end)

RegisterNetEvent('it-drugs:server:createNewDryingRack', function(coords, item, rotation)
    local src = source
    local player = it.getPlayer(src)
    local rackConfig = Config.DryingRacks[item]

    if not player or not rackConfig then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco (Config.PlaceMaxDistance + folga)

    if it.removeItem(src, item, 1) then
        local modelHash = GetHashKey(rackConfig.model)
        local heightOffset = rackConfig.heightOffset or 0
        local rack = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z + heightOffset, true, true, false)
        SetEntityHeading(rack, rotation)
        FreezeEntityPosition(rack, true)

        MySQL.insert('INSERT INTO `drug_dryingracks` (coords, item, rotation) VALUES (:coords, :item, :rotation)', {
            ['coords'] = json.encode(coords),
            ['item'] = item,
            ['rotation'] = rotation
        }, function(id)
            racks[rack] = {
                id = id,
                coords = coords,
                item = item,
                rot = rotation,
                entity = rack,
                dryingItem = nil,
                dryingAmount = 0,
                startedAt = nil,
            }
        end)
    end
end)

RegisterNetEvent('it-drugs:server:takeDryingRack', function(args)
    local entity = args.entity
    local rack = racks[entity]

    if not rack then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - rack.coords) > 10 then return end
    if rack.dryingItem then
        ShowNotification(source, _U('NOTIFICATION__DRYINGRACK__IN__USE'), 'error')
        return
    end

    it.giveItem(source, rack.item, 1)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        MySQL.query('DELETE from drug_dryingracks WHERE id = :id', { ['id'] = rack.id })
        racks[entity] = nil
    end
end)

-- Cura (Config.DryingRacks[x].cures): rede em lugar fechado (o client manda `indoor`, servidor não
-- tem raycast - mesmo esquema do sol das plantas) com ventilador ligado perto (sv_fans.lua)
local canCure = function(rack, rackConfig, rawItem, indoor)
    return indoor == true and rackConfig.cures ~= nil and rackConfig.cures[rawItem] ~= nil
        and IsFanOnNear ~= nil and IsFanOnNear(rack.coords)
end

-- Velocidade da cura agora: 1 com ventilador ligado perto, cureSlowRate (mais lento) sem
local cureRate = function(rack)
    return (IsFanOnNear and IsFanOnNear(rack.coords)) and 1.0 or Config.DryingRacks[rack.item].cureSlowRate
end

-- Soma o progresso da cura (segundos "de ventilador ligado") desde o último registro, na velocidade atual
local advanceCure = function(rack)
    local now = os.time()
    rack.cureProgress = (rack.cureProgress or 0) + (now - (rack.cureTick or now)) * cureRate(rack)
    rack.cureTick = now
    MySQL.update('UPDATE drug_dryingracks SET cureProgress = (:p), cureTick = (:t) WHERE id = (:id)', { ['p'] = rack.cureProgress, ['t'] = now, ['id'] = rack.id })
end

--- Chamado pelo sv_fans.lua ANTES de um ventilador ligar/desligar/sumir: fecha o progresso de cada
--- rede curando na velocidade que valia até agora
function UpdateCuringRacks()
    for _, rack in pairs(racks) do
        if rack.dryingItem and rack.curing then advanceCure(rack) end
    end
end

--- Segundos que faltam (na velocidade de agora) e se já terminou
local rackTimeLeft = function(rack, rackConfig)
    local total = rackConfig.duration * 60
    if not rack.curing then
        local left = math.max(0, total - (os.time() - rack.startedAt))
        return left, left <= 0
    end
    advanceCure(rack)
    local left = math.max(0, total - rack.cureProgress)
    return left / cureRate(rack), left <= 0
end

RegisterNetEvent('it-drugs:server:startDrying', function(args)
    local src = source
    local entity = args.entity
    local rack = racks[entity]
    local rackConfig = rack and Config.DryingRacks[rack.item]

    if not rack or not rackConfig then return end
    if rack.dryingItem then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - rack.coords) > 10 then return end

    local rawItem = args.rawItem
    local driedItem = rackConfig.dries[rawItem]
    if not driedItem then return end

    local amount = math.min(math.floor(tonumber(args.amount) or 0), rackConfig.capacity)
    if amount < 1 then return end

    -- Pureza média da erva pendurada (Config.Purity) - a seca sai com ela
    local purity = it.takeItemWithPurity(src, rawItem, amount)
    if not purity then
        ShowNotification(src, _U('NOTIFICATION__NO__ITEMS'), 'error')
        return
    end

    local startedAt = os.time()
    rack.dryingItem = rawItem
    rack.dryingAmount = amount
    rack.startedAt = startedAt
    rack.dryingPurity = purity
    rack.curing = canCure(rack, rackConfig, rawItem, args.indoor)
    rack.cureProgress = 0
    rack.cureTick = startedAt
    rack.indoor = args.indoor == true

    MySQL.update('UPDATE drug_dryingracks SET dryingItem = (:dryingItem), dryingAmount = (:dryingAmount), startedAt = (:startedAt), dryingPurity = (:dryingPurity), curing = (:curing), cureProgress = 0, cureTick = (:startedAt), indoor = (:indoor) WHERE id = (:id)', {
        ['dryingItem'] = rawItem,
        ['dryingAmount'] = amount,
        ['startedAt'] = startedAt,
        ['dryingPurity'] = purity,
        ['curing'] = rack.curing and 1 or 0,
        ['indoor'] = rack.indoor and 1 or 0,
        ['id'] = rack.id
    })

    ShowNotification(src, _U(rack.curing and 'NOTIFICATION__DRYINGRACK__CURING' or 'NOTIFICATION__DRYINGRACK__STARTED'), 'success')
    TriggerClientEvent('it-drugs:client:syncDryingRackBuds', -1)
end)

RegisterNetEvent('it-drugs:server:collectDrying', function(args)
    local src = source
    local entity = args.entity
    local rack = racks[entity]
    local rackConfig = rack and Config.DryingRacks[rack.item]

    if not rack or not rackConfig then return end
    if not rack.dryingItem then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - rack.coords) > 10 then return end

    local _, ready = rackTimeLeft(rack, rackConfig)
    if not ready then
        ShowNotification(src, _U('NOTIFICATION__DRYINGRACK__NOT__READY'), 'error')
        return
    end

    -- Começou curando (fechado + ventilador ligado) = sai curada; ventilador desligado no meio só deixou mais lento
    local cured = rack.curing
    local outItem = cured and rackConfig.cures[rack.dryingItem] or rackConfig.dries[rack.dryingItem]
    it.giveItem(src, outItem, rack.dryingAmount, { purity = it.roundPurity(rack.dryingPurity or Config.Purity.default) })

    local notification = cured and 'NOTIFICATION__DRYINGRACK__CURED' or 'NOTIFICATION__DRYINGRACK__COLLECTED'

    rack.dryingItem = nil
    rack.dryingAmount = 0
    rack.startedAt = nil
    rack.dryingPurity = nil
    rack.curing = false

    MySQL.update('UPDATE drug_dryingracks SET dryingItem = NULL, dryingAmount = 0, startedAt = NULL, dryingPurity = NULL, curing = 0 WHERE id = (:id)', {
        ['id'] = rack.id
    })

    ShowNotification(src, _U(notification), cured and 'success' or 'inform')
    TriggerClientEvent('it-drugs:client:syncDryingRackBuds', -1)
end)

-- Callbacks
-- Estado de todas as redes pros clients: buds nas bandejas, opções do E (pendurar/recolher) e o texto
-- de status em cima da rede (cl_dryingracks.lua). left = segundos que faltam na velocidade de agora.
lib.callback.register('it-drugs:server:getDryingRackBuds', function(source)
    local list = {}
    for entity, rack in pairs(racks) do
        if DoesEntityExist(entity) then
            local state = { netId = NetworkGetNetworkIdFromEntity(entity), item = rack.item, amount = rack.dryingAmount or 0, dryingItem = rack.dryingItem }
            if rack.dryingItem then
                local rackConfig = Config.DryingRacks[rack.item]
                state.left, state.ready = rackTimeLeft(rack, rackConfig)
                state.curing = rack.curing or false
                state.slow = rack.curing and cureRate(rack) < 1.0 or false
            end
            list[#list + 1] = state
        end
    end
    return list
end)

-- Client conferiu "tem teto?" chegando perto da rede: grava e vê se dá pra virar cura
RegisterNetEvent('it-drugs:server:rackIndoor', function(netId, indoor)
    local rack = racks[NetworkGetEntityFromNetworkId(netId)]
    if not rack or #(GetEntityCoords(GetPlayerPed(source)) - rack.coords) > 15 then return end
    if rack.indoor == (indoor == true) then return end
    rack.indoor = indoor == true
    MySQL.update('UPDATE drug_dryingracks SET indoor = (:indoor) WHERE id = (:id)', { ['indoor'] = rack.indoor and 1 or 0, ['id'] = rack.id })
    if RefreshCuringRacks then RefreshCuringRacks() end
end)

-- Rede SECANDO em lugar fechado que ganha ventilador ligado com energia depois de pendurar: vira cura.
-- O tempo que já passou conta como cura lenta (igual ventilador desligado: cureSlowRate).
local tryStartCuring = function(rack)
    local rackConfig = Config.DryingRacks[rack.item]
    if not rack.dryingItem or rack.curing or not rack.indoor then return end
    if not (rackConfig.cures and rackConfig.cures[rack.dryingItem]) or not (IsFanOnNear and IsFanOnNear(rack.coords)) then return end
    local now = os.time()
    rack.curing = true
    rack.cureProgress = math.max(0, now - rack.startedAt) * rackConfig.cureSlowRate
    rack.cureTick = now
    MySQL.update('UPDATE drug_dryingracks SET curing = 1, cureProgress = (:p), cureTick = (:t) WHERE id = (:id)', { ['p'] = rack.cureProgress, ['t'] = now, ['id'] = rack.id })
end

--- Chamado depois de ligar ventilador / mudar energia (sv_fans.lua, sv_generators.lua)
function RefreshCuringRacks()
    for _, rack in pairs(racks) do tryStartCuring(rack) end
    TriggerClientEvent('it-drugs:client:syncDryingRackBuds', -1) -- status (curando/lento) muda com a energia
end

--- @param indoor boolean? - o client confere "tem teto?" ao abrir o menu (vale pra rede pendurada antes de existir essa regra)
lib.callback.register('it-drugs:server:getDryingRackData', function(source, netId, indoor)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local rack = racks[entity]

    if not rack then return nil end

    if indoor ~= nil and rack.indoor ~= (indoor == true) then
        rack.indoor = indoor == true
        MySQL.update('UPDATE drug_dryingracks SET indoor = (:indoor) WHERE id = (:id)', { ['indoor'] = rack.indoor and 1 or 0, ['id'] = rack.id })
    end
    tryStartCuring(rack)

    local rackConfig = Config.DryingRacks[rack.item]
    local remaining = 0
    local ready = false

    if rack.dryingItem then
        remaining, ready = rackTimeLeft(rack, rackConfig)
    end

    return {
        id = rack.id,
        coords = rack.coords,
        item = rack.item,
        entity = entity,
        dryingItem = rack.dryingItem,
        dryingAmount = rack.dryingAmount,
        remaining = remaining,
        ready = ready,
        curing = rack.curing or false,
        slow = rack.curing and rack.dryingItem ~= nil and cureRate(rack) < 1.0, -- curando sem ventilador ligado
    }
end)

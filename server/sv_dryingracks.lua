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
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.rayCastingDistance + 10 then return end

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

    if not it.removeItem(src, rawItem, amount) then
        ShowNotification(src, _U('NOTIFICATION__NO__ITEMS'), 'error')
        return
    end

    local startedAt = os.time()
    rack.dryingItem = rawItem
    rack.dryingAmount = amount
    rack.startedAt = startedAt

    MySQL.update('UPDATE drug_dryingracks SET dryingItem = (:dryingItem), dryingAmount = (:dryingAmount), startedAt = (:startedAt) WHERE id = (:id)', {
        ['dryingItem'] = rawItem,
        ['dryingAmount'] = amount,
        ['startedAt'] = startedAt,
        ['id'] = rack.id
    })

    ShowNotification(src, _U('NOTIFICATION__DRYINGRACK__STARTED'), 'success')
end)

RegisterNetEvent('it-drugs:server:collectDrying', function(args)
    local src = source
    local entity = args.entity
    local rack = racks[entity]
    local rackConfig = rack and Config.DryingRacks[rack.item]

    if not rack or not rackConfig then return end
    if not rack.dryingItem then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - rack.coords) > 10 then return end

    local elapsed = os.time() - rack.startedAt
    if elapsed < (rackConfig.duration * 60) then
        ShowNotification(src, _U('NOTIFICATION__DRYINGRACK__NOT__READY'), 'error')
        return
    end

    local driedItem = rackConfig.dries[rack.dryingItem]
    it.giveItem(src, driedItem, rack.dryingAmount)

    rack.dryingItem = nil
    rack.dryingAmount = 0
    rack.startedAt = nil

    MySQL.update('UPDATE drug_dryingracks SET dryingItem = NULL, dryingAmount = 0, startedAt = NULL WHERE id = (:id)', {
        ['id'] = rack.id
    })

    ShowNotification(src, _U('NOTIFICATION__DRYINGRACK__COLLECTED'), 'success')
end)

-- Callbacks
lib.callback.register('it-drugs:server:getDryingRackData', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local rack = racks[entity]

    if not rack then return nil end

    local rackConfig = Config.DryingRacks[rack.item]
    local remaining = 0
    local ready = false

    if rack.dryingItem then
        local elapsed = os.time() - rack.startedAt
        local totalSeconds = rackConfig.duration * 60
        remaining = math.max(0, totalSeconds - elapsed)
        ready = remaining <= 0
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
    }
end)

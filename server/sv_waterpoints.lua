if not Config.EnableWaterPoints then return end
local waterpoints = {}

--- Method to load all water points from the database into memory
--- @return nil
local setupWaterPoints = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_waterpoints')

    for k, v in pairs(result) do
        local coords = json.decode(v.coords)
        waterpoints[v.id] = {
            id = v.id,
            coords = vector3(coords.x, coords.y, coords.z),
            label = v.label,
        }
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setting up Water Points') end
    setupWaterPoints()
end)

RegisterNetEvent('it-drugs:server:createWaterPoint', function(coords, label)
    local src = source
    if not IsPlayerAceAllowed(src, 'admin') then return end

    MySQL.insert('INSERT INTO `drug_waterpoints` (coords, label) VALUES (:coords, :label)', {
        ['coords'] = json.encode(coords),
        ['label'] = label,
    }, function(id)
        local point = { id = id, coords = coords, label = label }
        waterpoints[id] = point
        TriggerClientEvent('it-drugs:client:addWaterPointZone', -1, point)
        ShowNotification(src, _U('NOTIFICATION__WATERPOINT__CREATED'), 'success')
    end)
end)

RegisterNetEvent('it-drugs:server:removeWaterPoint', function(id)
    local src = source
    if not IsPlayerAceAllowed(src, 'admin') then return end
    if not waterpoints[id] then return end

    waterpoints[id] = nil
    MySQL.query('DELETE from drug_waterpoints WHERE id = :id', { ['id'] = id })
    TriggerClientEvent('it-drugs:client:removeWaterPointZone', -1, id)
    ShowNotification(src, _U('NOTIFICATION__WATERPOINT__REMOVED'), 'success')
end)

RegisterNetEvent('it-drugs:server:refillWateringCan', function(id)
    local src = source
    local point = waterpoints[id]
    if not point then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - point.coords) > Config.WaterPointRadius + 5 then return end

    if it.inventory ~= 'ox' then return end -- regador de cargas só suportado com ox_inventory (metadata)

    local slotData = exports.ox_inventory:GetSlotWithItem(src, 'watering_can')
    if not slotData then
        ShowNotification(src, _U('NOTIFICATION__NO__ITEMS'), 'error')
        return
    end

    local metadata = slotData.metadata or {}
    metadata.charges = Config.WateringCanMaxCharges
    metadata.durability = 100 -- barra visual no ícone do inventário (nativa do ox_inventory)
    exports.ox_inventory:SetMetadata(src, slotData.slot, metadata)
    ShowNotification(src, _U('NOTIFICATION__WATERPOINT__REFILLED'), 'success')
end)

-- Callbacks
lib.callback.register('it-drugs:server:getWaterPoints', function(source)
    return waterpoints
end)

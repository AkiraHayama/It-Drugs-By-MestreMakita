RegisterNetEvent('it-drugs:client:showAdminAlertBox', function(args)
    local userLicense = args.userLicense
    local username = args.username

    local alert = lib.alertDialog({
        header = _U('NOTIFICATION__NO__PERMS'),
        content = _U('NOTIFICATION__NO__PERMS_CONTENT'):format(userLicense, username),
        centered = true,
        size = 'xl',
        cancel = true,
        labels = {
            cancel = _U('ALERTBOX__CANCEL'),
            confirm = _U('ALERTBOX__CONFIRM')
        }
    })

    if alert == 'confirm' then
        -- copy content to clipboard
        lib.setClipboard('add_ace identifier.'..userLicense..' it-drugs allow #'..username..' License')
        ShowNotification(nil, _U('NOTIFICATION__COPY__CLIPBOARD'):format('User License'), "success")
    end
end)

RegisterNetEvent('it-drugs:client:addAllAdminBlips', function(args)
    local type = args.type

    if type == 'plants' then
        local allPlants = lib.callback.await('it-drugs:server:getPlants', false)
        for _, data in pairs(allPlants) do
            AddAdminBlip(data.id, data.coords, Config.Plants[data.type].label, 'plant')
        end
        ShowNotification(nil, _U('NOTIFICATION__ADD__BLIP'), "success")
    elseif type == 'tables' then
        local allTables = lib.callback.await('it-drugs:server:getTables', false)
        for _, data in pairs(allTables) do
            AddAdminBlip(data.id, data.coords, _U('BLIP__PROCESS_TABLE'):format(Config.ProcessingTables[data.type].type), 'processing')
        end
        ShowNotification(nil, _U('NOTIFICATION__ADD__BLIP'), "success")
    end
end)

RegisterNetEvent('it-drugs:client:addAdminBlip', function(args)
    local id = args.id
    local coords = args.coords
    local entityType = args.entityType
    local type = args.type

    if type == 'plant' then
        AddAdminBlip(id, coords, Config.Plants[entityType].label, 'plant')
        ShowNotification(nil, _U('NOTIFICATION__ADD__BLIP'), "success")
    elseif type == 'table' then
        AddAdminBlip(id, coords, _U('BLIP__PROCESS_TABLE'):format(Config.ProcessingTables[entityType].type), 'processing')
        ShowNotification(nil, _U('NOTIFICATION__ADD__BLIP'), "success")
    end
end)

RegisterNetEvent('it-drugs:client:removeAllAdminBlips', function(args)
    local type = args.type

    if type == 'plants' then
        local allPlants = lib.callback.await('it-drugs:server:getPlants', false)
        for _, data in pairs(allPlants) do
            RemoveAdminBlip(data.id)
            ShowNotification(nil, _U('NOTIFICATION__REMOVE__BLIP'), "success")
        end
    elseif type == 'tables' then
        local allTables = lib.callback.await('it-drugs:server:getTables', false)
        for _, data in pairs(allTables) do
            RemoveAdminBlip(data.id)
            ShowNotification(nil, _U('NOTIFICATION__REMOVE__BLIP'), "success")
        end
    end
end)

RegisterNetEvent('it-drugs:client:generatePlantListMenu', function()
    local currentCoords = GetEntityCoords(PlayerPedId())
    local allPlants = lib.callback.await('it-drugs:server:getPlants', false)

    -- check if there are any plants
    if not allPlants then return end

    local plantList = {}

    -- Sort plants by distance To player
    for _, data in pairs(allPlants) do
        local distance = #(currentCoords - data.coords)
        local temp = {
            id = data.id,
            owner = data.owner,
            coords = data.coords,
            entity = data.entity,
            type = data.type,
            label = Config.Plants[data.type].label,
            distance = distance
        }
        table.insert(plantList, temp)
    end

    table.sort(plantList, function(a, b) return a.distance < b.distance end)
    TriggerEvent('it-drugs:client:showPlantListMenu', {plantList = plantList})
end)

RegisterNetEvent('it-drugs:client:generateTableListMenu', function()
    local currentCoords = GetEntityCoords(PlayerPedId())
    local allTables = lib.callback.await('it-drugs:server:getTables', false)

    -- check if there are any tables
    if not allTables then return end

    local tableList = {}

    -- Sort tables by distance To player
    for _, data in pairs(allTables) do
        local distance = #(currentCoords - data.coords)
        local temp = {
            id = data.id,
            coords = data.coords,
            type = data.type,
            label = 'Proccessing Table: '..Config.ProcessingTables[data.type].type,
            distance = distance,
            entity = data.entity
        }
        table.insert(tableList, temp)
    end

    table.sort(tableList, function(a, b) return a.distance < b.distance end)
    TriggerEvent('it-drugs:client:showTableListMenu', {tableList = tableList})
end)


RegisterNetEvent('it-drugs:client:generateWaterPointListMenu', function()
    local currentCoords = GetEntityCoords(PlayerPedId())
    local allPoints = lib.callback.await('it-drugs:server:getWaterPoints', false)

    if not allPoints then return end

    local pointList = {}

    for _, data in pairs(allPoints) do
        local distance = #(currentCoords - data.coords)
        table.insert(pointList, {
            id = data.id,
            coords = data.coords,
            label = data.label or _U('MENU__WATERPOINT__UNNAMED'),
            distance = distance
        })
    end

    table.sort(pointList, function(a, b) return a.distance < b.distance end)
    TriggerEvent('it-drugs:client:showWaterPointListMenu', {pointList = pointList})
end)

RegisterNetEvent('it-drugs:client:showGroundHash', function()
    local posped = GetEntityCoords(PlayerPedId())
    local num =
        StartShapeTestCapsule(posped.x, posped.y, posped.z + 4, posped.x, posped.y, posped.z - 2.0, 2, 1, ped, 7)
    local arg1, arg2, arg3, arg4, arg5 = GetShapeTestResultEx(num)

    local alert = lib.alertDialog({
        header = 'Ground Hash',
        content = 'GroundHash:  \n '..arg5,
        centered = true,
        cancel = true,
        labels = {
            cancel = 'Exit',
            confirm = 'Copy'
        }
    })

    if alert == 'confirm' then
        -- copy content to clipboard
        lib.setClipboard(arg5)
        ShowNotification(nil, _U('NOTIFICATION__COPY__CLIPBOARD'):format(arg5), "success")
    end

end)
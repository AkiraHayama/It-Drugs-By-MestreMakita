local getMetadata = function(itemData)
    if not itemData then return nil end
    local encodedData = json.encode(itemData)
    if it.inventory == 'ox' then
        return itemData.metadata or nil
    elseif it.core == "qb-core" then
        return itemData.info or nil
    elseif it.core == "esx" then
        return itemData.metadata or nil
    end
end

for plant, _ in pairs(Config.Plants) do
    it.createUsableItem(plant, function(source, data)
        local src = source
        if it.hasItem(src, plant, 1) then
            local metadata = getMetadata(data)
            if Config.Debug then lib.print.info('Plant metadata', metadata) end
            TriggerClientEvent('it-drugs:client:useSeed', src, plant, metadata)
        end
    end)
end

if Config.EnableProcessing then
    for prTable, _ in pairs(Config.ProcessingTables) do
        it.createUsableItem(prTable, function(source, data)
            local src = source
            if it.hasItem(src, prTable, 1) then
                local metadata = getMetadata(data)
                if Config.Debug then lib.print.info('Table metadata', metadata) end
                TriggerClientEvent('it-drugs:client:placeProcessingTable', src, prTable, metadata)
            end
        end)
    end
end

if Config.EnableLamps then
    for lamp, _ in pairs(Config.Lamps) do
        it.createUsableItem(lamp, function(source, data)
            local src = source
            if it.hasItem(src, lamp, 1) then
                TriggerClientEvent('it-drugs:client:placeLamp', src, lamp)
            end
        end)
    end
end

if Config.EnableFans then
    for fan, _ in pairs(Config.Fans) do
        it.createUsableItem(fan, function(source, data)
            if it.hasItem(source, fan, 1) then
                TriggerClientEvent('it-drugs:client:placeFan', source, fan)
            end
        end)
    end
end

if Config.EnableGenerators then
    for generator, _ in pairs(Config.Generators) do
        it.createUsableItem(generator, function(source, data)
            if it.hasItem(source, generator, 1) then
                TriggerClientEvent('it-drugs:client:placeGenerator', source, generator)
            end
        end)
    end

    -- extensão: mira no gerador e depois no aparelho (cl_generators.lua); só é gasta ao conectar
    it.createUsableItem(Config.ExtensionItem, function(source, data)
        if it.hasItem(source, Config.ExtensionItem, 1) then
            TriggerClientEvent('it-drugs:client:useExtension', source)
        end
    end)
end

if Config.EnablePots then
    for pot, _ in pairs(Config.Pots) do
        it.createUsableItem(pot, function(source, data)
            local src = source
            if it.hasItem(src, pot, 1) then
                TriggerClientEvent('it-drugs:client:placePot', src, pot)
            end
        end)
    end
end

if Config.EnableDryingRacks then
    for rack, _ in pairs(Config.DryingRacks) do
        it.createUsableItem(rack, function(source, data)
            local src = source
            if it.hasItem(src, rack, 1) then
                TriggerClientEvent('it-drugs:client:placeDryingRack', src, rack)
            end
        end)
    end
end

if Config.EnableDrugs then
    for drug, _ in pairs(Config.Drugs) do
        it.createUsableItem(drug, function(source, data)
            local src = source
            if it.hasItem(src, drug, 1) then
                local currentDrug = lib.callback.await('it-drugs:client:getCurrentDrugEffect', src)
                if Config.Debug then lib.print.info('currentDrug', currentDrug) end
                if not currentDrug then

                    local isDrugOnCooldown = lib.callback.await('it-drugs:client:isDrugOnCooldown', src, drug)
                    if isDrugOnCooldown then
                        ShowNotification(src, _U('NOTIFICATION__DRUG__COOLDOWN'), "info")
                        return
                    end

                    local metadata = getMetadata(data)
                    if it.removeItem(src, drug, 1, metadata) then
                        TriggerClientEvent('it-drugs:client:takeDrug', src, drug)
                    else
                        if Config.Debug then lib.print.error('Failed to remove item') end
                    end
                else
                    ShowNotification(src, _U('NOTIFICATION__DRUG__ALREADY'), "info")
                end
            end
        end)
    end
end
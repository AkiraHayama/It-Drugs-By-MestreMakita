-- Setup the Database from the it_drugs.sql file
DatabaseSetuped = false

local function setupDatabase()
    local drugPlantsFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_plants.sql')

    local plantStatements = {}
    for line in drugPlantsFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
        table.insert(plantStatements, line)
    end
    
    for i = 1, #plantStatements do
        MySQL.rawExecute(plantStatements[i], {}, function(response)
            if response then
                if Config.Debug then lib.print.info('Executed SQL Statment ' .. plantStatements[i]) end
            else
                lib.print.error('Failed to execute SQL statement: ' .. plantStatements[i])
                return
            end
        end)
    end
    
    local drugProcessingFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_processing.sql')

    local proccessingStatements = {}
    for line in drugProcessingFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
        table.insert(proccessingStatements, line)
    end

    for i = 1, #proccessingStatements do
        MySQL.rawExecute(proccessingStatements[i], {}, function(response)
            if response then
                if Config.Debug then lib.print.info('Executed SQL Statment ' .. proccessingStatements[i]) end
            else
                lib.print.error('Failed to execute SQL statement: ' .. proccessingStatements[i])
                return
            end
        end)
    end

    if Config.EnableLamps then
        local drugLampsFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_lamps.sql')

        local lampsStatements = {}
        for line in drugLampsFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
            table.insert(lampsStatements, line)
        end

        for i = 1, #lampsStatements do
            MySQL.rawExecute(lampsStatements[i], {}, function(response)
                if response then
                    if Config.Debug then lib.print.info('Executed SQL Statment ' .. lampsStatements[i]) end
                else
                    lib.print.error('Failed to execute SQL statement: ' .. lampsStatements[i])
                    return
                end
            end)
        end
    end

    if Config.EnablePots then
        local drugPotsFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_pots.sql')

        local potsStatements = {}
        for line in drugPotsFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
            table.insert(potsStatements, line)
        end

        for i = 1, #potsStatements do
            MySQL.rawExecute(potsStatements[i], {}, function(response)
                if response then
                    if Config.Debug then lib.print.info('Executed SQL Statment ' .. potsStatements[i]) end
                else
                    lib.print.error('Failed to execute SQL statement: ' .. potsStatements[i])
                    return
                end
            end)
        end
    end

    if Config.EnableDryingRacks then
        local drugDryingRacksFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_dryingracks.sql')

        local dryingRacksStatements = {}
        for line in drugDryingRacksFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
            table.insert(dryingRacksStatements, line)
        end

        for i = 1, #dryingRacksStatements do
            MySQL.rawExecute(dryingRacksStatements[i], {}, function(response)
                if response then
                    if Config.Debug then lib.print.info('Executed SQL Statment ' .. dryingRacksStatements[i]) end
                else
                    lib.print.error('Failed to execute SQL statement: ' .. dryingRacksStatements[i])
                    return
                end
            end)
        end
    end

    if Config.EnableGenerators then
        local drugGeneratorsFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_generators.sql')

        local generatorsStatements = {}
        for line in drugGeneratorsFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
            table.insert(generatorsStatements, line)
        end

        for i = 1, #generatorsStatements do
            MySQL.rawExecute(generatorsStatements[i], {}, function(response)
                if response then
                    if Config.Debug then lib.print.info('Executed SQL Statment ' .. generatorsStatements[i]) end
                else
                    lib.print.error('Failed to execute SQL statement: ' .. generatorsStatements[i])
                    return
                end
            end)
        end
    end

    if Config.EnableFans then
        local drugFansFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_fans.sql')

        local fansStatements = {}
        for line in drugFansFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
            table.insert(fansStatements, line)
        end

        for i = 1, #fansStatements do
            MySQL.rawExecute(fansStatements[i], {}, function(response)
                if response then
                    if Config.Debug then lib.print.info('Executed SQL Statment ' .. fansStatements[i]) end
                else
                    lib.print.error('Failed to execute SQL statement: ' .. fansStatements[i])
                    return
                end
            end)
        end
    end

    if Config.EnableWaterPoints then
        local drugWaterPointsFile = LoadResourceFile(GetCurrentResourceName(), 'server/database/drug_waterpoints.sql')

        local waterPointsStatements = {}
        for line in drugWaterPointsFile:gsub("\r\n", "\n"):gsub("\n\n", "\n"):gmatch("[^\n]+") do
            table.insert(waterPointsStatements, line)
        end

        for i = 1, #waterPointsStatements do
            MySQL.rawExecute(waterPointsStatements[i], {}, function(response)
                if response then
                    if Config.Debug then lib.print.info('Executed SQL Statment ' .. waterPointsStatements[i]) end
                else
                    lib.print.error('Failed to execute SQL statement: ' .. waterPointsStatements[i])
                    return
                end
            end)
        end
    end

    return true
end

CreateThread(function()
    while not setupDatabase() do
        Wait(100)
    end
    DatabaseSetuped = true
end)
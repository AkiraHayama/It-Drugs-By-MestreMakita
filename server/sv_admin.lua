if it.getCoreName() == 'esx' then

    local ESX = exports['es_extended']:getSharedObject()

    ESX.RegisterCommand({_U('COMMAND__ADMINMENU')}, 'user', function(xPlayer, args, showError)
        local src = xPlayer.source
        if IsPlayerAceAllowed(src, 'admin') then
            if args[1] == nil then
                ShowNotification(src, _U('NOTIFICATION__ADMINMENU__USAGE'):format(_U('COMMAND__ADMINMENU')), "info")
                return
            end
            local menuType = args[1]
            if menuType == 'plants' then
                TriggerClientEvent('it-drugs:client:showMainAdminMenu', src, {menuType = 'plants'})
            elseif menuType == 'tables' then
                TriggerClientEvent('it-drugs:client:showMainAdminMenu', src, {menuType = 'tables'})
            elseif menuType == 'waterpoints' then
                TriggerClientEvent('it-drugs:client:showMainAdminMenu', src, {menuType = 'waterpoints'})
            else
                ShowNotification(src, _U('NOTIFICATION__ADMINMENU__USAGE'):format(_U('COMMAND__ADMINMENU')), "info")
            end
        else
            -- get user license
            local userLicense = GetPlayerIdentifiers(src)[1]
            local username = GetPlayerName(src)
    
            TriggerClientEvent('it-drugs:client:showAdminAlertBox', src, {userLicense = userLicense, username = username})
        end
    end, {help = _U('NOTIFICATION__ADMINMENU__USAGE'):format(_U('COMMAND__ADMINMENU')), validate = true, arguments = {{name = 'type', help = 'plants/tables/waterpoints', type = 'string', optional = false, default = 'plants'}}})

    ESX.RegisterCommand({_U('COMMAND__GROUNDHASH')}, 'user', function(xPlayer, args, showError)
        local src = xPlayer.source
        if IsPlayerAceAllowed(src, 'admin') then
            TriggerClientEvent('it-drugs:client:showGroundHash', src)
        else
            -- get user license
            local userLicense = GetPlayerIdentifiers(src)[1]
            local username = GetPlayerName(src)
    
            TriggerClientEvent('it-drugs:client:showAdminAlertBox', src, {userLicense = userLicense, username = username})
        end
    end, {help = _U('COMMAND__GROUNDHASH__HELP')})

elseif it.getCoreName() == 'qb-core' then
    local QbCore = exports['qb-core']:GetCoreObject()

    QbCore.Commands.Add(_U('COMMAND__ADMINMENU'), _U('NOTIFICATION__ADMINMENU__USAGE'):format(_U('COMMAND__ADMINMENU')), {{name= 'type', help = 'plants/tables/waterpoints'}}, true, function(source, args)
        local src = source
        if IsPlayerAceAllowed(src, 'admin') then
    
            if args[1] == nil then
                ShowNotification(src, _U('NOTIFICATION__ADMINMENU__USAGE'):format(_U('COMMAND__ADMINMENU')), "info")
                return
            end
            local menuType = args[1]
            if menuType == 'plants' then
                TriggerClientEvent('it-drugs:client:showMainAdminMenu', src, {menuType = 'plants'})
            elseif menuType == 'tables' then
                TriggerClientEvent('it-drugs:client:showMainAdminMenu', src, {menuType = 'tables'})
            elseif menuType == 'waterpoints' then
                TriggerClientEvent('it-drugs:client:showMainAdminMenu', src, {menuType = 'waterpoints'})
            else
                ShowNotification(src, _U('NOTIFICATION__ADMINMENU__USAGE'):format(_U('COMMAND__ADMINMENU')), "info")
            end
        else
            -- get user license
            local userLicense = GetPlayerIdentifiers(src)[1]
            local username = GetPlayerName(src)
    
            TriggerClientEvent('it-drugs:client:showAdminAlertBox', src, {userLicense = userLicense, username = username})
        end
    end)

    QbCore.Commands.Add(_U('COMMAND__GROUNDHASH'), _U('COMMAND__GROUNDHASH__HELP'), {}, false, function(source, args)
        local src = source
        if IsPlayerAceAllowed(src, 'admin') then
            TriggerClientEvent('it-drugs:client:showGroundHash', src)
        else
            -- get user license
            local userLicense = GetPlayerIdentifiers(src)[1]
            local username = GetPlayerName(src)
    
            TriggerClientEvent('it-drugs:client:showAdminAlertBox', src, {userLicense = userLicense, username = username})
        end
    end)
end

-- Usado pelo client só pra decidir se mostra opções de admin no menu (ex.: "Forçar 100%" no menu
-- de checar planta) - não é a checagem de segurança de verdade, isso continua sendo feito no
-- próprio evento (it-drugs:server:forceGrowPlant já confere IsPlayerAceAllowed de novo antes de
-- fazer qualquer coisa), aqui é só pra decidir o que exibir na UI.
lib.callback.register('it-drugs:server:isAdmin', function(source)
    return IsPlayerAceAllowed(source, 'admin')
end)
-- /limparpropsdrogas: apaga do mapa TODO objeto com modelo do it-drugs (vaso, planta, mesa, secador, lâmpada,
-- ventilador, gerador). Serve pra sumir com prop bugado que ficou sem estar no banco; os que estão no banco
-- voltam no próximo `restart it-drugs`. Só admin (ou console).
local function drugModels()
    local list = {}
    local function add(name) if type(name) == 'string' then list[joaat(name)] = true end end
    for _, groups in ipairs({ Config.Lamps, Config.Pots, Config.DryingRacks, Config.Fans, Config.Generators, Config.ProcessingTables }) do
        for _, v in pairs(groups or {}) do add(v.model); add(v.soilModel) end
    end
    for _, stages in pairs(Config.PlantTypes or {}) do
        for _, s in pairs(stages) do add(s[1]) end
    end
    add(Config.HarvestMinigame and Config.HarvestMinigame.prop) -- brotos do minigame que ficaram se ele travou
    return list
end

--- Apaga do mapa todo objeto com modelo do it-drugs; devolve quantos. Também roda sozinho no start
--- (sv_setupdatabase.lua), antes dos props do banco nascerem.
function ClearDrugProps()
    local models, n = drugModels(), 0
    for _, obj in ipairs(GetAllObjects()) do
        if models[GetEntityModel(obj)] and DoesEntityExist(obj) then
            DeleteEntity(obj)
            n = n + 1
        end
    end
    return n
end

RegisterCommand('limparpropsdrogas', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'admin') then return end
    local n = ClearDrugProps()
    print(('[it-drugs] /limparpropsdrogas: %d props apagados'):format(n))
    if source ~= 0 then ShowNotification(source, ('%d props do it-drugs apagados do mapa'):format(n), 'success') end
end, false)

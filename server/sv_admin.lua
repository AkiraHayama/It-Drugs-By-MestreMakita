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
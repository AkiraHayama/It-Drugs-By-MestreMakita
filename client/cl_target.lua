if Config.Debug and Config.Target then lib.print.info('Setting up Target System') end

-- Plant Target: removido daqui, agora é por zona/coordenada em client/cl_plant_targets.lua (o
-- alvo por model dependia de colisão, que os props customizados do nextgen_weedprops não têm).

if Config.EnableDealers then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.DrugDealers) do
                if v.ped ~= nil then
                    exports['qb-target']:AddTargetModel(v.ped, {
                        options = {
                            {
                                icon = 'fas fa-eye',
                                label = _U('TARGET__DEALER__LABEL'),
                                action = function (entity)
                                    TriggerEvent('it-drugs:client:showDealerMenu', k)
                                end
                            }
                        },
                        distance = 1.5,
                    })
                end
            end
        elseif Config.Target == 'ox_target' then
            -- Check if ox target is running
            if not exports.ox_target then return end
            for k, v in pairs(Config.DrugDealers) do
                if v.ped ~= nil then
                    exports.ox_target:addModel(v.ped, {
                        {
                            label = _U('TARGET__DEALER__LABEL'),
                            name = 'it-drugs-talk-dealer',
                            icon = 'fas fa-eye',
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:showDealerMenu', k)
                            end,
                            distance = 1.5
                        }
                    })
                end
            end
        end
    end)
end

-- ┌────────────────────────────────────────────────────────────────────────────────────┐
-- │ ____                                  _               _____                    _   │
-- │|  _ \ _ __ ___   ___ ___ ___  ___ ___(_)_ __   __ _  |_   _|_ _ _ __ __ _  ___| |_ │
-- │| |_) | '__/ _ \ / __/ __/ _ \/ __/ __| | '_ \ / _` |   | |/ _` | '__/ _` |/ _ \ __|│
-- │|  __/| | | (_) | (_| (_|  __/\__ \__ \ | | | | (_| |   | | (_| | | | (_| |  __/ |_ │
-- │|_|   |_|  \___/ \___\___\___||___/___/_|_| |_|\__, |   |_|\__,_|_|  \__, |\___|\__|│
-- │                                               |___/                 |___/          │
-- └────────────────────────────────────────────────────────────────────────────────────┘
-- Proccesing Target
if Config.EnableProcessing then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.ProcessingTables) do
                if v.model ~= nil then
                    exports['qb-target']:AddTargetModel(v.model, {
                        options = {
                            {
                                icon = 'fas fa-eye',
                                label = _U('TARGET__TABLE__LABEL'),
                                action = function (entity)
                                    TriggerEvent('it-drugs:client:useTable', {entity = entity, type = k})
                                end
                            }
                        },
                        distance = 1.5,
                    })
                end
            end
        elseif Config.Target == 'ox_target' then
            -- Check if ox target is running
            if not exports.ox_target then return end
            for k, v in pairs(Config.ProcessingTables) do
                if v.model ~= nil then
                    exports.ox_target:addModel(v.model, {
                        {
                            label = _U('TARGET__TABLE__LABEL'),
                            name = 'it-drugs-use-table',
                            icon = 'fas fa-eye',
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:useTable', {entity = data.entity})
                            end,
                            distance = 1.5
                        }
                    })
                end
            end
        end
    end)
end

-- ┌────────────────────────────────────────────────────────┐
-- │ _                            _____                    _ │
-- │| |    __ _ _ __ ___  _ __   |_   _|_ _ _ __ __ _  ___| |_│
-- │| |   / _` | '_ ` _ \| '_ \    | |/ _` | '__/ _` |/ _ \ __|│
-- │| |__| (_| | | | | | | |_) |   | | (_| | | | (_| |  __/ |_│
-- │|_____\__,_|_| |_| |_| .__/    |_|\__,_|_|  \__, |\___|\__|│
-- │                      |_|                    |___/         │
-- └────────────────────────────────────────────────────────┘
-- Grow Lamp Target
if Config.EnableLamps then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.Lamps) do
                if v.model ~= nil then
                    exports['qb-target']:AddTargetModel(v.model, {
                        options = {
                            {
                                icon = 'fas fa-lightbulb',
                                label = _U('TARGET__LAMP__LABEL'),
                                action = function (entity)
                                    TriggerEvent('it-drugs:client:takeLamp', {entity = entity})
                                end
                            }
                        },
                        distance = 1.5,
                    })
                end
            end
        elseif Config.Target == 'ox_target' then
            if not exports.ox_target then return end
            for k, v in pairs(Config.Lamps) do
                if v.model ~= nil then
                    exports.ox_target:addModel(v.model, {
                        {
                            label = _U('TARGET__LAMP__LABEL'),
                            name = 'it-drugs-take-lamp',
                            icon = 'fas fa-lightbulb',
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:takeLamp', {entity = data.entity})
                            end,
                            distance = 1.5
                        }
                    })
                end
            end
        end
    end)
end

-- ┌────────────────────────────────────────────────────────┐
-- │  ____      _         _____                    _        │
-- │ |  _ \ ___| |_ ___  |_   _|_ _ _ __ __ _  ___| |_       │
-- │ | |_) / _ \ __/ __|   | |/ _` | '__/ _` |/ _ \ __|      │
-- │ |  __/ (_) | |_\__ \   | | (_| | | | (_| |  __/ |_      │
-- │ |_|   \___/ \__|___/   |_|\__,_|_|  \__, |\___|\__|     │
-- │                                     |___/                │
-- └────────────────────────────────────────────────────────┘
-- Plant Pot Target
if Config.EnablePots then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.Pots) do
                local models = { v.model, v.soilModel } -- vaso troca de model quando recebe terra, os dois precisam responder ao alvo
                for _, model in pairs(models) do
                    if model ~= nil then
                        exports['qb-target']:AddTargetModel(model, {
                            options = {
                                {
                                    icon = 'fas fa-eye',
                                    label = _U('TARGET__POT__LABEL'),
                                    action = function (entity)
                                        TriggerEvent('it-drugs:client:checkPot', {entity = entity})
                                    end
                                }
                            },
                            distance = 1.5,
                        })
                    end
                end
            end
        elseif Config.Target == 'ox_target' then
            if not exports.ox_target then return end
            for k, v in pairs(Config.Pots) do
                local models = { v.model, v.soilModel } -- vaso troca de model quando recebe terra, os dois precisam responder ao alvo
                for _, model in pairs(models) do
                    if model ~= nil then
                        exports.ox_target:addModel(model, {
                            {
                                label = _U('TARGET__POT__LABEL'),
                                name = 'it-drugs-check-pot',
                                icon = 'fas fa-eye',
                                onSelect = function(data)
                                    TriggerEvent('it-drugs:client:checkPot', {entity = data.entity})
                                end,
                                distance = 1.5
                            }
                        })
                    end
                end
            end
        end
    end)
end

-- ┌────────────────────────────────────────────────────────┐
-- │ Drying Rack Target (Secador)                            │
-- └────────────────────────────────────────────────────────┘
if Config.EnableDryingRacks then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.DryingRacks) do
                if v.model ~= nil then
                    exports['qb-target']:AddTargetModel(v.model, {
                        options = {
                            {
                                icon = 'fas fa-eye',
                                label = _U('TARGET__DRYINGRACK__LABEL'),
                                action = function (entity)
                                    TriggerEvent('it-drugs:client:checkDryingRack', {entity = entity})
                                end
                            }
                        },
                        distance = 1.5,
                    })
                end
            end
        elseif Config.Target == 'ox_target' then
            if not exports.ox_target then return end
            for k, v in pairs(Config.DryingRacks) do
                if v.model ~= nil then
                    exports.ox_target:addModel(v.model, {
                        {
                            label = _U('TARGET__DRYINGRACK__LABEL'),
                            name = 'it-drugs-check-dryingrack',
                            icon = 'fas fa-eye',
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:checkDryingRack', {entity = data.entity})
                            end,
                            distance = 1.5
                        }
                    })
                end
            end
        end
    end)
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │ ____       _ _ _               _____                    _   │
-- │/ ___|  ___| | (_)_ __   __ _  |_   _|_ _ _ __ __ _  ___| |_ │
-- │\___ \ / _ \ | | | '_ \ / _` |   | |/ _` | '__/ _` |/ _ \ __|│
-- │ ___) |  __/ | | | | | | (_| |   | | (_| | | | (_| |  __/ |_ │
-- │|____/ \___|_|_|_|_| |_|\__, |   |_|\__,_|_|  \__, |\___|\__|│
-- │                        |___/                 |___/          │
-- └─────────────────────────────────────────────────────────────┘

local function isPedBlacklisted(ped)
	local model = GetEntityModel(ped)
	for i = 1, #Config.BlacklistPeds do
		if model == GetHashKey(Config.BlacklistPeds[i]) then
			return true
		end
	end
	return false
end

-- Create the selling Targets
CreateSellTarget = function()
    if Config.Target == 'qb-target' then
        if not exports['qb-target'] then return end
        exports['qb-target']:AddGlobalPed({
            options = {
                {
                    label = _U('TARGET__SELL__LABEL'),
                    icon = 'fas fa-comment',
                    action = function(entity)
                        TriggerEvent('it-drugs:client:checkSellOffer', entity)
                    end,
                    canInteract = function(entity)
                        if not IsPedDeadOrDying(entity, false) and not IsPedInAnyVehicle(entity, false) and (GetPedType(entity)~=28) and (not IsPedAPlayer(entity)) and (not isPedBlacklisted(entity)) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                            return true
                        end
                        return false
                    end,
                }
            },
            distance = 4,
        })

    elseif Config.Target == 'ox_target' then
        -- Check if ox target is running
        if not exports.ox_target then return end
        exports.ox_target:addGlobalPed({
            {
                label = _U('TARGET__SELL__LABEL'),
                name = 'it-drugs-sell',
                icon = 'fas fa-comment',
                onSelect = function(data)
                    TriggerEvent('it-drugs:client:checkSellOffer', data.entity)
                end,
                canInteract = function(entity, _, _, _, _)
                    if not IsPedDeadOrDying(entity, false) and not IsPedInAnyVehicle(entity, false) and (GetPedType(entity)~=28) and (not IsPedAPlayer(entity)) and (not isPedBlacklisted(entity)) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        return true
                    end
                    return false
                end,
                distance = 4
            }
        })
    end
end

RemoveSellTarget = function()
    if Config.Target == 'qb-target' then
        if not exports['qb-target'] then return end
        exports['qb-target']:RemoveGlobalPed({_U('TARGET__SELL__LABEL')})
    elseif Config.Target == 'ox_target' then
        -- Check if ox target is running
        if not exports.ox_target then return end
        exports.ox_target:removeGlobalPed('it-drugs-sell')
    end
end

-- Remove all Targets
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Config.Target == 'qb-target' then
        if not exports['qb-target'] then return end
        for k, v in pairs(Config.ProcessingTables) do
            if v.model ~= nil then
                exports['qb-target']:RemoveTargetModel(v.model)
            end
        end
        if Config.EnableLamps then
            for k, v in pairs(Config.Lamps) do
                if v.model ~= nil then
                    exports['qb-target']:RemoveTargetModel(v.model)
                end
            end
        end
        if Config.EnablePots then
            for k, v in pairs(Config.Pots) do
                for _, model in pairs({ v.model, v.soilModel }) do
                    if model ~= nil then
                        exports['qb-target']:RemoveTargetModel(model)
                    end
                end
            end
        end
        if Config.EnableDryingRacks then
            for k, v in pairs(Config.DryingRacks) do
                if v.model ~= nil then
                    exports['qb-target']:RemoveTargetModel(v.model)
                end
            end
        end
    elseif Config.Target == 'ox_target' then
        if not exports.ox_target then return end
        for k, v in pairs(Config.ProcessingTables) do
            if v.model ~= nil then
                exports.ox_target:removeModel(v.model, 'it-drugs-use-table')
            end
        end
        if Config.EnableLamps then
            for k, v in pairs(Config.Lamps) do
                if v.model ~= nil then
                    exports.ox_target:removeModel(v.model, 'it-drugs-take-lamp')
                end
            end
        end
        if Config.EnablePots then
            for k, v in pairs(Config.Pots) do
                for _, model in pairs({ v.model, v.soilModel }) do
                    if model ~= nil then
                        exports.ox_target:removeModel(model, 'it-drugs-check-pot')
                    end
                end
            end
        end
        if Config.EnableDryingRacks then
            for k, v in pairs(Config.DryingRacks) do
                if v.model ~= nil then
                    exports.ox_target:removeModel(v.model, 'it-drugs-check-dryingrack')
                end
            end
        end
    end
    if Config.EnableSelling then
        RemoveSellTarget()
    end
end)
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
            -- Uma opção no E por receita, só as que dá pra fazer agora (tem os ingredientes e as ferramentas) - sem painel
            local canMake = function(recipe)
                for item, amount in pairs(recipe.ingrediants) do
                    if not it.hasItemLocal(item, amount) then return false end
                end
                for item, amount in pairs(recipe.tools or {}) do
                    if not it.hasItemLocal(item, amount) then return false end
                end
                return true
            end
            for k, v in pairs(Config.ProcessingTables) do
                if v.model ~= nil then
                    local options, benchStrains = {}, {}
                    for recipeName, recipe in pairs(v.recipes) do
                        if recipe.bench then benchStrains[recipe.bench] = true else
                        options[#options + 1] = {
                            label = recipe.label,
                            name = 'it-drugs-recipe-' .. recipeName,
                            icon = v.type == 'cocaine' and 'fas fa-flask' or 'fas fa-cannabis',
                            canInteract = function() return canMake(recipe) end,
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:tableRecipe', { entity = data.entity, type = k, recipe = recipeName })
                            end,
                            distance = 1.5
                        }
                        end
                    end
                    -- cortar/embalar o tijolo: abre a bancada (cl_bench.lua). Sempre aparece: os cubos e zip locks podem
                    -- estar todos na mesa (fora do inventário) e é na bancada que se tira as coisas e pega os prontos
                    if next(benchStrains) then
                        -- camarão = dichavador; prensado = tijolo/cubos. O modo usado por último na mesa vem primeiro
                        -- (é só apertar E): camarão aparece antes OU depois do prensado, conforme BenchMode (cl_bench.lua)
                        for i, mode in ipairs({ 'camarao', 'prensado', 'camarao' }) do
                            options[#options + 1] = {
                                label = _U(mode == 'camarao' and 'TARGET__BENCH__CAMARAO' or 'TARGET__BENCH__PRENSADO'),
                                name = 'it-drugs-bench-' .. mode .. i,
                                icon = 'fas fa-cannabis',
                                canInteract = i ~= 2 and function(entity)
                                    local last = BenchMode and BenchMode(entity) or 'prensado'
                                    return (i == 1) == (last == 'camarao')
                                end or nil,
                                onSelect = function(data)
                                    TriggerEvent('it-drugs:client:bench', { entity = data.entity, strains = benchStrains, mode = mode })
                                end,
                                distance = 1.5
                            }
                        end
                    end
                    options[#options + 1] = {
                        label = _U('TARGET__TABLE__TAKE'),
                        name = 'it-drugs-take-table',
                        icon = 'fas fa-hand',
                        onSelect = function(data) TriggerEvent('it-drugs:client:tableTake', { entity = data.entity }) end,
                        distance = 1.5
                    }
                    exports.ox_target:addModel(v.model, options)
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
-- Fan Target (ligar/desligar + recolher) - mesmo esquema das lâmpadas abaixo
if Config.EnableFans then
    CreateThread(function()
        for _, v in pairs(Config.Fans) do
            if Config.Target == 'qb-target' then
                exports['qb-target']:AddTargetModel(v.model, {
                    options = {
                        {
                            icon = 'fas fa-power-off',
                            label = _U('TARGET__FAN__TURN_ON'),
                            canInteract = function(entity) return not IsFanOnAt(entity) end,
                            action = function(entity) TriggerEvent('it-drugs:client:toggleFan', { entity = entity }) end
                        },
                        {
                            icon = 'fas fa-power-off',
                            label = _U('TARGET__FAN__TURN_OFF'),
                            canInteract = function(entity) return IsFanOnAt(entity) end,
                            action = function(entity) TriggerEvent('it-drugs:client:toggleFan', { entity = entity }) end
                        },
                        {
                            icon = 'fas fa-fan',
                            label = _U('TARGET__FAN__TAKE'),
                            action = function(entity) TriggerEvent('it-drugs:client:takeFan', { entity = entity }) end
                        },
                    },
                    distance = 1.5,
                })
            elseif Config.Target == 'ox_target' and exports.ox_target then
                exports.ox_target:addModel(v.model, {
                    {
                        label = _U('TARGET__FAN__TURN_ON'),
                        name = 'it-drugs-turnon-fan',
                        icon = 'fas fa-power-off',
                        canInteract = function(entity) return not IsFanOnAt(entity) end,
                        onSelect = function(data) TriggerEvent('it-drugs:client:toggleFan', { entity = data.entity }) end,
                        distance = 1.5
                    },
                    {
                        label = _U('TARGET__FAN__TURN_OFF'),
                        name = 'it-drugs-turnoff-fan',
                        icon = 'fas fa-power-off',
                        canInteract = function(entity) return IsFanOnAt(entity) end,
                        onSelect = function(data) TriggerEvent('it-drugs:client:toggleFan', { entity = data.entity }) end,
                        distance = 1.5
                    },
                    {
                        label = _U('TARGET__FAN__TAKE'),
                        name = 'it-drugs-take-fan',
                        icon = 'fas fa-fan',
                        onSelect = function(data) TriggerEvent('it-drugs:client:takeFan', { entity = data.entity }) end,
                        distance = 1.5
                    },
                })
            end
        end
    end)
end

-- Gerador (menu) + "Desconectar extensão" no ventilador e na lâmpada (cl_generators.lua)
if Config.EnableGenerators then
    CreateThread(function()
        local generatorOption = {
            label = _U('TARGET__GENERATOR__LABEL'),
            name = 'it-drugs-use-generator',
            icon = 'fas fa-gas-pump',
            onSelect = function(data) TriggerEvent('it-drugs:client:openGenerator', { entity = data.entity }) end,
            action = function(entity) TriggerEvent('it-drugs:client:openGenerator', { entity = entity }) end,
            distance = 1.5,
        }
        local disconnectOption = {
            label = _U('TARGET__EXTENSION__DISCONNECT'),
            name = 'it-drugs-disconnect-extension',
            icon = 'fas fa-plug-circle-xmark',
            canInteract = function(entity) return IsDeviceConnected(entity) end,
            onSelect = function(data) TriggerEvent('it-drugs:client:disconnectExtension', { entity = data.entity }) end,
            action = function(entity) TriggerEvent('it-drugs:client:disconnectExtension', { entity = entity }) end,
            distance = 1.5,
        }
        local deviceModels = {}
        for _, v in pairs(Config.Fans or {}) do deviceModels[#deviceModels + 1] = v.model end
        for _, v in pairs(Config.Lamps or {}) do deviceModels[#deviceModels + 1] = v.model end

        for _, v in pairs(Config.Generators) do
            if Config.Target == 'qb-target' then
                exports['qb-target']:AddTargetModel(v.model, { options = { generatorOption }, distance = 1.5 })
            elseif Config.Target == 'ox_target' and exports.ox_target then
                -- ações direto no E, só as que valem agora; gasolina e aparelhos ficam no texto em cima do gerador
                exports.ox_target:addModel(v.model, {
                    {
                        label = _U('TARGET__GENERATOR__ON'),
                        name = 'it-drugs-generator-on',
                        icon = 'fas fa-power-off',
                        canInteract = function(entity)
                            local gen = GetGeneratorState(entity)
                            return gen ~= nil and gen.isOn == false
                        end,
                        onSelect = function(data) TriggerServerEvent('it-drugs:server:toggleGenerator', NetworkGetNetworkIdFromEntity(data.entity)) end,
                        distance = 1.5,
                    },
                    {
                        label = _U('TARGET__GENERATOR__OFF'),
                        name = 'it-drugs-generator-off',
                        icon = 'fas fa-power-off',
                        canInteract = function(entity)
                            local gen = GetGeneratorState(entity)
                            return gen ~= nil and gen.isOn ~= false
                        end,
                        onSelect = function(data) TriggerServerEvent('it-drugs:server:toggleGenerator', NetworkGetNetworkIdFromEntity(data.entity)) end,
                        distance = 1.5,
                    },
                    {
                        label = _U('TARGET__GENERATOR__REFUEL'),
                        name = 'it-drugs-generator-refuel',
                        icon = 'fas fa-gas-pump',
                        canInteract = function(entity)
                            local gen = GetGeneratorState(entity)
                            return gen ~= nil and gen.fuel < gen.tank - 0.1 and it.hasItemLocal(Config.FuelItem, 1)
                        end,
                        onSelect = function(data) TriggerEvent('it-drugs:client:generatorRefuel', { entity = data.entity }) end,
                        distance = 1.5,
                    },
                    {
                        label = _U('TARGET__GENERATOR__TAKE'),
                        name = 'it-drugs-generator-take',
                        icon = 'fas fa-hand',
                        canInteract = function(entity) return GetGeneratorState(entity) ~= nil end, -- com extensão ligada avisa ao escolher
                        onSelect = function(data) TriggerEvent('it-drugs:client:generatorTake', { entity = data.entity }) end,
                        distance = 1.5,
                    },
                })
            end
        end
        for _, model in ipairs(deviceModels) do
            if Config.Target == 'qb-target' then
                exports['qb-target']:AddTargetModel(model, { options = { disconnectOption }, distance = 1.5 })
            elseif Config.Target == 'ox_target' and exports.ox_target then
                exports.ox_target:addModel(model, { disconnectOption })
            end
        end
    end)
end

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
                            label = _U('TARGET__LAMP__ON'),
                            name = 'it-drugs-lamp-on',
                            icon = 'fas fa-power-off',
                            canInteract = function(entity) return Entity(entity).state.lampOn == false end,
                            onSelect = function(data) TriggerServerEvent('it-drugs:server:toggleLamp', NetworkGetNetworkIdFromEntity(data.entity)) end,
                            distance = 1.5
                        },
                        {
                            label = _U('TARGET__LAMP__OFF'),
                            name = 'it-drugs-lamp-off',
                            icon = 'fas fa-power-off',
                            canInteract = function(entity) return NetworkGetEntityIsNetworked(entity) and Entity(entity).state.lampOn ~= false end,
                            onSelect = function(data) TriggerServerEvent('it-drugs:server:toggleLamp', NetworkGetNetworkIdFromEntity(data.entity)) end,
                            distance = 1.5
                        },
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
                                    end,
                                    canInteract = function(entity) return not IsPotPlanted(entity) end -- com planta, o alvo é a planta (cl_plant_targets.lua)
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
                                canInteract = function(entity) return not IsPotPlanted(entity) end, -- com planta, o alvo é a planta (cl_plant_targets.lua)
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
            -- Ações direto no E (scroll troca): só aparecem as que valem agora - o status fica no texto em cima da rede (cl_dryingracks.lua)
            for k, v in pairs(Config.DryingRacks) do
                if v.model ~= nil then
                    local options = {}
                    for rawItem in pairs(v.dries) do
                        local strain = Config.WeedStrains[rawItem:match('^weed_(.+)$') or '']
                        options[#options + 1] = {
                            label = _U('TARGET__DRYINGRACK__HANG'):format(strain and strain.label or rawItem),
                            name = 'it-drugs-rack-hang-' .. rawItem,
                            icon = 'fas fa-cannabis',
                            canInteract = function(entity) return GetDryingRackState(entity) == 'empty' and it.hasItemLocal(rawItem, 1) end,
                            onSelect = function(data) TriggerEvent('it-drugs:client:rackHang', { entity = data.entity, rawItem = rawItem }) end,
                            distance = 1.5
                        }
                    end
                    options[#options + 1] = {
                        label = _U('TARGET__DRYINGRACK__COLLECT'),
                        name = 'it-drugs-rack-collect',
                        icon = 'fas fa-leaf',
                        canInteract = function(entity) return GetDryingRackState(entity) == 'ready' end,
                        onSelect = function(data) TriggerEvent('it-drugs:client:rackCollect', { entity = data.entity }) end,
                        distance = 1.5
                    }
                    options[#options + 1] = {
                        label = _U('TARGET__DRYINGRACK__TAKE'),
                        name = 'it-drugs-rack-take',
                        icon = 'fas fa-hand',
                        canInteract = function(entity) return GetDryingRackState(entity) == 'empty' end,
                        onSelect = function(data) TriggerEvent('it-drugs:client:rackTake', { entity = data.entity }) end,
                        distance = 1.5
                    }
                    exports.ox_target:addModel(v.model, options)
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
        if Config.EnableFans then
            for _, v in pairs(Config.Fans) do exports['qb-target']:RemoveTargetModel(v.model) end
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
                exports.ox_target:removeModel(v.model) -- tira todas as opções da mesa (receitas + recolher)
            end
        end
        if Config.EnableLamps then
            for k, v in pairs(Config.Lamps) do
                if v.model ~= nil then
                    exports.ox_target:removeModel(v.model, 'it-drugs-take-lamp')
                end
            end
        end
        if Config.EnableFans then
            for _, v in pairs(Config.Fans) do exports.ox_target:removeModel(v.model, { 'it-drugs-turnon-fan', 'it-drugs-turnoff-fan', 'it-drugs-take-fan' }) end
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
                    exports.ox_target:removeModel(v.model) -- tira todas as opções da rede (pendurar/recolher)
                end
            end
        end
    end
    if Config.EnableSelling then
        RemoveSellTarget()
    end
end)
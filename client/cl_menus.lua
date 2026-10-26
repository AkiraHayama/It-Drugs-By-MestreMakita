-- ┌────────────────────────────────────────┐
-- │  ____       _   __  __                  │
-- │ |  _ \ ___ | |_|  \/  | ___ _ __  _   _ │
-- │ | |_) / _ \| __| |\/| |/ _ \ '_ \| | | |│
-- │ |  __/ (_) | |_| |  | |  __/ | | | |_| |│
-- │ |_|   \___/ \__|_|  |_|\___|_| |_|\__,_|│
-- └────────────────────────────────────────┘
-- Plant Pot Menu

RegisterNetEvent('it-drugs:client:showPotMenu', function(potData)
    if potData.hasPlant then
        -- Mostra os controles de água/fertilizante/colheita direto (mesmo menu de quando mira
        -- na planta), em vez de só avisar "já tem planta aqui" - tudo no toggle, sem precisar
        -- sair do vaso pra cuidar da planta.
        local plantData = lib.callback.await('it-drugs:server:getPlantDataByPot', false, potData.id)
        if plantData then
            -- Repassa os dados do vaso pra showPlantMenu poder oferecer "Mover Vaso" (só faz
            -- sentido quando a planta está num vaso, por isso não é um campo fixo do plantData)
            plantData.potEntity = potData.entity
            plantData.potItem = potData.item
            plantData.potHasSoil = potData.hasSoil
            TriggerEvent('it-drugs:client:showPlantMenu', plantData)
        end
        return
    end

    local options = {}
    local potConfig = Config.Pots[potData.item]
    local soilItem = potConfig and potConfig.soilItem

    if not potData.hasSoil then
        table.insert(options, {
            title = _U('MENU__POT__ADD_SOIL'),
            description = _U('MENU__POT__ADD_SOIL__DESC'),
            icon = "shovel",
            arrow = true,
            event = "it-drugs:client:addSoil",
            args = { entity = potData.entity, soilItem = soilItem }
        })
    elseif potData.burnt then -- planta queimada: terra imprópria, só dá pra remover
        table.insert(options, {
            title = _U('MENU__POT__SOIL__BURNT'),
            description = _U('MENU__POT__SOIL__BURNT__DESC'),
            icon = "fire",
        })
    elseif potData.needsFertilizer then -- planta cortada: adubar antes de plantar de novo
        table.insert(options, {
            title = _U('MENU__POT__FERTILIZE'),
            description = _U('MENU__POT__FERTILIZE__DESC'),
            icon = "flask",
            arrow = true,
            event = "it-drugs:client:fertilizeSoil",
            args = { entity = potData.entity }
        })
    else
        local seedOptions = {}

        for seed, plantInfos in pairs(Config.Plants) do
            if it.hasItem(seed, 1) then
                table.insert(seedOptions, {
                    title = plantInfos.label,
                    description = _U('MENU__POT__PLANT__SEED__DESC'),
                    icon = "seedling",
                    arrow = true,
                    event = "it-drugs:client:plantInPot",
                    args = { entity = potData.entity, seed = seed, netId = potData.netId }
                })
            end
        end

        if #seedOptions == 0 then
            table.insert(options, {
                title = _U('MENU__POT__PLANT'),
                description = _U('NOTIFICATION__NO__ITEMS'),
                icon = "seedling",
            })
        else
            table.insert(options, {
                title = _U('MENU__POT__PLANT'),
                description = _U('MENU__POT__PLANT__DESC'),
                icon = "seedling",
                arrow = true,
                menu = "it-drugs-pot-seed-menu",
            })

            lib.registerContext({
                id = "it-drugs-pot-seed-menu",
                title = _U('MENU__POT__PLANT'),
                menu = "it-drugs-pot-menu",
                options = seedOptions
            })
        end
    end

    if potData.hasSoil then -- tirar a terra (queimada ou não): precisa pra pôr terra nova ou recolher o vaso
        table.insert(options, {
            title = _U('MENU__POT__REMOVE_SOIL'),
            description = _U('MENU__POT__REMOVE_SOIL__DESC'),
            icon = "trash",
            arrow = true,
            event = "it-drugs:client:removeSoil",
            args = { entity = potData.entity }
        })
    end

    table.insert(options, {
        title = _U('MENU__POT__MOVE'),
        description = _U('MENU__POT__MOVE__DESC'),
        icon = "up-down-left-right",
        arrow = true,
        event = "it-drugs:client:movePot",
        args = { entity = potData.entity, item = potData.item, hasSoil = potData.hasSoil }
    })

    table.insert(options, {
        title = _U('MENU__POT__TAKE'),
        description = _U('MENU__POT__TAKE__DESC'),
        icon = "hand",
        arrow = true,
        event = "it-drugs:client:takePot",
        args = { entity = potData.entity }
    })

    lib.registerContext({
        id = "it-drugs-pot-menu",
        title = _U('MENU__POT'),
        options = options
    })

    lib.showContext("it-drugs-pot-menu")
end)

-- ┌────────────────────────────────────────┐
-- │ Drying Rack Menu (Secador)              │
-- └────────────────────────────────────────┘

RegisterNetEvent('it-drugs:client:showDryingRackMenu', function(rackData)
    local options = {}
    local rackConfig = Config.DryingRacks[rackData.item]

    if rackData.dryingItem then
        if rackData.ready then
            table.insert(options, {
                title = _U(rackData.curing and 'MENU__DRYINGRACK__READY__CURED' or 'MENU__DRYINGRACK__READY'),
                description = _U('MENU__DRYINGRACK__READY__DESC'),
                icon = "leaf",
                arrow = true,
                event = "it-drugs:client:collectDrying",
                args = { entity = rackData.entity, item = rackData.item, coords = rackData.coords }
            })
        else
            local minutesLeft = math.ceil(rackData.remaining / 60)
            table.insert(options, {
                title = _U(rackData.slow and 'MENU__DRYINGRACK__CURING__SLOW' or rackData.curing and 'MENU__DRYINGRACK__CURING' or 'MENU__DRYINGRACK__DRYING'),
                description = _U('MENU__DRYINGRACK__DRYING__DESC'):format(minutesLeft),
                icon = rackData.curing and "fan" or "clock",
            })
        end
    else
        local rawOptions = {}
        for rawItem, _ in pairs(rackConfig.dries) do
            if it.hasItem(rawItem, 1) then
                table.insert(rawOptions, {
                    title = it.getItemLabel(rawItem),
                    description = _U('MENU__DRYINGRACK__HANG__ITEM__DESC'),
                    icon = "leaf",
                    arrow = true,
                    event = "it-drugs:client:startDrying",
                    args = { entity = rackData.entity, item = rackData.item, rawItem = rawItem, coords = rackData.coords }
                })
            end
        end

        if #rawOptions == 0 then
            table.insert(options, {
                title = _U('MENU__DRYINGRACK__HANG'),
                description = _U('NOTIFICATION__NO__ITEMS'),
                icon = "leaf",
            })
        else
            table.insert(options, {
                title = _U('MENU__DRYINGRACK__HANG'),
                description = _U('MENU__DRYINGRACK__HANG__DESC'),
                icon = "leaf",
                arrow = true,
                menu = "it-drugs-dryingrack-hang-menu",
            })

            lib.registerContext({
                id = "it-drugs-dryingrack-hang-menu",
                title = _U('MENU__DRYINGRACK__HANG'),
                menu = "it-drugs-dryingrack-menu",
                options = rawOptions
            })
        end

        table.insert(options, {
            title = _U('MENU__DRYINGRACK__TAKE'),
            description = _U('MENU__DRYINGRACK__TAKE__DESC'),
            icon = "hand",
            arrow = true,
            event = "it-drugs:client:takeDryingRack",
            args = { entity = rackData.entity }
        })
    end

    lib.registerContext({
        id = "it-drugs-dryingrack-menu",
        title = _U('MENU__DRYINGRACK'),
        options = options
    })

    lib.showContext("it-drugs-dryingrack-menu")
end)

-- ┌───────────────────────────────────────────────────┐
-- │ ____  _             _     __  __                  │
-- │|  _ \| | __ _ _ __ | |_  |  \/  | ___ _ __  _   _ │
-- │| |_) | |/ _` | '_ \| __| | |\/| |/ _ \ '_ \| | | |│
-- │|  __/| | (_| | | | | |_  | |  | |  __/ | | | |_| |│
-- │|_|   |_|\__,_|_| |_|\__| |_|  |_|\___|_| |_|\__,_|│
-- └───────────────────────────────────────────────────┘
-- Plant Menu

--- Barra de "Luz" (sol + lâmpada somados) + aviso se o local é aberto (sol) ou fechado (precisa
--- de lâmpada) - Config.IndoorSunlightThreshold decide o corte, só pro texto/aviso, o cálculo de
--- crescimento/saúde de verdade já soma sunlight+addedLight direto (server/sv_planting.lua)
local function getLightOptions(plantData)
    local totalLight = math.min((plantData.sunlight or 0) + (plantData.addedLight or 0), 100)
    local isOutdoor = (plantData.sunlight or 0) >= Config.IndoorSunlightThreshold

    local options = {
        {
            title = _U('MENU__PLANT__LIGHT'),
            description = math.floor(totalLight).. '%',
            icon = "sun",
            metadata = {
                _U('MENU__PLANT__LIGHT__META')
            },
            progress = math.floor(totalLight),
            colorScheme = "yellow"
        },
        {
            title = isOutdoor and _U('MENU__PLANT__LOCATION_STATUS__OUTDOOR') or _U('MENU__PLANT__LOCATION_STATUS__INDOOR'),
            description = isOutdoor and _U('MENU__PLANT__LOCATION_STATUS__OUTDOOR__DESC') or _U('MENU__PLANT__LOCATION_STATUS__INDOOR__DESC'),
            icon = isOutdoor and "sun" or "house",
        }
    }

    -- Pureza da maconha (Config.Purity) vai junto, já que essas opções aparecem nos 3 estados do menu
    if plantData.purity and it.usesPurity(plantData.type) then
        options[#options + 1] = {
            title = _U('MENU__PLANT__PURITY'),
            description = math.floor(plantData.purity) .. '%',
            icon = "dna",
            progress = math.floor(plantData.purity),
            colorScheme = "violet"
        }
    end
    return options
end

RegisterNetEvent("it-drugs:client:showPlantMenu", function(plantData)
    local plantName = Config.Plants[plantData.type].label
    -- Só decide se MOSTRA o botão de admin - a segurança de verdade é o próprio
    -- it-drugs:server:forceGrowPlant checando IsPlayerAceAllowed de novo antes de fazer qualquer
    -- coisa (ver sv_planting.lua), então não tem problema um client adulterado forçar isso a true.
    local isAdmin = lib.callback.await('it-drugs:server:isAdmin', false)

    if plantData.health == 0 then
        local options = {
            {
                title = _U('MENU__PLANT__LIFE'),
                icon = "notes-medical",
                description = math.floor(plantData.health).. '%',
                metadata = {
                    _U('MENU__PLANT__LIFE__META')
                },
                progress = math.floor(plantData.health),
                colorScheme = "red",
            },
            {
                title = _U('MENU__PLANT__STAGE'),
                description = math.floor(plantData.growth).. '%',
                icon = "seedling",
                metadata = {
                    _U('MENU__PLANT__STAGE__META')
                },
                progress = math.floor(plantData.growth),
                colorScheme = "green"
            },
            {
                title = _U('MENU__PLANT__FERTILIZER'),
                description = math.floor(plantData.fertilizer).. '%',
                icon = "bucket",
                metadata = {
                    _U('MENU__PLANT__STAGE__META')
                },
                progress = math.floor(plantData.fertilizer),
                colorScheme = "orange"
            },
            {
                title = _U('MENU__PLANT__WATER'),
                description = math.floor(plantData.water).. '%',
                icon = "droplet",
                metadata = {
                    _U('MENU__PLANT__STAGE__META')
                },
                progress = math.floor(plantData.water),
                colorScheme = "blue"
            },
            {
                title = _U('MENU__PLANT__DESTROY'),
                description = _U('MENU__PLANT__DESTROY__DESC'),
                icon = "fire",
                arrow = true,
                event = "it-drugs:client:destroyPlant",
                args = {entity = plantData.entity, type = plantData.type}
            }
        }

        if isAdmin then
            table.insert(options, {
                title = _U('MENU__PLANT__FORCE_GROW'),
                description = _U('MENU__PLANT__FORCE_GROW__DESC'),
                icon = "forward-fast",
                arrow = true,
                onSelect = function()
                    TriggerServerEvent('it-drugs:server:forceGrowPlant', {id = plantData.id})
                end
            })
        end

        for _, opt in ipairs(getLightOptions(plantData)) do
            table.insert(options, opt)
        end

        if plantData.potEntity then
            table.insert(options, {
                title = _U('MENU__POT__MOVE'),
                description = _U('MENU__POT__MOVE__DESC'),
                icon = "up-down-left-right",
                arrow = true,
                event = "it-drugs:client:movePot",
                args = { entity = plantData.potEntity, item = plantData.potItem, hasSoil = plantData.potHasSoil }
            })
        end

        lib.registerContext({
            id = "it-drugs-dead-plant-menu",
            title = _U('MENU__DEAD__PLANT'),
            options = options
        })
        lib.showContext("it-drugs-dead-plant-menu")
        return
    elseif plantData.growth == 100 then
        local options = {
            {
                title = _U('MENU__PLANT__LIFE'),
                icon = "notes-medical",
                description = math.floor(plantData.health).. '%',
                metadata = {
                    _U('MENU__PLANT__LIFE__META')
                },
                progress = math.floor(plantData.health),
                colorScheme = "red",
            },
            {
                title = _U('MENU__PLANT__STAGE'),
                description = math.floor(plantData.growth).. '%',
                icon = "seedling",
                metadata = {
                   _U('MENU__PLANT__STAGE__META')
                },
                progress = math.floor(plantData.growth),
                colorScheme = "green"
            },
            {
                title = _U('MENU__PLANT__FERTILIZER'),
                description = math.floor(plantData.fertilizer).. '%',
                icon = "bucket",
                metadata = {
                    _U('MENU__PLANT__FERTILIZER__META')
                },
                progress = math.floor(plantData.fertilizer),
                colorScheme = "orange"
            },
            {
                title = _U('MENU__PLANT__WATER'),
                description = math.floor(plantData.water).. '%',
                icon = "droplet",
                metadata = {
                    _U('MENU__PLANT__WATER__META')
                },
                progress = math.floor(plantData.water),
                colorScheme = "blue"
            },
            {
                title = _U('MENU__PLANT__DESTROY'),
                icon = "fire",
                description = _U('MENU__PLANT__DESTROY__DESC'),
                arrow = true,
                event = "it-drugs:client:destroyPlant",
                args = {entity = plantData.entity, type = plantData.type}
            }
        }

        -- Depois que os brotos já foram colhidos (budsHarvested), "Colher" some e dá lugar a
        -- "Cortar Planta" (foice, planta inteira, dá o prensado) - só uma opção por vez, nunca as
        -- duas juntas. Antes disso, só "Colher" aparece.
        if plantData.budsHarvested then
            table.insert(options, #options, {
                title = _U('MENU__PLANT__CUT'),
                icon = "wheat-awn",
                description = _U('MENU__PLANT__CUT__DESC'),
                arrow = true,
                event = "it-drugs:client:cutWholePlant",
                args = {id = plantData.id, coords = plantData.coords}
            })
        else
            table.insert(options, #options, {
                title = _U('MENU__PLANT__HARVEST'),
                icon = "scissors",
                description = _U('MENU__PLANT__HARVEST__DESC'),
                arrow = true,
                event = "it-drugs:client:harvestPlant",
                args = {id = plantData.id, type = plantData.type, fertilizer = plantData.fertilizer, coords = plantData.coords, purity = plantData.purity}
            })
        end

        for _, opt in ipairs(getLightOptions(plantData)) do
            table.insert(options, opt)
        end

        if plantData.potEntity then
            table.insert(options, {
                title = _U('MENU__POT__MOVE'),
                description = _U('MENU__POT__MOVE__DESC'),
                icon = "up-down-left-right",
                arrow = true,
                event = "it-drugs:client:movePot",
                args = { entity = plantData.potEntity, item = plantData.potItem, hasSoil = plantData.potHasSoil }
            })
        end

        lib.registerContext({
            id = "it-drugs-harvest-plant-menu",
            title = _U('MENU__PLANT'):format(plantName),
            options = options
        })
        lib.showContext("it-drugs-harvest-plant-menu")

    else
        local options = {
            {
                title = _U('MENU__PLANT__LIFE'),
                icon = "notes-medical",
                description = math.floor(plantData.health).. '%',
                metadata = {
                    _U('MENU__PLANT__LIFE__META')
                },
                progress = math.floor(plantData.health),
                colorScheme = "red",
            },
            {
                title = _U('MENU__PLANT__STAGE'),
                description = math.floor(plantData.growth).. '%',
                icon = "seedling",
                metadata = {
                    _U('MENU__PLANT__STAGE__META')
                },
                progress = math.floor(plantData.growth),
                colorScheme = "green"
            },
            {
                title = _U('MENU__PLANT__FERTILIZER'),
                description = math.floor(plantData.fertilizer).. '%',
                icon = "bucket",
                metadata = {
                    _U('MENU__PLANT__FERTILIZER__META')
                },
                arrow = true,
                progress = math.floor(plantData.fertilizer),
                colorScheme = "orange",
                event = "it-drugs:client:showItemMenu",
                args = {entity = plantData.entity, type = plantData.type, eventType = "fertilizer"}
            },
            {
                title = _U('MENU__PLANT__WATER'),
                description = math.floor(plantData.water).. '%',
                icon = "droplet",
                metadata = {
                    _U('MENU__PLANT__WATER__META')
                },
                arrow = true,
                progress = math.floor(plantData.water),
                colorScheme = "blue",
                event = "it-drugs:client:showItemMenu",
                args = {entity = plantData.entity, type = plantData.type, eventType = "water"}
            },
            {
                title = _U('MENU__PLANT__DESTROY'),
                icon = "fire",
                description = _U('MENU__PLANT__DESTROY__DESC'),
                arrow = true,
                event = "it-drugs:client:destroyPlant",
                args = {entity = plantData.entity, type = plantData.type}
            }
        }

        if isAdmin then
            table.insert(options, {
                title = _U('MENU__PLANT__FORCE_GROW'),
                description = _U('MENU__PLANT__FORCE_GROW__DESC'),
                icon = "forward-fast",
                arrow = true,
                onSelect = function()
                    TriggerServerEvent('it-drugs:server:forceGrowPlant', {id = plantData.id})
                end
            })
        end

        for _, opt in ipairs(getLightOptions(plantData)) do
            table.insert(options, opt)
        end

        if plantData.potEntity then
            table.insert(options, {
                title = _U('MENU__POT__MOVE'),
                description = _U('MENU__POT__MOVE__DESC'),
                icon = "up-down-left-right",
                arrow = true,
                event = "it-drugs:client:movePot",
                args = { entity = plantData.potEntity, item = plantData.potItem, hasSoil = plantData.potHasSoil }
            })
        end

        lib.registerContext({
            id = "it-drugs-plant-menu",
            title = _U('MENU__PLANT'):format(plantName),
            options = options
        })
        lib.showContext("it-drugs-plant-menu")
    end
end)

RegisterNetEvent('it-drugs:client:showItemMenu', function(data)
    local entity = data.entity
    local type = data.type
    local eventType = data.eventType

    local options = {}
    if eventType == 'water' then
        for item, itemData in pairs(Config.Items) do
            if it.hasItem(item, 1) and itemData.water ~= 0 then
                table.insert(options, {
                    title = it.getItemLabel(item),
                    description = _U('MENU__ITEM__DESC'),
                    metadata = {
                        {label = _U('MENU__PLANT__WATER'), value = itemData.water},
                        {label = _U('MENU__PLANT__FERTILIZER'), value = itemData.fertilizer}
                    },
                    arrow = true,
                    event = 'it-drugs:client:useItem',
                    args = {entity = entity, type = type, item = item}
                })
            end
        end
    elseif eventType == 'fertilizer' then
        for item, itemData in pairs(Config.Items) do
            if it.hasItem(item, 1) and itemData.fertilizer ~= 0 then
                table.insert(options, {
                    title = it.getItemLabel(item),
                    description = _U('MENU__ITEM__DESC'),
                    metadata = {
                        {label = _U('MENU__PLANT__WATER'), value = itemData.water},
                        {label = _U('MENU__PLANT__FERTILIZER'), value = itemData.fertilizer}
                    },
                    arrow = true,
                    event = 'it-drugs:client:useItem',
                    args = {entity = entity, type = type, item = item}
                })
            end
        end
    end
    if #options == 0 then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), 'error')
        return
    end

    lib.registerContext({
        id = "it-drugs-item-menu",
        title = _U('MENU__ITEM'),
        options = options
    })

    lib.showContext("it-drugs-item-menu")
end)

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ ____                              _               __  __                  │
-- │|  _ \ _ __ ___   ___ ___  ___ ___(_)_ __   __ _  |  \/  | ___ _ __  _   _ │
-- │| |_) | '__/ _ \ / __/ _ \/ __/ __| | '_ \ / _` | | |\/| |/ _ \ '_ \| | | |│
-- │|  __/| | | (_) | (_|  __/\__ \__ \ | | | | (_| | | |  | |  __/ | | | |_| |│
-- │|_|   |_|  \___/ \___\___||___/___/_|_| |_|\__, | |_|  |_|\___|_| |_|\__,_|│
-- │                                           |___/                           │
-- └───────────────────────────────────────────────────────────────────────────┘
-- Processing Menu
RegisterNetEvent('it-drugs:client:showRecipesMenu', function(data)

    local tableType = Config.ProcessingTables[data.type]
    local options = {}

    for k, v in pairs(tableType.recipes) do
        local ingredientList = {}

        for ingredient, amount in pairs(v.ingrediants) do
            local ingredientLabel = Config.ShowIngrediants and it.getItemLabel(ingredient) or _U('MENU__UNKNOWN__INGREDIANT')
            table.insert(ingredientList, ('%gx %s'):format(amount, ingredientLabel))
        end

        if v.tools then
            for tool, amount in pairs(v.tools) do
                local toolLabel = Config.ShowIngrediants and it.getItemLabel(tool) or _U('MENU__UNKNOWN__INGREDIANT')
                table.insert(ingredientList, ('%gx %s (%s)'):format(amount, toolLabel, _U('MENU__RECIPE__TOOL__TAG')))
            end
        end

        table.insert(options, {
            title = v.label,
            description = _U('MENU__RECIPE__INGREDIANTS__DESC'):format(table.concat(ingredientList, ', ')),
            icon = "flask-vial",
            arrow = true,
            event = "it-drugs:client:showProcessingMenu",
            args = {entity = data.entity, recipe = k, type = data.type}
        })
    end

    table.insert(options, {
        title = _U('MENU__TABLE__REMOVE'),
        icon = "ban",
        description = _U('MENU__TABLE__REMOVE__DESC'),
        arrow = true,
        event = "it-drugs:client:removeTable",
        args = {entity = data.entity, type = data.type}
    })

    lib.registerContext({
        id = "it-drugs-recipes-menu",
        title = _U('MENU__PROCESSING'),
        options = options
    })

    lib.showContext("it-drugs-recipes-menu")
end)

RegisterNetEvent("it-drugs:client:showProcessingMenu", function(data)

    local tableType = data.type
    local recipe = Config.ProcessingTables[tableType].recipes[data.recipe]

    local options = {}
    if not Config.ShowIngrediants then
        for k, v in pairs(recipe.ingrediants) do
            -- Menu only shows the amount not the name of the item
            table.insert(options, {
                title = _U('MENU__UNKNOWN__INGREDIANT'),
                description = _U('MENU__INGREDIANT__DESC'):format(v),
                icon = "flask",
            })
        end
    else
        for k, v in pairs(recipe.ingrediants) do
            table.insert(options, {
                title = it.getItemLabel(k),
                description = _U('MENU__INGREDIANT__DESC'):format(v), --:replace("{amount}", v),
                icon = "flask",
            })
        end
    end

    if recipe.tools then
        for k, v in pairs(recipe.tools) do
            table.insert(options, {
                title = Config.ShowIngrediants and it.getItemLabel(k) or _U('MENU__UNKNOWN__INGREDIANT'),
                description = _U('MENU__TOOL__DESC'):format(v),
                icon = "screwdriver-wrench",
            })
        end
    end

    table.insert(options, {
        title = _U('MENU__TABLE__PROCESS'),
        icon = "play",
        description = _U('MENU__TABLE__PROCESS__DESC'),
        arrow = true,
        event = "it-drugs:client:processDrugs",
        args = {entity = data.entity, type = data.type, recipe = data.recipe}
    })

    lib.registerContext({
        id = "it-drugs-processing-menu",
        title = recipe.label,
        options = options,
        menu = 'it-drugs-recipes-menu',
        onBack = function()
            TriggerEvent('it-drugs:client:showRecipesMenu', {type = data.type, entity = data.entity})
        end,
    })
    lib.showContext("it-drugs-processing-menu")
end)

-- ┌──────────────────────────────────────────┐
-- │ ____       _ _   __  __                  │
-- │/ ___|  ___| | | |  \/  | ___ _ __  _   _ │
-- │\___ \ / _ \ | | | |\/| |/ _ \ '_ \| | | |│
-- │ ___) |  __/ | | | |  | |  __/ | | | |_| |│
-- │|____/ \___|_|_| |_|  |_|\___|_| |_|\__,_|│
-- └──────────────────────────────────────────┘
-- Sell Menu

RegisterNetEvent("it-drugs:client:showSellMenu", function(data)
    local item = data.item
    local amount = data.amount
    local price = data.price
    local ped = data.entity

    local itemLabel = it.getItemLabel(item)

    lib.registerContext({
        id = "it-drugs-sell-menu",
        title = _U('MENU__SELL'),
        options = {
            {
                title = _U('MENU__SELL__DEAL'),
                description = _U('MENU__SELL__DESC'):format(itemLabel, amount, amount * price),
                icon = "coins",
            },
            {
                title = _U('MENU__SELL__ACCEPT'),
                icon = "circle-check",
                description = _U('MENU__SELL__ACCEPT__DESC'),
                arrow = true,
                event = "it-drugs:client:salesInitiate",
                args = {type = 'buy', item = item, price = price, amount = amount, tped = ped}
            },
            {
                title = _U('MENU__SELL__REJECT'),
                icon = "circle-xmark",
                description = _U('MENU__SELL__REJECT__DESC'),
                arrow = true,
                event = "it-drugs:client:salesInitiate",
                args = {type = 'close', tped = ped}
            }
        }
    })
    lib.showContext("it-drugs-sell-menu")
end)

-- ┌──────────────────────────────────────────────────────────┐
-- │    _       _           _         __  __                  │
-- │   / \   __| |_ __ ___ (_)_ __   |  \/  | ___ _ __  _   _ │
-- │  / _ \ / _` | '_ ` _ \| | '_ \  | |\/| |/ _ \ '_ \| | | |│
-- │ / ___ \ (_| | | | | | | | | | | | |  | |  __/ | | | |_| |│
-- │/_/   \_\__,_|_| |_| |_|_|_| |_| |_|  |_|\___|_| |_|\__,_|│
-- └──────────────────────────────────────────────────────────┘

local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

RegisterNetEvent('it-drugs:client:showMainAdminMenu', function(data)

    local menuType = data.menuType
    if menuType == 'plants' then
        local allPlants = lib.callback.await('it-drugs:server:getPlants', false)
        local plantCount = tablelength(allPlants)

        lib.registerContext({
            id = "it-drugs-admin-main-menu-plants",
            title = _U('MENU__ADMIN__PLANT__MAIN'),
            options = {
                {
                    title = _U('MENU__PLANT__COUNT'),
                    description = _U('MENU__PLANT__COUNT__DESC'):format(plantCount),
                    icon = "seedling",
                },
                {
                    title = _U('MENU__LIST__PLANTS'),
                    description = _U('MENU__LIST__PLANTS__DESC'),
                    icon = "list",
                    arrow = true,
                    event = "it-drugs:client:generatePlantListMenu",
                },
                {
                    title = _U('MENU__ADD__BLIPS'),
                    description = _U('MENU__ADD__PLANT__BLIPS__DESC'),
                    icon = "map-location-dot",
                    arrow = true,
                    event = "it-drugs:client:addAllAdminBlips",
                    args = {type = 'plants'}
                },
                {
                    title = _U('MENU__REMOVE__BLIPS'),
                    description = _U('MENU__REMOVE__PLANT__BLIPS__DESC'),
                    icon = "eraser",
                    arrow = true,
                    event = "it-drugs:client:removeAllAdminBlips",
                    args = {type = 'plants'}
                },
            }
        })
        lib.showContext("it-drugs-admin-main-menu-plants")
    elseif menuType == 'tables' then
        local allTables = lib.callback.await('it-drugs:server:getTables', false)
        local tableCount = tablelength(allTables)

        lib.registerContext({
            id = "it-drugs-admin-main-menu-tables",
            title = _U('MENU__ADMIN__TABLE__MAIN'),
            options = {
                {
                    title = _U('MENU__TABLE__COUNT'),
                    description = _U('MENU__TABLE__COUNT__DESC'):format(tableCount),
                    icon = "flask-vial",
                },
                {
                    title = _U('MENU__LIST__TABLES'),
                    description = _U('MENU__LIST__TABLES__DESC'),
                    icon = "list",
                    arrow = true,
                    event = "it-drugs:client:generateTableListMenu",
                },
                {
                    title = _U('MENU__ADD__BLIPS'),
                    description = _U('MENU__ADD_TABLE__BLIPS__DESC'),
                    icon = "map-location-dot",
                    arrow = true,
                    event = "it-drugs:client:addAllAdminBlips",
                    args = {type = 'tables'}
                },
                {
                    title = _U('MENU__REMOVE__BLIPS'),
                    description = _U('MENU__REMOVE__TABLE__BLIPS__DESC'),
                    icon = "eraser",
                    arrow = true,
                    event = "it-drugs:client:removeAllAdminBlips",
                    args = {type = 'tables'}
                },
            }
        })
        lib.showContext("it-drugs-admin-main-menu-tables")
    elseif menuType == 'waterpoints' then
        local allPoints = lib.callback.await('it-drugs:server:getWaterPoints', false)
        local pointCount = tablelength(allPoints)

        lib.registerContext({
            id = "it-drugs-admin-main-menu-waterpoints",
            title = _U('MENU__ADMIN__WATERPOINT__MAIN'),
            options = {
                {
                    title = _U('MENU__WATERPOINT__COUNT'),
                    description = _U('MENU__WATERPOINT__COUNT__DESC'):format(pointCount),
                    icon = "faucet-drip",
                },
                {
                    title = _U('MENU__WATERPOINT__CREATE'),
                    description = _U('MENU__WATERPOINT__CREATE__DESC'),
                    icon = "plus",
                    arrow = true,
                    event = "it-drugs:client:placeWaterPoint",
                },
                {
                    title = _U('MENU__LIST__WATERPOINTS'),
                    description = _U('MENU__LIST__WATERPOINTS__DESC'),
                    icon = "list",
                    arrow = true,
                    event = "it-drugs:client:generateWaterPointListMenu",
                },
            }
        })
        lib.showContext("it-drugs-admin-main-menu-waterpoints")
    end
end)

RegisterNetEvent('it-drugs:client:showPlantListMenu', function(data)

    local plantList = data.plantList

    local options = {}
    for _, v in ipairs(plantList) do
        table.insert(options, {
            title = v.label,
            description = _U('MENU__DIST'):format(it.round(v.distance, 2)),
            icon = "seedling",
            arrow = true,
            event = "it-drugs:client:showPlantAdminMenu",
            args = {plantData = v}
        })
    end

    lib.registerContext({
        id = "it-drugs-plant-list-menu",
        title = _U('MENU__PLANT__LIST'),
        menu = 'it-drugs-placeholder',
        onBack = function()
            Wait(5)
            TriggerEvent('it-drugs:client:showMainAdminMenu', {menuType = 'plants'})
        end,
        options = options
    })
    lib.showContext("it-drugs-plant-list-menu")
end)

RegisterNetEvent('it-drugs:client:showTableListMenu', function(data)
    
    local tableList = data.tableList

    local options = {}
    for _, v in ipairs(tableList) do
        table.insert(options, {
            title = v.label,
            description = _U('MENU__DIST'):format(it.round(v.distance, 2)),
            icon = "flask-vial",
            arrow = true,
            event = "it-drugs:client:showTableAdminMenu",
            args = {tableData = v}
        })
    end

    lib.registerContext({
        id = "it-drugs-table-list-menu",
        title = _U('MENU__TABLE__LIST'),
        menu = 'it-drugs-placeholder',
        onBack = function()
            TriggerEvent('it-drugs:client:showMainAdminMenu', {menuType = 'tables'})
        end,
        options = options
    })
    lib.showContext("it-drugs-table-list-menu")
end)

RegisterNetEvent('it-drugs:client:showPlantAdminMenu', function(data)
    local plantData = data.plantData
    local streetNameHash, _ = GetStreetNameAtCoord(plantData.coords.x, plantData.coords.y, plantData.coords.z)
    local streetName = GetStreetNameFromHashKey(streetNameHash)

    lib.registerContext({
        id = "it-drugs-plant-admin-menu",
        title = _U('MENU__PLANT__ID'):format(plantData.id),
        menu = 'it-drugs-placeholder',
        onBack = function()
            TriggerEvent('it-drugs:client:generatePlantListMenu')
        end,
        options = {
            {
                title = _U('MENU__OWNER'),
                description = plantData.owner,
                icon = "user",
                metadata = {
                    _U('MENU__OWNER__META')
                },
                onSelect = function()
                    lib.setClipboard(plantData.owner)
                    ShowNotification(nil, _U('NOTIFICATION__COPY__CLIPBOARD'):format(plantData.owner), 'success')
                end
            },
            {
                title = _U('MENU__PLANT__LOCATION'),
                description = _U('MENU__LOCATION__DESC'):format(streetName, plantData.coords.x, plantData.coords.y, plantData.coords.z),
                metadata = {
                    _U('MENU__LOCATION__META')
                },
                icon = "map-marker",
                onSelect = function()
                    lib.setClipboard('('..plantData.coords.x..", "..plantData.coords.y..", "..plantData.coords.z..')')
                    ShowNotification(nil, _U('NOTIFICATION__COPY__CLIPBOARD'):format('('..plantData.coords.x..", "..plantData.coords.y..", "..plantData.coords.z..')'), 'success')
                end
            },
            {
                title = _U('MENU__PLANT__TELEPORT'),
                description = _U('MENU__PLANT__TELEPORT__DESC'),
                icon = "route",
                arrow = true,
                onSelect = function()
                    SetEntityCoords(PlayerPedId(), plantData.coords.x, plantData.coords.y, plantData.coords.z)
                    ShowNotification(nil, _U('NOTIFICATION__TELEPORTED'), 'success')
                end
            },
            {
                title = _U('MENU__ADD__BLIP'),
                description = _U('MENU__ADD__PLANT__BLIP__DESC'),
                icon = "map-location-dot",
                arrow = true,
                event = "it-drugs:client:addAdminBlip",
                args = {id = plantData.id, coords = plantData.coords, entityType = plantData.type, type = 'plant'}
            },
            {
                title = _U('MENU__PLANT__DESTROY'),
                description = _U('MENU__PLANT__DESTROY__DESC'),
                icon = "fire",
                arrow = true,
                onSelect = function()
                    TriggerServerEvent('it-drugs:server:destroyPlant', {entity = plantData.entity, extra='admin'})
                    ShowNotification(nil, _U('NOTIFICATION__PLANT__DESTROYED'), 'success')
                end
            },
            {
                title = _U('MENU__PLANT__FORCE_GROW'),
                description = _U('MENU__PLANT__FORCE_GROW__DESC'),
                icon = "forward-fast",
                arrow = true,
                onSelect = function()
                    TriggerServerEvent('it-drugs:server:forceGrowPlant', {id = plantData.id})
                end
            }
        }
    })
    lib.showContext("it-drugs-plant-admin-menu")
end)

RegisterNetEvent('it-drugs:client:showTableAdminMenu', function(data)
    local tableData = data.tableData
    local streetNameHash, _ = GetStreetNameAtCoord(tableData.coords.x, tableData.coords.y, tableData.coords.z)
    local streetName = GetStreetNameFromHashKey(streetNameHash)

    lib.registerContext({
        id = "it-drugs-table-admin-menu",
        title = _U('MENU__TABLE__ID'):format(tableData.id),
        menu = 'it-drugs-placeholder',
        onBack = function()
            TriggerEvent('it-drugs:client:generateTableListMenu')
        end,
        options = {
            {
                title = _U('MENU__PLANT__LOCATION'),
                description = _U('MENU__LOCATION__DESC'):format(streetName, tableData.coords.x, tableData.coords.y, tableData.coords.z),
                metadata = {
                    _U('MENU__LOCATION__META')
                },
                icon = "map-marker",
                onSelect = function()
                    lib.setClipboard('('..tableData.coords.x..", "..tableData.coords.y..", "..tableData.coords.z..')')
                    ShowNotification(nil, _U('NOTIFICATION__COPY__CLIPBOARD'):format('('..tableData.coords.x..", "..tableData.coords.y..", "..tableData.coords.z..')'), 'success')
                end
            },
            {
                title = _U('MENU__TABLE__TELEPORT'),
                description = _U('MENU__TABLE__TELEPORT__DESC'),
                icon = "route",
                arrow = true,
                onSelect = function()
                    SetEntityCoords(PlayerPedId(), tableData.coords.x, tableData.coords.y, tableData.coords.z)
                    ShowNotification(nil, _U('NOTIFICATION__TELEPORTED'), 'success')
                end
            },
            {
                title = _U('MENU__ADD__BLIP'),
                description = _U('MENU__ADD__TABLE__BLIP__DESC'),
                icon = "map-location-dot",
                arrow = true,
                event = "it-drugs:client:addAdminBlip",
                args = {id = tableData.id, coords = tableData.coords, entityType = tableData.type, type = 'table'}
            },
            {
                title = _U('MENU__TABLE__DESTROY'),
                description = _U('MENU__TABLE__DESTROY__DESC'),
                icon = "trash",
                arrow = true,
                onSelect = function()
                    TriggerServerEvent('it-drugs:server:removeTable', {entity = tableData.entity, extra='admin'})
                    ShowNotification(nil, _U('NOTIFICATION__TABLE__DESTROYED'), 'success')
                end,
                
            }
        }
    })
    lib.showContext("it-drugs-table-admin-menu")
end)

RegisterNetEvent('it-drugs:client:showWaterPointListMenu', function(data)
    local pointList = data.pointList

    local options = {}
    for _, v in ipairs(pointList) do
        table.insert(options, {
            title = v.label,
            description = _U('MENU__DIST'):format(it.round(v.distance, 2)),
            icon = "faucet-drip",
            arrow = true,
            event = "it-drugs:client:showWaterPointAdminMenu",
            args = {pointData = v}
        })
    end

    lib.registerContext({
        id = "it-drugs-waterpoint-list-menu",
        title = _U('MENU__WATERPOINT__LIST'),
        menu = 'it-drugs-placeholder',
        onBack = function()
            TriggerEvent('it-drugs:client:showMainAdminMenu', {menuType = 'waterpoints'})
        end,
        options = options
    })
    lib.showContext("it-drugs-waterpoint-list-menu")
end)

RegisterNetEvent('it-drugs:client:showWaterPointAdminMenu', function(data)
    local pointData = data.pointData
    local streetNameHash, _ = GetStreetNameAtCoord(pointData.coords.x, pointData.coords.y, pointData.coords.z)
    local streetName = GetStreetNameFromHashKey(streetNameHash)

    lib.registerContext({
        id = "it-drugs-waterpoint-admin-menu",
        title = pointData.label,
        menu = 'it-drugs-placeholder',
        onBack = function()
            TriggerEvent('it-drugs:client:generateWaterPointListMenu')
        end,
        options = {
            {
                title = _U('MENU__PLANT__LOCATION'),
                description = _U('MENU__LOCATION__DESC'):format(streetName, pointData.coords.x, pointData.coords.y, pointData.coords.z),
                metadata = {
                    _U('MENU__LOCATION__META')
                },
                icon = "map-marker",
                onSelect = function()
                    lib.setClipboard('('..pointData.coords.x..", "..pointData.coords.y..", "..pointData.coords.z..')')
                    ShowNotification(nil, _U('NOTIFICATION__COPY__CLIPBOARD'):format('('..pointData.coords.x..", "..pointData.coords.y..", "..pointData.coords.z..')'), 'success')
                end
            },
            {
                title = _U('MENU__WATERPOINT__TELEPORT'),
                description = _U('MENU__WATERPOINT__TELEPORT__DESC'),
                icon = "route",
                arrow = true,
                onSelect = function()
                    SetEntityCoords(PlayerPedId(), pointData.coords.x, pointData.coords.y, pointData.coords.z)
                    ShowNotification(nil, _U('NOTIFICATION__TELEPORTED'), 'success')
                end
            },
            {
                title = _U('MENU__WATERPOINT__REMOVE'),
                description = _U('MENU__WATERPOINT__REMOVE__DESC'),
                icon = "trash",
                arrow = true,
                onSelect = function()
                    TriggerServerEvent('it-drugs:server:removeWaterPoint', pointData.id)
                end
            }
        }
    })
    lib.showContext("it-drugs-waterpoint-admin-menu")
end)
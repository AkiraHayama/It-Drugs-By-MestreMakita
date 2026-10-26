if not Config.EnableProcessing then return end
local processingTables = {}

--- Method to setup all the weedplants, fetched from the database
--- @return nil
local setupTables = function()
    local result = MySQL.Sync.fetchAll('SELECT * FROM drug_processing')
    local current_time = os.time()

    for k, v in pairs(result) do
        local modelHash = GetHashKey(Config.ProcessingTables[v.type].model)
        local coords = json.decode(v.coords)
        local table = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(table, v.rotation + .0)
        Wait(100)
        FreezeEntityPosition(table, true)
        processingTables[table] = {
            id = v.id,
            coords = vector3(coords.x, coords.y, coords.z),
            type = v.type,
            rot = v.rotation + .0,
            entity = table,
            bench = v.bench and json.decode(v.bench) or nil, -- o que ficou em cima da mesa (cl_bench.lua)
        }
    end
end

--- Method to delete all cached weed plants and their entities
--- @return nil
local destroyAllTables = function()    
    for k, v in pairs(processingTables) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
            processingTables[k] = nil
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    while not DatabaseSetuped do
        Wait(100)
    end
    if Config.Debug then lib.print.info('Setting up Processing Tables') end
    setupTables()
    -- client que pediu a arrumação das mesas antes delas carregarem recebe agora
    for entity, data in pairs(processingTables) do
        if data.bench then TriggerClientEvent('it-drugs:client:benchLayout', -1, NetworkGetNetworkIdFromEntity(entity), data.bench) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyAllTables()
end)

RegisterNetEvent('it-drugs:server:processDrugs', function(entity, recipeName)

    if not processingTables[entity] then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - processingTables[entity].coords) > 10 then return end

    local player = it.getPlayer(source)
    if not player then return end

    -- Receita SEMPRE resolvida aqui a partir da Config, nunca aceita a tabela vinda do client -
    -- senão dava pra forjar um `recipe` com ingredientes vazios e outputs arbitrários (dupe de
    -- qualquer item, em qualquer quantidade, sem gastar nada).
    local tableConfig = Config.ProcessingTables[processingTables[entity].type]
    local recipe = tableConfig and tableConfig.recipes[recipeName]
    if not recipe then return end

    local givenItems = {}

    if recipe.tools then
        for k, v in pairs(recipe.tools) do
            if not it.hasItem(source, k, v) then
                ShowNotification(source, _U('NOTIFICATION__MISSING__TOOL'), 'error')
                return
            end
        end
    end

    local failChance = math.random(1, 100)
    if failChance <= recipe.failChance then
        ShowNotification(source, _U('NOTIFICATION__PROCESS__FAIL'), 'error')
        for k,v in pairs(recipe.ingrediants) do
            it.removeItem(source, k, v)
        end
        return
    end

    -- recipe.purityFrom: ingrediente cuja pureza média (Config.Purity) passa pros outputs
    local purity
    for k, v in pairs(recipe.ingrediants) do
        local removed
        if k == recipe.purityFrom then
            purity = it.takeItemWithPurity(source, k, v)
            removed = purity ~= nil
        else
            removed = it.removeItem(source, k, v)
        end
        if not removed then
            ShowNotification(source, _U('NOTIFICATION__MISSING__INGIDIANT'), 'error')
            if #givenItems > 0 then
                for _, x in pairs(givenItems) do
                    it.giveItem(source, x.name, x.amount, x.metadata)
                end
            end
            return
        else
            table.insert(givenItems, {name = k, amount = v, metadata = k == recipe.purityFrom and { purity = it.roundPurity(purity) } or nil})
        end
    end
    SendToWebhook(source, 'table', 'process', processingTables[entity])

    local outputMeta = purity and { purity = it.roundPurity(purity) } or nil
    for k, v in pairs(recipe.outputs) do
        it.giveItem(source, k, v, outputMeta)
    end
end)


--- Bancada: ainda tem coisa em cima da mesa? (faca, balança, zip lock, tijolo, cubos, contados ou prontos)
local function benchHasItems(bench)
    if not bench then return false end
    if next(bench.tools or {}) or bench.brick or bench.counted or bench.ready or bench.cready then return true end
    local stock = bench.stock
    return stock ~= nil and ((stock.film or 0) > 0 or next(stock.cubes or {}) ~= nil or next(stock.tools or {}) ~= nil or stock.brick ~= nil or stock.grinder ~= nil or next(stock.buds or {}) ~= nil or (stock.plastic or 0) > 0)
end

RegisterNetEvent('it-drugs:server:removeTable', function(args)
    local entity = args.entity
    if not processingTables[entity] then return end
    
    if args.extra == nil then
        if #(GetEntityCoords(GetPlayerPed(source)) - processingTables[entity].coords) > 10 then return end
        -- mesa só sai vazia: o que está em cima (estoque e prontos) se perderia junto
        if benchHasItems(processingTables[entity].bench) then
            return ShowNotification(source, _U('NOTIFICATION__TABLE__NOT__EMPTY'), 'error')
        end
        it.giveItem(source, processingTables[entity].type, 1)
    elseif not IsPlayerAceAllowed(source, 'admin') then -- o "extra" é o recolher do menu de admin
        return
    end
    SendToWebhook(source, 'table', 'remove', processingTables[entity])

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        MySQL.query('DELETE from drug_processing WHERE id = :id', {
            ['id'] = processingTables[entity].id
        })
        processingTables[entity] = nil
    end
    
end)

--- Bancada: grava a arrumação + os prontos da mesa no banco e avisa todo mundo (cl_bench.lua desenha)
local function saveBench(entity, data)
    MySQL.update('UPDATE drug_processing SET bench = ? WHERE id = ?', { json.encode(data.bench), data.id })
    TriggerClientEvent('it-drugs:client:benchLayout', -1, NetworkGetNetworkIdFromEntity(entity), data.bench)
end

-- Bancada: estoque da mesa (bench.stock, salvo no banco, só o servidor mexe). Cubos e zip lock soltos na mesa
-- SAEM do inventário e ficam aqui; embalar gasta daqui; botão direito devolve.
-- stock = { film = n, cubes = { variedade = { count, purity } }, tools = { knife/scale/grinder = metadata }, brick = { strain, purity },
--           grinder = { strain, count, purity } (buds curadas dentro do dichavador, modo camarão),
--           buds = { variedade = { count, purity } } (pilhas de buds curadas na mesa, modo camarão),
--           plastic = n (saquinhos plásticos na mesa, modo camarão); tools.cscale = balança do camarão;
--           grinder.ground = true quando já dichavou (a dichavada fica no dichavador até ir pra balança) }
local function benchStock(data)
    data.bench = data.bench or { tools = {}, piles = {} }
    local stock = data.bench.stock or { film = 0, cubes = {} }
    stock.cubes, stock.tools, stock.buds = stock.cubes or {}, stock.tools or {}, stock.buds or {}
    data.bench.stock = stock
    return stock
end

--- Tira 1 unidade do item (o primeiro slot) e devolve o metadata dele (a faca é arma: volta com o mesmo número de série)
local function takeOne(src, item)
    local slot = (exports.ox_inventory:Search(src, 'slots', item) or {})[1]
    if not slot or not exports.ox_inventory:RemoveItem(src, item, 1, nil, slot.slot) then return end
    return slot.metadata or {}
end

--- Cabe +amount cubos dessa variedade na mesa? (limite por variedade e quantas variedades cabem)
local function cubesFit(stock, strain, amount)
    local current = stock.cubes[strain]
    if not current then
        local strainsOnTable = 0
        for _ in pairs(stock.cubes) do strainsOnTable = strainsOnTable + 1 end
        if strainsOnTable >= #Config.Bench.pileSlots then return false end
    end
    return (current and current.count or 0) + amount <= Config.Bench.maxCubes
end

--- Junta numa pilha { count, purity } (pureza = média ponderada); devolve a pilha
local function mergePile(pile, amount, purity)
    if not pile then return { count = amount, purity = it.roundPurity(purity) } end
    pile.purity = it.roundPurity((pile.count * pile.purity + amount * purity) / (pile.count + amount))
    pile.count = pile.count + amount
    return pile
end

-- Um modo por vez na mesa: camarão (dichavador e buds) ou prensado (faca, balança, zip lock, tijolo, cubos, prontos)
local CAMARAO_KINDS = { grinder = true, bud = true, buds = true, cscale = true, plastic = true }
local function camaraoBusy(stock, bench)
    return stock.tools.grinder ~= nil or stock.tools.cscale ~= nil or stock.grinder ~= nil or next(stock.buds) ~= nil
        or (stock.plastic or 0) > 0 or bench.cready ~= nil
end
local function prensadoBusy(stock, bench)
    return stock.tools.knife ~= nil or stock.tools.scale ~= nil or (stock.film or 0) > 0 or next(stock.cubes) ~= nil
        or stock.brick ~= nil or bench.ready ~= nil
end

local function addCubes(stock, strain, amount, purity)
    local current = stock.cubes[strain]
    if current then -- pureza da pilha = média ponderada
        current.purity = it.roundPurity((current.count * current.purity + amount * purity) / (current.count + amount))
        current.count = current.count + amount
    else
        stock.cubes[strain] = { count = amount, purity = it.roundPurity(purity) }
    end
end

--- Mesa de bancada perto do jogador? (devolve os dados da mesa)
local function benchTable(src, entity)
    local data = processingTables[entity]
    if not data or not Config.Bench or data.type ~= Config.Bench.table then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - data.coords) > 10 then return end
    return data
end

-- Soltou cubos ('cube', variedade) ou zip lock ('film') na mesa: tira do inventário o que couber no limite
-- (Config.Bench.maxCubes por variedade, Config.Bench.maxFilm de zip lock, até #pileSlots variedades na mesa)
RegisterNetEvent('it-drugs:server:benchStock', function(entity, kind, strain)
    local src = source
    local data = benchTable(src, entity)
    if not data then return end
    local stock, P = benchStock(data), Config.Prensado
    if (CAMARAO_KINDS[kind] and prensadoBusy(stock, data.bench)) or (not CAMARAO_KINDS[kind] and camaraoBusy(stock, data.bench)) then
        return ShowNotification(src, _U('NOTIFICATION__BENCH__OTHER__MODE'), 'error')
    end
    if kind == 'film' then
        if stock.film > 0 and (stock.filmItem or 'plastico_filme') ~= P.filmItem then -- outro item no espaço do filme: tira ele primeiro
            return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error')
        end
        local amount = math.min(it.getItemCount(src, P.filmItem) or 0, Config.Bench.maxFilm - stock.film)
        if amount < 1 then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        if not it.removeItem(src, P.filmItem, amount) then return end
        stock.film, stock.filmItem = stock.film + amount, P.filmItem
    elseif kind == 'cube' and Config.WeedStrains[strain] then
        local cube = ('cubo_%s'):format(strain)
        local current = stock.cubes[strain]
        local amount = math.min(it.getItemCount(src, cube) or 0, Config.Bench.maxCubes - (current and current.count or 0))
        if amount < 1 or not cubesFit(stock, strain, amount) then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        local purity = it.takeItemWithPurity(src, cube, amount)
        if not purity then return end
        addCubes(stock, strain, amount, purity)
    elseif kind == 'buds' and Config.WeedStrains[strain] then -- buds curadas do inventário pra pilha da mesa (até o limite)
        local current = stock.buds[strain]
        if not current then
            local strainsOnTable = 0
            for _ in pairs(stock.buds) do strainsOnTable = strainsOnTable + 1 end
            if strainsOnTable >= #Config.Bench.budSlots then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        end
        local cured = ('weed_%s_curada'):format(strain)
        local amount = math.min(it.getItemCount(src, cured) or 0, Config.Bench.maxBuds - (current and current.count or 0))
        if amount < 1 then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        local purity = it.takeItemWithPurity(src, cured, amount)
        if not purity then return end
        stock.buds[strain] = mergePile(current, amount, purity)
    elseif kind == 'plastic' then -- saquinhos plásticos do inventário pra mesa (até Config.Bench.maxPlastic)
        local amount = math.min(it.getItemCount(src, Config.Bench.grinder.bagItem) or 0, Config.Bench.maxPlastic - (stock.plastic or 0))
        if amount < 1 then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        if not it.removeItem(src, Config.Bench.grinder.bagItem, amount) then return end
        stock.plastic = (stock.plastic or 0) + amount
    elseif kind == 'bud' and Config.WeedStrains[strain] then -- 1 bud da pilha da mesa pra dentro do dichavador (até grinder.capacity, uma variedade)
        local g, pile = stock.grinder, stock.buds[strain]
        if not stock.tools.grinder or not pile or (g and (g.ground or g.strain ~= strain or g.count >= Config.Bench.grinder.capacity)) then
            return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error')
        end
        pile.count = pile.count - 1
        if pile.count < 1 then stock.buds[strain] = nil end
        stock.grinder = mergePile(g, 1, pile.purity)
        stock.grinder.strain = strain
    elseif kind == 'knife' or kind == 'scale' or kind == 'grinder' or kind == 'cscale' then -- uma de cada na mesa
        if stock.tools[kind] then return end
        local meta = takeOne(src, (kind == 'knife' and P.knifeItem) or ((kind == 'scale' or kind == 'cscale') and P.scaleItem) or Config.Bench.grinder.item)
        if not meta then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        stock.tools[kind] = meta
    elseif kind == 'brick' and Config.WeedStrains[strain] then -- um tijolo no meio, esperando a faca
        if stock.brick then return end
        local purity = it.takeItemWithPurity(src, 'tijolo_' .. strain, 1)
        if not purity then return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error') end
        stock.brick = { strain = strain, purity = it.roundPurity(purity) }
    else
        return
    end
    saveBench(entity, data)
end)

--- Junta itens prontos na mesa: lista = bench.ready (prensado) ou bench.cready (camarão)
local function addReady(list, entries)
    list = list or { bags = 0, items = {} }
    for _, e in ipairs(entries) do
        local merged = false
        for _, r in ipairs(list.items) do
            if r.item == e.item and r.purity == e.purity then
                r.count, merged = r.count + e.count, true
                break
            end
        end
        if not merged then list.items[#list.items + 1] = { item = e.item, count = e.count, purity = e.purity } end
    end
    list.bags = list.bags + 1
    return list
end

--- Esvazia o dichavador: buds ainda inteiras voltam pra pilha da mesa; dichavada (já moída) vai pro inventário
local function emptyGrinder(src, stock)
    local g = stock.grinder
    if g.ground then
        if not it.giveItem(src, ('weed_%s_dichavada'):format(g.strain), g.count, { purity = g.purity }) then return false end
    else
        stock.buds = stock.buds or {}
        stock.buds[g.strain] = mergePile(stock.buds[g.strain], g.count, g.purity)
    end
    stock.grinder = nil
    return true
end

-- Botão direito numa pilha de cubos ('cube', variedade) ou no zip lock ('film'): volta tudo pro inventário
-- de quem tirou (o que não couber continua na mesa)
RegisterNetEvent('it-drugs:server:benchUnstock', function(entity, kind, strain)
    local src = source
    local data = benchTable(src, entity)
    if not data or not data.bench or not data.bench.stock then return end
    local stock = data.bench.stock
    if kind == 'film' and stock.film > 0 then
        -- devolve o item que entrou (mesas de antes guardavam plastico_filme sem filmItem)
        if it.giveItem(src, stock.filmItem or 'plastico_filme', stock.film) then stock.film, stock.filmItem = 0, nil end
    elseif kind == 'cube' and stock.cubes and stock.cubes[strain] then
        local s = stock.cubes[strain]
        if it.giveItem(src, ('cubo_%s'):format(strain), s.count, { purity = s.purity }) then stock.cubes[strain] = nil end
    elseif (kind == 'knife' or kind == 'scale' or kind == 'grinder' or kind == 'cscale') and stock.tools and stock.tools[kind] then
        local item = (kind == 'knife' and Config.Prensado.knifeItem) or ((kind == 'scale' or kind == 'cscale') and Config.Prensado.scaleItem)
            or Config.Bench.grinder.item
        if kind == 'grinder' and stock.grinder and not emptyGrinder(src, stock) then return end
        if it.giveItem(src, item, 1, stock.tools[kind]) then stock.tools[kind] = nil end
    elseif kind == 'bud' and stock.grinder then -- o que está dentro do dichavador
        if not emptyGrinder(src, stock) then return end
    elseif kind == 'plastic' and (stock.plastic or 0) > 0 then
        if it.giveItem(src, Config.Bench.grinder.bagItem, stock.plastic) then stock.plastic = 0 end
    elseif kind == 'buds' and stock.buds and stock.buds[strain] then -- pilha de buds da mesa volta pro inventário
        local b = stock.buds[strain]
        if it.giveItem(src, ('weed_%s_curada'):format(strain), b.count, { purity = b.purity }) then stock.buds[strain] = nil end
    elseif kind == 'brick' and stock.brick then
        if it.giveItem(src, 'tijolo_' .. stock.brick.strain, 1, { purity = stock.brick.purity }) then stock.brick = nil end
    else
        return
    end
    saveBench(entity, data)
end)

-- Modo camarão: tampa no dichavador cheio (grinder.capacity buds) = dichava. A dichavada fica NO dichavador
-- (grinder.ground) até ser arrastada pra balança e ensacada (benchBag).
RegisterNetEvent('it-drugs:server:benchGrind', function(entity)
    local src = source
    local data = benchTable(src, entity)
    if not data then return end
    local stock = benchStock(data)
    local g, capacity = stock.grinder, Config.Bench.grinder.capacity
    if not stock.tools.grinder or not g or g.ground or g.count < capacity then
        return ShowNotification(src, _U('NOTIFICATION__BENCH__GRINDER__FILL'):format(capacity), 'error')
    end
    g.ground = true
    saveBench(entity, data)
end)

-- Modo camarão: dichavada do dichavador na balança da mesa -> saquinho. 1 dichavada + 1 zip lock (da mesa)
-- = 1 weed_<variedade>_saquinho (pureza da bud), que fica no "Produto pronto" da mesa (bench.cready) até alguém
-- clicar nele (benchCollect 'camarao').
RegisterNetEvent('it-drugs:server:benchBag', function(entity)
    local src = source
    local data = benchTable(src, entity)
    if not data then return end
    local stock = benchStock(data)
    local g = stock.grinder
    if not stock.tools.cscale or not g or not g.ground or (stock.plastic or 0) < g.count then
        return ShowNotification(src, _U('NOTIFICATION__BENCH__NEED__BAG'), 'error')
    end
    data.bench.cready = addReady(data.bench.cready, { { item = ('weed_%s_saquinho'):format(g.strain), count = g.count, purity = g.purity } })
    stock.plastic = stock.plastic - g.count
    stock.grinder = nil
    saveBench(entity, data)
    SendToWebhook(src, 'table', 'process', data)
end)

-- Faca da mesa no tijolo da mesa: corta. Os cubos (Config.Prensado.cubesPerBrick, pureza do tijolo) vão direto pro
-- estoque de cubos da mesa; não corta se não couberem (limite por variedade / variedades na mesa).
RegisterNetEvent('it-drugs:server:benchCut', function(entity)
    local src = source
    local data = benchTable(src, entity)
    if not data then return end
    local stock = benchStock(data)
    if not stock.brick or not stock.tools.knife then
        return ShowNotification(src, _U('NOTIFICATION__MISSING__TOOL'), 'error')
    end
    local strain, amount = stock.brick.strain, Config.Prensado.cubesPerBrick
    if not cubesFit(stock, strain, amount) then
        return ShowNotification(src, _U('NOTIFICATION__BENCH__LIMIT'), 'error')
    end
    addCubes(stock, strain, amount, stock.brick.purity)
    stock.brick = nil
    saveBench(entity, data)
    SendToWebhook(src, 'table', 'process', data)
end)

-- Bancada (client/cl_bench.lua): embala os cubos contados no meio, podendo misturar variedades.
-- mix = { variedade = quantos }, somando Config.Prensado.cubesPerWrap; 1 zip lock por cubo; precisa da balança.
-- Gasta do ESTOQUE da mesa (cubos e zip lock que o jogador pôs nela); cada variedade sai embalada com a pureza
-- da sua pilha. Os embalados ficam NA MESA (bench.ready) até alguém clicar nos Prontos (benchCollect).
RegisterNetEvent('it-drugs:server:benchWrap', function(entity, mix)
    local src = source
    local data = benchTable(src, entity)
    if not data or type(mix) ~= 'table' then return end

    local P = Config.Prensado
    local total, list = 0, {}
    for strain, n in pairs(mix) do
        n = tonumber(n)
        if not Config.WeedStrains[strain] or not n or n < 1 or n ~= math.floor(n) then return end
        total = total + n
        list[#list + 1] = { strain = strain, n = n }
    end
    if total ~= P.cubesPerWrap then return end
    local stock = benchStock(data)
    if not stock.tools.scale then -- balança da mesa
        return ShowNotification(src, _U('NOTIFICATION__MISSING__TOOL'), 'error')
    end
    if stock.film > 0 and (stock.filmItem or 'plastico_filme') ~= P.filmItem then -- outro item no espaço do filme
        return ShowNotification(src, _U('NOTIFICATION__BENCH__OLD__FILM'), 'error')
    end
    local enough = stock.film >= P.filmPerWrap
    for _, e in ipairs(list) do enough = enough and stock.cubes[e.strain] ~= nil and stock.cubes[e.strain].count >= e.n end
    if not enough then
        return ShowNotification(src, _U('NOTIFICATION__MISSING__INGIDIANT'), 'error')
    end

    stock.film = stock.film - P.filmPerWrap
    local ready = data.bench.ready or { bags = 0, items = {} }
    for _, e in ipairs(list) do
        local pile = stock.cubes[e.strain]
        pile.count = pile.count - e.n
        if pile.count < 1 then stock.cubes[e.strain] = nil end
        local item, merged = ('cubo_%s_embalado'):format(e.strain), false
        for _, r in ipairs(ready.items) do
            if r.item == item and r.purity == pile.purity then
                r.count, merged = r.count + e.n, true
                break
            end
        end
        if not merged then ready.items[#ready.items + 1] = { item = item, count = e.n, purity = pile.purity } end
    end
    ready.bags = ready.bags + 1
    data.bench.ready = ready
    data.bench.wrapped = math.min(ready.bags, 6)
    saveBench(entity, data)
    SendToWebhook(src, 'table', 'process', data)
end)

-- Bancada: clicou nos Prontos (prensado) ou no Produto pronto (which = 'camarao') = leva tudo que está ali
-- (quem estiver na mesa leva). O que não couber no inventário continua na mesa.
RegisterNetEvent('it-drugs:server:benchCollect', function(entity, which)
    local src = source
    local data = benchTable(src, entity)
    local key = which == 'camarao' and 'cready' or 'ready'
    if not data or not data.bench or not data.bench[key] then return end
    local left = {}
    for _, r in ipairs(data.bench[key].items) do
        if not it.giveItem(src, r.item, r.count, { purity = r.purity }) then left[#left + 1] = r end
    end
    data.bench[key] = #left > 0 and { bags = 1, items = left } or nil
    if key == 'ready' then data.bench.wrapped = #left > 0 and 1 or 0 end
    saveBench(entity, data)
    ShowNotification(src, _U(#left > 0 and 'NOTIFICATION__BENCH__COLLECT__FULL' or 'NOTIFICATION__BENCH__COLLECTED'), #left > 0 and 'error' or 'success')
end)

RegisterNetEvent('it-drugs:server:createNewTable', function(coords, type, rotation, metadata)
    local src = source
    local player = it.getPlayer(src)
    local tableInfos = Config.ProcessingTables[type]

    if not player then if Config.Debug then lib.print.error("No Player") end return end
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > Config.PlaceMaxDistance + 2.0 then return end -- longe do boneco (Config.PlaceMaxDistance + folga)

    if it.removeItem(src, type, 1, metadata) then
        local modelHash = GetHashKey(tableInfos.model)
        local table = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(table, rotation)
        FreezeEntityPosition(table, true)

        MySQL.insert('INSERT INTO `drug_processing` (coords, type, rotation) VALUES (:coords, :type, :rotation)', {
            ['coords'] = json.encode(coords),
            ['type'] = type,
            ['rotation'] = rotation
        }, function(id)
            processingTables[table] = {
                id = id,
                coords = coords,
                type = type,
                rot = rotation,
                entity = table
            }
            SendToWebhook(src, 'table', 'place', processingTables[table])
        end)
    else
        if Config.Debug then lib.print.error("Can not remove item") end
    end
end)

-- Callbacks
lib.callback.register('it-drugs:server:getTableData', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if Config.Debug then lib.print.info('Getting Data for entity', entity) end
    if not processingTables[entity] then return nil end
    local temp = {
        id = processingTables[entity].id,
        coords = processingTables[entity].coords,
        type = processingTables[entity].type,
        rot = processingTables[entity].rot,
        entity = entity,
        notEmpty = benchHasItems(processingTables[entity].bench), -- "Recolher Mesa" avisa antes da barra de progresso
    }
    if Config.Debug then lib.print.info('Returning Data', temp) end
    return temp
end)

lib.callback.register('it-drugs:server:getTables', function(source)
    return processingTables
end)

-- Bancada (client/cl_bench.lua): o que o jogador deixou em cima da mesa. É só visual (os itens ficam no
-- inventário), mas vem do client: aceita só os campos conhecidos, posição perto da mesa e variedade que existe.
local function benchSpot(p)
    if type(p) ~= 'table' then return end
    local x, y = tonumber(p.x), tonumber(p.y)
    if not x or not y or math.abs(x) > 2.0 or math.abs(y) > 2.0 then return end
    return { x = x, y = y }
end

local function cleanBench(layout)
    if type(layout) ~= 'table' then return end
    local clean = { tools = {}, piles = {} }
    for _, key in ipairs({ 'knife', 'scale', 'film' }) do
        clean.tools[key] = type(layout.tools) == 'table' and benchSpot(layout.tools[key]) or nil
    end
    local brick = layout.brick
    if type(brick) == 'table' and Config.WeedStrains[brick.strain] then
        local p = benchSpot(brick)
        if p then clean.brick = { strain = brick.strain, x = p.x, y = p.y } end
    end
    -- cubos recém-cortados que ficaram no meio (só visual: os cubos já estão no estoque da mesa)
    if not clean.brick and Config.WeedStrains[layout.cutpile] then clean.cutpile = layout.cutpile end
    -- cubos contados no meio esperando o zip lock (só visual: só saem do inventário ao embalar)
    if not clean.brick and not clean.cutpile and type(layout.counted) == 'table' then
        local counted, total = {}, 0
        for strain, n in pairs(layout.counted) do
            n = tonumber(n)
            if Config.WeedStrains[strain] and n and n >= 1 and n == math.floor(n) then
                counted[strain], total = n, total + n
            end
        end
        if total > 0 and total <= Config.Prensado.cubesPerWrap then clean.counted = counted end
    end
    if type(layout.piles) == 'table' then
        for strain, p in pairs(layout.piles) do
            if Config.WeedStrains[strain] then clean.piles[strain] = benchSpot(p) end
        end
    end
    clean.wrapped = math.max(0, math.min(6, math.floor(tonumber(layout.wrapped) or 0)))
    clean.mode = layout.mode == 'camarao' and 'camarao' or 'prensado' -- o que a mesa mostra (último modo usado)
    return clean
end

lib.callback.register('it-drugs:server:getBenchLayouts', function(source)
    local list = {}
    for entity, data in pairs(processingTables) do
        if data.bench and DoesEntityExist(entity) then list[NetworkGetNetworkIdFromEntity(entity)] = data.bench end
    end
    return list
end)

RegisterNetEvent('it-drugs:server:setBenchLayout', function(netId, layout)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local data = processingTables[entity]
    if not data or (Config.Bench and data.type ~= Config.Bench.table) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - data.coords) > 10.0 then return end
    local clean = cleanBench(layout)
    if not clean then return end
    -- os prontos são do servidor: o client não muda (nem a quantidade de saquinhos que aparece)
    clean.ready = data.bench and data.bench.ready or nil
    clean.stock = data.bench and data.bench.stock or nil -- estoque da mesa também é só do servidor
    clean.cready = data.bench and data.bench.cready or nil -- produto pronto do camarão também
    clean.wrapped = clean.ready and math.min(clean.ready.bags, 6) or 0
    data.bench = clean
    MySQL.update('UPDATE drug_processing SET bench = ? WHERE id = ?', { json.encode(clean), data.id })
    TriggerClientEvent('it-drugs:client:benchLayout', -1, netId, clean)
end)
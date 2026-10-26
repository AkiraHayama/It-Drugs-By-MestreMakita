-- Bancada da mesa de maconha (Config.Bench): enfeite sempre em cima da mesa + "Usar bancada" no E.
-- Na bancada a tela (resource itdrugs_bancada) mostra uma barra com o que o jogador tem; ele arrasta da barra
-- pro espaço marcado de cada coisa (Config.Bench.slots: tracejado + nome) e o prop encaixa ali (o item não sai
-- do inventário). O meio ("Fabricação") é onde se trabalha:
--   tijolo no meio + faca nele = corta (vira cubos no meio) -> cubos pro espaço "Cubos" ->
--   um cubo por vez na balança (pesa e vai sozinho pro meio, conta até 10) -> zip lock nos 10 = embala ->
--   saquinho pronto pro espaço "Prontos".
-- Quem confere e troca os itens é o servidor (receitas cortar_/embalar_ do sv_processing).
local bench = Config.Bench
if not bench or not Config.EnableProcessing then return end

local P = Config.Prensado
local tableModel = joaat(Config.ProcessingTables[bench.table].model)

--- Ponto em cima do tampo: along/across em fração do tamanho do modelo (along = lado comprido; across negativo =
--- frente) + mAlong/mAcross em metros
local function tablePoint(tbl, along, across, dz, mAlong, mAcross)
    local mn, mx = GetModelDimensions(GetEntityModel(tbl))
    local sx, sy = mx.x - mn.x, mx.y - mn.y
    local cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    local x, y
    if sx >= sy then
        x, y = cx + along * sx + (mAlong or 0.0), cy + across * sy + (mAcross or 0.0)
    else
        x, y = cx + across * sx + (mAcross or 0.0), cy + along * sy + (mAlong or 0.0)
    end
    return GetOffsetFromEntityInWorldCoords(tbl, x, y, mx.z + bench.topOffset + (dz or 0.0))
end

--- Centro de um espaço marcado (Config.Bench.slots, em metros a partir do meio da mesa) + deslocamento em metros
local function slotPoint(tbl, key, mAlong, mAcross, dz)
    local slot = bench.slots[key]
    return tablePoint(tbl, 0.0, 0.0, dz, slot.along + (mAlong or 0.0), slot.across + (mAcross or 0.0))
end

--- Onde o prop fica dentro do espaço: o centro + slot.prop (metros), pra prop com a origem fora do meio (faca)
local function propPoint(tbl, key)
    local off = bench.slots[key].prop
    return slotPoint(tbl, key, off and off[1] or 0.0, off and off[2] or 0.0)
end

--- O ponto (no tampo) está dentro do espaço marcado? (com uma folga pra não precisar mirar no milímetro)
local function inSlot(tbl, key, point)
    if not point then return false end
    local slot = bench.slots[key]
    local mn, mx = GetModelDimensions(GetEntityModel(tbl))
    local r = GetOffsetFromEntityGivenWorldCoords(tbl, point.x, point.y, point.z)
    local a, c
    if (mx.x - mn.x) >= (mx.y - mn.y) then
        a, c = r.x - (mn.x + mx.x) / 2, r.y - (mn.y + mx.y) / 2
    else
        a, c = r.y - (mn.y + mx.y) / 2, r.x - (mn.x + mx.x) / 2
    end
    local margin = 0.04
    return math.abs(a - slot.along) <= slot.w / 2 + margin and math.abs(c - slot.across) <= slot.d / 2 + margin
end

--- Desenho dos espaços marcados: borda tracejada arredondada com neon (brilho largo e fraco + traço fino forte),
--- fundinho bem leve e o nome no meio. A forma é calculada uma vez por sessão (a mesa não se mexe) e cada
--- frame só desenha os polígonos prontos.
local DASH, GAP, CORE, GLOW, RADIUS = 0.045, 0.026, 0.0035, 0.011, 0.035

--- Contorno arredondado do espaço em metros locais (along, across), fechado
local function roundedPath(w, d)
    local r = math.min(RADIUS, w, d)
    local pts = {}
    local corners = { { w - r, -d + r, -90 }, { w - r, d - r, 0 }, { -w + r, d - r, 90 }, { -w + r, -d + r, 180 } }
    for _, c in ipairs(corners) do
        for step = 0, 5 do
            local ang = math.rad(c[3] + step * 18)
            pts[#pts + 1] = { c[1] + math.cos(ang) * r, c[2] + math.sin(ang) * r }
        end
    end
    pts[#pts + 1] = pts[1]
    return pts
end

--- Quadrado de um traço p->q com meia largura `half` no plano do tampo
local function stripe(p, q, half)
    local dir = q - p
    local len = #dir
    if len < 0.0001 then return end
    local n = vector3(dir.y / len, -dir.x / len, 0.0) * half
    return { p - n, q - n, q + n, p + n }
end

--- Monta os polígonos de todos os espaços dessa mesa (mundo), uma vez por sessão
local function buildSlotShapes(tbl)
    local o = tablePoint(tbl, 0.0, 0.0, 0.004)
    local alongDir = tablePoint(tbl, 0.0, 0.0, 0.004, 1.0, 0.0) - o
    local acrossDir = tablePoint(tbl, 0.0, 0.0, 0.004, 0.0, 1.0) - o
    local shapes = {}
    for key, slot in pairs(bench.slots) do
        local function world(a, c) return o + alongDir * (slot.along + a) + acrossDir * (slot.across + c) end
        local path = roundedPath(slot.w / 2, slot.d / 2)
        local pts, dist = {}, { 0.0 }
        for i, p in ipairs(path) do
            pts[i] = world(p[1], p[2])
            if i > 1 then dist[i] = dist[i - 1] + #(pts[i] - pts[i - 1]) end
        end
        local function at(s) -- ponto a s metros do começo do contorno
            for i = 2, #pts do
                if s <= dist[i] then
                    local f = (s - dist[i - 1]) / math.max(dist[i] - dist[i - 1], 0.0001)
                    return pts[i - 1] + (pts[i] - pts[i - 1]) * f, i
                end
            end
            return pts[#pts], #pts
        end
        local shape = {
            core = {}, glow = {}, fill = {},
            center = world(0.0, 0.0) + vector3(0.0, 0.0, 0.01),
            below = world(0.0, -slot.d / 2 - 0.035) + vector3(0.0, 0.0, 0.01), -- nome fica embaixo do espaço (lado do jogador)
        }
        local s, total = 0.0, dist[#dist]
        while s < total do -- cada traço segue a curva: quebra nos vértices do contorno
            local e = math.min(s + DASH, total)
            local a, ia = at(s)
            local b, ib = at(e)
            local chain = { a }
            for i = ia, ib - 1 do chain[#chain + 1] = pts[i] end
            chain[#chain + 1] = b
            for i = 1, #chain - 1 do
                shape.core[#shape.core + 1] = stripe(chain[i], chain[i + 1], CORE)
                shape.glow[#shape.glow + 1] = stripe(chain[i], chain[i + 1], GLOW)
            end
            s = e + GAP
        end
        for i = 1, #pts - 1 do shape.fill[#shape.fill + 1] = { shape.center - vector3(0.0, 0.0, 0.006), pts[i], pts[i + 1] } end
        shapes[key] = shape
    end
    return shapes
end

local function poly(p, q, w, r, g, b, a) -- os dois lados, pra aparecer de qualquer ângulo
    DrawPoly(p.x, p.y, p.z, q.x, q.y, q.z, w.x, w.y, w.z, r, g, b, a)
    DrawPoly(w.x, w.y, w.z, q.x, q.y, q.z, p.x, p.y, p.z, r, g, b, a)
end

local function text3d(at, text, r, g, b, a, size)
    SetDrawOrigin(at.x, at.y, at.z, 0)
    SetTextScale(0.0, size)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(r, g, b, a)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, -0.014)
    ClearDrawOrigin()
end

--- Desenha um espaço: cor do espaço (Config.Bench.slots[..].color), força 0..1, o nome (embaixo, sempre) e um
--- texto no meio (nil = nenhum; ex.: 3/10 dos cubos contados)
local function drawSlot(shape, color, strength, label, inside)
    local r, g, b = color[1], color[2], color[3]
    for _, q in ipairs(shape.glow) do
        poly(q[1], q[2], q[3], r, g, b, math.floor(45 * strength))
        poly(q[1], q[3], q[4], r, g, b, math.floor(45 * strength))
    end
    for _, q in ipairs(shape.core) do
        poly(q[1], q[2], q[3], r, g, b, math.floor(235 * strength))
        poly(q[1], q[3], q[4], r, g, b, math.floor(235 * strength))
    end
    for _, t in ipairs(shape.fill) do poly(t[1], t[2], t[3], r, g, b, math.floor(16 * strength)) end
    text3d(shape.below, label, r, g, b, math.floor(255 * math.min(strength + 0.35, 1.0)), 0.28)
    if inside then text3d(shape.center, inside, 255, 255, 255, 240, 0.34) end
end

local function spawnProp(model, coords, heading)
    local hash = joaat(model)
    if not IsModelValid(hash) then
        print(('[it-drugs] bancada: modelo inválido %s'):format(model))
        return
    end
    lib.requestModel(hash)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

-- Prop encolhido (cubinho): o GTA desenha menor pela matriz da entidade. Mover sempre por moveProp,
-- que reaplica a escala e leva junto os "seguidores" (os outros cubinhos da pilha).
local scaleOf, followers = {}, {} -- prop -> escala; prop -> { { prop, deslocamento } }
local function setScaled(obj, pos)
    local s = scaleOf[obj]
    local f, r, u = GetEntityMatrix(obj)
    f, r, u = f / #f * s, r / #r * s, u / #u * s
    SetEntityMatrix(obj, f.x, f.y, f.z, r.x, r.y, r.z, u.x, u.y, u.z, pos.x, pos.y, pos.z)
end

local function moveProp(obj, pos)
    if not obj then return end
    if scaleOf[obj] then setScaled(obj, pos) else SetEntityCoords(obj, pos.x, pos.y, pos.z, false, false, false, false) end
    for _, fl in ipairs(followers[obj] or {}) do moveProp(fl[1], pos + fl[2]) end
end

local function deleteProp(obj)
    if not obj then return end
    for _, fl in ipairs(followers[obj] or {}) do deleteProp(fl[1]) end
    followers[obj], scaleOf[obj] = nil, nil
    if DoesEntityExist(obj) then DeleteEntity(obj) end
end

local function spawnScaled(model, pos, heading, size)
    local obj = spawnProp(model, pos, heading)
    if not obj then return end
    local mn, mx = GetModelDimensions(GetEntityModel(obj))
    scaleOf[obj] = size / math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    setScaled(obj, pos)
    return obj
end

-- cubinhos em volta do primeiro (metros); o primeiro é o que o mouse pega
local CUBE_OFFSETS = {
    vector3(0.0, 0.0, 0.0), vector3(0.055, 0.01, 0.0), vector3(-0.05, 0.03, 0.0),
    vector3(0.02, -0.05, 0.0), vector3(0.065, -0.045, 0.0), vector3(-0.02, -0.01, 0.04),
}
local function spawnCubes(pos, heading, n, model, size) -- model/size: pilha de outra coisa (buds do camarão)
    model, size = model or bench.props.cube, size or bench.cubeSize
    local main = spawnScaled(model, pos, heading, size)
    if not main then return end
    local list = {}
    for i = 2, math.min(n, #CUBE_OFFSETS) do
        local c = spawnScaled(model, pos + CUBE_OFFSETS[i], heading + i * 37.0, size)
        if c then list[#list + 1] = { c, CUBE_OFFSETS[i] } end
    end
    followers[main] = list
    return main
end

-- prontos dentro do espaço "wrapped" (metros a partir do centro dele; 6 lugares, depois recicla)
local WRAPPED_SPOTS = { { -0.13, 0.0 }, { 0.0, 0.0 }, { 0.13, 0.0 } } -- saquinhos do Produto pronto (camarão, 12 cm)
-- pacotinhos nos Prontos do prensado: 1 por cubo embalado, 2 fileiras de 10 (depois recomeça)
local PACK_SPOTS = {}
for i = 0, 19 do PACK_SPOTS[i + 1] = { -0.18 + (i % 10) * 0.04, i < 10 and -0.03 or 0.03 } end
-- os cubos contados no meio (até 10): duas fileiras de 5
local COUNT_SPOTS = {}
for i = 0, 9 do COUNT_SPOTS[i + 1] = { -0.12 + (i % 5) * 0.06, i < 5 and -0.05 or 0.05 } end -- 6 cm entre eles (cubo tem 5)

-- O que fica em cima de cada mesa vem do servidor (coluna bench do drug_processing): salvo ao sair da
-- bancada, volta depois de reiniciar e todo mundo vê. Cada client desenha os props localmente, cada um no
-- seu espaço marcado (as posições x, y que vêm junto ficam só de registro; o tijolo salvo fica no meio).
-- layout = { tools = { knife/scale/film = { x, y } }, brick = { strain, x, y }, counted = { variedade = n },
--   piles = { variedade = { x, y } }, wrapped = n, ready = (prontos, só o servidor mexe) }
local layouts, versions = {}, {} -- netId da mesa -> layout; netId -> nº da mudança
local rendered = {} -- mesa -> nº da mudança que está desenhada
local ownSend = {} -- netId -> true: a próxima mudança que chegar é a que este client mandou (já está desenhada)
local activeTable -- mesa em uso na bancada (não redesenha embaixo do jogador)

RegisterNetEvent('it-drugs:client:benchLayout', function(netId, layout)
    layouts[netId] = layout
    versions[netId] = (versions[netId] or 0) + 1
    if ownSend[netId] then
        ownSend[netId] = nil
        local tbl = NetworkGetEntityFromNetworkId(netId)
        if rendered[tbl] then rendered[tbl] = versions[netId] end
    end
end)

CreateThread(function()
    for netId, layout in pairs(lib.callback.await('it-drugs:server:getBenchLayouts', false) or {}) do
        netId = tonumber(netId)
        layouts[netId] = layout
        versions[netId] = (versions[netId] or 0) + 1
    end
end)

local saved = {} -- mesa -> { tools = { knife/scale/film -> prop }, brick = { strain, obj }, counted = { cubes = { { obj, strain } } }, piles = { variedade -> prop }, pileAt = { variedade -> espaço }, wrapped = { props } }
local function clearSaved(tbl)
    local state = saved[tbl]
    if not state then return end
    for _, obj in pairs(state.tools) do deleteProp(obj) end
    if state.brick then deleteProp(state.brick.obj) end
    if state.cutpile then deleteProp(state.cutpile.obj) end
    for _, c in ipairs(state.counted and state.counted.cubes or {}) do deleteProp(c.obj) end
    for _, obj in pairs(state.piles) do deleteProp(obj) end
    for _, obj in ipairs(state.wrapped) do deleteProp(obj) end
    if state.grinder then
        deleteProp(state.grinder.base)
        deleteProp(state.grinder.lid)
        for _, b in ipairs(state.grinder.buds) do deleteProp(b) end
    end
    for _, obj in pairs(state.budPiles or {}) do deleteProp(obj) end
    for _, obj in pairs(state.ctools or {}) do deleteProp(obj) end
    for _, obj in ipairs(state.creadyProps or {}) do deleteProp(obj) end
    saved[tbl] = nil
end

--- Gira um prop (x, y, z em graus) mantendo o sentido da mesa; a faca usa bench.knifeFlat (deitada) e bench.knifeUp (cortando)
local function turnProp(obj, rot, heading)
    if obj then SetEntityRotation(obj, rot.x, rot.y, heading + rot.z, 2, true) end
end

local function spawnWrapped(tbl, list, i)
    local spot = PACK_SPOTS[i]
    list[i] = spawnScaled(bench.props.wrapped, slotPoint(tbl, 'wrapped', spot[1], spot[2]), GetEntityHeading(tbl) + i * 23.0, bench.packSize)
end

--- Quantos cubos embalados estão esperando nos Prontos (vem do servidor)
local function readyCount(ready)
    local n = 0
    for _, r in ipairs(ready and ready.items or {}) do n = n + (tonumber(r.count) or 0) end
    return n
end

-- Dichavador (modo camarão): base no meio, tampa aberta (de cabeça pra baixo) no espaço dela, buds dentro da base.
-- As origens das duas peças são o centro do dichavador FECHADO: base e tampa na mesma posição = fechado.
local BUD_SPOTS = { { 0.0, 0.0 }, { 0.014, 0.004 }, { -0.012, 0.008 }, { 0.004, -0.014 }, { -0.009, -0.010 } }
local function grinderAt(tbl) return propPoint(tbl, 'grinder') + vector3(0.0, 0.0, bench.grinder.height) end
local function lidHome(tbl) return propPoint(tbl, 'lid') + vector3(0.0, 0.0, bench.grinder.height) end

--- Gira e posiciona mantendo o tamanho (o dichavador é aumentado pela matriz: SetEntityRotation sozinho voltaria ao normal)
local function poseProp(obj, pos, rx, rz)
    if not obj then return end
    SetEntityRotation(obj, rx, 0.0, rz, 2, true)
    moveProp(obj, pos)
end

local function spawnGrinder(tbl)
    local heading, G = GetEntityHeading(tbl), bench.grinder
    local g = {
        base = spawnScaled(G.base, grinderAt(tbl), heading, G.size),
        lid = spawnScaled(G.lid, lidHome(tbl), heading, G.size),
        buds = {},
    }
    poseProp(g.lid, lidHome(tbl), 180.0, heading) -- aberta: o lado de dentro pra cima
    return g
end

--- O que aparece dentro da base = o estoque do dichavador (inside = { strain, count, ground } ou nil):
--- buds inteiras, ou a dichavada depois de moer (grinder.ground)
local function setBuds(tbl, g, inside)
    local ground = inside and inside.ground or false
    if (g.ground or false) ~= ground then -- trocou bud <-> dichavada: refaz
        for _, b in ipairs(g.buds) do deleteProp(b) end
        g.buds, g.ground = {}, ground
    end
    local n = inside and math.min(tonumber(inside.count) or 0, #BUD_SPOTS) or 0
    while #g.buds > n do deleteProp(table.remove(g.buds)) end
    local at, G = grinderAt(tbl), bench.grinder
    for i = #g.buds + 1, n do
        g.buds[i] = spawnScaled(ground and G.ground or G.bud, at + vector3(BUD_SPOTS[i][1], BUD_SPOTS[i][2], 0.004),
            GetEntityHeading(tbl) + i * 50.0, ground and G.groundSize or G.budSize)
    end
end

--- Saquinhos com maconha no "Produto pronto" do camarão (até #WRAPPED_SPOTS aparecem)
local function setReadyBags(tbl, list, bags)
    local n = math.min(tonumber(bags) or 0, #WRAPPED_SPOTS)
    while #list > n do deleteProp(table.remove(list)) end
    for i = #list + 1, n do
        local spot = WRAPPED_SPOTS[i]
        list[i] = spawnScaled(bench.grinder.readyProp, slotPoint(tbl, 'cready', spot[1], spot[2]), GetEntityHeading(tbl), bench.wrappedSize)
    end
end

--- Desenha na mesa o layout que veio do servidor (apaga o que tinha); cada coisa no seu espaço.
--- A mesa mostra o modo usado por último (layout.mode): camarão = dichavador; prensado = o resto.
local function renderLayout(tbl, layout, mode)
    clearSaved(tbl)
    mode = mode or (layout and layout.mode) or 'prensado'
    local state = { mode = mode, tools = {}, piles = {}, pileAt = {}, wrapped = {}, budPiles = {}, budAt = {}, ctools = {}, creadyProps = {} }
    saved[tbl] = state
    if not layout then return end
    local heading = GetEntityHeading(tbl)
    local stock = layout.stock or {}
    if mode == 'camarao' then
        if (stock.tools or {}).grinder then
            state.grinder = spawnGrinder(tbl)
            setBuds(tbl, state.grinder, stock.grinder)
        end
        if (stock.tools or {}).cscale then state.ctools.cscale = spawnProp(bench.props.scale, propPoint(tbl, 'cscale'), heading) end
        if (tonumber(stock.plastic) or 0) > 0 then state.ctools.cbag = spawnProp(bench.grinder.bagProp, propPoint(tbl, 'cbag'), heading) end
        setReadyBags(tbl, state.creadyProps, layout.cready and layout.cready.bags or 0)
        local list = {}
        for strain, b in pairs(stock.buds or {}) do
            if (tonumber(b.count) or 0) > 0 then list[#list + 1] = strain end
        end
        table.sort(list)
        for i, strain in ipairs(list) do
            local key = bench.budSlots[i]
            if key then
                state.budPiles[strain] = spawnCubes(propPoint(tbl, key), heading, #CUBE_OFFSETS, bench.grinder.bud, bench.grinder.budSize)
                state.budAt[strain] = key
            end
        end
        return
    end
    -- faca, balança e zip lock aparecem se estiverem no estoque da mesa
    local present = { knife = (stock.tools or {}).knife ~= nil, scale = (stock.tools or {}).scale ~= nil, film = (tonumber(stock.film) or 0) > 0 }
    for key, here in pairs(present) do
        local model = (key == 'film' and (stock.filmItem or 'plastico_filme') ~= Config.Prensado.filmItem) and bench.grinder.bagProp or bench.props[key]
        if here then state.tools[key] = spawnProp(model, propPoint(tbl, key), heading) end
        if key == 'knife' then turnProp(state.tools.knife, bench.knifeFlat, heading) end
    end
    local cutStrain = layout.cutpile -- cubos recém-cortados que ficaram no meio
    if cutStrain and not ((stock.cubes or {})[cutStrain] and (tonumber(stock.cubes[cutStrain].count) or 0) > 0) then cutStrain = nil end
    if stock.brick then -- tijolo da mesa esperando a faca: fica no meio
        local obj = spawnProp(bench.props.brick, propPoint(tbl, 'center'), heading)
        if obj then state.brick = { strain = stock.brick.strain, obj = obj } end
    elseif cutStrain then
        local obj = spawnCubes(propPoint(tbl, 'center'), heading, #CUBE_OFFSETS)
        if obj then state.cutpile = { strain = cutStrain, obj = obj } end
    elseif layout.counted then -- cubos contados esperando o zip lock: ficam no meio, em ordem de variedade
        local list, cubes = {}, {}
        for strain, n in pairs(layout.counted) do list[#list + 1] = { strain, tonumber(n) or 0 } end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        for _, e in ipairs(list) do
            for _ = 1, e[2] do
                local i = #cubes + 1
                if not COUNT_SPOTS[i] then break end
                local obj = spawnScaled(bench.props.cube, slotPoint(tbl, 'center', COUNT_SPOTS[i][1], COUNT_SPOTS[i][2]), heading, bench.cubeSize)
                if obj then cubes[i] = { obj = obj, strain = e[1] } end
            end
        end
        if #cubes > 0 then state.counted = { cubes = cubes } end
    end
    -- pilhas = cubos no estoque da mesa; cada variedade volta pro espaço mais perto de onde estava (um por variedade)
    for strain, st in pairs(stock.cubes or {}) do
        if state.cutpile and state.cutpile.strain == strain and not (layout.piles or {})[strain] then goto nextPile end -- está no meio
        local p = (tonumber(st.count) or 0) > 0 and (layout.piles or {})[strain] or nil
        local was = p and GetOffsetFromEntityInWorldCoords(tbl, (p.x or 0.0) + 0.0, (p.y or 0.0) + 0.0, 0.0)
        local best, bestDist
        for _, key in ipairs((tonumber(st.count) or 0) > 0 and bench.pileSlots or {}) do
            local taken = false
            for _, k in pairs(state.pileAt) do taken = taken or k == key end
            local dist = was and #(propPoint(tbl, key).xy - was.xy) or 0.0
            if not taken and (not bestDist or dist < bestDist) then best, bestDist = key, dist end
        end
        if best then
            state.piles[strain] = spawnCubes(propPoint(tbl, best), heading, #CUBE_OFFSETS)
            state.pileAt[strain] = best
        end
        ::nextPile::
    end
    for i = 1, math.min(readyCount(layout.ready), #PACK_SPOTS) do spawnWrapped(tbl, state.wrapped, i) end
end

-- cubinhos continuam pequenos mesmo fora da bancada
CreateThread(function()
    while true do
        if next(scaleOf) then
            for obj in pairs(scaleOf) do -- shortcut: reaplica o tamanho todo frame, caso o GTA volte pro normal; tirar se não precisar
                if DoesEntityExist(obj) then setScaled(obj, GetEntityCoords(obj)) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Enfeite (folhas) em toda mesa perto: props locais, cada client põe os seus
local decorated = {} -- mesa -> lista de props

-- reiniciar o it-drugs não deixa props soltos no mundo (o GTA não apaga sozinho o que o script criou)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for tbl in pairs(saved) do clearSaved(tbl) end
    for _, props in pairs(decorated) do
        for _, p in ipairs(props) do deleteProp(p) end
    end
end)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, obj in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(obj) == tableModel and #(GetEntityCoords(obj) - pos) < bench.decorDistance then
                if not decorated[obj] then
                    local props = {}
                    for _, def in ipairs(bench.decor) do
                        props[#props + 1] = spawnProp(def.model, tablePoint(obj, def.along, def.across, def.dz), GetEntityHeading(obj) + (def.heading or 0.0))
                    end
                    decorated[obj] = props
                end
                -- arrumação salva (só mesa do it-drugs, que é do servidor; a do mapeditor não tem)
                if NetworkGetEntityIsNetworked(obj) and obj ~= activeTable then
                    local netId = NetworkGetNetworkIdFromEntity(obj)
                    if rendered[obj] ~= (versions[netId] or 0) then
                        renderLayout(obj, layouts[netId])
                        rendered[obj] = versions[netId] or 0
                    end
                end
            end
        end
        for tbl, props in pairs(decorated) do
            if not DoesEntityExist(tbl) or #(GetEntityCoords(tbl) - pos) > bench.decorDistance + 5.0 then
                for _, p in ipairs(props) do deleteProp(p) end
                decorated[tbl], rendered[tbl] = nil, nil
                clearSaved(tbl)
            end
        end
        Wait(1000)
    end
end)

--- Onde o mouse aponta no plano do tampo (câmera sem roll; FOV do GTA é vertical)
local function cursorOnTable(cam, pitch, yaw, topZ, sx, sy)
    local p, y = math.rad(pitch), math.rad(yaw)
    local fwd = vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p))
    local right = vector3(math.cos(y), math.sin(y), 0.0)
    local up = vector3(right.y * fwd.z, -right.x * fwd.z, right.x * fwd.y - right.y * fwd.x)
    local tanV = math.tan(math.rad(GetCamFov(cam)) / 2)
    local tanH = tanV * GetAspectRatio(false)
    local dir = fwd + right * ((sx - 0.5) * 2 * tanH) + up * ((0.5 - sy) * 2 * tanV)
    if dir.z > -0.001 then return end
    local camPos = GetCamCoord(cam)
    return camPos + dir * ((topZ - camPos.z) / dir.z)
end

--- Distância na tela entre o mouse e um ponto do mundo (fração da altura da tela)
local function screenDist(coords, sx, sy)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return math.huge end
    return math.sqrt(((x - sx) * GetAspectRatio(false)) ^ 2 + (y - sy) ^ 2)
end

--- Em qual espaço marcado vai esse item da barra (nil = não vai na mesa; 'pile' = qualquer espaço de cubos)
local function itemSlot(item)
    if item == P.knifeItem then return 'knife' end
    if item == P.scaleItem then return 'scale' end
    if item == P.filmItem then return 'film' end
    if item:find('^tijolo_') then return 'center' end -- tijolo vai direto pro meio, pra cortar
    if item:find('^cubo_') and not item:find('_embalado$') then return 'pile' end
    if item == bench.grinder.item then return 'grinder' end
    if item:find('^weed_.+_curada$') then return 'buds' end -- qualquer espaço de buds
end

local active, onMouse = false, nil
AddEventHandler('itdrugs_bancada:mouse', function(data)
    if onMouse then onMouse(data) end
end)

--- Anda até a frente da mesa (Config.ProcessingTables[..].front; mesa antiga com a frente na parede: chega de onde
--- estiver), trava o boneco no emote e põe a câmera em cima do tampo. Devolve ped, cam, pitch, yaw, topZ.
local function enterBench(tbl)
    local frontDepth = Config.ProcessingTables[bench.table].front
    local useFront = frontDepth and not it.isFrontBlocked(tbl, frontDepth)
    local ped = PlayerPedId()
    if useFront then
        local _, _, _, _, frontAt = it.frontArea(tbl, frontDepth)
        local stand, middle = frontAt(0.0, 0.45), frontAt(0.0, -0.3)
        TaskGoStraightToCoord(ped, stand.x, stand.y, stand.z, 1.0, 5000, GetHeadingFromVector_2d(middle.x - stand.x, middle.y - stand.y), 0.05)
        local giveUpAt = GetGameTimer() + 5000
        repeat Wait(50) until #(GetEntityCoords(ped).xy - stand.xy) < 0.25 or GetGameTimer() > giveUpAt
        ClearPedTasks(ped)
        SetEntityHeading(ped, GetHeadingFromVector_2d(middle.x - stand.x, middle.y - stand.y))
    else
        it.walkToPlace(GetEntityCoords(tbl))
    end
    FreezeEntityPosition(ped, true)
    lib.requestAnimDict(bench.animation.dict)
    TaskPlayAnim(ped, bench.animation.dict, bench.animation.anim, 8.0, 8.0, -1, 1, 0, false, false, false)

    -- câmera em cima da mesa, recuada pro lado onde o jogador está, olhando o centro do tampo
    local mn, mx = GetModelDimensions(GetEntityModel(tbl))
    local pedAt = GetEntityCoords(ped)
    local rel = GetOffsetFromEntityGivenWorldCoords(tbl, pedAt.x, pedAt.y, pedAt.z)
    local side = (((mx.x - mn.x) >= (mx.y - mn.y)) and rel.y or rel.x) >= 0 and 1 or -1
    if useFront then side = -1 end -- a frente é o lado -Y/-X do modelo (it.frontArea)
    local center3 = tablePoint(tbl, 0.0, 0.0)
    local camPos = tablePoint(tbl, 0.0, side * bench.camBack, bench.camHeight)
    local d = center3 - camPos
    local pitch = math.deg(math.atan(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
    local yaw = math.deg(math.atan(-d.x, d.y))
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, pitch, 0.0, yaw, 50.0, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, false)
    return ped, cam, pitch, yaw, center3.z
end

local function leaveBench(ped, cam)
    RenderScriptCams(false, true, 600, true, false)
    DestroyCam(cam, false)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    RemoveAnimDict(bench.animation.dict)
end

--- Modo camarão: dichavador no meio, tampa aberta do lado, pilhas de buds curadas nos espaços "Buds", balança e
--- saquinhos plásticos nos espaços deles. Tudo SAI do inventário pra mesa (servidor: benchStock). Arrasta UMA bud da
--- pilha pro dichavador; clicar na tampa fecha, gira e dichava (a dichavada fica nele); arrastar o zip lock até o
--- dichavador ensaca (pesa na balança; benchBag: o saquinho fica no Produto pronto). Botão direito devolve.
local function grinderSession(tbl, serverEntity, netId, strains)
    local G = bench.grinder
    if not saved[tbl] or saved[tbl].mode ~= 'camarao' then renderLayout(tbl, layouts[netId], 'camarao') end
    local state = saved[tbl]
    local budPiles, budAt, ctools, creadyProps = state.budPiles, state.budAt, state.ctools, state.creadyProps -- pilhas; espaço de cada; balança/zip lock; prontos

    local strainList = {}
    for strain in pairs(strains) do strainList[#strainList + 1] = strain end
    table.sort(strainList)
    local names = { G.item, P.scaleItem, G.bagItem }
    for _, strain in ipairs(strainList) do names[#names + 1] = ('weed_%s_curada'):format(strain) end
    local count = {}
    local function readCounts()
        local found = exports.ox_inventory:Search('count', names) or {}
        for _, name in ipairs(names) do count[name] = tonumber(found[name]) or 0 end
    end
    local itemDefs = exports.ox_inventory:Items()
    local function label(item) return itemDefs[item] and itemDefs[item].label or item end
    local function curedOf(strain) return ('weed_%s_curada'):format(strain) end
    local function stock() return layouts[netId] and layouts[netId].stock or {} end
    local function stockTool(key) return (stock().tools or {})[key] ~= nil end
    local function plastic() return tonumber(stock().plastic) or 0 end
    local function inside() return stock().grinder end -- { strain, count, purity, ground } ou nil
    local function cready() return layouts[netId] and layouts[netId].cready end -- produto pronto { bags, items }
    local function budsOf(strain)
        local b = (stock().buds or {})[strain]
        return b and tonumber(b.count) or 0
    end
    local function budIn(key) -- variedade que está nesse espaço de buds
        for strain, k in pairs(budAt) do
            if k == key then return strain end
        end
    end
    local function freeBudSlot()
        for _, key in ipairs(bench.budSlots) do
            if not budIn(key) then return key end
        end
    end
    local function slotOf(item) -- espaço de cada item da barra no camarão
        if item == G.item then return 'grinder' end
        if item == P.scaleItem then return 'cscale' end
        if item == G.bagItem then return 'cbag' end
        if item:find('^weed_.+_curada$') then return 'buds' end
    end

    local function barItems()
        local list, full = {}, freeBudSlot() == nil
        local function add(name, disabled)
            if count[name] > 0 then list[#list + 1] = { name = name, label = label(name), count = count[name], disabled = disabled } end
        end
        add(G.item, state.grinder ~= nil)
        add(P.scaleItem, ctools.cscale ~= nil)
        add(G.bagItem, plastic() >= bench.maxPlastic)
        for _, strain in ipairs(strainList) do
            add(curedOf(strain), budPiles[strain] and budsOf(strain) >= bench.maxBuds or (not budPiles[strain] and full))
        end
        return list
    end
    local function updateBar() TriggerEvent('itdrugs_bancada:items', barItems()) end

    --- Dichavador (e o que tem dentro), pilhas de buds, balança e saquinhos conforme o estoque da mesa
    local function syncTable()
        if not stockTool('grinder') then
            if state.grinder then
                deleteProp(state.grinder.base)
                deleteProp(state.grinder.lid)
                for _, b in ipairs(state.grinder.buds) do deleteProp(b) end
                state.grinder = nil
            end
        else
            if not state.grinder then state.grinder = spawnGrinder(tbl) end
            setBuds(tbl, state.grinder, inside())
        end
        for strain in pairs(budPiles) do
            if budsOf(strain) < 1 then
                deleteProp(budPiles[strain])
                budPiles[strain], budAt[strain] = nil, nil
            end
        end
        for strain in pairs(stock().buds or {}) do -- pilha nova (voltou do dichavador, por exemplo)
            local key = not budPiles[strain] and budsOf(strain) > 0 and freeBudSlot()
            if key then
                budPiles[strain] = spawnCubes(propPoint(tbl, key), GetEntityHeading(tbl), #CUBE_OFFSETS, G.bud, G.budSize)
                budAt[strain] = key
            end
        end
        setReadyBags(tbl, creadyProps, cready() and cready().bags or 0)
        for key, here in pairs({ cscale = stockTool('cscale'), cbag = plastic() > 0 }) do
            if here and not ctools[key] then
                ctools[key] = spawnProp(key == 'cscale' and bench.props.scale or G.bagProp, propPoint(tbl, key), GetEntityHeading(tbl))
            elseif not here and ctools[key] then
                deleteProp(ctools[key])
                ctools[key] = nil
            end
        end
    end
    local function afterServer()
        SetTimeout(600, function()
            if not active then return end
            readCounts()
            syncTable()
            updateBar()
        end)
    end

    local ped, cam, pitch, yaw, topZ = enterBench(tbl)
    local heading = GetEntityHeading(tbl)
    local shapes = buildSlotShapes(tbl)
    local busy, hovered, hoverKey, barDrag, drag = false, nil, nil, nil, nil

    local function outline(entity)
        if hovered == entity then return end
        if hovered and DoesEntityExist(hovered) then SetEntityDrawOutline(hovered, false) end
        if entity then
            SetEntityDrawOutlineColor(255, 255, 255, 200)
            SetEntityDrawOutline(entity, true)
        end
        hovered = entity
    end
    --- O que está embaixo do mouse: { kind = 'base' | 'lid' | 'pile' | 'cscale' | 'cbag', key = variedade, obj }
    local function under(sx, sy)
        local list = {}
        if state.grinder then
            list[#list + 1] = { kind = 'base', obj = state.grinder.base, pos = grinderAt(tbl), radius = bench.scaleRadius }
            list[#list + 1] = { kind = 'lid', obj = state.grinder.lid, radius = bench.scaleRadius }
        end
        for strain, obj in pairs(budPiles) do list[#list + 1] = { kind = 'pile', key = strain, obj = obj, radius = bench.grabRadius } end
        for key, obj in pairs(ctools) do list[#list + 1] = { kind = key, obj = obj, radius = bench.scaleRadius } end
        if creadyProps[1] then list[#list + 1] = { kind = 'cready', obj = creadyProps[1], pos = slotPoint(tbl, 'cready'), radius = bench.scaleRadius } end
        local best, bestDist
        for _, g in ipairs(list) do
            local dist = screenDist(g.pos or GetEntityCoords(g.obj), sx, sy)
            if dist < g.radius and (not bestDist or dist < bestDist) then best, bestDist = g, dist end
        end
        return best
    end
    local function overGrinder(sx, sy, point)
        return state.grinder and (inSlot(tbl, 'grinder', point) or screenDist(grinderAt(tbl), sx, sy) < bench.scaleRadius)
    end
    local function overScale(sx, sy, point)
        return ctools.cscale and (inSlot(tbl, 'cscale', point) or screenDist(GetEntityCoords(ctools.cscale), sx, sy) < bench.scaleRadius)
    end
    local function hover(g)
        local info
        if g and g.kind == 'pile' then
            info = { label = label(curedOf(g.key)), count = budsOf(g.key) }
        elseif g and g.kind == 'cscale' then
            info = { label = label(P.scaleItem), count = 1 }
        elseif g and g.kind == 'cbag' then
            info = { label = label(G.bagItem), count = plastic() }
        elseif g and g.kind == 'cready' then -- o que está no Produto pronto (vem do servidor)
            local total, names = 0, {}
            for _, r in ipairs(cready() and cready().items or {}) do
                total = total + r.count
                names[#names + 1] = ('%d %s'):format(r.count, label(r.item))
            end
            table.sort(names)
            info = { label = #names > 0 and table.concat(names, ' + ') or bench.slots.cready.label, count = total }
        elseif g then
            local now = inside()
            local item = now and (now.ground and ('weed_%s_dichavada'):format(now.strain) or curedOf(now.strain)) or G.item
            info = { label = label(item), count = now and now.count or 0 }
        end
        local key = info and (info.label .. '|' .. info.count) or nil
        if key == hoverKey then return end
        hoverKey = key
        TriggerEvent('itdrugs_bancada:hover', info)
    end

    local function fly(obj, from, to, height)
        for f = 0.0, 1.0, 0.08 do
            moveProp(obj, from + (to - from) * f + vector3(0.0, 0.0, math.sin(f * math.pi) * (height or 0.08)))
            Wait(15)
        end
        moveProp(obj, to)
    end

    --- Tampa voa, vira e encaixa na base (a bud de dentro some), gira; servidor dichava; tampa volta aberta
    local function grind()
        local lid, closed, home = state.grinder.lid, grinderAt(tbl), lidHome(tbl)
        for f = 0.0, 1.0, 0.05 do
            poseProp(lid, home + (closed - home) * f + vector3(0.0, 0.0, math.sin(f * math.pi) * 0.08), 180.0 * (1.0 - f), heading)
            Wait(15)
        end
        poseProp(lid, closed, 0.0, heading)
        setBuds(tbl, state.grinder, nil) -- fechou: não aparece mais nada dentro
        local start = GetGameTimer()
        while GetGameTimer() - start < G.spinTime do -- gira a tampa
            poseProp(lid, closed, 0.0, heading + (GetGameTimer() - start) * 0.54)
            Wait(0)
        end
        TriggerServerEvent('it-drugs:server:benchGrind', serverEntity)
        Wait(700)
        if state.grinder then
            lid = state.grinder.lid
            for f = 0.0, 1.0, 0.05 do
                poseProp(lid, closed + (home - closed) * f + vector3(0.0, 0.0, math.sin(f * math.pi) * 0.08), 180.0 * f, heading)
                Wait(15)
            end
            poseProp(lid, home, 180.0, heading)
        end
        readCounts()
        syncTable() -- abriu: aparece a dichavada dentro
        updateBar()
    end

    --- Zip lock no dichavador: a dichavada vai pra dentro dele, ele pesa na balança e vai pro Produto pronto;
    --- o servidor ensaca (o saquinho fica no Produto pronto até clicar nele)
    local function bagIt(zip)
        local over = grinderAt(tbl) + vector3(0.0, 0.0, 0.04)
        moveProp(zip, over)
        Wait(400)
        setBuds(tbl, state.grinder, nil) -- a dichavada entrou no zip lock
        local onScale = GetEntityCoords(ctools.cscale) + vector3(0.0, 0.0, bench.scaleTop)
        fly(zip, over, onScale, 0.1)
        Wait(800) -- pesando
        fly(zip, onScale, slotPoint(tbl, 'cready', 0.0, 0.0, 0.03), 0.1)
        deleteProp(zip)
        TriggerServerEvent('it-drugs:server:benchBag', serverEntity)
        Wait(700)
        readCounts()
        syncTable()
        updateBar()
    end

    local function dropFromBar(item, point)
        if (count[item] or 0) < 1 then return end
        local key = slotOf(item)
        if not key then return end
        if key ~= 'buds' then
            if not inSlot(tbl, key, point) then
                return ShowNotification(nil, _U('NOTIFICATION__BENCH__WRONG__SLOT'):format(bench.slots[key].label), 'error')
            end
            if key == 'grinder' then
                if state.grinder then return end
                state.grinder = spawnGrinder(tbl)
                TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'grinder')
            elseif key == 'cscale' then
                if ctools.cscale then return end
                ctools.cscale = spawnProp(bench.props.scale, propPoint(tbl, 'cscale'), heading)
                TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'cscale')
            else -- saquinhos: repõe até o limite
                if not ctools.cbag then ctools.cbag = spawnProp(G.bagProp, propPoint(tbl, 'cbag'), heading) end
                TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'plastic')
            end
            return afterServer()
        end
        local strain = item:match('^weed_(.+)_curada$')
        if not strain or not strains[strain] then return end
        local at
        for _, k in ipairs(bench.budSlots) do
            if inSlot(tbl, k, point) then at = k end
        end
        if not at then
            return ShowNotification(nil, _U('NOTIFICATION__BENCH__WRONG__SLOT'):format(bench.slots[bench.budSlots[1]].label), 'error')
        end
        local other = budIn(at)
        if other and other ~= strain then return ShowNotification(nil, _U('NOTIFICATION__BENCH__PILE__BUSY'), 'error') end
        if not budPiles[strain] then
            budPiles[strain] = spawnCubes(propPoint(tbl, at), heading, #CUBE_OFFSETS, G.bud, G.budSize)
            budAt[strain] = at
        end
        TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'buds', strain) -- sai do inventário (até o limite)
        afterServer()
    end

    --- Soltou o que pegou: bud em cima do dichavador = vai pra dentro; zip lock em cima do dichavador = ensaca
    local function release(sx, sy, point)
        local g = drag
        drag = nil
        if g.zip then
            local now = inside()
            if overGrinder(sx, sy, point) then
                if not now or not now.ground or not ctools.cscale or plastic() < 1 then
                    ShowNotification(nil, _U('NOTIFICATION__BENCH__NEED__BAG'), 'error')
                else
                    busy = true
                    return CreateThread(function() bagIt(g.obj); busy = false end)
                end
            end
            return deleteProp(g.obj)
        end
        deleteProp(g.obj)
        if not overGrinder(sx, sy, point) then return end
        local now = inside()
        if now and (now.ground or now.strain ~= g.key or now.count >= G.capacity) then
            return ShowNotification(nil, _U('NOTIFICATION__BENCH__GRINDER__FILL'):format(G.capacity), 'error')
        end
        TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'bud', g.key)
        afterServer()
    end

    onMouse = function(data)
        if data.type == 'exit' then
            if not busy then active = false end
            return
        end
        if data.type == 'dragitem' then
            barDrag = type(data.item) == 'string' and slotOf(data.item) or nil
            return
        end
        if busy then return end
        local sx, sy = tonumber(data.x) or 0.5, tonumber(data.y) or 0.5
        local point = cursorOnTable(cam, pitch, yaw, topZ, sx, sy)
        if data.type == 'drop' then
            barDrag = nil
            if point and type(data.item) == 'string' then dropFromBar(data.item, point) end
        elseif data.type == 'down' then
            local g = under(sx, sy)
            if not g then return end
            outline(nil)
            hover(nil)
            local now = inside()
            if g.kind == 'cready' then -- clicar no Produto pronto recolhe tudo pro inventário
                TriggerServerEvent('it-drugs:server:benchCollect', serverEntity, 'camarao')
                return afterServer()
            end
            if g.kind == 'pile' then -- pega uma bud da pilha
                if not state.grinder then return ShowNotification(nil, _U('NOTIFICATION__BENCH__NEED__GRINDER'), 'error') end
                local obj = spawnScaled(G.bud, GetEntityCoords(g.obj), heading, G.budSize)
                if obj then drag = { key = g.key, obj = obj } end
            elseif g.kind == 'cbag' then -- pega um zip lock pra levar até o dichavador
                local obj = spawnProp(G.bagProp, GetEntityCoords(g.obj), heading)
                if obj then drag = { zip = true, obj = obj } end
            elseif g.kind == 'base' and now and now.ground then
                ShowNotification(nil, _U('NOTIFICATION__BENCH__DRAG__ZIP'), 'inform')
            elseif g.kind == 'lid' then
                if not now or now.ground or now.count < G.capacity then
                    return ShowNotification(nil, _U('NOTIFICATION__BENCH__GRINDER__FILL'):format(G.capacity), 'error')
                end
                busy = true
                CreateThread(function() grind(); busy = false end)
            end
        elseif data.type == 'up' and drag then
            release(sx, sy, point)
        elseif data.type == 'remove' then
            -- pilha: buds voltam pro inventário; base: o que tem dentro; tampa: o dichavador; balança; saquinhos
            local g = not drag and under(sx, sy)
            if not g then return end
            outline(nil)
            hover(nil)
            if g.kind == 'cready' then
                TriggerServerEvent('it-drugs:server:benchCollect', serverEntity, 'camarao')
                return afterServer()
            end
            local kind = (g.kind == 'pile' and 'buds') or (g.kind == 'cbag' and 'plastic') or (g.kind == 'cscale' and 'cscale')
                or ((g.kind == 'base' and inside()) and 'bud') or 'grinder'
            TriggerServerEvent('it-drugs:server:benchUnstock', serverEntity, kind, g.key)
            afterServer()
        elseif data.type == 'move' then
            if drag then
                if overGrinder(sx, sy, point) then -- bud ou zip lock sobe e fica em cima do dichavador
                    moveProp(drag.obj, grinderAt(tbl) + vector3(0.0, 0.0, 0.04))
                elseif point then
                    moveProp(drag.obj, vector3(point.x, point.y, topZ + 0.03))
                end
            else
                local g = under(sx, sy)
                outline(g and g.obj)
                hover(g)
            end
        end
    end

    readCounts()
    syncTable()
    TriggerEvent('itdrugs_bancada:open', barItems(), _U('BENCH__HELP__CAMARAO'))
    while active do
        DisableAllControlActions(0)
        SetEntityLocallyInvisible(ped)
        if not DoesEntityExist(tbl) or IsEntityDead(ped) then break end
        local target = drag and 'grinder' or barDrag
        for key, slot in pairs(bench.slots) do
            if slot.mode == 'camarao' then
                local strain = slot.buds and budIn(key)
                local full = (slot.buds and strain ~= nil) or ((key == 'grinder' or key == 'lid') and state.grinder ~= nil)
                    or (ctools[key] ~= nil) or (key == 'cready' and creadyProps[1] ~= nil)
                local isTarget = key == target or (target == 'buds' and slot.buds and not full)
                local now = key == 'grinder' and inside()
                local text = strain and (Config.WeedStrains[strain] and Config.WeedStrains[strain].label or strain) or slot.label
                local pulse = 0.75 + 0.25 * math.sin(GetGameTimer() / 160)
                drawSlot(shapes[key], slot.color, (isTarget and pulse) or (full and 0.3) or 0.65, text,
                    now and (now.ground and label(('weed_%s_dichavada'):format(now.strain)) or ('%d/%d'):format(now.count, G.capacity)) or nil)
            end
        end
        Wait(0)
    end

    -- salva: a mesa passa a mostrar o camarão; o resto da arrumação do prensado continua guardado como estava
    active, onMouse = false, nil
    TriggerEvent('itdrugs_bancada:close')
    outline(nil)
    if drag then deleteProp(drag.obj) end
    if DoesEntityExist(tbl) then
        local old = layouts[netId] or {}
        ownSend[netId] = true
        TriggerServerEvent('it-drugs:server:setBenchLayout', netId, {
            mode = 'camarao', tools = old.tools or {}, piles = old.piles or {}, brick = old.brick, counted = old.counted, cutpile = old.cutpile,
        })
    end
    activeTable = nil
    leaveBench(ped, cam)
end

RegisterNetEvent('it-drugs:client:bench', function(args)
    local tbl, strains = args.entity, args.strains
    if active or not tbl or not DoesEntityExist(tbl) or not strains then return end
    if GetResourceState('itdrugs_bancada') ~= 'started' then
        return print('[it-drugs] bancada: o resource itdrugs_bancada não está rodando')
    end
    local result = lib.callback.await('it-drugs:server:getTableData', false, NetworkGetNetworkIdFromEntity(tbl))
    if not result then return end
    local serverEntity = result.entity
    local netId = NetworkGetNetworkIdFromEntity(tbl)
    local st, ready = layouts[netId] and layouts[netId].stock or {}, layouts[netId] and layouts[netId].ready
    local camaraoOn = (st.tools or {}).grinder or (st.tools or {}).cscale or st.grinder or next(st.buds or {}) or (tonumber(st.plastic) or 0) > 0
        or (layouts[netId] and layouts[netId].cready)
    local prensadoOn = (st.tools or {}).knife or (st.tools or {}).scale or (tonumber(st.film) or 0) > 0
        or next(st.cubes or {}) or st.brick or ready
    if (args.mode == 'camarao' and prensadoOn) or (args.mode ~= 'camarao' and camaraoOn) then
        return ShowNotification(nil, _U('NOTIFICATION__BENCH__OTHER__MODE'), 'error')
    end
    active, activeTable = true, tbl
    if args.mode == 'camarao' then return grinderSession(tbl, serverEntity, netId, strains) end

    -- itens que entram na barra (só aparecem os que o jogador tem)
    local strainList = {}
    for strain in pairs(strains) do strainList[#strainList + 1] = strain end
    table.sort(strainList)
    local names = { P.knifeItem, P.scaleItem, P.filmItem }
    for _, strain in ipairs(strainList) do
        names[#names + 1] = 'tijolo_' .. strain
        names[#names + 1] = ('cubo_%s'):format(strain)
        names[#names + 1] = ('cubo_%s_embalado'):format(strain)
    end
    local count = {}
    local function readCounts()
        local found = exports.ox_inventory:Search('count', names) or {}
        for _, name in ipairs(names) do count[name] = tonumber(found[name]) or 0 end
    end
    local itemDefs = exports.ox_inventory:Items()
    local function label(item) return itemDefs[item] and itemDefs[item].label or item end
    local function cubeOf(strain) return ('cubo_%s'):format(strain) end
    local function wrappedOf(strain) return ('cubo_%s_embalado'):format(strain) end

    -- o que está em cima da mesa (o que ficou salvo)
    if not saved[tbl] or saved[tbl].mode ~= 'prensado' then renderLayout(tbl, layouts[netId], 'prensado') end
    local state = saved[tbl]
    local tools = state.tools -- knife / scale / film -> prop
    local piles, pileAt = state.piles, state.pileAt -- espaços "Cubos": variedade -> prop; variedade -> qual espaço
    local wrappedProps = state.wrapped -- espaço "Prontos"
    -- o meio (Fabricação): nil | { kind = 'brick' | 'cutpile', strain, obj } | { kind = 'bag', obj, mix }
    --   | { kind = 'counted', cubes = { { obj, strain } } } (pode misturar variedades)
    local center = (state.brick and { kind = 'brick', strain = state.brick.strain, obj = state.brick.obj })
        or (state.counted and { kind = 'counted', cubes = state.counted.cubes })
        or (state.cutpile and { kind = 'cutpile', strain = state.cutpile.strain, obj = state.cutpile.obj }) or nil
    state.brick, state.counted, state.cutpile = nil, nil, nil

    local function pileIn(key) -- variedade que está nesse espaço de cubos
        for strain, k in pairs(pileAt) do
            if k == key then return strain end
        end
    end
    local function freePile()
        for _, key in ipairs(bench.pileSlots) do
            if not pileIn(key) then return key end
        end
    end
    local function removePile(strain)
        deleteProp(piles[strain])
        piles[strain], pileAt[strain] = nil, nil
    end

    -- estoque da mesa (vem do servidor): cubos e zip lock que estão na mesa NÃO estão mais no inventário
    local function stock() return layouts[netId] and layouts[netId].stock or {} end
    local function stockCubes(strain)
        local c = (stock().cubes or {})[strain]
        return c and tonumber(c.count) or 0
    end
    local function stockFilm() return tonumber(stock().film) or 0 end
    local function oldFilm() return stockFilm() > 0 and (stock().filmItem or 'plastico_filme') ~= P.filmItem end -- outro item no espaço do filme
    local function stockTool(key) return (stock().tools or {})[key] ~= nil end
    local function stockBrick() return stock().brick end

    local function barItems()
        local list = {}
        local function add(name, disabled)
            if count[name] > 0 then
                list[#list + 1] = {
                    name = name, label = label(name), count = count[name], disabled = disabled,
                    fallback = (name:find('^tijolo_') or name:find('^cubo_')) and 'weed_brick' or nil, -- ainda sem ícone próprio
                }
            end
        end
        add(P.knifeItem, tools.knife ~= nil or stockTool('knife'))
        add(P.scaleItem, tools.scale ~= nil or stockTool('scale'))
        add(P.filmItem, stockFilm() >= bench.maxFilm) -- dá pra repor até o limite
        local full = freePile() == nil
        for _, strain in ipairs(strainList) do
            add('tijolo_' .. strain, center ~= nil)
            add(cubeOf(strain), piles[strain] and stockCubes(strain) >= bench.maxCubes or (not piles[strain] and full))
        end
        return list
    end
    local function updateBar() TriggerEvent('itdrugs_bancada:items', barItems()) end

    local ped, cam, pitch, yaw, topZ = enterBench(tbl)

    local heading = GetEntityHeading(tbl)
    local shapes = buildSlotShapes(tbl) -- contorno dos espaços (a mesa não se mexe durante a bancada)
    local function put(model, key) return spawnProp(model, propPoint(tbl, key), heading) end
    local function centerCube(i) return slotPoint(tbl, 'center', COUNT_SPOTS[i][1], COUNT_SPOTS[i][2]) end

    local busy, drag, hovered, barDrag = false, nil, nil, nil -- barDrag = espaço do item que está sendo arrastado da barra
    local function outline(entity)
        if hovered == entity then return end
        if hovered and DoesEntityExist(hovered) then SetEntityDrawOutline(hovered, false) end
        if entity then
            SetEntityDrawOutlineColor(255, 255, 255, 200)
            SetEntityDrawOutline(entity, true)
        end
        hovered = entity
    end

    --- O que está na mesa: { kind, key, obj, pos }
    local function grabbables()
        local list = {}
        for key, obj in pairs(tools) do list[#list + 1] = { kind = key, obj = obj } end
        for strain, obj in pairs(piles) do list[#list + 1] = { kind = 'pile', key = strain, obj = obj } end
        if center then
            local obj = center.obj or center.cubes[1].obj
            list[#list + 1] = { kind = 'center', obj = obj, pos = slotPoint(tbl, 'center') }
        end
        if wrappedProps[1] then list[#list + 1] = { kind = 'wrapped', obj = wrappedProps[1], pos = slotPoint(tbl, 'wrapped') } end
        return list
    end
    local function under(sx, sy)
        local best, bestDist
        for _, g in ipairs(grabbables()) do
            local dist = screenDist(g.pos or GetEntityCoords(g.obj), sx, sy)
            local radius = (g.kind == 'scale' or g.kind == 'center' or g.kind == 'wrapped') and bench.scaleRadius or bench.grabRadius
            if dist < radius and (not bestDist or dist < bestDist) then best, bestDist = g, dist end
        end
        return best
    end
    -- mouse em cima da balança (alvo maior que o dos outros itens)
    local function overScale(sx, sy, point)
        return tools.scale and (screenDist(GetEntityCoords(tools.scale), sx, sy) < bench.scaleRadius or inSlot(tbl, 'scale', point))
    end
    local function overSlot(key, sx, sy, point)
        return inSlot(tbl, key, point) or screenDist(slotPoint(tbl, key), sx, sy) < bench.dropRadius
    end
    local function overPile(sx, sy, point) -- qual espaço de cubos está embaixo do mouse
        for _, key in ipairs(bench.pileSlots) do
            if overSlot(key, sx, sy, point) then return key end
        end
    end

    -- faca: sempre deitada; só fica em pé (ponta pra baixo) na hora de cortar
    local function layKnife() turnProp(tools.knife, bench.knifeFlat, heading) end
    local function standKnife() turnProp(tools.knife, bench.knifeUp, heading) end

    local function occupied(key)
        if key == 'center' then return center ~= nil end
        if key == 'wrapped' then return #wrappedProps > 0 end
        if bench.slots[key].pile then return pileIn(key) ~= nil end
        return tools[key] ~= nil
    end

    --- Quantos cubos de cada variedade estão contados no meio
    local function countedMix()
        local mix, total = {}, 0
        if center and center.kind == 'counted' then
            for _, c in ipairs(center.cubes) do
                mix[c.strain] = (mix[c.strain] or 0) + 1
                total = total + 1
            end
        end
        return mix, total
    end
    local function mixText(mix) -- "4 Lemon Haze + 6 OG Kush"
        local parts = {}
        for strain, n in pairs(mix) do parts[#parts + 1] = ('%d %s'):format(n, Config.WeedStrains[strain] and Config.WeedStrains[strain].label or strain) end
        table.sort(parts)
        return table.concat(parts, ' + ')
    end

    local function clearCenter()
        if not center then return end
        deleteProp(center.obj)
        for _, c in ipairs(center.cubes or {}) do deleteProp(c.obj) end
        center = nil
    end

    --- Some da mesa o que acabou no estoque (contados também: não dá pra contar mais do que tem na pilha)
    local function syncStock()
        for strain in pairs(piles) do
            if stockCubes(strain) < 1 then removePile(strain) end
        end
        if tools.film and stockFilm() < 1 then
            deleteProp(tools.film)
            tools.film = nil
        end
        for _, key in ipairs({ 'knife', 'scale' }) do
            if tools[key] and not stockTool(key) then
                deleteProp(tools[key])
                tools[key] = nil
            end
        end
        if center and center.kind == 'brick' and not (stockBrick() and stockBrick().strain == center.strain) then return clearCenter() end
        if center and center.kind == 'counted' then
            for strain, n in pairs((countedMix())) do
                if stockCubes(strain) < n then return clearCenter() end
            end
        end
    end
    local function afterServer() -- espera o servidor responder e acerta a mesa e a barra
        SetTimeout(600, function()
            if not active then return end
            readCounts()
            syncStock()
            updateBar()
        end)
    end

    --- Os pacotinhos da embalada vão pro espaço "Prontos" (um por cubo; cheio = recomeça)
    local function addWrapped()
        for _ = 1, P.cubesPerWrap do
            if #wrappedProps >= #PACK_SPOTS then
                for _, obj in ipairs(wrappedProps) do deleteProp(obj) end
                for i = #wrappedProps, 1, -1 do wrappedProps[i] = nil end
            end
            spawnWrapped(tbl, wrappedProps, #wrappedProps + 1)
        end
    end

    --- Os cubos contados viram pacotinhos no mesmo lugar (um por cubo); andam juntos ao arrastar pros Prontos
    local function spawnPacks()
        local first = centerCube(1)
        local main = spawnScaled(bench.props.wrapped, first, heading, bench.packSize)
        if not main then return end
        local list = {}
        for i = 2, P.cubesPerWrap do
            local at = centerCube(i)
            local obj = spawnScaled(bench.props.wrapped, at, heading + i * 23.0, bench.packSize)
            if obj then list[#list + 1] = { obj, at - first } end
        end
        followers[main] = list
        return main
    end

    --- Arco de um prop de um ponto a outro (cubo voando pro meio, zip lock indo até os cubos)
    local function fly(obj, from, to, height)
        for f = 0.0, 1.0, 0.08 do
            moveProp(obj, from + (to - from) * f + vector3(0.0, 0.0, math.sin(f * math.pi) * (height or 0.08)))
            Wait(15)
        end
        moveProp(obj, to)
    end

    --- Faca no tijolo do meio: corta (servidor usa o tijolo e a faca da mesa; os cubos vão pro estoque de cubos da mesa)
    local function cut()
        local strain, at = center.strain, GetEntityCoords(center.obj)
        local knife, cube = tools.knife, cubeOf(center.strain)
        local top = at.z + bench.knifeLift
        standKnife()
        for _ = 1, 3 do -- faca sobe e desce em cima do tijolo
            for f = 0.0, 1.0, 0.1 do
                SetEntityCoords(knife, at.x, at.y, top + 0.08 - f * 0.12, false, false, false, false)
                Wait(15)
            end
            for f = 0.0, 1.0, 0.2 do
                SetEntityCoords(knife, at.x, at.y, top - 0.04 + f * 0.12, false, false, false, false)
                Wait(15)
            end
        end
        local before = stockCubes(strain)
        TriggerServerEvent('it-drugs:server:benchCut', serverEntity)
        Wait(700)
        readCounts()
        moveProp(knife, propPoint(tbl, 'knife')) -- faca volta deitada pro lugar dela
        layKnife()
        if stockCubes(strain) > before then
            clearCenter()
            center = { kind = 'cutpile', strain = strain, obj = spawnCubes(propPoint(tbl, 'center'), heading, #CUBE_OFFSETS) }
        end
        updateBar()
    end

    --- Um cubo na balança: pesa e vai sozinho pro meio (conta até cubesPerWrap, pode misturar variedades)
    local function weigh(strain, cube)
        local onScale = GetEntityCoords(tools.scale) + vector3(0.0, 0.0, bench.scaleTop)
        moveProp(cube, onScale)
        Wait(600) -- pesando
        if not center then center = { kind = 'counted', cubes = {} } end
        local i = #center.cubes + 1
        fly(cube, onScale, centerCube(i), 0.1)
        center.cubes[i] = { obj = cube, strain = strain }
    end

    --- Zip lock nos contados do meio: embala a mistura (servidor confere, tira cubos + 1 zip lock por cubo e guarda
    --- os embalados na mesa até alguém recolher nos Prontos) e vira um saquinho pronto
    local function bagIt()
        local mix, total = countedMix()
        local filmHome, mid = propPoint(tbl, 'film'), slotPoint(tbl, 'center', 0.0, 0.0, 0.04)
        fly(tools.film, filmHome, mid, 0.08)
        Wait(300)
        local before = stockFilm()
        TriggerServerEvent('it-drugs:server:benchWrap', serverEntity, mix)
        Wait(700)
        readCounts()
        moveProp(tools.film, filmHome)
        if stockFilm() <= before - P.filmPerWrap then -- gastou o plástico filme da mesa = embalou
            clearCenter()
            center = { kind = 'bag', mix = mix, obj = spawnPacks() }
        end
        syncStock()
        updateBar()
    end

    --- Item solto da barra: só entra no espaço marcado dele, e se o espaço estiver vazio
    local function dropItem(item, point, sx, sy)
        if (count[item] or 0) < 1 then return end
        local key = itemSlot(item)
        if not key then return end
        if key == 'pile' then
            local strain = item:match('^cubo_(.+)$')
            local at = overPile(sx, sy, point)
            if not at then
                return ShowNotification(nil, _U('NOTIFICATION__BENCH__WRONG__SLOT'):format(bench.slots[bench.pileSlots[1]].label), 'error')
            end
            if not strains[strain] then return end
            local other = pileIn(at)
            if other and other ~= strain then return ShowNotification(nil, _U('NOTIFICATION__BENCH__PILE__BUSY'), 'error') end
            if not piles[strain] then
                piles[strain] = spawnCubes(propPoint(tbl, at), heading, #CUBE_OFFSETS)
                pileAt[strain] = at
            end
            TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'cube', strain) -- sai do inventário (até o limite)
            return afterServer()
        end
        if key == 'film' then
            if not inSlot(tbl, key, point) then
                return ShowNotification(nil, _U('NOTIFICATION__BENCH__WRONG__SLOT'):format(bench.slots[key].label), 'error')
            end
            if oldFilm() then return ShowNotification(nil, _U('NOTIFICATION__BENCH__OLD__FILM'), 'error') end
            if not tools.film then tools.film = put(bench.props.film, 'film') end
            TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'film') -- sai do inventário (até o limite)
            return afterServer()
        end
        if not inSlot(tbl, key, point) then
            return ShowNotification(nil, _U('NOTIFICATION__BENCH__WRONG__SLOT'):format(bench.slots[key].label), 'error')
        end
        if occupied(key) then return end
        if key == 'center' then -- tijolo sai do inventário e fica no meio
            local strain = item:match('^tijolo_(.+)$')
            if not strains[strain] then return end
            center = { kind = 'brick', strain = strain, obj = put(bench.props.brick, 'center') }
            TriggerServerEvent('it-drugs:server:benchStock', serverEntity, 'brick', strain)
        else -- faca e balança saem do inventário e ficam na mesa
            tools[key] = put(bench.props[key], key)
            if key == 'knife' then layKnife() end
            TriggerServerEvent('it-drugs:server:benchStock', serverEntity, key)
        end
        afterServer()
    end

    -- caixinha com nome e quantidade ao passar o mouse num item da mesa (a tela desenha perto do mouse)
    local hoverKey
    local function hover(g)
        local info
        if g then
            if g.kind == 'wrapped' then -- o que está esperando nos Prontos (vem do servidor)
                local ready = layouts[netId] and layouts[netId].ready
                local mix, total = {}, 0
                for _, r in ipairs(ready and ready.items or {}) do
                    local strain = r.item:match('^cubo_(.+)_embalado$')
                    if strain then mix[strain], total = (mix[strain] or 0) + r.count, total + r.count end
                end
                info = { label = total > 0 and mixText(mix) or bench.slots.wrapped.label, count = total }
            elseif g.kind == 'center' then
                if center.kind == 'counted' or center.kind == 'bag' then
                    local mix, total = center.mix, P.cubesPerWrap
                    if center.kind == 'counted' then mix, total = countedMix() end
                    info = { label = mixText(mix), count = total }
                else
                    local item = center.kind == 'brick' and 'tijolo_' .. center.strain or cubeOf(center.strain)
                    info = { label = label(item), count = center.kind == 'brick' and 1 or stockCubes(center.strain) }
                end
            else
                local item = (g.kind == 'knife' and P.knifeItem) or (g.kind == 'scale' and P.scaleItem) or (g.kind == 'film' and (oldFilm() and stock().filmItem or P.filmItem)) or cubeOf(g.key)
                local n = (g.kind == 'film' and stockFilm()) or (g.kind == 'pile' and stockCubes(g.key)) or (stockTool(g.kind) and 1) or 0
                info = { label = label(item), count = n }
            end
        end
        local key = info and (info.label .. '|' .. info.count) or nil
        if key == hoverKey then return end
        hoverKey = key
        TriggerEvent('itdrugs_bancada:hover', info)
    end

    --- Clicou nos Prontos: o servidor entrega no inventário tudo que foi embalado nessa mesa (o aviso vem dele)
    local function collectWrapped()
        TriggerServerEvent('it-drugs:server:benchCollect', serverEntity)
        for i = #wrappedProps, 1, -1 do
            deleteProp(wrappedProps[i])
            wrappedProps[i] = nil
        end
        if center and center.kind == 'bag' then clearCenter() end -- o saquinho do meio também já foi
        SetTimeout(700, function() -- a barra mostra os itens que chegaram
            if not active then return end
            readCounts()
            updateBar()
        end)
    end

    --- Botão direito: tira da mesa (o que está no estoque dela volta pro inventário)
    local function removeFromTable(g)
        outline(nil)
        hover(nil)
        if g.kind == 'wrapped' then
            collectWrapped()
        elseif g.kind == 'center' then
            if center.kind == 'bag' then addWrapped() end -- saquinho pronto não some: vai pros prontos
            if center.kind == 'brick' then
                TriggerServerEvent('it-drugs:server:benchUnstock', serverEntity, 'brick')
                afterServer()
            end
            clearCenter()
        elseif g.kind == 'pile' then
            TriggerServerEvent('it-drugs:server:benchUnstock', serverEntity, 'cube', g.key)
            removePile(g.key)
            if center and center.kind == 'counted' and countedMix()[g.key] then clearCenter() end
            afterServer()
        else
            TriggerServerEvent('it-drugs:server:benchUnstock', serverEntity, g.kind) -- film / knife / scale
            afterServer()
            deleteProp(g.obj)
            tools[g.kind] = nil
        end
        updateBar()
    end

    local function run(fn) -- animação com o mouse travado
        busy = true
        CreateThread(function() fn(); busy = false end)
    end

    --- Cubos cortados do meio pro espaço de cubos `key` (junta se a variedade já tem pilha)
    local function storeCut(key)
        local strain = center.strain
        if piles[strain] then
            clearCenter()
        elseif pileIn(key) then
            ShowNotification(nil, _U('NOTIFICATION__BENCH__PILE__BUSY'), 'error')
            return false
        else
            piles[strain], pileAt[strain] = center.obj, key
            moveProp(center.obj, propPoint(tbl, key))
            center = nil
        end
        return true -- os cubos cortados já estão no estoque da mesa (benchCut): aqui é só onde a pilha fica
    end

    --- Soltou o que estava arrastando na mesa: faz a ação se caiu no lugar certo; senão volta pro lugar
    local function release(sx, sy, point)
        local g = drag
        drag = nil
        if g.kind == 'knife' then
            if center and center.kind == 'brick' and overSlot('center', sx, sy, point) then
                if not stockTool('knife') then
                    ShowNotification(nil, _U('NOTIFICATION__MISSING__TOOL'), 'error')
                else
                    return run(cut)
                end
            end
            moveProp(g.obj, g.from)
            layKnife()
        elseif g.kind == 'pile' then -- g.obj é um cubo só, saído da pilha
            local strain = g.key
            if overScale(sx, sy, point) then
                local mix, total = countedMix()
                local err
                if center and center.kind ~= 'counted' then
                    err = _U('NOTIFICATION__BENCH__CENTER__BUSY')
                elseif total >= P.cubesPerWrap then
                    err = _U('NOTIFICATION__BENCH__CENTER__FULL')
                elseif stockCubes(strain) < (mix[strain] or 0) + 1 then
                    err = _U('NOTIFICATION__MISSING__INGIDIANT')
                end
                if not err then return run(function() weigh(strain, g.obj) end) end
                ShowNotification(nil, err, 'error')
            end
            deleteProp(g.obj)
        elseif g.kind == 'film' then
            if center and center.kind == 'counted' and overSlot('center', sx, sy, point) then
                local mix, total = countedMix()
                if oldFilm() then
                    moveProp(g.obj, g.from)
                    return ShowNotification(nil, _U('NOTIFICATION__BENCH__OLD__FILM'), 'error')
                end
                local missing = stockFilm() < P.filmPerWrap
                for strain, n in pairs(mix) do missing = missing or stockCubes(strain) < n end
                if total < P.cubesPerWrap then
                    ShowNotification(nil, _U('NOTIFICATION__BENCH__COUNT'):format(P.cubesPerWrap), 'error')
                elseif missing then
                    ShowNotification(nil, _U('NOTIFICATION__BENCH__NO__WRAP'):format(P.cubesPerWrap, P.filmPerWrap), 'error')
                else
                    moveProp(g.obj, g.from)
                    return run(bagIt)
                end
            end
            moveProp(g.obj, g.from)
        elseif g.kind == 'center' and center.kind == 'cutpile' then -- cubos cortados pra um espaço de cubos
            local key = overPile(sx, sy, point)
            if key and storeCut(key) then return updateBar() end
            moveProp(g.obj, g.from)
        elseif g.kind == 'center' and center.kind == 'bag' then -- saquinho pronto pro espaço "Prontos"
            if overSlot('wrapped', sx, sy, point) then
                clearCenter()
                addWrapped()
                return updateBar()
            end
            moveProp(g.obj, g.from)
        end
    end

    -- o que dá pra arrastar na mesa (o resto fica parado no espaço; botão direito tira)
    local function startDrag(g)
        if g.kind == 'wrapped' then -- clicar nos prontos recolhe
            outline(nil)
            hover(nil)
            return collectWrapped()
        end
        if g.kind == 'knife' or g.kind == 'film' then
            g.from = GetEntityCoords(g.obj)
        elseif g.kind == 'pile' then -- tira um cubo da pilha
            g.obj = spawnScaled(bench.props.cube, GetEntityCoords(g.obj), heading, bench.cubeSize)
            if not g.obj then return end
        elseif g.kind == 'center' and (center.kind == 'cutpile' or center.kind == 'bag') then
            g.from = GetEntityCoords(center.obj)
            g.obj = center.obj
        else
            return
        end
        outline(nil)
        hover(nil)
        drag = g
    end

    onMouse = function(data)
        if data.type == 'exit' then
            if not busy then active = false end
            return
        end
        if data.type == 'dragitem' then -- começou/parou de arrastar um item da barra: acende o espaço dele
            barDrag = type(data.item) == 'string' and itemSlot(data.item) or nil
            return
        end
        if busy then return end
        local sx, sy = tonumber(data.x) or 0.5, tonumber(data.y) or 0.5
        local point = cursorOnTable(cam, pitch, yaw, topZ, sx, sy)
        if data.type == 'drop' then
            barDrag = nil
            if point and type(data.item) == 'string' then
                dropItem(data.item, point, sx, sy)
                updateBar()
            end
        elseif data.type == 'down' then
            local g = under(sx, sy)
            if g then startDrag(g) end
        elseif data.type == 'remove' then
            local g = not drag and under(sx, sy)
            if g then removeFromTable(g) end
        elseif data.type == 'move' then
            if drag then
                if drag.kind == 'pile' and overScale(sx, sy, point) then -- o cubo sobe e encaixa em cima do prato da balança
                    moveProp(drag.obj, GetEntityCoords(tools.scale) + vector3(0.0, 0.0, bench.scaleTop))
                elseif point then
                    moveProp(drag.obj, vector3(point.x, point.y, topZ + 0.03))
                end
            else
                local g = under(sx, sy)
                outline(g and g.obj)
                hover(g)
            end
        elseif data.type == 'up' and drag then
            release(sx, sy, point)
        end
    end

    readCounts()
    for strain, obj in pairs(piles) do
        if not DoesEntityExist(obj) then removePile(strain) end
    end
    syncStock() -- faca, balança, zip lock, tijolo, pilhas e contados conforme o estoque da mesa
    TriggerEvent('itdrugs_bancada:open', barItems(), _U('BENCH__HELP'))

    while active do
        DisableAllControlActions(0)
        SetEntityLocallyInvisible(ped) -- o boneco não tampa a mesa (os outros continuam vendo ele)
        if not DoesEntityExist(tbl) or IsEntityDead(ped) then break end
        -- espaços marcados: verde onde o que está sendo arrastado pode ir ('pile' = todo espaço de cubos livre)
        local target = barDrag
        if drag then
            target = (drag.kind == 'knife' or drag.kind == 'film') and 'center' or (drag.kind == 'pile' and 'scale')
                or (center and center.kind == 'cutpile' and 'pile') or (center and center.kind == 'bag' and 'wrapped') or nil
        end
        local pulse = 0.75 + 0.25 * math.sin(GetGameTimer() / 160) -- o destino pisca devagar
        local _, total = countedMix()
        for key, slot in pairs(bench.slots) do
            if slot.mode == 'camarao' then goto continue end -- espaços do dichavador só no modo camarão
            local full = occupied(key)
            local isTarget = key == target or (target == 'pile' and slot.pile and not full)
            local text = slot.label
            local strain = slot.pile and pileIn(key)
            if strain then text = Config.WeedStrains[strain] and Config.WeedStrains[strain].label or strain end -- espaço de cubos mostra a variedade
            local inside = key == 'center' and center and center.kind == 'counted' and ('%d/%d'):format(total, P.cubesPerWrap) or nil
            drawSlot(shapes[key], slot.color, (isTarget and pulse) or (full and 0.3) or 0.65, text, inside)
            ::continue::
        end
        Wait(0)
    end

    -- arruma o meio antes de salvar: cubos cortados vão pra um espaço de cubos, saquinho vai pros prontos,
    -- contados somem (só visual: os cubos nunca saíram do inventário)
    active, onMouse = false, nil
    TriggerEvent('itdrugs_bancada:close')
    outline(nil)
    if drag then
        if drag.kind == 'pile' then deleteProp(drag.obj) elseif drag.from then moveProp(drag.obj, drag.from) end
        if drag.kind == 'knife' then layKnife() end
    end
    if center then
        if center.kind == 'brick' then
            state.brick = { strain = center.strain, obj = center.obj }
            center = nil
        elseif center.kind == 'counted' then -- os contados ficam no meio esperando o zip lock
            state.counted = { cubes = center.cubes }
            center = nil
        elseif center.kind == 'cutpile' then -- os cubos cortados ficam no meio até você levar pro espaço deles
            state.cutpile = { strain = center.strain, obj = center.obj }
            center = nil
        else
            if center.kind == 'bag' then addWrapped() end
        end
        clearCenter()
    end
    -- o que está na mesa fica lá: salva no servidor (volta depois de reiniciar e os outros veem)
    if DoesEntityExist(tbl) then
        local function spot(obj)
            local c = GetEntityCoords(obj)
            local r = GetOffsetFromEntityGivenWorldCoords(tbl, c.x, c.y, c.z)
            return { x = r.x, y = r.y }
        end
        local layout = { mode = 'prensado', tools = {}, piles = {}, wrapped = #wrappedProps }
        for key, obj in pairs(tools) do
            if DoesEntityExist(obj) then layout.tools[key] = spot(obj) end
        end
        if state.brick and DoesEntityExist(state.brick.obj) then
            local p = spot(state.brick.obj)
            layout.brick = { strain = state.brick.strain, x = p.x, y = p.y }
        end
        if state.cutpile then layout.cutpile = state.cutpile.strain end
        if state.counted then
            layout.counted = {}
            for _, c in ipairs(state.counted.cubes) do layout.counted[c.strain] = (layout.counted[c.strain] or 0) + 1 end
        end
        for strain, obj in pairs(piles) do
            if DoesEntityExist(obj) then layout.piles[strain] = spot(obj) end
        end
        ownSend[netId] = true
        TriggerServerEvent('it-drugs:server:setBenchLayout', netId, layout)
    end
    activeTable = nil
    leaveBench(ped, cam)
end)

--- Modo usado por último nessa mesa (o E mostra ele primeiro)
function BenchMode(entity)
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity)
    return netId and layouts[netId] and layouts[netId].mode or 'prensado'
end

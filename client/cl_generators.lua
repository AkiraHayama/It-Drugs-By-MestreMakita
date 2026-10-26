if not Config.EnableGenerators then return end

-- Estado vindo do servidor (sv_generators.lua: SyncGenerators)
local generators = {} -- { id, netId, coords, item, fuel, tank, connected, active, maxDevices }
local connections = {} -- { genNetId, devNetId }
local connectedDevices = {} -- devNetId -> true

local generatorModels, deviceModels = {}, {}
for _, v in pairs(Config.Generators) do generatorModels[GetHashKey(v.model)] = true end
for _, v in pairs(Config.Fans or {}) do deviceModels[GetHashKey(v.model)] = true end
for _, v in pairs(Config.Lamps or {}) do deviceModels[GetHashKey(v.model)] = true end

local CABLE_DRAW_DISTANCE = 30.0
local CABLE_SAG = 3.0 -- quanto o meio do cabo "pesa" pra baixo (m): grande = deita no chão como extensão jogada
local CABLE_WIDTH = 0.012 -- meia largura (m): fio de ~2,5 cm
local CABLE_COLOR = { 25, 25, 25, 255 }
local TEXT_DISTANCE = 5.0
local cables = {} -- "genNetId:devNetId" -> pontos do cabo (calculados 1x; gerador e aparelho não se mexem)

local applySync = function(data)
    generators = data and data.generators or {}
    connections = data and data.connections or {}
    connectedDevices = {}
    for _, c in ipairs(connections) do connectedDevices[c.devNetId] = true end
    cables = {} -- o loop dos cabos recalcula só os que ainda existem
end

RegisterNetEvent('it-drugs:client:syncGenerators', applySync)
CreateThread(function()
    applySync(lib.callback.await('it-drugs:server:getGenerators', false))
end)

--- Energia de um ventilador/lâmpada: 'on' (extensão num gerador com gasolina), 'nofuel' (extensão, gerador sem
--- gasolina) ou 'none' (sem extensão) - texto em cima da lâmpada (cl_lamps.lua)
function DevicePower(entity)
    if not NetworkGetEntityIsNetworked(entity) then return 'none' end
    local devNetId = NetworkGetNetworkIdFromEntity(entity)
    for _, c in ipairs(connections) do
        if c.devNetId == devNetId then
            for _, g in ipairs(generators) do
                if g.netId == c.genNetId then
                    if g.isOn == false then return 'off' end
                    return (tonumber(g.fuel) or 0) > 0 and 'on' or 'nofuel'
                end
            end
        end
    end
    return 'none'
end

--- Ventilador/lâmpada ligado numa extensão? (opção "Desconectar extensão" em cl_target.lua)
function IsDeviceConnected(entity)
    return NetworkGetEntityIsNetworked(entity) and connectedDevices[NetworkGetNetworkIdFromEntity(entity)] == true
end

-- ┌────────────────────────────────────────────────────────┐
-- │ Colocar, menu, abastecer e recolher                     │
-- └────────────────────────────────────────────────────────┘
RegisterNetEvent('it-drugs:client:placeGenerator', function(item)
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end
    local ok, hashModel = it.requestModel(Config.Generators[item].model, 'Config.Generators.' .. item .. '.model errado')
    if not ok then
        ShowNotification(nil, 'Modelo do gerador não carregou (Config.Generators.' .. item .. '.model errado)', "error")
        return
    end
    it.placeObjectWithRotation(hashModel, "bolt", function(coords, rotation)
        if it.playAnimatedProgress(_U('PROGRESSBAR__PLACE__GENERATOR'), 3000) then
            TriggerServerEvent('it-drugs:server:createNewGenerator', coords, item, rotation)
        end
    end)
end)

RegisterNetEvent('it-drugs:client:openGenerator', function(args)
    local data = lib.callback.await('it-drugs:server:getGeneratorData', false, NetworkGetNetworkIdFromEntity(args.entity))
    if not data then return end

    lib.registerContext({
        id = 'it-drugs-generator-menu',
        title = _U('MENU__GENERATOR'),
        options = {
            {
                title = _U('MENU__GENERATOR__FUEL'),
                description = ('%.1f / %.0f L'):format(data.fuel, data.tank),
                icon = 'gas-pump',
                progress = math.floor(data.fuel / data.tank * 100),
                colorScheme = data.fuel > 0 and 'yellow' or 'red',
            },
            {
                title = _U('MENU__GENERATOR__DEVICES'):format(data.connected, data.maxDevices),
                description = _U('MENU__GENERATOR__DEVICES__DESC'):format(data.active),
                icon = 'plug',
            },
            {
                title = _U('MENU__GENERATOR__REFUEL'),
                description = _U('MENU__GENERATOR__REFUEL__DESC'),
                icon = 'gas-pump',
                arrow = true,
                onSelect = function()
                    if not it.hasItem(Config.FuelItem, 1) then
                        ShowNotification(nil, _U('NOTIFICATION__GENERATOR__NO__FUEL'), 'error')
                        return
                    end
                    TaskTurnPedToFaceEntity(PlayerPedId(), args.entity, 800)
                    if it.playAnimatedProgress(_U('PROGRESSBAR__REFUEL__GENERATOR'), 4000) then
                        TriggerServerEvent('it-drugs:server:refuelGenerator', { entity = data.entity })
                    end
                end,
            },
            {
                title = _U('MENU__GENERATOR__TAKE'),
                description = _U('MENU__GENERATOR__TAKE__DESC'),
                icon = 'hand',
                arrow = true,
                onSelect = function()
                    if it.playAnimatedProgress(_U('PROGRESSBAR__TAKE__GENERATOR'), 3000) then
                        TriggerServerEvent('it-drugs:server:takeGenerator', { entity = data.entity })
                    end
                end,
            },
        },
    })
    lib.showContext('it-drugs-generator-menu')
end)

--- Estado do gerador dessa entidade pras opções do E (cl_target.lua), vindo do último sync
function GetGeneratorState(entity)
    if not NetworkGetEntityIsNetworked(entity) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    for _, gen in ipairs(generators) do
        if gen.netId == netId then return gen end
    end
end

-- Opções do E (sem menu): pegam o handle do servidor e seguem o mesmo fluxo do menu
RegisterNetEvent('it-drugs:client:generatorRefuel', function(args)
    -- só com galão com gasolina (metadata cdn_fuel do cdn-fuel); vazio não enche
    local liters = 0
    for _, slot in ipairs(exports.ox_inventory:Search('slots', Config.FuelItem) or {}) do
        liters = math.max(liters, tonumber(slot.metadata and slot.metadata.cdn_fuel) or 0)
    end
    if liters <= 0 then return ShowNotification(nil, _U('NOTIFICATION__GENERATOR__EMPTY__CAN'), 'error') end
    local data = lib.callback.await('it-drugs:server:getGeneratorData', false, NetworkGetNetworkIdFromEntity(args.entity))
    if not data then return end
    TaskTurnPedToFaceEntity(PlayerPedId(), args.entity, 800)
    Wait(500)
    -- o galão vai pra mão enquanto despeja (shortcut: posição do galão chutada; ajustar pos/rot se ficar torto)
    if lib.progressBar({
        duration = 4000,
        label = _U('PROGRESSBAR__REFUEL__GENERATOR'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flag = 1 },
        prop = { model = 'prop_ld_jerrycan_01', bone = 57005, pos = vec3(0.12, 0.05, -0.33), rot = vec3(-80.0, 10.0, 0.0) },
    }) then
        TriggerServerEvent('it-drugs:server:refuelGenerator', { entity = data.entity })
    end
end)

RegisterNetEvent('it-drugs:client:generatorTake', function(args)
    local gen = GetGeneratorState(args.entity)
    if gen and gen.connected > 0 then return ShowNotification(nil, _U('NOTIFICATION__GENERATOR__HAS__DEVICES'), 'error') end
    local data = lib.callback.await('it-drugs:server:getGeneratorData', false, NetworkGetNetworkIdFromEntity(args.entity))
    if not data then return end
    if it.playAnimatedProgress(_U('PROGRESSBAR__TAKE__GENERATOR'), 3000) then
        TriggerServerEvent('it-drugs:server:takeGenerator', { entity = data.entity })
    end
end)

RegisterNetEvent('it-drugs:client:disconnectExtension', function(args)
    if it.playAnimatedProgress(_U('PROGRESSBAR__DISCONNECT__EXTENSION'), 2000) then
        TriggerServerEvent('it-drugs:server:disconnectExtension', NetworkGetNetworkIdFromEntity(args.entity))
    end
end)

-- ┌────────────────────────────────────────────────────────┐
-- │ Extensão: mira no gerador [E], depois no aparelho [E]   │
-- └────────────────────────────────────────────────────────┘
--- Mira (mesmo raio da colocação) num objeto válido, com contorno azul; [E] escolhe, [G] cancela
--- @return number? entity
local pickEntity = function(text, isValid)
    lib.showTextUI(text, { position = 'left-center', icon = 'plug' })
    local outlined
    local outline = function(entity)
        if outlined == entity then return end
        if outlined and DoesEntityExist(outlined) then SetEntityDrawOutline(outlined, false) end
        outlined = entity
        if entity then
            SetEntityDrawOutlineColor(80, 170, 255, 255)
            SetEntityDrawOutline(entity, true)
        end
    end

    while true do
        Wait(0)
        local hit, _, entity = it.rayCastCamera(Config.rayCastingDistance)
        local target = hit == 1 and entity and entity ~= 0 and DoesEntityExist(entity)
            and NetworkGetEntityIsNetworked(entity) and isValid(entity) and entity or nil
        outline(target)
        if target and IsControlJustPressed(0, 38) then
            outline(nil)
            lib.hideTextUI()
            return target
        end
        if IsControlJustPressed(0, 47) then
            outline(nil)
            lib.hideTextUI()
            return nil
        end
    end
end

RegisterNetEvent('it-drugs:client:useExtension', function()
    local generator = pickEntity(_U('INTERACTION__EXTENSION__GENERATOR'), function(e) return generatorModels[GetEntityModel(e)] end)
    if not generator then return end
    local device = pickEntity(_U('INTERACTION__EXTENSION__DEVICE'), function(e) return deviceModels[GetEntityModel(e)] end)
    if not device then return end

    TaskTurnPedToFaceEntity(PlayerPedId(), device, 800)
    if it.playAnimatedProgress(_U('PROGRESSBAR__CONNECT__EXTENSION'), 2500) then
        TriggerServerEvent('it-drugs:server:connectExtension', NetworkGetNetworkIdFromEntity(generator), NetworkGetNetworkIdFromEntity(device))
    end
end)

-- ┌────────────────────────────────────────────────────────┐
-- │ Cabos (desenhados) e combustível em cima do gerador     │
-- └────────────────────────────────────────────────────────┘
-- A corda física do GTA ficava dura em linha reta (ignorava a folga), então o cabo é desenhado:
-- sai da tomada do gerador, desce até o chão, corre pelo piso e sobe até o aparelho.
local localEntity = function(netId)
    return NetworkDoesEntityExistWithNetworkId(netId) and NetworkGetEntityFromNetworkId(netId) or 0
end

local buildCable = function(gen, dev)
    local from = GetOffsetFromEntityInWorldCoords(gen, 0.0, 0.0, 0.4)
    local to = GetOffsetFromEntityInWorldCoords(dev, 0.0, 0.0, 0.3)
    local steps = math.max(10, math.floor(#(from - to) * 6))
    local points = {}
    for i = 0, steps do
        local t = i / steps
        local p = from + (to - from) * t
        local z = p.z - CABLE_SAG * 4 * t * (1 - t)
        local found, ground = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.5, false)
        if found and z < ground + 0.02 then z = ground + 0.02 end -- não atravessa o chão: deita nele
        points[#points + 1] = vector3(p.x, p.y, z)
    end
    return points
end

local quad = function(a1, a2, b1, b2)
    local r, g, b, al = CABLE_COLOR[1], CABLE_COLOR[2], CABLE_COLOR[3], CABLE_COLOR[4]
    -- as duas faces de cada triângulo (DrawPoly só desenha um lado)
    DrawPoly(a1.x, a1.y, a1.z, a2.x, a2.y, a2.z, b1.x, b1.y, b1.z, r, g, b, al)
    DrawPoly(b1.x, b1.y, b1.z, a2.x, a2.y, a2.z, a1.x, a1.y, a1.z, r, g, b, al)
    DrawPoly(a2.x, a2.y, a2.z, b2.x, b2.y, b2.z, b1.x, b1.y, b1.z, r, g, b, al)
    DrawPoly(b1.x, b1.y, b1.z, b2.x, b2.y, b2.z, a2.x, a2.y, a2.z, r, g, b, al)
end

-- duas faixas cruzadas (deitada + em pé) pra o fio aparecer de cima e de lado
local drawCable = function(points)
    local up = vector3(0.0, 0.0, CABLE_WIDTH)
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local len = math.sqrt(dx * dx + dy * dy)
        local side = len > 0.001 and vector3(-dy / len * CABLE_WIDTH, dx / len * CABLE_WIDTH, 0.0) or vector3(CABLE_WIDTH, 0.0, 0.0)
        quad(a + side, a - side, b + side, b - side)
        quad(a + up, a - up, b + up, b - up)
    end
end

CreateThread(function()
    while true do
        local playerCoords, near = GetEntityCoords(PlayerPedId()), false
        for _, c in ipairs(connections) do
            local gen, dev = localEntity(c.genNetId), localEntity(c.devNetId)
            if gen ~= 0 and dev ~= 0 and #(GetEntityCoords(gen) - playerCoords) < CABLE_DRAW_DISTANCE then
                near = true
                local key = c.genNetId .. ':' .. c.devNetId
                cables[key] = cables[key] or buildCable(gen, dev)
                drawCable(cables[key])
            end
        end
        Wait(near and 0 or 500)
    end
end)

local drawText3D = function(coords, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local genTop = {}
CreateThread(function()
    while true do
        local playerCoords, near = GetEntityCoords(PlayerPedId()), false
        for _, gen in ipairs(generators) do
            if #(gen.coords - playerCoords) < TEXT_DISTANCE then
                near = true
                if not genTop[gen.item] then
                    local _, max = GetModelDimensions(GetHashKey(Config.Generators[gen.item].model))
                    genTop[gen.item] = max.z > 0.1 and max.z + 0.2 or 1.0
                end
                local color = gen.fuel > 0 and '~y~' or '~r~'
                local state = gen.isOn == false and ('~r~' .. _U('TEXT__GENERATOR__OFF')) or ('~g~' .. _U('TEXT__GENERATOR__ON'))
                drawText3D(gen.coords + vector3(0.0, 0.0, genTop[gen.item]),
                    ('%s~w~  ·  %s%.1f / %.0f L~w~  ·  %d/%d'):format(state, color, gen.fuel, gen.tank, gen.connected, gen.maxDevices))
            end
        end
        Wait(near and 0 or 500)
    end
end)

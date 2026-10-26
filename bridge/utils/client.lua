function it.notify(message, type, length)
    if it.core == 'qb-core' then
        CoreObject.Functions.Notify(message, type, length)
    elseif it.core == 'esx' then
        CoreObject.ShowNotification(message, type, length)
    end
end

RegisterNetEvent('it-drugs:client:Notify', function(message, type, length)
    it.notify(message, type, length)
end)

-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ Helpers de posicionamento/interação usados por todo item colocável      │
-- │ (vaso, lâmpada, secador, mesa de processamento, semente no chão) -      │
-- │ antes cada client/cl_*.lua tinha sua própria cópia colada dessas mesmas │
-- │ funções (RotationToDirection/RayCastCamera/anim+progressbar/load model  │
-- │ com timeout), centralizado aqui pra não precisar repetir/manter 5x.     │
-- └────────────────────────────────────────────────────────────────────────┘

function it.rotationToDirection(rot)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local cosOfRotX = math.abs(math.cos(rotX))
    return vector3(-math.sin(rotZ) * cosOfRotX, math.cos(rotZ) * cosOfRotX, math.sin(rotX))
end

--- Raycast a partir da câmera do jogador (usado pra mirar onde posicionar um objeto).
--- @param dist number - distância máxima (metros)
--- @return number hit, vector3 endPos, number entityHit, vector3 surfaceNormal
function it.rayCastCamera(dist)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local dir = it.rotationToDirection(camRot)
    local dest = camPos + (dir * dist)
    local ray = StartShapeTestRay(camPos, dest, 17, -1, 0)
    local _, hit, endPos, surfaceNormal, entityHit = GetShapeTestResult(ray)
    if hit == 0 then endPos = dest end
    return hit, endPos, entityHit, surfaceNormal
end

--- Ponto mirado preso a no máximo Config.PlaceMaxDistance do boneco (na horizontal), no chão:
--- mirando mais longe, o objeto/planta fica parado na borda do alcance naquela direção
--- @param dest vector3
--- @return vector3
function it.clampToReach(dest)
    local ped = GetEntityCoords(PlayerPedId())
    local dx, dy = dest.x - ped.x, dest.y - ped.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= Config.PlaceMaxDistance then return dest end
    local x, y = ped.x + dx / dist * Config.PlaceMaxDistance, ped.y + dy / dist * Config.PlaceMaxDistance
    local found, z = GetGroundZFor_3dCoord(x, y, dest.z + 1.0, false)
    return vector3(x, y, found and z or dest.z)
end

local PLACE_STAND_DISTANCE = 0.8 -- o boneco para a essa distância (m) do ponto antes de colocar
local PLACE_WALK_TIMEOUT = 5000 -- ms; travou em algo no caminho, coloca de onde está (o servidor aceita até PlaceMaxDistance + folga)

--- Anda até perto do ponto escolhido e vira de frente pra ele, antes da animação de colocar
--- @param coords vector3
function it.walkToPlace(coords)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local dx, dy = coords.x - pos.x, coords.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > PLACE_STAND_DISTANCE then
        local standX, standY = coords.x - dx / dist * PLACE_STAND_DISTANCE, coords.y - dy / dist * PLACE_STAND_DISTANCE
        TaskGoStraightToCoord(ped, standX, standY, pos.z, 1.0, PLACE_WALK_TIMEOUT, GetHeadingFromVector_2d(dx, dy), 0.1)
        local giveUpAt = GetGameTimer() + PLACE_WALK_TIMEOUT
        repeat
            Wait(50)
            local now = GetEntityCoords(ped)
            local left = math.sqrt((standX - now.x) ^ 2 + (standY - now.y) ^ 2)
        until left < 0.3 or GetGameTimer() > giveUpAt
        ClearPedTasks(ped)
    end

    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 800)
    Wait(400)
end

--- Pede um model e espera carregar, com timeout (~500 ticks) - mostra erro no console em vez de
--- travar o thread do cliente pra sempre em silêncio se o model for inválido ou o resource do
--- prop não estiver rodando (bug já visto antes em vaso/lâmpada/secador/semente, um de cada vez).
--- @param model string|number - nome do model ou hash já calculado
--- @param debugLabel string|nil - texto extra pro print de erro (ex.: "Config.Pots.vaso.model errado")
--- @return boolean success, number hashModel
function it.requestModel(model, debugLabel)
    local hashModel = type(model) == 'number' and model or GetHashKey(model)
    RequestModel(hashModel)

    local waited = 0
    while not HasModelLoaded(hashModel) do
        Wait(0)
        waited = waited + 1
        if waited > 500 then -- ~a few seconds, model is invalid/never streamed in
            print(('[it-drugs][debug] failed to load model "%s" (hash %s)%s'):format(tostring(model), tostring(hashModel), debugLabel and (' - ' .. debugLabel) or ''))
            return false, hashModel
        end
    end
    return true, hashModel
end

--- Anim de "mexendo no chão" + progressbar cancelável - usado em praticamente toda ação de
--- plantio/cuidado de planta/colocar objeto do it-drugs. Mostra a notificação de cancelado
--- sozinho quando o progressbar é interrompido.
--- @param label string
--- @param duration number - ms
--- @return boolean success
function it.playAnimatedProgress(label, duration)
    local ped = PlayerPedId()

    RequestAnimDict('amb@medic@standing@kneel@base')
    RequestAnimDict('anim@gangops@facility@servers@bodysearch@')
    while
        not HasAnimDictLoaded('amb@medic@standing@kneel@base') or
        not HasAnimDictLoaded('anim@gangops@facility@servers@bodysearch@')
    do
        Wait(0)
    end

    TaskPlayAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
    TaskPlayAnim(ped, 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, 8.0, -1, 48, 0, false, false, false)

    local success = lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
    })

    ClearPedTasks(ped)
    RemoveAnimDict('amb@medic@standing@kneel@base')
    RemoveAnimDict('anim@gangops@facility@servers@bodysearch@')

    if not success then
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
    end

    return success
end

local PLACE_ROTATION_STEP = 15.0 -- graus por clique da rodinha do mouse ao posicionar (era 1, lento demais)

--- Frente de uma mesa: o lado comprido em -Y do modelo (-X se o modelo for comprido no Y), onde o jogador fica.
--- Devolve os 4 cantos de um retângulo no chão que sai depth metros da borda (perto-esq, perto-dir,
--- longe-dir, longe-esq) e at(along, out): ponto a along metros do meio da borda e out metros pra fora.
function it.frontArea(obj, depth)
    local mn, mx = GetModelDimensions(GetEntityModel(obj))
    local longX = (mx.x - mn.x) >= (mx.y - mn.y)
    local function at(along, out)
        local x, y
        if longX then
            x, y = (mn.x + mx.x) / 2 + along, mn.y - out
        else
            x, y = mn.x - out, (mn.y + mx.y) / 2 + along
        end
        return GetOffsetFromEntityInWorldCoords(obj, x, y, 0.0)
    end
    local half = (longX and (mx.x - mn.x) or (mx.y - mn.y)) * 0.4
    return at(-half, 0.05), at(half, 0.05), at(half, depth), at(-half, depth), at
end

--- Tem parede/objeto/carro na frente da mesa? Raios na altura da canela, cintura e peito cruzando o retângulo.
function it.isFrontBlocked(obj, depth)
    local a, b, c, d, at = it.frontArea(obj, depth)
    local segments = { { a, d }, { b, c }, { at(0.0, 0.05), at(0.0, depth) }, { d, c }, { (a + d) / 2, (b + c) / 2 } }
    for _, h in ipairs({ 0.3, 0.9, 1.5 }) do
        for _, s in ipairs(segments) do
            local p, q = s[1], s[2]
            local ray = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, p.z + h, q.x, q.y, q.z + h, 1 + 2 + 16, obj, 7)
            local _, hit = GetShapeTestResult(ray)
            if hit == 1 then return true end
        end
    end
    return false
end

--- Quadrado no chão na frente da mesa: verde = livre, vermelho = bloqueado
local function drawFront(obj, depth, blocked)
    local a, b, c, d = it.frontArea(obj, depth)
    local up = vector3(0.0, 0.0, 0.03)
    a, b, c, d = a + up, b + up, c + up, d + up
    local r, g, bl = 70, 200, 100
    if blocked then r, g, bl = 220, 60, 60 end
    local function tri(p, q, w) -- os dois lados, pra aparecer de qualquer ângulo
        DrawPoly(p.x, p.y, p.z, q.x, q.y, q.z, w.x, w.y, w.z, r, g, bl, 80)
        DrawPoly(w.x, w.y, w.z, q.x, q.y, q.z, p.x, p.y, p.z, r, g, bl, 80)
    end
    tri(a, b, c)
    tri(a, c, d)
    for _, e in ipairs({ { a, b }, { b, c }, { c, d }, { d, a } }) do
        DrawLine(e[1].x, e[1].y, e[1].z, e[2].x, e[2].y, e[2].z, r, g, bl, 220)
    end
end

--- Loop interativo de "segura o objeto na frente da câmera, gira com Q/E, confirma com [E],
--- cancela com [G]" - usado por vaso, lâmpada, secador e mesa de processamento (a única
--- diferença entre eles era o ícone do textUI e o que acontecia ao confirmar). Sempre spawna
--- no chão (na mira, ou projetado à frente do ped se a mira não bater em nada), nunca flutuando.
--- @param hashModel number
--- @param icon string - ícone do lib.showTextUI
--- @param onConfirm function(coords: vector3, rotation: number) - chamado ao confirmar (o objeto
---   fantasma já foi deletado antes de chamar - onConfirm é responsável por dar o evento pro server)
--- @param range number? - alcance em metros (ventilador): segurando ALT mostra essa área em volta do fantasma
--- @param front number? - mesa: metros que precisam ficar livres na frente (quadrado no chão; bloqueado não deixa por)
function it.placeObjectWithRotation(hashModel, icon, onConfirm, range, front)
    local ped = PlayerPedId()

    local text = _U('INTERACTION__PLACING__TEXT')
    if range then text = text .. ' / ' .. _U('INTERACTION__PLACING__RANGE') end
    if front then text = text .. ' / ' .. _U('INTERACTION__PLACING__FRONT') end
    lib.showTextUI(text, {
        position = "left-center",
        icon = icon,
    })

    local hit, dest = it.rayCastCamera(Config.rayCastingDistance)
    local coords = GetEntityCoords(ped)
    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, true)

    local obj = CreateObject(hashModel, coords.x, coords.y, groundZ, false, false, false)
    SetEntityCollision(obj, false, false)
    SetEntityAlpha(obj, 150, true)
    SetEntityHeading(obj, 0.0)

    local placed = false
    local rotation = 0.0
    local frontBlocked, nextFrontCheck = false, 0
    -- frente bloqueada: avisa e continua posicionando
    local function frontOk()
        if front and frontBlocked then
            ShowNotification(nil, _U('NOTIFICATION__TABLE__FRONT__BLOCKED'), 'error')
            return false
        end
        return true
    end
    while not placed do
        Wait(0)
        hit, dest = it.rayCastCamera(Config.rayCastingDistance)
        if hit == 1 then dest = it.clampToReach(dest) end

        if front then
            if GetGameTimer() >= nextFrontCheck then -- raios custam: confere 6x por segundo
                frontBlocked = it.isFrontBlocked(obj, front)
                nextFrontCheck = GetGameTimer() + 150
            end
            drawFront(obj, front, frontBlocked)
        end

        if range then
            DisableControlAction(0, 19, true) -- ALT: não deixa outro script usar enquanto posiciona
            if IsDisabledControlPressed(0, 19) then
                local c = GetEntityCoords(obj)
                -- círculo no chão com o raio do alcance, em volta do pé do objeto
                DrawMarker(1, c.x, c.y, c.z - 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, range * 2.0, range * 2.0, 0.15, 80, 170, 255, 120, false, false, 2, false, nil, nil, false)
            end
        end

        if hit == 1 then
            SetEntityCoords(obj, dest.x, dest.y, dest.z)

            if IsControlJustPressed(0, 14) or IsControlJustPressed(0, 16) then
                rotation = (rotation + PLACE_ROTATION_STEP) % 360.0
                SetEntityHeading(obj, rotation)
            end

            if IsControlJustPressed(0, 15) or IsControlJustPressed(0, 17) then
                rotation = (rotation - PLACE_ROTATION_STEP) % 360.0
                SetEntityHeading(obj, rotation)
            end

            if IsControlJustPressed(0, 38) and frontOk() then
                placed = true
                lib.hideTextUI()
                it.walkToPlace(dest) -- o fantasma fica parado no lugar enquanto o boneco anda até ele
                DeleteObject(obj)
                onConfirm(dest, rotation)
                return
            end

            if IsControlJustPressed(0, 47) then
                placed = true
                lib.hideTextUI()
                DeleteObject(obj)
                return
            end
        else
            coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local forwardVector = GetEntityForwardVector(ped)
            _, groundZ = GetGroundZFor_3dCoord(coords.x + (forwardVector.x * .5), coords.y + (forwardVector.y * .5), coords.z + (forwardVector.z * .5), true)

            SetEntityCoords(obj, coords.x + (forwardVector.x * .5), coords.y + (forwardVector.y * .5), groundZ)
            SetEntityHeading(obj, heading)

            if IsControlJustPressed(0, 38) and frontOk() then
                placed = true
                local finalCoords = GetEntityCoords(obj)
                lib.hideTextUI()
                DeleteObject(obj)
                onConfirm(finalCoords, heading)
                return
            end

            if IsControlJustPressed(0, 47) then
                placed = true
                lib.hideTextUI()
                DeleteObject(obj)
                return
            end
        end
    end
end
--- Tem teto em cima dessas coords (mapa ou objeto; árvore não conta)? Mesmo raio pra cima do cálculo
--- de sol das plantas (cl_pots.lua:calculateSunlight) - usado pra saber se a rede está em lugar fechado
--- @param coords vector3
--- @param height number? - de quanto acima das coords o raio sai (pra não bater no próprio prop)
function it.isIndoors(coords, height)
    local z = coords.z + (height or 0.0)
    local ray = StartShapeTestRay(coords.x, coords.y, z, coords.x, coords.y, z + 50.0, 1 + 16, PlayerPedId(), 0)
    local _, hit = GetShapeTestResult(ray)
    return hit == 1
end

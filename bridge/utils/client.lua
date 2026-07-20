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

--- Loop interativo de "segura o objeto na frente da câmera, gira com Q/E, confirma com [E],
--- cancela com [G]" - usado por vaso, lâmpada, secador e mesa de processamento (a única
--- diferença entre eles era o ícone do textUI e o que acontecia ao confirmar). Sempre spawna
--- no chão (na mira, ou projetado à frente do ped se a mira não bater em nada), nunca flutuando.
--- @param hashModel number
--- @param icon string - ícone do lib.showTextUI
--- @param onConfirm function(coords: vector3, rotation: number) - chamado ao confirmar (o objeto
---   fantasma já foi deletado antes de chamar - onConfirm é responsável por dar o evento pro server)
function it.placeObjectWithRotation(hashModel, icon, onConfirm)
    local ped = PlayerPedId()

    lib.showTextUI(_U('INTERACTION__PLACING__TEXT'), {
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
    while not placed do
        Wait(0)
        hit, dest = it.rayCastCamera(Config.rayCastingDistance)

        if hit == 1 then
            SetEntityCoords(obj, dest.x, dest.y, dest.z)

            if IsControlJustPressed(0, 14) or IsControlJustPressed(0, 16) then
                rotation = rotation + 1.0
                if rotation >= 360.0 then rotation = 0.0 end
                SetEntityHeading(obj, rotation)
            end

            if IsControlJustPressed(0, 15) or IsControlJustPressed(0, 17) then
                rotation = rotation - 1.0
                if rotation <= 0.0 then rotation = 360.0 end
                SetEntityHeading(obj, rotation)
            end

            if IsControlJustPressed(0, 38) then
                placed = true
                lib.hideTextUI()
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

            if IsControlJustPressed(0, 38) then
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
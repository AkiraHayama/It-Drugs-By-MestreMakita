local growZones = {}

for k, v in pairs(Config.Zones) do
    local coords = {}
    for _, point in ipairs(v.points) do
        table.insert(coords, vector3(point.x, point.y, point.z))
    end

    growZones[k] = lib.zones.poly({
        points = coords,
        thickness = v.thickness,
        debug = Config.DebugPoly,
    })
end

-- Functions
local GetGroundHash = function(ped)
    local posped = GetEntityCoords(ped)
    local num =
        StartShapeTestCapsule(posped.x, posped.y, posped.z + 4, posped.x, posped.y, posped.z - 2.0, 2, 1, ped, 7)
    local arg1, arg2, arg3, arg4, arg5 = GetShapeTestResultEx(num)
    return arg5
end

-- Base sunlight for the zone, reduced by whatever is blocking the sky above (roof, tree, etc.)
local calculateSunlight = function(coords)
    local baseSunlight = Config.SunlightZones[GetZoneAtCoords(coords.x, coords.y, coords.z)] or Config.DefaultSunlight
    baseSunlight = math.max(50, math.min(100, baseSunlight + (math.random() * 10 - 5)))

    -- Qualquer teto/cobertura acima (não importa a altura) já conta como "fechado" - sol direto só
    -- existe a céu aberto de verdade. Antes isso era proporcional à distância do teto (um teto alto
    -- ainda dava luz parcial), o que deixava lugar fechado nascendo com luz mesmo sem lâmpada
    -- nenhuma por perto - errado, luz indoor tem que vir só da lâmpada.
    local skyCoords = vector3(coords.x, coords.y, coords.z + 50.0)
    local ray = StartShapeTestRay(coords.x, coords.y, coords.z, skyCoords.x, skyCoords.y, skyCoords.z, 273, 0, 0)
    local _, hit = GetShapeTestResult(ray)
    local skyFactor = hit == 1 and 0.0 or 1.0

    return math.max(0, math.min(100, baseSunlight * skyFactor))
end

local getCurrentZone = function(coords, plantItem)
    for k, v in pairs(growZones) do
        if growZones[k]:contains(vector3(coords.x, coords.y, coords.z)) then
            if Config.Debug then lib.print.info('Inside Zone: ', k) end -- DEBUG
            for _, drug in ipairs(Config.Zones[k].exclusive) do
                if Config.Debug then lib.print.info('Drugs: ', Config.Zones[k].exclusive) end -- DEBUG
                if drug == plantItem then
                    if Config.Debug then lib.print.info('Zone: ', k) end -- DEBUG
                    return k
                end
            end
        end
    end
    return nil
end

local plantSeed = function(ped, plant, plantInfos, plantItem, coords, metadata)

    -- check for near plants
    local plants = lib.callback.await('it-drugs:server:getPlants', false)

    if plants ~= nil then
        for k, v in pairs(plants) do
            if #(vector3(coords.x, coords.y, coords.z) - vector3(v.coords.x, v.coords.y, v.coords.z)) <= Config.PlantDistance then
                ShowNotification(nil, _U('NOTIFICATION__TO__NEAR'), "error")
                DeleteObject(plant)
                return
            end
        end
    end

    if Config.OnlyAllowedGrounds then
        local groundHash = GetGroundHash(plant)
        local canplant = false
        if Config.Debug then lib.print.info('Current Ground Hash: ' .. groundHash) end -- DEBUG 
        for _, ground in pairs(Config.AllowedGrounds) do
            if groundHash == ground then
                canplant = true
            end
        end

        if not canplant then
            ShowNotification(nil, _U('NOTIFICATION__CANT__PLACE'), "error")
            DeleteObject(plant)
            return
        end
    end

    local zone = getCurrentZone(coords, plantItem)
    if Config.OnlyZones then
        if zone == nil then
            ShowNotification(nil, _U('NOTIFICATION__CANT__PLACE'), "error")
            DeleteObject(plant)
            return
        end
    end

    DeleteObject(plant)

    if it.playAnimatedProgress(_U('PROGRESSBAR__SPAWN__PLANT'), plantInfos.time) then
        local sunlight = calculateSunlight(coords)
        TriggerServerEvent('it-drugs:server:createNewPlant', coords, plantItem, zone, metadata, sunlight)
    end
end

-- Events
RegisterNetEvent('it-drugs:client:useSeed', function(plantItem, metadata)

    if Config.Debug then lib.print.info('Planting: ', plantItem) end -- DEBUG 

    local ped = PlayerPedId()
    local plantInfos = Config.Plants[plantItem]
    if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
        ShowNotification(nil, _U('NOTIFICATION__IN__VEHICLE'), "error")
        return
    end

    local ownedPlants = lib.callback.await('it-drugs:server:getPlantsOwned', false)
    if ownedPlants ~= nil then
        if #ownedPlants >= Config.PlayerPlantLimit then
            ShowNotification(nil, _U('NOTIFICATION__MAX__PLANTS'), "error")
            return
        end
    end

    local plantModelName = Config.PlantTypes[plantInfos.plantType][1][1]
    local customOffset = Config.PlantTypes[plantInfos.plantType][1][2]
    local ok, hashModel = it.requestModel(plantModelName, ('semente "%s" (plantType "%s") - check Config.PlantTypes[%s][1][1]'):format(plantItem, plantInfos.plantType, plantInfos.plantType))
    if not ok then
        ShowNotification(nil, 'Modelo da planta não carregou (Config.PlantTypes.' .. plantInfos.plantType .. ' errado, ou o resource do prop não está rodando)', "error")
        return
    end

    lib.showTextUI(_U('INTERACTION__PLACING__TEXT'), {
        position = "left-center",
        icon = "spoon",
    })

    -- Placing the plant on the ground and waiting for the player to press [E] to plant it
    local hit, dest, _, _ = it.rayCastCamera(Config.rayCastingDistance)
    local coords = GetEntityCoords(ped)
    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, true)

    local plant = CreateObject(hashModel, coords.x, coords.y, groundZ + customOffset, false, false, false)
    SetEntityCollision(plant, false, false)
    SetEntityAlpha(plant, 150, true)

    local planted = false
    while not planted do
        Wait(0)
        hit, dest, _, _ = it.rayCastCamera(Config.rayCastingDistance)
        if hit == 1 then
            SetEntityCoords(plant, dest.x, dest.y, dest.z + customOffset)
        
        -- [E] To spawn plant
            if IsControlJustPressed(0, 38) then
                if Config.Debug then lib.print.info('Control 38 pressed') end -- DEBUG 
                planted = true
                lib.hideTextUI()

                plantSeed(ped, plant, plantInfos, plantItem, dest, metadata)
                return
            end

            -- [G] To destroy plant
            if IsControlJustPressed(0, 47) then
                if Config.Debug then lib.print.info('Control 47 pressed') end -- DEBUG
                lib.hideTextUI()
                planted = true
                DeleteObject(plant)
                return
            end
        else

            coords = GetEntityCoords(ped)
            local forardVector = GetEntityForwardVector(ped)
            _, groundZ = GetGroundZFor_3dCoord(coords.x + (forardVector.x * .5), coords.y + (forardVector.y * .5), coords.z + (forardVector.z * .5), true)
            
            SetEntityCoords(plant, coords.x + (forardVector.x * .5), coords.y + (forardVector.y * .5), groundZ + customOffset)
            if IsControlJustPressed(0, 38) then
                planted = true
                local coords = GetEntityCoords(plant)
                plantSeed(ped, plant, plantInfos, plantItem, vector3(coords.x, coords.y, coords.z + (math.abs(customOffset))), metadata)
                lib.hideTextUI()
                return
            end
            if IsControlJustPressed(0, 47) then
                if Config.Debug then lib.print.info('Control 47 pressed') end -- DEBUG
                planted = true
                lib.hideTextUI()
                DeleteObject(plant)
                return
            end
        end
    end
end)

-- Estado do minigame ativo (se algum) - usado só pelo failsafe de onResourceStop logo abaixo,
-- pra destravar o jogador (ped congelado, câmera presa, radar sumido) se o resource for
-- reiniciado com alguém NO MEIO do minigame. Sem isso, a thread do while morre na hora (o
-- FXServer mata todas as threads do resource ao parar) e o código de limpeza no fim da função
-- nunca roda - o jogador fica preso até relogar.
local activeHarvestCam = nil
local activeHarvestPed = nil

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not activeHarvestPed then return end

    if activeHarvestCam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(activeHarvestCam, false)
    end
    FreezeEntityPosition(activeHarvestPed, false)
    ClearPedTasksImmediately(activeHarvestPed)
    SetEntityVisible(activeHarvestPed, true, false)
    DisplayRadar(true)
end)

--- Converte uma posição de "cursor virtual" (0.0-1.0, mesmo sistema de GetScreenCoordFromWorldCoord)
--- num ponto 3D de verdade, projetando um raio da câmera através desse ponto de tela e cruzando
--- com um plano fixo (plano da planta, virado pra câmera) - é o "inverso" de
--- GetScreenCoordFromWorldCoord, que não tem native pronta no FiveM, por isso calculado na mão via
--- GetCamMatrix/GetCamFov (técnica padrão de raycast de câmera).
--- Normal do plano SEMPRE derivada do forwardVector atual da câmera (não recebida de fora,
--- calculada uma vez só antes do loop) - a câmera pode não ter "assentado" na orientação nova
--- ainda no instante logo após PointCamAtCoord, então uma normal fixa calculada cedo demais ficava
--- desalinhada com a visão real, e mover o cursor de lado vazava em profundidade (parecia andar
--- na diagonal, pra frente). Recalculando junto do raio, os dois sempre usam a mesma leitura.
--- @param cam number
--- @param cursorX number - 0.0-1.0
--- @param cursorY number - 0.0-1.0
--- @param planePoint vector3 - um ponto qualquer do plano
--- @return vector3|nil
local function cursorToWorldOnPlane(cam, cursorX, cursorY, planePoint)
    local rightVector, forwardVector, upVector, camPos = GetCamMatrix(cam)
    local planeNormal = forwardVector * -1.0
    local fov = GetCamFov(cam)
    local screenW, screenH = GetActiveScreenResolution()
    local aspect = screenW / screenH

    local ndcX = (cursorX - 0.5) * 2.0
    local ndcY = (cursorY - 0.5) * 2.0 -- tela: Y cresce pra baixo

    local tanY = math.tan(math.rad(fov) / 2)
    local tanX = tanY * aspect

    local rayDir = forwardVector + (rightVector * (ndcX * tanX)) + (upVector * (-ndcY * tanY))
    local rayMag = #rayDir
    if rayMag < 0.0001 then return nil end
    rayDir = rayDir / rayMag

    local denom = rayDir.x * planeNormal.x + rayDir.y * planeNormal.y + rayDir.z * planeNormal.z
    if math.abs(denom) < 0.0001 then return nil end -- raio quase paralelo ao plano

    local diff = planePoint - camPos
    local t = (diff.x * planeNormal.x + diff.y * planeNormal.y + diff.z * planeNormal.z) / denom
    if t < 0 then return nil end -- plano atrás da câmera

    return camPos + (rayDir * t)
end

--- Escala visual de um entity - não existe native pronta tipo SetObjectScale no FiveM, então mexe
--- na matriz do entity (forward/right/up escalados), mesma técnica já usada e confirmada
--- funcionando em [mri]/[jim]/jim_bridge/shared/scaleEntity.lua. Só funciona bem em entities sem
--- colisão real (é o caso dos brotos, já criados com SetEntityCollision false) - com colisão a
--- forma física não acompanha a escala visual.
--- @param entity number
--- @param scale number
local function scaleEntity(entity, scale)
    local forward, right, up = GetEntityMatrix(entity)
    local pos = GetEntityCoords(entity)
    SetEntityMatrix(entity, forward * scale, right * scale, up * scale, pos)
end

--- Minigame de colheita: spawna N brotos com contorno neon em volta da planta, prende a
--- câmera nela e deixa o jogador clicar em cada um com o mouse. Só dispara o harvest de
--- verdade pro servidor depois que todos forem clicados (ou cancela sem dar nada no ESC).
--- Recebe as COORDS da planta (não um entity handle) de propósito - um entity handle vindo do
--- server (ver comentário em it-drugs:client:harvestPlant abaixo) só é válido do lado do server,
--- e resolver o handle local de volta via netId provou ser frágil (planta pode ter sido
--- recriada no servidor entre abrir o menu e clicar em colher - troca de estágio, hiccup de rede
--- etc. - af netId fica "órfão" e o minigame cancelava sozinho). Coords são um valor simples,
--- sempre corretas, sem esse problema.
--- @param plantCoords vector3
--- @param type string - seed type (Config.Plants key)
--- @param fertilizer number - fertilizer% da planta, usado só pra decidir QUANTOS brotos desenhar
local runHarvestMinigame = function(plantCoords, type, fertilizer)
    local mgConfig = Config.HarvestMinigame
    local _, productData = next(Config.Plants[type].products)
    local fertilizerFactor = (fertilizer or 0) / 100
    local budCount = math.max(math.floor(productData.min + ((productData.max - productData.min) * fertilizerFactor) + 0.5), 1)

    local ok, hashModel = it.requestModel(mgConfig.prop, 'Config.HarvestMinigame.prop errado')
    if not ok then
        ShowNotification(nil, 'Modelo do broto não carregou (Config.HarvestMinigame.prop errado)', "error")
        return false
    end

    local ped = PlayerPedId()

    -- Direção da câmera calculada ANTES de espalhar os brotos (era depois antes) - precisa saber
    -- pra QUE LADO a câmera olha antes de decidir onde os brotos podem nascer, ver comentário
    -- abaixo. Câmera posicionada na direção planta->jogador (horizontal), não num offset fixo do
    -- mundo - antes era sempre vector3(0,-1.6,1.4) (lado sul fixo), então se o jogador chegasse na
    -- planta por qualquer outro ângulo a câmera ficava martelada num lado sem nada a ver com de
    -- onde ele estava olhando.
    local pedCoords = GetEntityCoords(ped)
    local toPed = pedCoords - plantCoords
    toPed = vector3(toPed.x, toPed.y, 0.0) -- só direção horizontal, ignora diferença de altura
    local horizontalDist = #toPed
    local camDir = horizontalDist > 0.01 and (toPed / horizontalDist) or vector3(0.0, -1.0, 0.0)

    -- Ângulo 3/4 (metade na direção do jogador, metade perpendicular) em vez de ficar bem atrás
    -- dele em linha reta - numa versão anterior a câmera ficava exatamente na linha jogador->planta,
    -- então o próprio boneco (congelado ali no meio) tampava o quadro ("boneco ficou na frente").
    -- Deslocada pro lado e bem mais alta (2.3m em vez de 1.6m), olhando de cima em diagonal, o
    -- boneco fica fora do centro do enquadramento.
    local perpDir = vector3(-camDir.y, camDir.x, 0.0)
    local camAngleDir = camDir + perpDir
    local angleMag = #camAngleDir
    camAngleDir = angleMag > 0.01 and (camAngleDir / angleMag) or camDir
    local camDistance = horizontalDist + 1.5
    local camCoords = plantCoords + (camAngleDir * camDistance) + vector3(0.0, 0.0, 2.3)

    -- Ângulo (radianos, visto de cima) de onde a câmera está em relação à planta - ponto de
    -- partida da rotação (jogador consegue girar com A/D depois, ver loop abaixo).
    local orbitAngle = math.atan(camAngleDir.y, camAngleDir.x)

    local buds = {}
    for i = 1, budCount do
        -- Círculo 360° completo em volta da planta de novo (era um arco de ±80° voltado pra
        -- câmera) - agora que dá pra girar a câmera com A/D, não precisa mais esconder os brotos
        -- do lado de trás, o jogador gira até eles.
        local angle = math.random() * 2 * math.pi
        local radius = math.random() * mgConfig.spawnRadius
        local height = mgConfig.minHeight + math.random() * (mgConfig.maxHeight - mgConfig.minHeight)
        local bud = CreateObject(hashModel, plantCoords.x + math.cos(angle) * radius, plantCoords.y + math.sin(angle) * radius, plantCoords.z + height, true, true, false)
        SetEntityCollision(bud, false, false)
        FreezeEntityPosition(bud, true)
        scaleEntity(bud, mgConfig.budScale)
        SetEntityDrawOutline(bud, true)
        table.insert(buds, bud)
    end

    local outline = mgConfig.outlineColor
    SetEntityDrawOutlineColor(outline[1], outline[2], outline[3], outline[4])

    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0, 50.0, false, 0)
    -- Mira no meio da faixa onde os brotos nascem agora (minHeight/maxHeight), não mais fixo em
    -- +0.4m (baixo demais pra faixa nova, que vai até 2m de altura pra cobrir a planta grande).
    local budRangeCenter = (mgConfig.minHeight + mgConfig.maxHeight) / 2
    PointCamAtCoord(cam, plantCoords.x, plantCoords.y, plantCoords.z + budRangeCenter)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, false)
    FreezeEntityPosition(ped, true)
    -- Só some da SUA tela (SetEntityVisible é local, não sincroniza pra outros jogadores) - mais
    -- simples e confiável que tentar desviar o ângulo da câmera pra não pegar o boneco no quadro.
    SetEntityVisible(ped, false, false)
    DisplayRadar(false)
    activeHarvestCam = cam
    activeHarvestPed = ped

    -- Tesoura 3D como "cursor" em vez do cursor de seta padrão - fica presa no plano da planta
    -- (mesma altura central dos brotos), seguindo o mouse. Por isso NÃO chama
    -- SetMouseCursorActiveThisFrame (mostraria a seta padrão junto) - a posição do "cursor" é
    -- controlada na mão, acumulando o movimento relativo do mouse (mesma técnica usada em
    -- qbx_customs/client/dragcam.lua pra girar a câmera, só que aqui pra mover um ponto 2D).
    -- camAngleDir (calculado lá em cima, pra posicionar a câmera) aponta da planta pra câmera -
    -- desloca o plano nessa mesma direção (cursorPlaneOffset) pra ficar na FRENTE da folhagem em
    -- vez de bem no centro da planta, que tem volume pra todo lado e escondia a tesoura atrás
    -- das folhas na maior parte do tempo.
    local planePoint = plantCoords + (camAngleDir * mgConfig.cursorPlaneOffset) + vector3(0.0, 0.0, budRangeCenter)

    local scissorsOk, scissorsModel = it.requestModel(mgConfig.scissorsProp, 'Config.HarvestMinigame.scissorsProp errado')
    local scissors = nil
    if scissorsOk then
        scissors = CreateObject(scissorsModel, planePoint.x, planePoint.y, planePoint.z, false, false, false)
        SetEntityCollision(scissors, false, false)
    else
        ShowNotification(nil, 'Modelo da tesoura não carregou (Config.HarvestMinigame.scissorsProp errado)', "error")
    end

    local cursorX, cursorY = 0.5, 0.5 -- posição virtual do "cursor" (0.0-1.0, mesmo sistema de GetScreenCoordFromWorldCoord)

    lib.showTextUI(_U('INTERACTION__HARVEST__CLICK'), {
        position = "top-center",
        icon = "scissors",
    })

    local cancelled = false
    while #buds > 0 and not cancelled do
        Wait(0)
        DisableControlAction(0, 1, true) -- LookLeftRight
        DisableControlAction(0, 2, true) -- LookUpDown
        DisableControlAction(0, 24, true) -- Attack
        DisableControlAction(0, 25, true) -- Aim
        DisableControlAction(0, 30, true) -- MoveLeftRight
        DisableControlAction(0, 31, true) -- MoveUpDown
        DisableControlAction(0, 34, true) -- MoveLeftOnly (A) - usado pra girar a câmera, não mover o ped
        DisableControlAction(0, 35, true) -- MoveRightOnly (D)

        -- Gira a câmera ao redor da planta com A/D (mesmo esquema de controles desabilitados já
        -- usado em qbx_customs/client/dragcam.lua) - reposiciona a câmera E o plano onde a tesoura
        -- se move toda vez que o ângulo muda, senão os dois ficam desalinhados com o que a câmera
        -- realmente mostra depois de girar.
        local rotated = false
        if IsDisabledControlPressed(0, 34) then
            orbitAngle = orbitAngle - mgConfig.orbitSpeed
            rotated = true
        elseif IsDisabledControlPressed(0, 35) then
            orbitAngle = orbitAngle + mgConfig.orbitSpeed
            rotated = true
        end
        if rotated then
            camAngleDir = vector3(math.cos(orbitAngle), math.sin(orbitAngle), 0.0)
            camCoords = plantCoords + (camAngleDir * camDistance) + vector3(0.0, 0.0, 2.3)
            SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
            PointCamAtCoord(cam, plantCoords.x, plantCoords.y, plantCoords.z + budRangeCenter)
            planePoint = plantCoords + (camAngleDir * mgConfig.cursorPlaneOffset) + vector3(0.0, 0.0, budRangeCenter)
        end

        -- Acumula o movimento relativo do mouse (controles 1/2, já desabilitados acima pra não
        -- girar a câmera) num cursor virtual, em vez de ler a posição absoluta do cursor de
        -- sistema (que exigiria SetMouseCursorActiveThisFrame e mostraria a seta padrão).
        cursorX = math.min(math.max(cursorX + GetDisabledControlNormal(0, 1) * mgConfig.cursorSensitivity, 0.0), 1.0)
        cursorY = math.min(math.max(cursorY + GetDisabledControlNormal(0, 2) * mgConfig.cursorSensitivity, 0.0), 1.0)

        if scissors then
            local worldPos = cursorToWorldOnPlane(cam, cursorX, cursorY, planePoint)
            if worldPos then
                -- Limita o quanto a tesoura pode se afastar do centro da planta (dentro do próprio
                -- plano, então só lateral/vertical - profundidade já não existe nesse esquema) -
                -- sem isso dava pra mandar ela pra bem longe da planta só mexendo o mouse.
                local fromCenter = worldPos - planePoint
                local dist = #fromCenter
                if dist > mgConfig.cursorMaxRadius then
                    worldPos = planePoint + (fromCenter / dist) * mgConfig.cursorMaxRadius
                end

                SetEntityCoords(scissors, worldPos.x, worldPos.y, worldPos.z, false, false, false, false)
                SetEntityHeading(scissors, GetCamRot(cam, 2).z + 180.0) -- +180 pq tava virada de costas pra câmera
            end
        end

        -- Igual ao cancelamento com Backspace logo abaixo (que já funciona) - checa as duas
        -- variantes (disabled/normal), não só a disabled sozinha. Mesmo padrão confirmado
        -- funcionando em outro resource desse servidor (qbx_customs/client/dragcam.lua).
        if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) then
            for i = #buds, 1, -1 do
                local bud = buds[i]
                local budCoords = GetEntityCoords(bud)
                local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(budCoords.x, budCoords.y, budCoords.z)
                if onScreen and #(vector2(screenX, screenY) - vector2(cursorX, cursorY)) <= mgConfig.clickRadius then
                    DeleteEntity(bud)
                    table.remove(buds, i)
                    break
                end
            end
        end

        if IsDisabledControlJustPressed(0, 194) or IsControlJustPressed(0, 194) then -- Backspace cancela
            cancelled = true
        end
    end

    lib.hideTextUI()
    for _, bud in pairs(buds) do
        if DoesEntityExist(bud) then DeleteEntity(bud) end
    end
    if scissors and DoesEntityExist(scissors) then DeleteEntity(scissors) end

    -- Corte instantâneo (sem os 500ms de transição que tinha antes) e ClearPedTasksImmediately
    -- de segurança - o ped ficava com uma sensação de "travado"/sem responder por um instante ao
    -- sair do minigame, principalmente cancelando com Backspace.
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityVisible(ped, true, false)
    DisplayRadar(true)
    activeHarvestCam = nil
    activeHarvestPed = nil

    return not cancelled
end

RegisterNetEvent('it-drugs:client:harvestPlant', function(args)

    local type = args.type
    local id = args.id -- ID da planta (nunca muda) - o server resolve o entity atual sozinho a partir disso, ver sv_planting.lua
    local fertilizer = args.fertilizer
    local coords = args.coords -- coords "de verdade", vem direto do banco - usado pro minigame em vez de tentar resolver um entity handle local

    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 1.0) -- mesmo duration usado no resto do arquivo pra TaskTurnPedToFaceEntity
    Wait(200)

    if runHarvestMinigame(coords, type, fertilizer) then
        TriggerServerEvent('it-drugs:server:harvestPlant', id)
    else
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
    end
end)

--- Corta a planta INTEIRA com a foice (bzzz_cutting_weed) - só aparece no menu depois de já ter
--- colhido os brotos (budsHarvested, ver sv_planting.lua/cl_menus.lua). Prop/anim/osso/offset
--- confirmados em bzzz_cutting_weed/data/coords.lua (config de referência do próprio pacote).
RegisterNetEvent('it-drugs:client:cutWholePlant', function(args)
    local id = args.id
    local coords = args.coords
    local mgConfig = Config.HarvestMinigame

    -- Checagem só pra UX (feedback na hora, sem precisar iniciar a animação toda) - o servidor
    -- confere de novo (nunca confia só no client) antes de dar qualquer coisa.
    if not it.hasItem(mgConfig.sickleItem, 1) then
        ShowNotification(nil, _U('NOTIFICATION__MISSING__TOOL'), "error")
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 1.0)
    Wait(200)

    local propOk, propModel = it.requestModel(mgConfig.sickleProp, 'Config.HarvestMinigame.sickleProp errado')
    if not propOk then
        ShowNotification(nil, 'Modelo da foice não carregou (Config.HarvestMinigame.sickleProp errado)', "error")
        return
    end

    RequestAnimDict(mgConfig.sickleAnimDict)
    local waited = 0
    while not HasAnimDictLoaded(mgConfig.sickleAnimDict) do
        Wait(0)
        waited = waited + 1
        if waited > 500 then
            ShowNotification(nil, 'Animação da foice não carregou (Config.HarvestMinigame.sickleAnimDict errado, ou bzzz_cutting_weed não está rodando)', "error")
            return
        end
    end

    local placement = mgConfig.sicklePlacement
    local sickle = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(sickle, ped, GetPedBoneIndex(ped, mgConfig.sickleBone), placement[1], placement[2], placement[3], placement[4], placement[5], placement[6], true, true, false, true, 1, true)
    TaskPlayAnim(ped, mgConfig.sickleAnimDict, mgConfig.sickleAnim, 8.0, 8.0, -1, 1, 0, false, false, false)

    local success = lib.progressBar({
        duration = mgConfig.cutDuration,
        label = _U('PROGRESSBAR__CUT__PLANT'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
    })

    ClearPedTasks(ped)
    RemoveAnimDict(mgConfig.sickleAnimDict)
    if DoesEntityExist(sickle) then DeleteEntity(sickle) end

    if success then
        TriggerServerEvent('it-drugs:server:cutWholePlant', id)
    else
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
    end
end)

local giveWater = function(args)
    local item = args.item
    local type = args.type
    local entity = args.entity

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = 'prop_wateringcan'
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)
    RequestModel(model)
    RequestNamedPtfxAsset('core')
    while not HasModelLoaded(model) or not HasNamedPtfxAssetLoaded('core') do Wait(0) end
    SetPtfxAssetNextCall('core')
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.4, 0.1, 0.0, 90.0, 180.0, 0.0, true, true, false, true, 1, true)
    local effect = StartParticleFxLoopedOnEntity('ent_sht_water', created_object, 0.35, 0.0, 0.25, 0.0, 0.0, 0.0, 2.0, false, false, false)

    if lib.progressBar({
        duration = Config.Plants[type].time,
        label = _U('PROGRESSBAR__SOAK__PLANT'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'weapon@w_sp_jerrycan',
            clip = 'fire',
        },
    }) then
        TriggerServerEvent('it-drugs:server:plantTakeCare', entity, item)
        ClearPedTasks(ped)
        StopParticleFxLooped(effect, 0)
        if DoesEntityExist(created_object) then DeleteEntity(created_object) end
    else
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
        ClearPedTasks(ped)
        StopParticleFxLooped(effect, 0)
        if DoesEntityExist(created_object) then DeleteEntity(created_object) end
    end
end

local giveFertilizer = function(args)
    local item = args.item
    local type = args.type
    local entity = args.entity

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = 'w_am_jerrycan_sf'
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    local created_object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    AttachEntityToEntity(created_object, ped, GetPedBoneIndex(ped, 28422), 0.3, 0.1, 0.0, 90.0, 180.0, 0.0, true, true, false, true, 1, true)

    if lib.progressBar({
        duration = Config.Plants[type].time,
        label = _U('PROGRESSBAR__FERTILIZE__PLANT'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'weapon@w_sp_jerrycan',
            clip = 'fire',
        },
    }) then
        TriggerServerEvent('it-drugs:server:plantTakeCare', entity, item)
        ClearPedTasks(ped)
        if DoesEntityExist(created_object) then DeleteEntity(created_object) end
    else
        ShowNotification(nil, _U('NOTIFICATION__CANCELED'), "error")
        ClearPedTasks(ped)
        if DoesEntityExist(created_object) then DeleteEntity(created_object) end
    end
end

RegisterNetEvent('it-drugs:client:useItem', function (args)
    local item = args.item

    if not it.hasItem(item, 1 ) then
        ShowNotification(nil, _U('NOTIFICATION__NO__ITEMS'), "error")
        return
    end

    local itemInfos = Config.Items[item]
    if itemInfos.water ~= 0 then
        giveWater(args)
    elseif itemInfos.fertilizer ~= 0 then
        giveFertilizer(args)
    end
end)

RegisterNetEvent('it-drugs:client:destroyPlant', function(args)

    local type = args.type
    local entity = args.entity

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 1.0)
    Wait(200)

    if it.playAnimatedProgress(_U('PROGRESSBAR__DESTROY__PLANT'), Config.Plants[type].time) then
        TriggerServerEvent('it-drugs:server:destroyPlant', {entity = entity})
    end
end)

RegisterNetEvent('it-drugs:client:startPlantFire', function(coords)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    if #(pedCoords - vector3(coords.x, coords.y, coords.z)) > 300 then return end

    RequestNamedPtfxAsset('core')
    while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
    SetPtfxAssetNextCall('core')
    local effect = StartParticleFxLoopedAtCoord('ent_ray_paleto_gas_flames', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.6, false, false, false, false)
    Wait(Config.FireTime)
    StopParticleFxLooped(effect, 0)
end)
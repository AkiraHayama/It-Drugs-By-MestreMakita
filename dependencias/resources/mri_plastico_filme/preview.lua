local object, ownerPed
local loading, stopping = false, false

local function remove()
    if object and DoesEntityExist(object) then DeleteEntity(object) end
    object, ownerPed = nil, nil
end

local function notice(message)
    print('[mri_plastico_filme] ' .. message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterCommand('filme_teste', function(_, args)
    if stopping or loading then return end
    if object or args[1] == 'remover' then remove() return end
    local model = joaat(Config.Model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        notice('Modelo indisponivel. Confira o resource e o YTYP.')
        return
    end
    loading = true
    RequestModel(model)
    local deadline = GetGameTimer() + 8000
    while not stopping and not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if stopping or not HasModelLoaded(model) then
        loading = false
        SetModelAsNoLongerNeeded(model)
        if not stopping then notice('Tempo excedido ao carregar o modelo.') end
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    object = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    loading = false
    if object == 0 then object = nil notice('Falha ao criar o objeto.') return end
    SetEntityCollision(object, false, false)
    local cfg = Config.Hand
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, cfg.bone),
        cfg.pos[1], cfg.pos[2], cfg.pos[3], cfg.rot[1], cfg.rot[2], cfg.rot[3],
        true, true, false, true, 1, true)
    ownerPed = ped
    notice('Rolo de plastico filme (30 cm). /filme_teste remover para retirar.')
end, false)

CreateThread(function()
    while not stopping do
        Wait(1000)
        if ownerPed and (PlayerPedId() ~= ownerPed or IsEntityDead(ownerPed)) then remove() end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopping = true remove() end
end)

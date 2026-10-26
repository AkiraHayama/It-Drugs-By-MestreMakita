-- Local visual preview; independent of inventory, consumes no items.
local objects = {}
local loading, stopping = false, false
local ownerPed

local function clear()
    for _, entity in pairs(objects) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    objects = {}
    ownerPed = nil
end

local function notice(message)
    print('[mri_dichavador] ' .. message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterCommand('dichavador_mri', function(_, args)
    if stopping or loading then return end
    local mode = args[1] or (next(objects) and 'remover' or 'fechado')
    if mode == 'remover' then clear() return end
    if mode ~= 'aberto' and mode ~= 'fechado' then
        notice('Use /dichavador_mri fechado, aberto ou remover.')
        return
    end
    clear()
    local hashes = {}
    for part, name in pairs(Config.Models) do
        local hash = joaat(name)
        if not IsModelInCdimage(hash) or not IsModelValid(hash) then
            notice('Modelo indisponivel: ' .. name .. '. Confira o resource e o YTYP.')
            return
        end
        hashes[part] = hash
    end
    loading = true
    for _, hash in pairs(hashes) do RequestModel(hash) end
    local deadline = GetGameTimer() + 8000
    local loaded = false
    while not stopping and GetGameTimer() < deadline do
        loaded = true
        for _, hash in pairs(hashes) do
            if not HasModelLoaded(hash) then loaded = false end
        end
        if loaded then break end
        Wait(0)
    end
    if not loaded or stopping then
        for _, hash in pairs(hashes) do SetModelAsNoLongerNeeded(hash) end
        loading = false
        if not stopping then notice('Tempo excedido ao carregar os modelos.') end
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local failed = false
    for part, hash in pairs(hashes) do
        local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
        if entity == 0 then failed = true break end
        objects[part] = entity
        SetEntityCollision(entity, false, false)
        local cfg = mode == 'fechado' and Config.Closed or Config.Open[part]
        AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, cfg.bone),
            cfg.pos[1], cfg.pos[2], cfg.pos[3], cfg.rot[1], cfg.rot[2], cfg.rot[3],
            true, true, false, true, 1, true)
    end
    for _, hash in pairs(hashes) do SetModelAsNoLongerNeeded(hash) end
    loading = false
    if failed then clear() notice('Nao foi possivel criar as duas pecas.') return end
    ownerPed = ped
    notice('Dichavador ' .. mode .. ' (7 cm). /dichavador_mri remover para retirar.')
end, false)

CreateThread(function()
    while not stopping do
        Wait(1000)
        if ownerPed and (PlayerPedId() ~= ownerPed or IsEntityDead(ownerPed)) then clear() end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopping = true clear() end
end)

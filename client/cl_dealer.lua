if not Config.EnableDealers then return end

local dealerPeds = {}

--- Spawn a ped at the given position
--- @param model string
--- @param position vector4
local function spawnDealerPed(model, position)
    local pedHash = GetHashKey(model)

    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do
        Wait(200)
    end

    local ped = CreatePed(4, pedHash, position.x, position.y, position.z, position.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)

    return ped
end


CreateThread(function()
    for dealerID, dealerData in pairs(Config.DrugDealers) do

        local dealerPosition = lib.callback.await('it-drugs:server:getDealerPosition', false, dealerID)

        while not dealerPosition do
            Wait(500)
            dealerPosition = lib.callback.await('it-drugs:server:getDealerPosition', false, dealerID)
            if Config.Debug then lib.print.info(_U('DEALER__POSITION'), dealerPosition) end
        end

        local ped = spawnDealerPed(dealerData.ped, dealerPosition)
        dealerPeds[dealerID] = ped

        if dealerData.blip.display then
            AddDealerBlip(dealerPosition, dealerData.blip.sprite, dealerData.blip.displayColor, dealerData.blip.displayText)
        end
    end
end)

-- ┌────────────────────────────────────────────────────────┐
-- │ ____                        _____ _                    │
-- │/ ___|  ___ | | ___  _ __   / ____| |__   ___  _ __       │
-- │\___ \/ __\| |/ _ \| '_ \  \___ \| '_ \ / _ \| '_ \      │
-- │ ___) \__ \| | (_) | |_) |  ___) | | | | (_) | |_) |     │
-- │|____/|___/|_|\___/| .__/  |____/|_| |_|\___/| .__/      │
-- │                    |_|                        |_|        │
-- └────────────────────────────────────────────────────────┘
-- Opens the dealer's stock as an ox_inventory shop (same UI as the player inventory,
-- so it renders reliably). Purchases are handled entirely by ox_inventory, paid with
-- the 'money' item (cash in hand).

RegisterNetEvent('it-drugs:client:showDealerMenu', function(dealerId)
    if it.inventory ~= 'ox' then return end
    exports.ox_inventory:openInventory('shop', { type = 'it_drugs_' .. dealerId })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, ped in pairs(dealerPeds) do
            DeleteEntity(ped)
        end
    end
end)
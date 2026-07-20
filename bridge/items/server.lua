ConsumableItems = {}
local ox_inventory = exports.ox_inventory

function it.hasItem(source, item, amount)
    if not amount then amount = 1 end
    if it.inventory == 'ox' then
        local itemData = ox_inventory:GetItem(source, item, nil, true)
        if not itemData then
            if Config.Debug then
                print('[it-drugs] The item ' .. item .. ' does not exist in the inventory.')
                return false
            end
        end
        if itemData >= amount then return true end
	elseif it.core == "qb-core" then
		local Player = CoreObject.Functions.GetPlayer(source)
		if not Player then return false end
        local itemData = Player.Functions.GetItemByName(item)
        if not itemData then
            if Config.Debug then
                print('[it-drugs] The item ' .. item .. ' does not exist in the inventory.')
                return false
            end
        end
		if itemData.amount >= amount then return true end
	elseif it.core == "esx" then
		local Player = CoreObject.GetPlayerFromId(source)
		local esxItem = Player.getInventoryItem(item)
        if not esxItem then 
            if Config.Debug then 
                print('[it-drugs] The item ' .. item .. ' does not exist in the inventory.')
                return false 
            end
        end
		if esxItem.count >= amount then return true end
	end
    return false
end

function it.giveItem(source, item, amount, metadata)
    if it.inventory == 'ox' then
        local added, _ = ox_inventory:AddItem(source, item, amount, metadata)
        return added
	elseif it.core == "qb-core" then
		local Player = CoreObject.Functions.GetPlayer(source)
		if not Player then return end
		if Player.Functions.AddItem(item, amount, false, metadata or {}) then
            TriggerClientEvent("inventory:client:ItemBox", source, CoreObject.Shared.Items[item], "add", amount)
            return true
        end
	elseif it.core == "esx" then
		local Player = CoreObject.GetPlayerFromId(source)
        local original_amount = Player.getInventoryItem(item)?.count
		Player.addInventoryItem(item, amount, metadata or {})
        local new_amount = Player.getInventoryItem(item)?.count
        if new_amount >= original_amount + amount then
            return true
        end
	end
    return false
end

function it.removeItem(source, item, amount, metadata)
    if it.inventory == 'ox' then
        local removedItem = ox_inventory:GetItem(source, item, metadata or nil, true)
        if removedItem >= amount then
            ox_inventory:RemoveItem(source, item, amount, metadata or nil)
            return true
        end
	elseif it.core == "qb-core" then
        local Player = CoreObject.Functions.GetPlayer(source)
		if not Player then return end
		if Player.Functions.RemoveItem(item, amount) then
            TriggerClientEvent("inventory:client:ItemBox", source, CoreObject.Shared.Items[item], "remove", amount)
            return true
        end
	elseif it.core == "esx" then
        local Player = CoreObject.GetPlayerFromId(source)
        local removedItem = Player.getInventoryItem(item)
        if removedItem.count >= amount then
            Player.removeInventoryItem(item, amount)
            return true
        end
	end
    return false
end

function it.createUsableItem(item, cb)
    if ConsumableItems[item] then print('[it-drugs] The item ' .. item .. ' is already registered as a consumable item. Skipping the registration of this item.') end

    if it.inventory == 'ox' then
        -- ox_inventory items are registered with client = { event = 'it-drugs:ox:useItem' }
        -- (see [ox]/ox_inventory/data/items.lua), which forwards here - see below.
        ConsumableItems[item] = cb
	elseif it.core == "qb-core" then
		CoreObject.Functions.CreateUseableItem(item, cb)
        ConsumableItems[item] = cb
	elseif it.core == "esx" then
		CoreObject.RegisterUsableItem(item, cb)
        ConsumableItems[item] = cb
    end
end

if it.inventory == 'ox' then
    RegisterNetEvent('it-drugs:ox:useItem', function(itemName, metadata)
        local cb = ConsumableItems[itemName]
        if not cb then return end

        local ok, err = pcall(cb, source, { metadata = metadata })
        if not ok then
            print(('[it-drugs] usable item "%s" handler errored: %s'):format(itemName, tostring(err)))
        end
    end)
end

function it.toggleItem(source, toggle, name, amount, metadata)
    if toggle == 1 or toggle == true then
        it.giveItem(source, name, amount, metadata or nil)
    elseif toggle == 0 or toggle == false then
        it.removeItem(source, name, amount, metadata or nil)
    end
end

function it.getItemCount(source, item)
    if it.inventory == 'ox' then
        local itemData = ox_inventory:GetItem(source, item, nil, true)
        if itemData then return itemData else return 0 end
	elseif it.core == "qb-core" then
		local Player = CoreObject.Functions.GetPlayer(source)
		if not Player then return 0 end
        local itemData = Player.Functions.GetItemByName(item)
        if itemData then return itemData.amount else return 0 end
	elseif it.core == "esx" then
		local Player = CoreObject.GetPlayerFromId(source)
		local itemData = Player.getInventoryItem(item)
		if itemData then return itemData.count else return 0 end
	end
    return 0
end

function it.getItemLabel(source, itemName)
    local itemLabel
    if it.inventory == 'ox' then
        itemLabel = lib.callback.await('it-drugs:client:getItemLabel', source, itemName)
    elseif it.core == 'qb-core' then
        itemLabel = CoreObject.Shared.Items[itemName].label
    elseif it.core == 'esx' then
        itemLabel = CoreObject.GetItemLabel(itemName)
    end
    return itemLabel
end

lib.callback.register('it-drugs:hasItem', function(source, item, amount)
    local hasItem = it.hasItem(source, item, amount)
    --lib.print.info('The player has the item ' .. item .. ' with the amount of ' .. amount .. ': ' .. tostring(hasItem))
    return hasItem
end)

lib.callback.register('it-drugs:getItemCount', function(source, item)
    local itemCount = it.getItemCount(source, item)
    return itemCount
end)

lib.callback.register('it-drugs:server:getItemLabel', function(source, itemName)
    local itemLabel = CoreObject.GetItemLabel(itemName)
    return itemLabel
end)

RegisterNetEvent('it-drugs:toggleItem', function(toggle, name, amount, metadata)
    local source = source
    -- Evento disparável direto pelo client (TriggerServerEvent) - nunca confiar em `name`/`amount`
    -- sem checar: só deixa dar/tirar itens que o próprio it-drugs registrou como usável
    -- (ConsumableItems, populado por it.createUsableItem), senão dava pra pedir QUALQUER item
    -- do inventário (arma, dinheiro etc.) em qualquer quantidade só chamando o evento na mão.
    if not ConsumableItems[name] then return end
    it.toggleItem(source, toggle, name, 1, metadata)
end)
if not Config.EnableDealers then return end

local dealers = {}

--- @class Dealer : OxClass
--- @field id string
local Dealer = lib.class('Dealer')

function Dealer:constructor(id)
    self.id = id
    self.position = nil
    self.items = {}

    self:generatePosition()
end

function Dealer:generatePosition()
    local locations = Config.DrugDealers[self.id].locations
    math.randomseed(os.time() + #locations)

    self.position = locations[math.random(1, #locations)]
end

function Dealer:generateItemData(item)
    local priceData = Config.DrugDealers[self.id].items[item]
    math.randomseed(os.time() + #self.items)

    self.items[item] = {
        price = math.random(priceData.min, priceData.max),
        --amount = math.random(priceData.amount.min, priceData.amount.max)
    }
end

function Dealer:getPosition()
    return self.position
end

function Dealer:getItemData(item)
    return self.items[item]
end

lib.callback.register('it-drugs:server:getDealerPosition', function(_, dealerID)
    lib.print.info("Getting position for dealer ID", dealerID)
    if not dealers[dealerID] then
        if Config.Debug then lib.print.info(_U('NOTIFICATION__NO_DEALER_FOUND')) end
        return _U('NOTIFICATION__NO_DEALER_FOUND')
    end

    lib.print.info("Dealer Position", dealers[dealerID]:getPosition())
    return dealers[dealerID]:getPosition()
end)

CreateThread(function()
    local dealer = Config.DrugDealers
    for dealerId, dealerData in pairs(dealer) do
        if Config.Debug then lib.print.info("Create Dealer", dealerId) end
        dealers[dealerId] = Dealer:new(dealerId)

        local shopInventory = {}
        for item, _ in pairs(dealerData.items) do
            dealers[dealerId]:generateItemData(item)
            shopInventory[#shopInventory + 1] = {
                name = item,
                price = dealers[dealerId]:getItemData(item).price,
                currency = 'money', -- ox_inventory item that represents cash in hand
                metadata = it.usesPurity(item) and { purity = Config.Purity.default } or nil -- semente de maconha sai com a pureza inicial (Config.Purity)
            }
        end

        -- Registers a location-less shop (it-drugs already handles ped placement/targeting).
        -- Shop id follows the 'it_drugs_<dealerId>' convention - client opens it with the same id.
        if it.inventory == 'ox' then
            exports.ox_inventory:RegisterShop('it_drugs_' .. dealerId, {
                name = dealerData.label,
                inventory = shopInventory
            })
        end
    end
end)
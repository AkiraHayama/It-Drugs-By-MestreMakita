function it.round(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / (power)
end

function it.getCoreName()
    return it.core
end

function it.getInventoryName()
    return it.inventory
end

function it.getCoreObject()
    return CoreObject
end

function it.generateUUID()
    local random = math.random
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end
-- Pureza (Config.Purity): arredonda no passo configurado e limita a 0-100
function it.roundPurity(purity)
    local step = Config.Purity.step
    return math.max(0, math.min(100, math.floor(purity / step + 0.5) * step))
end

function it.purityYieldFactor(purity)
    return Config.Purity.yieldAtZero + (1 - Config.Purity.yieldAtZero) * ((purity or Config.Purity.default) / 100)
end

function it.purityPriceFactor(purity)
    return Config.Purity.priceAtZero + (1 - Config.Purity.priceAtZero) * ((purity or Config.Purity.default) / 100)
end

-- Pureza só vale pra maconha (planta que produz weed_<variedade> de Config.WeedStrains) - coca continua como antes
function it.usesPurity(plantType)
    for product in pairs(Config.Plants[plantType] and Config.Plants[plantType].products or {}) do
        if Config.WeedStrains[product:match('^weed_(.+)$') or ''] then return true end
    end
    return false
end

Config = Config or {}
Locales = Locales or {}

-- ┌───────────────────────────────────┐
-- │  ____                           _ │
-- │ / ___| ___ _ __   ___ _ __ __ _| |│
-- │| |  _ / _ \ '_ \ / _ \ '__/ _` | |│
-- │| |_| |  __/ | | |  __/ | | (_| | |│
-- │ \____|\___|_| |_|\___|_|  \__,_|_|│
-- └───────────────────────────────────┘
-- All general settings like language or webhook can be found here

--[[
    The first thing will be to choose our main language, here you can choose
    between the default languages that you will find within locales/*,
    if yours is not there, feel free to create it!
]]
Config.Language = 'pt-br'
Config.Target = 'ox_target' -- Target system ('qb-target', 'ox_target' or false to disable)

--[[
    Here you set up the discord webhook, you can find more information about
    this in the server/webhook.lua file.
    If you dont know what a webhook is, you can read more about it here:
    https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks
]]
Config.Webhook = {
    ['active'] = false, -- Set to true to enable the webhook
    ['url'] = nil, -- This will do nothing set you webhook url in server/sv_webhook.lua
    ['name'] = 'it-drugs', -- Name for the webhook
    ['avatar'] = 'https://i.imgur.com/KvZZn88.png', -- Avatar for the webhook
}

-- The Drug Dealer system is a system that allows you to buy seed from a dealer
Config.EnableDealers = true -- Enable drug dealer system

Config.DrugDealers = {
    ['seed_dealer'] = { -- Dealer id (Musst be unique)
        label = 'Seed Dealer', -- Dealer name
        locations = { -- Dealer will spawn at one of these locations
            vector4(-462.8489, 1101.5592, 326.6819, 166.9773),
            vector4(-49.4244, 1903.6714, 194.3613, 95.7213),
            vector4(2414.2463, 5003.8462, 45.6655, 40.8932),
        },
        ped = 's_m_y_dealer_01', -- Ped model
        blip = {
            display = false, -- Display blip on map
            sprite = 140, -- Select blip from (https://docs.fivem.net/docs/game-references/blips/)
            displayColor = 2, -- Select blip color from (https://docs.fivem.net/docs/game-references/blips/)
            displayText = 'Seed Dealer',
        },
        items = { -- Items the dealer is selling
            ['weed_lemonhaze_seed'] = {min = 100, max = 200}, -- min/max price
            ['coca_seed'] = {min = 100, max = 300},
        }
    },
}

--- Growing Related Settings
Config.rayCastingDistance = 7.0 -- distance in meters
Config.FireTime = 10000 -- in ms
Config.ClearOnStartup = true -- Clear dead plants on script start-up
Config.PlayerPlantLimit = 10 -- Max amount of plants a player can have simultaneously

--[[
    Minigame de colheita: em vez de dar o item na hora, aparecem N brotos (props) em volta da
    planta pronta (N = Config.Plants[seed].products[item].min/max, escalado pelo fertilizante -
    mesma fórmula do rendimento antigo, só que agora virou quantidade de prop em vez de item
    direto). A câmera é redirecionada pra planta, o mouse fica livre, e o jogador clica em cada
    broto pra "colher" ele. Só depois de clicar em todos é que o servidor dá os itens de verdade
    (o servidor calcula a quantidade sozinho a partir do fertilizante salvo, o client só usa isso
    pra decidir quantos brotos desenhar - clicar nos brotos é só a parte visual/skill, não manda
    contagem pro servidor).
]]
Config.HarvestMinigame = {
    prop = 'bkr_prop_weed_bud_02a', -- broto solto, confirmado em mri_Qadmin/data/object.lua (mesmo usado no estágio da small_plant)
    spawnRadius = 0.6, -- raio (metros) em volta da planta onde os brotos aparecem espalhados - reduzido (era 1.0) pra não nascer fora da copa
    budScale = 0.55, -- escala visual do broto (1.0 = tamanho normal do model) - não existe native de escala pronta, aplicado na mão via matriz do entity (ver scaleBud em client/cl_planting.lua)
    -- Colheita só libera com a planta 100% crescida, que é SEMPRE o estágio 3 (grande) - bem mais
    -- alta que o estágio 1/2. minHeight/maxHeight definem a faixa de altura (metros acima da base
    -- da planta) onde os brotos nascem - cobrindo a copa/folhagem de verdade em vez de nascer rente
    -- ao chão/vaso (era um valor fixo 0-0.6m antes, pensado pra planta pequena).
    minHeight = 0.6,
    maxHeight = 2.0,
    clickRadius = 0.05, -- distância (em tela, 0.0-1.0) tolerada entre o cursor e o broto pra contar como clique
    outlineColor = {60, 255, 100, 255}, -- cor do contorno neon (R, G, B, A)

    -- Tesoura 3D (pacote tesouras_do_makita, dependency nova, ver fxmanifest.lua) usada como
    -- "cursor" do minigame - em vez do cursor de seta padrão do Windows/jogo, esse prop flutua e
    -- acompanha o mouse dentro do plano da planta (ver runHarvestMinigame em client/cl_planting.lua).
    scissorsProp = 'tesouras_do_makita', -- nome do model - AINDA NÃO confirmado ao vivo, se não carregar dá erro no console avisando
    cursorSensitivity = 0.15, -- quanto o "cursor" (posição da tesoura) anda por tick de movimento do mouse - ajustar se tiver rápido/devagar demais
    cursorMaxRadius = 1.2, -- raio (metros) máximo que a tesoura pode se afastar do centro da planta (lateral/vertical) - mantém ela perto, sem deixar sair pela tangente
    cursorPlaneOffset = 0.9, -- metros mais perto da câmera (em relação ao centro exato da planta) - senão a tesoura fica atrás/dentro da folhagem, que tem volume pra todo lado
    orbitSpeed = 0.03, -- radianos por tick que a câmera gira ao redor da planta segurando A/D - ajustar se tiver rápido/devagar demais

    -- Cortar a planta INTEIRA com a foice (pacote bzzz_cutting_weed, dependency nova, ver
    -- fxmanifest.lua) - só libera depois de já ter colhido os brotos (budsHarvested, ver
    -- sv_planting.lua). Nomes de anim/prop/osso confirmados em
    -- bzzz_cutting_weed/data/coords.lua (config de referência do próprio pacote pro dpemotes),
    -- não são chute.
    sickleProp = 'bzzz_prop_sickle_a',
    sickleAnimDict = 'bzzz_cutting_sickle',
    sickleAnim = 'bzzz_cutting_sickle',
    sickleBone = 57005, -- hash pra GetPedBoneIndex, não é o índice em si
    -- {x, y, z, rotX, rotY, rotZ} - mesmo offset documentado no coords.lua do pacote
    sicklePlacement = {0.1, 0.03, -0.01, -123.0, -52.0, -36.0},
    cutDuration = 6000, -- ms segurando a animação de cortar
    -- Item de verdade (registrado no ox_inventory) - precisa TER no inventário pra cortar a planta,
    -- mesmo esquema de ferramenta reutilizável do bubble_bag (recipe.tools) - nunca é consumida.
    sickleItem = 'foice',
    -- Cortar a planta inteira dá MAIS do produto CRU da própria variedade (Config.Plants[type].products,
    -- o mesmo item que colher os brotos já dá) - não um item novo direto. O "prensado" de verdade só
    -- sai depois de secar + processar na mesa (mesmo caminho do joint), ver receita nova em
    -- Config.ProcessingTables.weed_processing_table.recipes.prensado.
    wholePlantMultiplier = 2.5, -- multiplicador em cima do min/max normal de Config.Plants[type].products
}

-- % de luz solar (Config.SunlightZones/DefaultSunlight, ANTES de somar lâmpada) abaixo do qual o
-- menu da planta mostra "Ambiente Fechado" em vez de "Ao Ar Livre" - só afeta o texto/aviso no
-- menu, não muda o cálculo de crescimento/saúde (que já soma sunlight + addedLight de qualquer jeito)
Config.IndoorSunlightThreshold = 40

-- Zona de alvo (ox_target/qb-target) da PLANTA em si (client/cl_plant_targets.lua), separada do
-- alvo do vaso. IMPORTANTE (visto lendo o código-fonte do ox_target/ox_lib direto,
-- [ox]/ox_target/client/main.lua e [ox]/ox_lib/imports/raycast/client.lua): zona NÃO é sobre
-- "colisão bloqueando a mira" - o ox_target manda um raycast da câmera (`lib.raycast.fromCamera`,
-- 20 metros de alcance) e só considera as zonas cujo RAIO contenha o PONTO FINAL desse raycast
-- (`zone:contains(endCoords)`). Como o modelo da planta não tem colisão nenhuma, mirar nas folhas
-- faz o raio atravessar tudo e o ponto final acaba a 20 metros de distância (não bate em nada) -
-- bem longe de qualquer zona perto da planta. O ÚNICO jeito do raio realmente parar perto da
-- planta é batendo na colisão sólida do VASO (que fica bem perto de plant.coords), então a zona
-- PRECISA ficar posicionada onde esse impacto de verdade acontece (perto da altura do vaso, não
-- levantada pra dentro da folhagem como numa tentativa anterior) e com raio generoso pra cobrir a
-- margem de erro de onde exatamente o raio bate no vaso.
Config.PlantTargetZone = {
    radius = 1.0, -- raio (metros) da esfera de detecção - grande de propósito, ver comentário acima
    heightOffset = 0.15, -- pequeno, só pra não ficar exatamente na base/solo do vaso - ajuste fino se precisar
    distance = 1.5, -- distância máxima (metros) do jogador até a zona pra opção aparecer

    -- Planta estágio 3 (grande/pronta) é bem mais alta e larga que estágio 1 (pequena) - o
    -- jogador tende a mirar mais alto (na folhagem, que não tem colisão) e fica mais longe pra
    -- enquadrar ela toda, então o raio da câmera erra o centro da zona com mais frequência. Somado
    -- em cima de `radius`/`distance` acima, indexado por estágio (client/cl_plant_targets.lua).
    radiusByStage = { [1] = 0, [2] = 0.6, [3] = 1.2 },
    distanceByStage = { [1] = 0, [2] = 0.8, [3] = 1.5 },
}

--[[
    Growth ticks automatically every Config.GrowthTickInterval seconds by a small step, reaching
    100% in exactly "growtime" minutes (Config.GlobalGrowTime or Config.Plants[seed].growthTime)
    IF the plant never got any fertilizer. Fertilizer speeds this up - see
    Config.FertilizerGrowTimeReduction below. Growth only PAUSES if the plant is dead
    (health <= 0); health depends only on water and light (sunlight + grow lamps), never
    fertilizer - fertilizer's only other effect is on how much you harvest (server/sv_planting.lua).
]]
Config.GrowthTickInterval = 30 -- seconds between each growth/water/fertilizer tick
Config.FertilizerGrowTimeReduction = {
    [50] = 3, -- minutos a menos no tempo de crescimento quando o fertilizante médio da planta está em 50% (15min -> 12min)
    [100] = 5, -- minutos a menos quando o fertilizante está em 100% (15min -> 10min)
}
Config.DefaultSunlight = 85 -- base sunlight% (0-100) used when a zone isn't listed below
Config.SunlightZones = { -- GetZoneAtCoords() hash -> base sunlight% before the sky-occlusion raycast
    [-1599626598] = 50, [217609618] = 55, [-726383499] = 60, [2124916078] = 65, [96430881] = 60,
    [1856487421] = 70, [-1546516250] = 75, [166634372] = 70, [-996066219] = 75, [-282295942] = 70,
    [-1742071187] = 75, [-269010440] = 80, [635563000] = 85, [-1330490651] = 80, [775971358] = 85,
    [857755945] = 80, [991407252] = 90, [165497857] = 95, [2010282870] = 100, [1593576848] = 95,
    [-866369392] = 90, [-571439372] = 95, [1101979391] = 90, [1359796162] = 100, [1479267379] = 100,
    [-987244304] = 95
}

-- Grow Lamps: placeable items that add artificial light to nearby plants (for indoor grows)
Config.EnableLamps = true

Config.Lamps = {
    ['portable_lamp'] = {
        label = 'Lâmpada Portátil',
        model = 'bzzz_world_of_lamps_purple', -- lâmpada de tripé roxa de verdade (pacote bzzz_lights_and_lamps, dependency nova, ver fxmanifest.lua) - troca do prop nativo do GTA (xm_prop_base_tripod_lampa) por essa, cor de luz de verdade. Outras cores disponíveis no mesmo pacote: bzzz_world_of_lamps_{blue,green,orange,pink,red,white,yellow}
        range = 10.0,
        light = 70,
    },
    ['reflector_lamp'] = {
        label = 'Lâmpada Portátil (Refletora)',
        model = 'xm_prop_base_tripod_lampb', -- mesmo tripé, mas com o refletor atrás do tubo que direciona a luz - também prop nativo do GTA (DLC de Natal)
        range = 15.0, -- luz mais focada/forte por causa do refletor, alcance maior que a portable_lamp comum
        light = 80,
    },
}

--[[
    Plant pots: a placeable, reusable container that lets you plant anywhere (indoors,
    on top of furniture, etc.), skipping the ground-type/grass check entirely - it does
    NOT skip the sunlight calculation, so an indoor pot will still need a grow lamp
    nearby to grow at a decent speed.

    Flow: use the pot item to place it (spawns empty, Config.Pots[x].model) -> add soil to it
    (consumes Config.Pots[x].soilItem, swaps the prop for Config.Pots[x].soilModel so it visually
    shows dirt) -> plant a seed in it (menu on the pot itself, no raycast placement, plant spawns
    at Config.Pots[x].heightOffset - same height as the pot itself, no per-seed offset anymore) ->
    water/fertilize normally like any other plant -> harvest -> soil stays, plant a new seed again.
]]
Config.EnablePots = true

Config.Pots = {
    ['vaso'] = {
        label = 'Vaso de Plantio',
        model = 'bzzz_growing_freepot_a', -- vaso VAZIO (pacote de asset MakitaPot, dependency nova, ver fxmanifest.lua), usado enquanto hasSoil = false. Preview confirmado por imagem (data/bzzz_growing_freepot_a.png).
        soilModel = 'bzzz_growing_freepot_c', -- vaso COM TERRA, troca pra esse model assim que o jogador usa "Colocar Terra" (server/sv_pots.lua troca o prop de verdade, apaga o vazio e cria esse no lugar). Preview: data/bzzz_growing_freepot_c.png. Pacote também tem "_b" (com pedrinha) e "_d" (com terra+plantado) se quiser trocar.
        soilItem = 'terra',
        heightOffset = 0.0, -- altura (metros) do VASO em si em relação ao chão; número negativo afunda, positivo levanta. Ajuste aqui se o vaso ficar flutuando/enterrado.
        -- A planta plantada num vaso nasce em heightOffset + plantHeightOffset (não existe mais um
        -- offset separado por semente, Config.Plants[seed].potHeightOffset foi removido).
        plantHeightOffset = -0.02, -- ajuste fino só da planta (em cima do heightOffset do vaso) - negativo afunda ela um pouco na terra, positivo levanta.
    },
}

--[[
    Drying Racks: a placeable object (like Config.Pots) where raw harvested weed has to
    dry for a while before it can be processed into joints. This is a MANDATORY step -
    the processing table recipe below only accepts the dried item, not the raw one.

    Flow: use the 'secador' item to place it (raycast placement, same as vaso/lamps)
    -> target on it -> "Pendurar Maconha" (consumes raw weed from your inventory, up to
    Config.DryingRacks[x].capacity at once) -> wait Config.DryingRacks[x].duration minutes
    -> target on it again -> "Recolher Maconha Seca" (gives back the dried item 1:1) ->
    rack is empty again, can dry another batch or be picked back up.
]]
Config.EnableDryingRacks = true

Config.DryingRacks = {
    ['secador'] = {
        label = 'Varal de Secagem',
        model = 'bkr_prop_weed_drying_01a', -- confirmado em mri_Qadmin/data/object.lua. Alternativas pra trocar aqui se o visual não for o esperado: bkr_prop_weed_dry_01a, bkr_prop_weed_dry_02a, bkr_prop_weed_dry_02b, bkr_prop_weed_drying_02a, h4_prop_h4_weed_dry_01a
        heightOffset = 0.0, -- altura (metros) do secador em relação ao chão, mesmo esquema do Config.Pots - ajuste se ficar flutuando/enterrado
        capacity = 10, -- quantidade máxima de erva crua por secagem (uma "fornada")
        duration = 10, -- minutos até a secagem terminar
        dries = { -- item cru (colhido da planta) -> item seco (o que você recolhe depois), 1 pra 1
            ['weed_lemonhaze'] = 'weed_lemonhaze_dried',
            -- 7 variedades novas (nextgen_weedprops) - antes só liberavam pra vender cru, agora
            -- também dá pra secar igual a lemonhaze (o processamento em receita ainda é só pra
            -- lemonhaze por enquanto, ver Config.ProcessingTables).
            ['weed_ogkush'] = 'weed_ogkush_dried',
            ['weed_nlights'] = 'weed_nlights_dried',
            ['weed_dosidos'] = 'weed_dosidos_dried',
            ['weed_acapulcogold'] = 'weed_acapulcogold_dried',
            ['weed_colombiangold'] = 'weed_colombiangold_dried',
            ['weed_limegreenskunk'] = 'weed_limegreenskunk_dried',
            ['weed_rainbowbelts'] = 'weed_rainbowbelts_dried',
        },
    },
}

-- ┌───────────────────────────┐
-- │ _____                     │
-- │|__  /___  _ __   ___  ___ │
-- │  / // _ \| '_ \ / _ \/ __|│
-- │ / /| (_) | | | |  __/\__ \│
-- │/____\___/|_| |_|\___||___/│
-- └───────────────────────────┘

Config.OnlyZones = false -- Allow drug growth only in defined zones
Config.GlobalGrowTime = 15 -- Time in minutes for a plant to grow at 0% fertilizer (baseline, see Config.FertilizerGrowTimeReduction below)

Config.Zones = {
    ['weed_zone_one'] = { -- Zone id (Musst be unique)
        points = {
            vec3(2031.0, 4853.0, 43.0),
            vec3(2007.0, 4877.0, 43.0),
            vec3(1981.0, 4903.0, 43.0),
            vec3(2006.0, 4929.0, 43.0),
            vec3(2032.0, 4903.0, 43.0),
            vec3(2057.0, 4878.0, 43.0),
        },
        thickness = 4.0,
        growMultiplier = 2, -- GlobalGrowTime / growMultiplier = Time in minutes for a plant to grow in this zone
        
        blip = {
            display = true, -- Display blip on map
            sprite = 469, -- Select blip from (https://docs.fivem.net/docs/game-references/blips/)
            displayColor = 2, -- Select blip color from (https://docs.fivem.net/docs/game-references/blips/)
            displayText = 'Weed Zone',
        },
        exclusive = {'weed_lemonhaze_seed'} -- Types of drugs that will be affected in this are.
    },
    ['weed_zone_two'] = { -- Zone id (Musst be unique)
        points = {
            vec3(2067.0, 4890.0, 41.0),
            vec3(2043.0, 4914.0, 41.0),
            vec3(2017.0, 4940.0, 41.0),
            vec3(2045.0, 4969.0, 41.0),
            vec3(2069.0, 4946.0, 41.0),
            vec3(2097.0, 4918.0, 41.0),
        },
        thickness = 4.0,
        growMultiplier = 2, -- GlobalGrowTime / growMultiplier = Time in minutes for a plant to grow in this zone
        blip = {
            display = true, -- Display blip on map
            sprite = 469, -- Select blip from (https://docs.fivem.net/docs/game-references/blips/)
            displayColor = 2, -- Select blip color from (https://docs.fivem.net/docs/game-references/blips/)
            displayText = 'Weed Zone',
        },
        exclusive = {'weed_lemonhaze_seed'} -- Types of drugs that will be affected in this are.
    },
}


-- ┌─────────────────────────────┐
-- │ ____  _             _       │
-- │|  _ \| | __ _ _ __ | |_ ___ │
-- │| |_) | |/ _` | '_ \| __/ __|│
-- │|  __/| | (_| | | | | |_\__ \│
-- │|_|   |_|\__,_|_| |_|\__|___/│
-- └─────────────────────────────┘

Config.PlantDistance = 1.5 -- minimum Distance between two plants

Config.OnlyAllowedGrounds = true -- Allow drug growth only on allowed grounds
Config.AllowedGrounds = {   -- Allowed ground types for planting
    1109728704, -- fields
    -1942898710, -- grass/dirt
    510490462, -- dirt path
    -1286696947,
    -1885547121,
    223086562,
    -461750719,
    1333033863,
    -1907520769,
    1144315879, -- canteiros
    -2041329971, -- terra sandyshores
}

Config.WaterDecay = 1 -- Percent of water that decays every minute
Config.FertilizerDecay = 0.7 -- Percent of fertilizers that decays every minute

Config.WaterThreshold = 10
Config.LightThreshold = 10 -- % de luz (sol + lâmpada somados) abaixo do qual a planta começa a perder saúde
Config.HealthBaseDecay = {7, 10} -- Min/Max Amount of health decay when the plant is below the above thresholds for water and light
-- Fertilizante NÃO afeta mais a saúde/sobrevivência da planta - só a quantidade colhida (ver
-- Config.Plants[x].products e o cálculo em server/sv_planting.lua:harvestPlant). Só água e luz
-- (sol + Config.Lamps) mantêm a planta viva.

-- Luz de lâmpada sobe aos poucos em vez de instantânea: toda vez que passa um Config.GrowthTickInterval,
-- addedLight sobe até esse tanto (pontos percentuais) em direção ao valor alvo (calculado pela
-- distância até a lâmpada mais perto, ver calculateAddedLight em server/sv_planting.lua) - simula
-- a lâmpada "esquentando"/a planta se adaptando. Perder a lâmpada (sair do alcance/ser removida) é
-- instantâneo, só o ganho é gradual. Luz do sol (ao ar livre) não usa esse ramp, já vem no valor cheio.
Config.LampLightRampStep = 20


Config.Items = {
    ['watering_can'] = {
        water = 25,
        fertilizer = 0,
        itemBack = nil, -- ignorado quando charges = true (o item nunca é removido, então nunca precisa devolver)
        charges = true, -- item de cargas limitadas: não é consumido por uso, só perde 1 carga (metadata do ox_inventory) até zerar. Precisa reabastecer num Config.WaterPoints pra voltar a Config.WateringCanMaxCharges.
    },
    ['liquid_fertilizer'] = {
        water = 15,
        fertilizer = 15,
        itemBack = nil,
    },
    ['fertilizer'] = {
        water = 0,
        fertilizer = 25,
        itemBack = nil,
    },
    ['advanced_fertilizer'] = {
        water = 0,
        fertilizer = 40,
        itemBack = nil,
    },
}

Config.WateringCanMaxCharges = 5 -- quantas vezes dá pra regar antes do regador ficar vazio e precisar reabastecer

--[[
    Water Points: pontos criados por ADMIN (não por item) onde o jogador reabastece o regador
    de volta pra Config.WateringCanMaxCharges. Não spawna nenhum prop novo - é só uma zona de
    interação (ox_target/qb-target por coordenada), pensada pra ser colocada em cima de uma
    torneira/pia/hidrante que já existe no mapa.

    Criar um ponto: comando /it-drugs waterpoints (admin, mesma permissão ace 'it-drugs' usada
    pros outros comandos de admin em server/sv_admin.lua) -> menu -> "Criar Ponto" -> mira no chão
    e aperta E (ou G pra cancelar) -> pronto, salvo em drug_waterpoints e sincronizado pra todo
    mundo na hora, sem precisar reiniciar o resource.
]]
Config.EnableWaterPoints = true
Config.WaterPointRadius = 1.5 -- raio (metros) da zona de interação de cada ponto

Config.PlantTypes = {
    -- small is growth 0-30%, medium is 30-80%, large is 80-100%
    ["plant1"] = {
        [1] = {"bkr_prop_weed_01_small_01a", -0.5},
        [2] = {"bkr_prop_weed_med_01a", -0.5},
        [3] = {"bkr_prop_weed_lrg_01a", -0.5},
    },
    ["plant2"] = {
        [1] = {"bkr_prop_weed_01_small_01b", -0.5},
        [2] = {"bkr_prop_weed_med_01b",-0.5},
        [3] = {"bkr_prop_weed_lrg_01b", -0.5},
    },
    ["small_plant"] = {
        [1] = {"bkr_prop_weed_bud_pruned_01a", 0},
        [2] = {"bkr_prop_weed_bud_02b", 0},
        [3] = {"bkr_prop_weed_bud_02a", 0},
    },
    ["tomate_plant"] = {
        [1] = {"bkr_prop_tomato_plant_01a", 0},
        [2] = {"bkr_prop_tomato_plant_01b", 0},
    },
    -- Planta de coca de verdade, modelo customizado do pacote lunar_drugscreator_props
    -- (resource separado, precisa estar rodando - "dependencies" no fxmanifest.lua).
    -- Offsets copiados direto da config original do lunar (server/default.lua).
    -- Testando o segundo conjunto (d/e/f, usado indoor/qualquer lugar no lunar original) já que
    -- o primeiro (a/b/c, só grama/outdoor no lunar) ficou com visual ruim.
    ["coca_plant"] = {
        -- Segundo número = quanto a planta afunda no chão (negativo = mais fundo). Ajuste aqui se
        -- ainda estiver flutuando acima da terra ao plantar direto no chão (fora do vaso).
        [1] = {"elm_coca_d", -0.5},
        [2] = {"elm_coca_e", -0.5},
        [3] = {"elm_coca_f", -0.5},
    },

    --[[
        7 variedades novas de maconha, modelos customizados do pacote nextgen_weedprops (resource
        separado, precisa estar rodando - "dependencies" no fxmanifest.lua). Nomes verdadeiros de
        raças de maconha pesquisados (o pacote só vinha com apelidos curtos tipo "acagold",
        "ogkush" etc. nos nomes dos arquivos, sem descrição de que raça era cada um):
        acagold = Acapulco Gold, colomgold = Colombian Gold, dosidos = Do-Si-Dos,
        lgreen = Lime Green Skunk, nlights = Northern Lights, ogkush = OG Kush,
        rainbowb = Rainbow Belts. Cada uma tem 3 variantes por estágio pequeno (_a/_b/_c) e 2 por
        médio/grande (_a/_b) - usando sempre a variante "_a" pra manter 1 modelo fixo por estágio,
        igual ao resto do config. Offset -0.5 copiado do plant1/plant2 (mesmo estilo de prop),
        ajuste aqui se alguma ficar flutuando/enterrada.
    ]]
    ["ogkush_plant"] = {
        [1] = {"ng_prop_weed_s_ogkush_a", -0.5},
        [2] = {"ng_prop_weed_m_ogkush_a", -0.5},
        [3] = {"ng_prop_weed_b_ogkush_a", -0.5},
    },
    ["nlights_plant"] = {
        [1] = {"ng_prop_weed_s_nlights_a", -0.5},
        [2] = {"ng_prop_weed_m_nlights_a", -0.5},
        [3] = {"ng_prop_weed_b_nlights_a", -0.5},
    },
    ["dosidos_plant"] = {
        [1] = {"ng_prop_weed_s_dosidos_a", -0.5},
        [2] = {"ng_prop_weed_m_dosidos_a", -0.5},
        [3] = {"ng_prop_weed_b_dosidos_a", -0.5},
    },
    ["acapulcogold_plant"] = {
        [1] = {"ng_prop_weed_s_acagold_a", -0.5},
        [2] = {"ng_prop_weed_m_acagold_a", -0.5},
        [3] = {"ng_prop_weed_b_acagold_a", -0.5},
    },
    ["colombiangold_plant"] = {
        [1] = {"ng_prop_weed_s_colomgold_a", -0.5},
        [2] = {"ng_prop_weed_m_colomgold_a", -0.5},
        [3] = {"ng_prop_weed_b_colomgold_a", -0.5},
    },
    ["limegreenskunk_plant"] = {
        [1] = {"ng_prop_weed_s_lgreen_a", -0.5},
        [2] = {"ng_prop_weed_m_lgreen_a", -0.5},
        [3] = {"ng_prop_weed_b_lgreen_a", -0.5},
    },
    ["rainbowbelts_plant"] = {
        [1] = {"ng_prop_weed_s_rainbowb_a", -0.5},
        [2] = {"ng_prop_weed_m_rainbowb_a", -0.5},
        [3] = {"ng_prop_weed_b_rainbowb_a", -0.5},
    },
}

Config.Plants = { -- Create seeds for drugs

    ['weed_lemonhaze_seed'] = {
        growthTime = false, -- Cutsom growth time in minutes false if you want to use the global growth time
        label = 'Lemon Haze', --
        plantType = 'plant1', -- Choose plant types from (plant1, plant2, small_plant)
        products = { -- Item the plant is going to produce when harvested with the max amount - também define quantos brotos aparecem no minigame de colheita (ver Config.HarvestMinigame)
            ['weed_lemonhaze'] = {min = 4, max = 12},
            --['other_item'] = {min = 1, max = 2}
        },
        seed = {
            chance = 50, -- Percent of getting back the seed
            min = 1, -- Min amount of seeds
            max = 2 -- Max amount of seeds
        },
        time = 3000 -- Time it takes to plant/harvest in miliseconds
    },
    ['coca_seed'] = {
        growthTime = 45, -- revertido do valor de teste (0.2) de volta pro real
        label = 'Coca Plant', --
        plantType = 'coca_plant', -- arbusto de coca de verdade (Cayo Perico), não é mais reaproveitamento do modelo de weed
        products = { -- Item the plant is going to produce when harvested with the max amount
            ['coca']= {min = 1, max = 2}
        },
        seed = {
            chance = 50, -- Percent of getting back the seed
            min = 1, -- Min amount of seeds
            max = 2 -- Max amount of seeds
        },
        time = 3000 -- Time it takes to harvest in miliseconds
    },

    -- 7 variedades novas (nextgen_weedprops) - nomes de raças reais de maconha, ver comentário
    -- em Config.PlantTypes. Cada uma produz seu próprio item bruto (weed_<variedade>), ainda não
    -- ligado ao secador nem às receitas de mesa (só o weed_lemonhaze está ligado por enquanto) -
    -- fácil de estender depois se quiser (Config.DryingRacks.secador.dries / recipe.ingrediants).
    ['ogkush_seed'] = {
        growthTime = false,
        label = 'OG Kush',
        plantType = 'ogkush_plant',
        products = {
            ['weed_ogkush'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
    ['nlights_seed'] = {
        growthTime = false,
        label = 'Northern Lights',
        plantType = 'nlights_plant',
        products = {
            ['weed_nlights'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
    ['dosidos_seed'] = {
        growthTime = false,
        label = 'Do-Si-Dos',
        plantType = 'dosidos_plant',
        products = {
            ['weed_dosidos'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
    ['acapulcogold_seed'] = {
        growthTime = false,
        label = 'Acapulco Gold',
        plantType = 'acapulcogold_plant',
        products = {
            ['weed_acapulcogold'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
    ['colombiangold_seed'] = {
        growthTime = false,
        label = 'Colombian Gold',
        plantType = 'colombiangold_plant',
        products = {
            ['weed_colombiangold'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
    ['limegreenskunk_seed'] = {
        growthTime = false,
        label = 'Lime Green Skunk',
        plantType = 'limegreenskunk_plant',
        products = {
            ['weed_limegreenskunk'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
    ['rainbowbelts_seed'] = {
        growthTime = false,
        label = 'Rainbow Belts',
        plantType = 'rainbowbelts_plant',
        products = {
            ['weed_rainbowbelts'] = {min = 1, max = 4}
        },
        seed = { chance = 50, min = 1, max = 2 },
        time = 3000
    },
}

--[[
    Next you have to prepeare the Processing settings. You can create as many processing tables as you want.
    You can create use as many ingrediants as you want. You can also change the processing table models to your liking.
    Each table is for proccessing a specific drug type. You can also create to tables for the same drug type.

]]

-- ┌─────────────────────────────────────────────────┐
-- │ ____                              _             │
-- │|  _ \ _ __ ___   ___ ___  ___ ___(_)_ __   __ _ │
-- │| |_) | '__/ _ \ / __/ _ \/ __/ __| | '_ \ / _` |│
-- │|  __/| | | (_) | (_|  __/\__ \__ \ | | | | (_| |│
-- │|_|   |_|  \___/ \___\___||___/___/_|_| |_|\__, |│
-- │                                           |___/ │
-- └─────────────────────────────────────────────────┘

Config.EnableProcessing = true -- Enable crafting system
Config.ShowIngrediants = true -- Show ingrediants in the processing table

Config.ProcessingSkillCheck = false -- Enable skill check for processingTables (Replaces the progressbar)
Config.SkillCheck = {
    difficulty = {'easy', 'easy', 'medium', 'easy'},
    keys = {'w', 'a', 's', 'd'}
}

Config.ProcessingTables = { -- Create processing table
    ['weed_processing_table'] = {
        type = 'weed',
        model = 'bkr_prop_weed_table_01a', -- Exanples: bkr_prop_weed_table_01a, bkr_prop_meth_table01a, bkr_prop_coke_table01a
        recipes = {
            ['joint'] = {
                label = 'Maconha',
                ingrediants = {
                    ['weed_lemonhaze_dried'] = 3, -- precisa secar a erva crua no secador antes (Config.DryingRacks)
                    ['rolling_paper'] = 1
                },
                outputs = {
                    ['joint'] = 2
                },
                processTime = 5,
                failChance = 15,
                animation = {
                    dict = 'mini@repair',
                    anim = 'fixing_a_ped',
                }
            },
            ['hash'] = {
                label = 'Haxixe',
                ingrediants = { -- consumidos a cada extração - usa a erva CRUA (resina sai melhor fresca, não precisa secar primeiro)
                    ['weed_lemonhaze'] = 5,
                    ['gelo_seco'] = 2,
                },
                tools = { -- precisa TER no inventário, mas não é gasto (ferramenta reutilizável)
                    ['bubble_bag'] = 1,
                },
                outputs = {
                    ['haxixe'] = 1
                },
                processTime = 8,
                failChance = 15,
                animation = {
                    dict = 'mini@repair',
                    anim = 'fixing_a_ped',
                }
            },
            -- Add more recipes here like this
            --[[ ['weedbag'] = {
                label = 'Weed Bag',
                ingrediants = {
                    ['weed_lemonhaze'] = 3,
                    ['plastic'] = 1
                },
                outputs = {
                    ['weedbag'] = 1
                },
                processTime = 10,
                failChance = 15
            } ]]
        }
    },

    -- Prensa: mesa dedicada só pra transformar QUALQUER uma das 8 variedades de maconha (já
    -- secas no secador) no "Tijolo" daquela variedade específica - uma receita por variedade,
    -- cada uma dando um item FINAL DIFERENTE (tijolo_<variedade>, não um "prensado" genérico
    -- único). Reaproveita a prop da mesa de cocaína (bkr_prop_coke_press_01b, confirmada válida
    -- nesse servidor - usada em mri_Qadmin/data/object.lua).
    -- PENDENTE: usuário vai adicionar uma etapa de "moedor" antes da prensa (moer a planta
    -- inteira + outros ingredientes ainda não definidos) - por enquanto a Prensa aceita direto a
    -- erva seca, igual já funcionava. Ajustar quando o moedor for definido.
    ['prensa'] = {
        type = 'weed',
        model = 'bkr_prop_coke_press_01b',
        recipes = {
            ['tijolo_lemonhaze'] = {
                label = 'Tijolo de Lemon Haze',
                ingrediants = { ['weed_lemonhaze_dried'] = 8 },
                outputs = { ['tijolo_lemonhaze'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_ogkush'] = {
                label = 'Tijolo de OG Kush',
                ingrediants = { ['weed_ogkush_dried'] = 8 },
                outputs = { ['tijolo_ogkush'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_nlights'] = {
                label = 'Tijolo de Northern Lights',
                ingrediants = { ['weed_nlights_dried'] = 8 },
                outputs = { ['tijolo_nlights'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_dosidos'] = {
                label = 'Tijolo de Do-Si-Dos',
                ingrediants = { ['weed_dosidos_dried'] = 8 },
                outputs = { ['tijolo_dosidos'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_acapulcogold'] = {
                label = 'Tijolo de Acapulco Gold',
                ingrediants = { ['weed_acapulcogold_dried'] = 8 },
                outputs = { ['tijolo_acapulcogold'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_colombiangold'] = {
                label = 'Tijolo de Colombian Gold',
                ingrediants = { ['weed_colombiangold_dried'] = 8 },
                outputs = { ['tijolo_colombiangold'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_limegreenskunk'] = {
                label = 'Tijolo de Lime Green Skunk',
                ingrediants = { ['weed_limegreenskunk_dried'] = 8 },
                outputs = { ['tijolo_limegreenskunk'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
            ['tijolo_rainbowbelts'] = {
                label = 'Tijolo de Rainbow Belts',
                ingrediants = { ['weed_rainbowbelts_dried'] = 8 },
                outputs = { ['tijolo_rainbowbelts'] = 1 },
                processTime = 10,
                failChance = 15,
                animation = { dict = 'mini@repair', anim = 'fixing_a_ped' }
            },
        }
    },

    ['cocaine_processing_table'] = {
        type = 'cocaine',
        model = 'bkr_prop_coke_table01a', -- Exanples: bkr_prop_weed_table_01a, bkr_prop_meth_table01a, bkr_prop_coke_table01a
        recipes = {
            ['cocaine'] = {
                label = 'Cocaine',
                ingrediants = {
                    ['coca'] = 3,
                    ['nitrous'] = 1
                },
                outputs = {
                    ['cocaine'] = 2
                },
                processTime = 10,
                failChance = 15,
                animation = {
                    dict = 'mini@repair',
                    anim = 'fixing_a_ped',
                }
            },
        }
    },
}

-- ┌────────────────────────────┐
-- │ ____                       │
-- │|  _ \ _ __ _   _  __ _ ___ │
-- │| | | | '__| | | |/ _` / __|│
-- │| |_| | |  | |_| | (_| \__ \│
-- │|____/|_|   \__,_|\__, |___/│
-- │                  |___/     │
-- └────────────────────────────┘

--[[ Possible Drug Effects:
    stressDecrease,
    runningSpeedIncrease, 
    infinateStamina,
    moreStrength,
    healthRegen,
    foodRegen,
    halfArmor,
    fullArmor,
    drunkWalk,
    psycoWalk,
    outOfBody,
    cameraShake,
    fogEffect,
    confusionEffect,
    whiteoutEffect,
    intenseEffect,
    focusEffect,
    superJump,
    swimming
--]]

Config.EnableDrugs = true -- Enable drug effects
Config.Drugs = { -- Create you own drugs

    ['joint'] = {
        label = 'Maconha',
        animation = 'smoke', -- Animations: blunt, sniff, pill
        time = 80, -- Time in seconds of the Effects
        effects = { -- Effects: runningSpeedIncrease, infinateStamina, moreStrength, healthRegen, foodRegen, drunkWalk, psycoWalk, outOfBody, cameraShake, fogEffect, confusionEffect, whiteoutEffect, intenseEffect, focusEffect
            'intenseEffect',
            'stressDecrease',
            'healthRegen',
            'moreStrength',
            'drunkWalk'
        },
        cooldown = 360, -- Cooldown in seconds until you can use this drug again
    },
    ['cocaine'] = {
        label = 'Cocaine',
        animation = 'sniff', -- Animations: blunt, sniff, pill
        time = 60, -- Time in seconds of the Effects
        effects = { -- Effects: runningSpeedIncrease, infinateStamina, moreStrength, healthRegen, foodRegen, drunkWalk, psycoWalk, outOfBody, cameraShake, fogEffect, confusionEffect, whiteoutEffect, intenseEffect, focusEffect
            'runningSpeedIncrease',
            'infinateStamina',
            'fogEffect',
            'psycoWalk'
        },
        cooldown = 480, -- Cooldown in seconds until you can use this drug again
    },
    ['haxixe'] = {
        label = 'Haxixe',
        animation = 'smoke', -- Animations: blunt, sniff, pill
        time = 100, -- Time in seconds of the Effects
        effects = { -- Effects: runningSpeedIncrease, infinateStamina, moreStrength, healthRegen, foodRegen, drunkWalk, psycoWalk, outOfBody, cameraShake, fogEffect, confusionEffect, whiteoutEffect, intenseEffect, focusEffect
            'intenseEffect',
            'stressDecrease',
            'healthRegen',
            'moreStrength',
            'drunkWalk',
            'confusionEffect'
        },
        cooldown = 420, -- Cooldown in seconds until you can use this drug again
    },
}

--[[
    You also can sell the drugs you created. You can create as many sell zones as you want.
    You can also change the sell zone models to your liking. You can change the price of each drug in each zone.
]]

-- ┌──────────────────────────────┐
-- │ ____       _ _ _             │
-- │/ ___|  ___| | (_)_ __   __ _ │
-- │\___ \ / _ \ | | | '_ \ / _` |│
-- │ ___) |  __/ | | | | | | (_| |│
-- │|____/ \___|_|_|_|_| |_|\__, |│
-- │                        |___/ │
-- └──────────────────────────────┘

---@desativado Estamos usando o qbx_drugs para vendas de drogas (é melhor!)
Config.EnableSelling = false -- Enable selling system

Config.MinimumCops = 0 -- Minimum cops required to sell drugs
Config.OnlyCopsOnDuty = true -- Check if cops are on-duty (Only QBCore).
Config.PoliceJobs = {
    'police',
    'offpolice',
    'sheriff',
    'offsheriff',
}

Config.SellSettings = {
    ['onlyAvailableItems'] = true, -- Only offers with drugs the player has in his inventory
    ['sellChance'] = 70, -- Chance to sell drug (in %)
    ['stealChance'] = 20, -- Chance that the ped dont give you money (in %)
    ['sellAmount'] = { -- Amount of drugs you can sell
        min = 1,
        max = 6,
    },
    ['sellTimeout'] = 20, -- Max time you get to choose your option (secs)
    ['giveBonusOnPolice'] = true, -- Give bonus money if there is police online | 1-2 Cops : x1.2 | 3-6 Cops : x1.5 | 7-10 Cops : x1.7 | +10 Cops : x2.0
}

Config.SellZones = {
    ['groove'] = {
        points = {
            vec3(-154.0, -1778.0, 30.0),
            vec3(48.0, -1690.0, 30.0),
            vec3(250.0, -1860.0, 30.0),
            vec3(142.0, -1993.0, 30.0),
            vec3(130.0, -2029.0, 30.0),
        },
        thickness = 27,
        drugs = {
            { item = 'cocaine', price = math.random(100, 200)},
            { item = 'joint', price = math.random(50, 100)},
            { item = 'weed_lemonhaze', price = math.random(50, 100)}
        }
    },
    ['vinewood'] = {
        points = {
            vec3(685.0, 36.0, 84.0),
            vec3(647.0, 53.0, 84.0),
            vec3(575.0, 81.0, 84.0),
            vec3(529.0, 100.0, 84.0),
            vec3(52.0, 274.0, 84.0),
            vec3(-34.0, 42.0, 84.0),
            vec3(426.0, -125.0, 84.0),
            vec3(494.0, -140.0, 84.0),
            vec3(518.0, -101.0, 84.0),
            vec3(595.0, -60.0, 84.0),
            vec3(667.0, -9.0, 84.0),
        },
        thickness = 59.0,
        drugs = {
            { item = 'cocaine', price = math.random(100, 200)},
            { item = 'joint', price = math.random(50, 100)},
            { item = 'weed_lemonhaze', price = math.random(50, 100)}
        }
    },
    ['beach'] = {
        points = {
            vec3(-1328.0, -1340.0, 5.0),
            vec3(-1307.0, -1399.0, 5.0),
            vec3(-1297.0, -1421.0, 5.0),
            vec3(-1266.0, -1466.0, 5.0),
            vec3(-1139.0, -1646.0, 5.0),
            vec3(-1129.0, -1640.0, 5.0),
            vec3(-1307.0, -1358.0, 5.0),
            vec3(-1335.0, -1279.0, 5.0),
            vec3(-1349.0, -1285.0, 5.0),
        },
        thickness = 4.0,
        drugs = {
            { item = 'cocaine', price = math.random(100, 200)},
            { item = 'joint', price = math.random(50, 100)},
            { item = 'weed_lemonhaze', price = math.random(50, 100)}
        }
    },
}

Config.BlacklistPeds = { 
    -- Peds you cant sell drugs to
    "mp_m_shopkeep_01",
    "s_m_y_ammucity_01",
    "s_m_m_lathandy_01",
    "s_f_y_clubbar_01",
    "ig_talcc",
    "g_f_y_vagos_01",
    "hc_hacker",
    "s_m_m_migrant_01",
}

function SendPoliceAlert()
    if GetResourceState('ps-dispatch') == 'started' then
        exports['ps-dispatch']:DrugDealing()
    end
    -- Add You own police alert system here
    -- local message = 'Drug Dealer spotted at '..coords
    -- TriggerEvent('chat:addMessage', {
    -- args = {message}
    -- })
end

function ShowNotification(source, message, type)
    -- Bridge.Functions.Notify(message, type) are the default Framework notifications
    -- You can change this to your own notification systems
    if source ~= nil then -- Server Messages
        if type == 'error' then
            it.notify(source, message, "error")
        elseif type == 'success' then
            it.notify(source, message, "success")
        else
            it.notify(source, message)
        end
    else -- Client Messages
        if type == 'error' then
            it.notify(message, "error")
        elseif type == 'success' then
            it.notify(message, "success")
        else
            it.notify(message)
        end
    end
end

--[[
    Debug mode, you can see all kinds of prints/logs using debug,
    but it's only for development.
]]
Config.EnableVersionCheck = false -- Enable version check
Config.Branch = 'main' -- Set to 'master' to use the master branch, set to 'development' to use the dev branch
Config.Debug = false -- Set to true to enable debug mode
Config.DebugPoly = false -- Set to true to enable debug mode for PolyZone

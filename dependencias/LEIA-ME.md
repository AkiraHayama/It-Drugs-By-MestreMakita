# O que mais o it-drugs precisa pra rodar (servidor Qbox + ox_inventory)

Tudo que foi feito junto com este it-drugs e não fica dentro dele está aqui.

## 1. Resources (`resources/`)

Copie cada pasta pra dentro da pasta `resources` do servidor (qualquer categoria que já tenha `ensure`)
e garanta que elas sobem ANTES do it-drugs (o fxmanifest do it-drugs lista como dependency).

| pasta | o que é |
|---|---|
| `itdrugs_bancada` | tela da bancada (barra de itens, arrastar com o mouse). **Sem ela a bancada não abre.** |
| `itdrugs_som` | som do ventilador |
| `redinha` | redinha de secar as buds (`prop_redinha_06`) |
| `terra_nobre` | saco de terra (`terra_nobre`, `saco_terra_nobre_aberto`) |
| `mri_dichavador` | dichavador de 2 peças (`mri_dichavador_base` / `_tampa`), bancada modo camarão |
| `mri_plastico_filme` | rolo de plástico filme (`mri_rolo_plastico_filme`), bancada modo prensado |
| `MakitaPot` | vaso de plantio (`bzzz_growing_freepot_*`) |
| `tesouras_do_makita` | tesoura da colheita |

## 2. Props de terceiros (NÃO estão aqui)

São de outros criadores; cada um precisa baixar/comprar o seu:

- `bzzz_lights_and_lamps` e `bzzz_cutting_weed` — BzZz (pagos, protegidos por escrow: só funcionam na conta de quem comprou)
- `nextgen_weedprops` — Pandinja
- `lunar_drugscreator_props` — Lunar Scripts

Sem eles: lâmpadas, foice, plantas novas e plantas de coca não aparecem. Dá pra trocar os modelos no `shared/config.lua`.

## 3. Itens (`itens_inventory.json`)

Definição de todos os itens usados (95): sementes, erva crua/seca/curada/dichavada, saquinho, tijolo,
cubo de prensado, prensado embalado, balança, plástico filme, zip lock, dichavador, gerador, extensão,
ventilador, pá de jardim, mesas, prensa...

- **MRI Qbox:** junte o conteúdo de `items` dentro de `[mri]/mri_Qbox/data/inventory.json`
  (NÃO em `mri_Qbox/resources/modules/inventory/base/items.lua`: a atualização do MRI apaga).
- **ox_inventory puro:** passe pro formato de `ox_inventory/data/items.lua`.

## 4. Ícones (`icones/`)

Copie tudo pra `ox_inventory/web/images/`.

## 5. Banco de dados

As tabelas do it-drugs (`drug_*`) são criadas sozinhas quando ele inicia. Reinicie o servidor inteiro
depois de colocar itens, props e resources novos.

## 6. Outros recursos que o it-drugs usa

`ox_lib`, `oxmysql`, `ox_inventory`, um target que forneça `ox_target` (aqui é o `mri_Qinteract`) e,
pro gerador, o galão do `cdn-fuel` (item `jerrycan` com metadata `cdn_fuel`).

## 7. Lista de itens

**95 itens próprios** (estão em `itens_inventory.json`) + itens padrão do MRI/Qbox.

### Itens gerais

| item | nome no jogo |
|---|---|
| `coca_seed` | Semente de Coca *(item do MRI; o it-drugs só define o uso)* |
| `weed_processing_table` | Mesa de Produção *(item do MRI; o it-drugs só define o uso)* |
| `cocaine_processing_table` | Mesa de Produção *(item do MRI; o it-drugs só define o uso)* |
| `joint` | Cigarro de Maconha *(item do MRI; o it-drugs só define o uso)* |
| `cocaine` | Cocaína Processada |
| `haxixe` | Haxixe |
| `prensa` | Prensa |
| `portable_lamp` | Lâmpada Portátil |
| `reflector_lamp` | Lâmpada Portátil (Refletora) |
| `vaso` | Vaso de Plantio |
| `secador` | Rede de Secagem |
| `ventilador` | Ventilador |
| `terra` | Saco de Terra |
| `foice` | Foice |
| `bubble_bag` | Bubble Bag |
| `gelo_seco` | Gelo Seco |
| `dichavador` | Dichavador |
| `gerador` | Gerador |
| `extensao` | Extensão |
| `plastico_filme` | Plástico Filme |
| `ziplock` | Zip Lock |
| `balanca` | Balança de Precisão |
| `pa_jardim` | Pá de Jardim |

### Por variedade de maconha

Cada variedade tem a mesma cadeia: semente → erva crua → seca → curada → dichavada → saquinho, e no prensado: tijolo → cubo → cubo embalado.

| variedade | semente | crua | seca | curada | dichavada | saquinho | tijolo | cubo | cubo embalado |
|---|---|---|---|---|---|---|---|---|---|
| lemonhaze | `weed_lemonhaze_seed` | `weed_lemonhaze` | `weed_lemonhaze_dried` | `weed_lemonhaze_curada` | `weed_lemonhaze_dichavada` | `weed_lemonhaze_saquinho` | `tijolo_lemonhaze` | `cubo_lemonhaze` | `cubo_lemonhaze_embalado` |
| ogkush | `ogkush_seed` | `weed_ogkush` | `weed_ogkush_dried` | `weed_ogkush_curada` | `weed_ogkush_dichavada` | `weed_ogkush_saquinho` | `tijolo_ogkush` | `cubo_ogkush` | `cubo_ogkush_embalado` |
| nlights | `nlights_seed` | `weed_nlights` | `weed_nlights_dried` | `weed_nlights_curada` | `weed_nlights_dichavada` | `weed_nlights_saquinho` | `tijolo_nlights` | `cubo_nlights` | `cubo_nlights_embalado` |
| dosidos | `dosidos_seed` | `weed_dosidos` | `weed_dosidos_dried` | `weed_dosidos_curada` | `weed_dosidos_dichavada` | `weed_dosidos_saquinho` | `tijolo_dosidos` | `cubo_dosidos` | `cubo_dosidos_embalado` |
| acapulcogold | `acapulcogold_seed` | `weed_acapulcogold` | `weed_acapulcogold_dried` | `weed_acapulcogold_curada` | `weed_acapulcogold_dichavada` | `weed_acapulcogold_saquinho` | `tijolo_acapulcogold` | `cubo_acapulcogold` | `cubo_acapulcogold_embalado` |
| colombiangold | `colombiangold_seed` | `weed_colombiangold` | `weed_colombiangold_dried` | `weed_colombiangold_curada` | `weed_colombiangold_dichavada` | `weed_colombiangold_saquinho` | `tijolo_colombiangold` | `cubo_colombiangold` | `cubo_colombiangold_embalado` |
| limegreenskunk | `limegreenskunk_seed` | `weed_limegreenskunk` | `weed_limegreenskunk_dried` | `weed_limegreenskunk_curada` | `weed_limegreenskunk_dichavada` | `weed_limegreenskunk_saquinho` | `tijolo_limegreenskunk` | `cubo_limegreenskunk` | `cubo_limegreenskunk_embalado` |
| rainbowbelts | `rainbowbelts_seed` | `weed_rainbowbelts` | `weed_rainbowbelts_dried` | `weed_rainbowbelts_curada` | `weed_rainbowbelts_dichavada` | `weed_rainbowbelts_saquinho` | `tijolo_rainbowbelts` | `cubo_rainbowbelts` | `cubo_rainbowbelts_embalado` |

### Itens padrão do MRI/Qbox que o it-drugs também usa

Já vêm no MRI (não precisa criar): `watering_can` (Regador), `water_bottle` / `empty_water_bottle` (Garrafa de Água, rega e devolve a vazia), `fertilizer`, `liquid_fertilizer`, `advanced_fertilizer`, `rolling_paper` (Seda), `shovel`, `plastic`, `bag`, `coca`, `weed_brick`, `nitrous`, `jerrycan` (galão do cdn-fuel, pro gerador), `money`, `black_money`, `WEAPON_KNIFE` (faca da bancada).


## 8. Lista de props (modelos 3D)

Todos os modelos que o it-drugs coloca no mundo. Os nomes ficam em `shared/config.lua` (dá pra trocar lá).

### Feitos junto com este it-drugs (estão em `resources/`)

| modelo | o que é | resource |
|---|---|---|
| `bzzz_growing_freepot_a` | vaso vazio | `MakitaPot` |
| `bzzz_growing_freepot_c` | vaso com terra | `MakitaPot` |
| `prop_redinha_06` | redinha de secar (6 bandejas) | `redinha` |
| `saco_terra_nobre_aberto` | saco de terra aberto ("Colocar Terra" no vaso) | `terra_nobre` |
| `tesouras_do_makita` | tesoura da colheita | `tesouras_do_makita` |
| `mri_dichavador_base` / `mri_dichavador_tampa` | dichavador na bancada (camarão) | `mri_dichavador` |
| `mri_rolo_plastico_filme` | rolo de plástico filme na bancada (prensado) | `mri_plastico_filme` |

### De terceiros (NÃO estão aqui, ver seção 2)

| modelo | o que é | pacote |
|---|---|---|
| `bzzz_world_of_lamps_purple` | lâmpada da plantação | `bzzz_lights_and_lamps` (BzZz) |
| `bzzz_cutting_sickle`, `bzzz_prop_sickle_a` | foice | `bzzz_cutting_weed` (BzZz) |
| `elm_coca_d`, `elm_coca_e`, `elm_coca_f` | pé de coca (pequeno, médio, grande) | `lunar_drugscreator_props` (Lunar) |
| `ng_prop_weed_s_<raça>_a`, `ng_prop_weed_m_<raça>_a`, `ng_prop_weed_b_<raça>_a` | pé de maconha pequeno/médio/grande das 7 raças novas (`acagold`, `colomgold`, `dosidos`, `lgreen`, `nlights`, `ogkush`, `rainbowb`) | `nextgen_weedprops` (Pandinja) |

### Nativos do GTA (já vêm no jogo)

| modelo | onde aparece |
|---|---|
| `bkr_prop_weed_01_small_01a/b`, `bkr_prop_weed_med_01a/b`, `bkr_prop_weed_lrg_01a/b` | pé de maconha (tipos `plant1`/`plant2`, 3 estágios) |
| `bkr_prop_tomato_plant_01a/b` | planta de exemplo (config original) |
| `bkr_prop_weed_bud_pruned_01a`, `bkr_prop_weed_bud_02b`, `bkr_prop_weed_bud_02a` | planta pequena (`small_plant`); o `02a` também é o broto do minigame da colheita |
| `bkr_prop_weed_leaf_dry_01a` | folhas secas de enfeite em cima da bancada |
| `bkr_prop_weed_bud_01a` | bud curada na bancada e no dichavador |
| `h4_prop_h4_weed_dry_01a` | erva dichavada |
| `bkr_prop_weed_bag_01a` | zip lock na bancada |
| `sf_prop_sf_bag_weed_01b` | saquinho pronto (camarão) |
| `ba_prop_battle_weed_bigbag_01a` | cubos embalados prontos (camarão) |
| `prop_weed_block_01` | tijolo de prensado |
| `hei_prop_heist_weed_block_01b` | cubinho de prensado |
| `bkr_prop_weed_table_01b` | mesa de maconha / bancada |
| `bkr_prop_coke_table01a` | mesa de cocaína |
| `bkr_prop_coke_press_01b` | prensa |
| `bkr_prop_coke_scale_01` | balança |
| `prop_w_me_knife_01` | faca da bancada |
| `bkr_prop_weed_fan_floor_01a` | ventilador |
| `prop_generator_01a` | gerador |
| `xm_prop_base_tripod_lampb` | lâmpada refletora (tripé) |
| `prop_wateringcan` | regador na mão |
| `prop_ld_flow_bottle` | garrafa de água na mão (regando) |
| `w_am_jerrycan_sf`, `prop_ld_jerrycan_01` | galão na mão (abastecer gerador) |

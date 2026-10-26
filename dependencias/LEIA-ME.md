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

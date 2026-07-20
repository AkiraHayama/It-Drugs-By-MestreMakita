<div align="center">

[![Drugs Banner](https://i.imgur.com/BdAp0Rw.png)](https://github.com/it-scripts/it-drugs?tab=readme-ov-file#it-drugs "Go to repo")

</div>

<div align="center">

[![Discord](https://img.shields.io/badge/Discord%20-Join%20now-blue?logo=discord)](https://discord.gg/4KtC77WMPK)
[![Downloads](https://img.shields.io/github/downloads/it-scripts/it-drugs/total?logo=github)]()
[![Version](https://img.shields.io/github/v/release/it-scripts/it-drugs?logo=github)]()
[![License](https://img.shields.io/github/license/it-scripts/it-drugs?logo=github)]()

</div>

**Fork customizado do it-drugs (it-scripts), modificado por MestreMakita.** Sistema de cultivo e produção de drogas pra FiveM (QBCore/ESX): plantio direto no chão ou em vaso, lâmpadas de cultivo pra indoor, secagem e processamento em mesa (joint, haxixe, cocaína, prensado). A colheita é em duas etapas - primeiro um minigame de cortar os brotos com uma tesoura 3D, depois (opcional) cortar a planta inteira com uma foice pra aproveitar o resto dela. Tem 8 variedades de maconha plantáveis, além de coca.

Não é plug-and-play: precisa de alguns pacotes de props/animações customizados que não vêm nesse repositório (props do vaso, das lâmpadas, das plantas novas, da tesoura e da foice). **Leia a seção "O que precisa pra esse sistema funcionar" mais abaixo antes de instalar** - sem essas dependências, partes do sistema não vão funcionar.

### Supported Frameworks
- `✅` **| [ESX](https://github.com/esx-framework/esx_core)**
- `✅` **| [QbCore](https://github.com/qbcore-framework/qb-core)**

### Suported Inventorys
- `✅` **| [esx_inventory](https://github.com/esx-framework/esx_core)**
- `✅` **| [qb_inventory](https://github.com/qbcore-framework/qb-inventory)**
- `✅` **| [ox_inventory](https://github.com/overextended/ox_inventory)**
- `🔧` **| [qs_inventory](https://github.com/overextended/ox_inventory)** *(Nativ qb-core support should work)*

`✅` **| Supported** `🔧` **| Pending** `❌` **| Not Supported**

### Dependencys
- `⚙️` **| [ox_lib](https://github.com/overextended/ox_lib)**
- `⚙️` **| [oxmysql](https://github.com/overextended/oxmysql)**
- `⚙️` **| [PolyZone](https://github.com/mkafrin/PolyZone)**
- `⚙️` **| [ox_target](https://github.com/overextended/ox_target)** *
- `⚙️` **| [qb-target](https://github.com/qbcore-framework/qb-target)** *

* Please use only one

---

## ⚠️ O que precisa pra esse sistema (versão customizada) funcionar

Isso aqui é específico dessa cópia do it-drugs, depois de todas as mudanças feitas nessa sessão (vaso, colheita com tesoura, corte da planta inteira com foice, prensado, etc). Lista direta do que precisa existir/estar rodando pra tudo funcionar - sem isso, partes do sistema quebram ou nem sobem.

### 1. Resources que precisam estar rodando ANTES do it-drugs (nessa ordem no server.cfg)
Framework: `qb-core` **ou** `es_extended` (ESX)
Inventário: `ox_inventory` **ou** `qb-inventory`
Target (opcional mas usado por padrão): `ox_target` **ou** `qb-target`

Dependências obrigatórias (declaradas no `fxmanifest.lua`, o server já recusa iniciar o it-drugs sem elas):
- `ox_lib`
- `oxmysql`
- `lunar_drugscreator_props` — modelos 3D da planta de coca (`elm_coca_*`)
- `MakitaPot` — vaso de plantio (`bzzz_growing_freepot_*`)
- `bzzz_lights_and_lamps` — lâmpadas de cultivo com cor de luz de verdade (`bzzz_world_of_lamps_*`)
- `nextgen_weedprops` — as 7 variedades novas de maconha (`ng_prop_weed_*`)
- `tesouras_do_makita` — tesoura 3D usada como "cursor" no minigame de colher (prop `tesouras_do_makita`, model **ainda não confirmado ao vivo**)
- `bzzz_cutting_weed` — foice + animação de cortar a planta inteira (prop `bzzz_prop_sickle_a`, anim dict/clip `bzzz_cutting_sickle`)

Opcionais (integrações automáticas, só ativam se estiverem rodando, não precisam estar no fxmanifest):
- `ps-dispatch` — alerta de polícia quando usa o dealer de sementes
- `mri_Qbox` — adiciona os pontos de água no menu F10 de admin

### 2. Itens que precisam existir em `ox_inventory/data/items.lua` (ou o equivalente do qb-inventory)
Nessa cópia do projeto **já estão todos registrados** em `[ox]/ox_inventory/data/items.lua` - mas se for subir só a pasta do it-drugs pro GitHub (sem o ox_inventory customizado junto), esses itens precisam ser recriados/mesclados manualmente no inventário de destino, senão eles não existem no jogo:

`watering_can`, `fertilizer`, `advanced_fertilizer`, `liquid_fertilizer`, `weed_lemonhaze_seed`, `weed_lemonhaze`, `weed_lemonhaze_dried`, `coca_seed`, `coca`, `rolling_paper`, `nitrous`, `cocaine`, `joint`, `weed_processing_table`, `cocaine_processing_table`, `portable_lamp`, `reflector_lamp`, `vaso`, `terra`, `secador`, `bubble_bag`, `gelo_seco`, `haxixe`, `ogkush_seed`, `weed_ogkush`, `nlights_seed`, `weed_nlights`, `dosidos_seed`, `weed_dosidos`, `acapulcogold_seed`, `weed_acapulcogold`, `colombiangold_seed`, `weed_colombiangold`, `limegreenskunk_seed`, `weed_limegreenskunk`, `rainbowbelts_seed`, `weed_rainbowbelts`, e os dois itens **novos** dessa sessão: **`foice`** (ferramenta, nunca é gasta) e **`prensado`** (produto final da mesa de processamento).

Os itens usáveis (semente, vaso, secador, mesas, drogas) também precisam do `client = { event = "it-drugs:ox:useItem" }` na definição pra funcionar com `ox_inventory` (ver `bridge/items/*.lua`).

### 3. Ícones que ainda FALTAM (o sistema funciona sem eles, só fica sem imagem no inventário)
Faltam em `ox_inventory/web/images/`:
- `secador.png`, `weed_lemonhaze_dried.png`, `reflector_lamp.png`
- `weed_ogkush.png`, `weed_nlights.png`, `weed_dosidos.png`, `weed_acapulcogold.png`, `weed_colombiangold.png`, `weed_limegreenskunk.png`, `weed_rainbowbelts.png` e as sementes correspondentes (as 7 variedades novas não têm nenhum ícone ainda, nem cru nem semente)
- **Novos dessa sessão**: `foice.png`, `prensado.png`

### 4. Banco de dados
Não precisa importar SQL na mão - o próprio resource cria/atualiza as tabelas sozinho no primeiro start (`server/database/sv_setupdatabase.lua`, roda os `.sql` de `server/database/*.sql` automaticamente via `oxmysql`). Só precisa o `oxmysql` já configurado com um banco válido.

### 5. Permissão de admin
Os comandos/menus de admin (`/it-drugs plants|tables|waterpoints`, "Forçar 100%") checam `IsPlayerAceAllowed(source, 'admin')` - precisa ter no `server.cfg` (ou nos arquivos de permission) um `add_ace` liberando `admin` pro identifier/grupo dos administradores, senão ninguém consegue usar essas opções mesmo sendo staff.

### 6. Coisas ainda sem confirmação ao vivo (testar antes de considerar "pronto")
- Nome exato do model da tesoura (`tesouras_do_makita`) e da foice/animação (`bzzz_prop_sickle_a`/`bzzz_cutting_sickle`) - os da foice vieram confirmados do próprio arquivo de config do pacote (`bzzz_cutting_weed/data/coords.lua`), a tesoura é uma suposição pelo nome do arquivo.
- Sensibilidade/raio/offset do "cursor" 3D da tesoura (`Config.HarvestMinigame.cursorSensitivity/cursorMaxRadius/cursorPlaneOffset`) - ajustados no olho durante os testes, pode precisar de retoque em telas/resoluções diferentes.

<div align="center">

![Drugs Features Banner](https://i.imgur.com/oMoMrkN.png)

</div>

### `🌱` **| Planting**
Our script offers a unique planting system that allows players to grow unlimited plants *(or a set max amount in the config)*. With the ability to plant seeds, players can cultivate their own plants and harvest them for raw materials. Our planting system makes the complete map a potential farm, allowing players to grow plants in any location they choose (*Soil/Ground check can be enabled in the config*). Optional growth speed zones add a strategic layer to farming, making it a fun and engaging experience.

### `🧪` **| Processing Tables**
Our script features processing tables that allow players to transform raw materials into high-value drugs. Players can use these tables to create drugs themselves, adding a layer of complexity to the drug economy. The Tables can be placed anywhere on the map, making it easy for players to process their materials and create drugs. Every table can be configured in the config file, allowing server admins to customize the experience to fit their unique needs.

### `💰` **| Selling Drugs to NPCs**
Our script allows players to sell drugs to NPCs, creating a dynamic market environment. Players can sell their drugs to NPCs for a profit, enhancing the overall gameplay. This feature adds a layer of realism to the drug economy, making it a fun and engaging experience for players. The selling prices on selling zones can be configured in the config file.

### `🚬` **| Takeable Drugs**
Our script offers takeable drugs that players can consume for various effects. Players can take drugs to enhance their gameplay experience, adding a layer of realism to the drug economy. The effects of the drugs can be configured in the config file.

### `📊` **| Ingame Admin Menu**
Our script features an ingame admin menu that allows server admins to manage drugs and tables. Admins can use the menu view and manage all drugs and tables on the server, making it easy to keep track of everything. The admin menu can be accessed by typing `/drugadmin [plants/tables]` in the chat.

### `🔧` **| Fully Configurable**
Our script is fully configurable, allowing server admins to customize every aspect to fit their unique needs. From growth speed zones to selling prices, every aspect of the script can be configured in the config file.

<div align="center">

[![Drugs Documentation Banner](https://i.imgur.com/x00BnXb.png)](https://help.it-scripts.com/scripts/it-drugs)

## You can find the install guide in the [documentation](https://help.it-scripts.com/scripts/it-drugs)
<br>
</div>


<div align="center">

[![Drugs Schowcase Banner](https://i.imgur.com/pLhHIeU.png)](https://www.youtube.com/watch?v=4Yjuu1Fptm4)
[![Drugs YouTube Banner](https://img.youtube.com/vi/4Yjuu1Fptm4/maxresdefault.jpg)](https://www.youtube.com/watch?v=4Yjuu1Fptm4)

**[VIEW ON YOUTUBE](https://www.youtube.com/watch?v=4Yjuu1Fptm4)**
</div>

<br>
<table><tr><td><h4 align='center'>Legal Notices</h4></tr></td>
<tr><td>
it-drugs (it-scripts)

Copyright (C) 2024 [it-scripts](https://github.com/it-scripts)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.


This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.


You should have received a copy of the GNU General Public License
along with this program.
If not, see <https://www.gnu.org/licenses/>
</td></tr></table>

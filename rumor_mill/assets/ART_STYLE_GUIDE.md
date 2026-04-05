# Rumor Mill — Art Style Guide (Art Pass 12 / SPA-591)

**Visual target:** Pentiment × Dwarf Fortress.
Desaturated naturals, ink-line silhouettes, warm parchment UI.
No gradients. No glows (except forge). Limited palette per zone.

---

## Palette — LOCKED

All assets must use only the colours below.

| Token           | Hex       | RGB               | Usage                              |
|-----------------|-----------|-------------------|------------------------------------|
| `VOID`          | `#0C0A14` | 12, 10, 20        | Empty tiles, void cells            |
| `GRASS_L`       | `#4C723C` | 76, 114, 60       | Grass highlight / noise            |
| `GRASS_M`       | `#3A5C2C` | 58, 92, 44        | Grass base fill                    |
| `GRASS_D`       | `#2A441E` | 42, 68, 30        | Grass edge / shadow                |
| `DIRT_L`        | `#AC864C` | 172, 134, 76      | Dirt road highlight                |
| `DIRT_M`        | `#8A6836` | 138, 104, 54      | Dirt road base                     |
| `DIRT_D`        | `#684C26` | 104, 76, 38       | Dirt road shadow / ruts            |
| `STONE_L`       | `#A29C8A` | 162, 156, 138     | Stonework highlight                |
| `STONE_M`       | `#746E60` | 116, 110, 96      | Stonework base                     |
| `STONE_D`       | `#504A3E` | 80, 74, 62        | Stonework shadow / mortar          |
| `WOOD_L`        | `#BA8C52` | 186, 140, 82      | Oak highlight                      |
| `WOOD_M`        | `#8E6232` | 142, 98, 50       | Oak base                           |
| `WOOD_D`        | `#603E1A` | 96, 62, 26        | Oak shadow / beams                 |
| `THATCH_L`      | `#BEA25A` | 190, 162, 90      | Thatch roof highlight              |
| `THATCH_D`      | `#604C28` | 96, 76, 40        | Thatch roof shadow                 |
| `ROOF_TILE`     | `#984832` | 152, 72, 50       | Clay-tile roof                     |
| `ROOF_SLATE`    | `#4C4C5A` | 76, 76, 90        | Slate roof (manor, chapel)         |
| `PLASTER`       | `#DECAA2` | 222, 202, 162     | Tavern / mill plaster walls        |
| `MANOR_STONE`   | `#C6BAA2` | 198, 186, 162     | Manor limestone                    |
| `CHAPEL_STONE`  | `#CECAC4` | 206, 202, 196     | Chapel cool-grey stone             |
| `WATER_L`       | `#5894C4` | 88, 148, 196      | Water surface highlights           |
| `WATER_D`       | `#346296` | 52, 98, 150       | Water depth                        |
| `FORGE`         | `#F0822C` | 240, 130, 44      | Forge / fire glow                  |
| `CANVAS`        | `#C8963A` | 200, 150, 58      | Market stall awning                |
| `OUTLINE`       | `#1C1814` | 28, 24, 20        | All sprite outlines                |
| `SKIN`          | `#DEBA96` | 222, 186, 150     | NPC skin                           |
| `HAIR`          | `#3C2A1C` | 60, 42, 28        | NPC hair / boots                   |
| **MERCH_BODY**  | `#1A3E76` | 26, 62, 118       | Merchant tunic (deep blue)         |
| **MERCH_TRIM**  | `#C8A22E` | 200, 162, 46      | Merchant belt / badge (gold)       |
| **NOBLE_BODY**  | `#6C162A` | 108, 22, 42       | Noble tunic (burgundy)             |
| **NOBLE_TRIM**  | `#B4B4C2` | 180, 180, 194     | Noble belt / badge (silver)        |
| **CLERGY_BODY** | `#E4DECC` | 228, 222, 204     | Clergy robe (cream)                |
| **CLERGY_TRIM** | `#1E1A1E` | 30, 26, 30        | Clergy belt / badge (near-black)   |
| `FLAG_R`        | `#B22626` | 178, 38, 38       | Pennant / flag                     |
| `PARCH_L`       | `#E4D2A8` | 228, 210, 168     | Parchment panel highlight          |
| `PARCH_M`       | `#C8B280` | 200, 178, 128     | Parchment panel base               |
| `PARCH_D`       | `#98784E` | 152, 120, 78      | Parchment panel border             |
| `INK`           | `#2C2216` | 44, 34, 22        | Ink text / scroll decorations      |

---

## Tile Specifications

| Category      | Size    | Atlas source | File                       |
|---------------|---------|--------------|----------------------------|
| Ground / Road | 64×32px | isometric    | `tiles_ground.png`         |
| Road dirt     | 64×32px | isometric    | `tiles_road_dirt.png`      |
| Road stone    | 64×32px | isometric    | `tiles_road_stone.png`     |
| Buildings     | 64×64px | isometric    | `tiles_buildings.png`      |

**Ground atlas** (`tiles_ground.png`, 768×32, twelve 64×32 tiles):

| Col | Const              | Description                          |
|-----|--------------------|--------------------------------------|
| 0   | `ATLAS_VOID`       | Transparent / empty                  |
| 1   | `ATLAS_GRASS`      | Standard grass                       |
| 2   | `ATLAS_GRASS_DARK` | Shadow grass (under buildings)       |
| 3   | —                  | Grass sparse (lighter, pale patches) |
| 4   | —                  | Grass dense (darker crosshatch)      |
| 5   | —                  | Grass floral (flower specks)         |
| 6   | —                  | Dirt muddy (puddles, wet look)       |
| 7   | —                  | Dirt packed (compressed, smooth)     |
| 8   | —                  | Grass/dirt blend (organic edge)      |
| 9   | `ATLAS_STONE_SMOOTH`  | Smooth dressed stone — courtyard  |
| 10  | `ATLAS_STONE_CRACKED` | Cracked/weathered stone           |
| 11  | `ATLAS_STONE_COBBLE`  | Cobblestone paving                |

**Building atlas** (`tiles_buildings.png`, 640×64, 10 tiles):

| Col | Const             | Building      | Faction       |
|-----|-------------------|---------------|---------------|
| 0   | `ATLAS_MANOR`     | Manor         | Noble         |
| 1   | `ATLAS_TAVERN`    | Tavern        | Neutral       |
| 2   | `ATLAS_CHAPEL`    | Chapel        | Clergy        |
| 3   | `ATLAS_MARKET`    | Market        | Merchant      |
| 4   | `ATLAS_WELL`      | Well          | Neutral       |
| 5   | `ATLAS_BLACKSMITH`| Blacksmith    | Merchant      |
| 6   | `ATLAS_MILL`      | Mill          | Merchant      |
| 7   | `ATLAS_STORAGE`   | Storage       | Merchant      |
| 8   | `ATLAS_GUARDPOST` | Guard Post    | Noble         |
| 9   | `ATLAS_TOWN_HALL` | Town Hall     | Noble         |

---

## NPC Sprite Specifications

File: `assets/textures/npc_sprites.png` (336×648)  
Frame size: **48×72px** (upscaled 1.5× from 32×48 base art)  
Sheet layout: 7 columns × 9 rows (3 faction rows + 6 archetype rows; rows 6–8 added in SPA-486)

| Row | Type      | Faction / Archetype | Body colour     | Trim colour    | Hat silhouette                              |
|-----|-----------|---------------------|-----------------|----------------|---------------------------------------------|
| 0   | Faction   | Merchant            | `MERCH_BODY`    | `MERCH_TRIM`   | Wide-brim felt (14 px) + feather quill      |
| 1   | Faction   | Noble               | `NOBLE_BODY`    | `NOBLE_TRIM`   | 3-spike coronet with silver gem tips        |
| 2   | Faction   | Clergy              | `CLERGY_BODY`   | `CLERGY_TRIM`  | Draped hood + bell-shaped cassock robe      |
| 3   | Archetype | Guard               | `STONE_M`       | `STONE_D`      | Nasal helmet                                |
| 4   | Archetype | Commoner            | `DIRT_M`        | `DIRT_D`       | Soft cloth cap                              |
| 5   | Archetype | Tavern Staff        | `WOOD_M`        | `PLASTER`      | Parchment head-kerchief                     |
| 6   | Archetype | Scholar             | `MERCH_B`       | `FLAG_R`       | Square mortarboard skullcap + scroll prop   |
| 7   | Archetype | Elder               | `PLASTER`       | `STONE_M`      | Open grey hood + white temple hair + staff  |
| 8   | Archetype | Spy                 | `STONE_D`       | `INK`          | Deep cowl hiding face + dagger at belt      |

**Faction silhouette differentiation (SPA-478):** Merchant, Noble, and Clergy each have a unique hat shape readable at the 48×72 sprite scale. Merchant reads wide (hat brim 14 px base, 21 px upscaled), Noble reads tall (3-spike crown), Clergy reads soft and wide-shouldered (hood drapes + cassock bell).

**Art Pass 8 archetype additions (SPA-486):** Scholar (row 6) reads academic — square flat mortarboard + ink-blue robe + scroll. Elder (row 7) reads ancient — open grey hood showing white temple hair + walking staff. Spy (row 8) reads shadowy — deep dark cowl hiding face + narrow hunched cloak silhouette.

| Cols | Animation | Speed  | Loop |
|------|-----------|--------|------|
| 0–2  | `idle`    | 4 fps  | yes  |
| 3–6  | `walk`    | 8 fps  | yes  |

---

## VFX Colors

These colors are **not** part of the locked palette. They are HDR-range modulate values (components > 1.0) applied at runtime to produce a bloom/glow effect. They exist only in code and must never be used for sprites or UI fills.

Defined in `npc.gd` lines 885–887.

| Token        | Godot `Color`              | RGB (normalised)          | Heat threshold | Purpose                        |
|--------------|----------------------------|---------------------------|----------------|--------------------------------|
| `HEAT_WARN`  | `Color(1.30, 0.65, 0.35)`  | 331, 166, 89 (HDR)        | heat 50–74     | Amber shimmer — moderate heat  |
| `HEAT_ALARM` | `Color(1.45, 0.40, 0.25)`  | 370, 102, 64 (HDR)        | heat ≥ 75      | Red-orange alarm — severe heat |

**Why HDR?** Values above 1.0 multiply the sprite's existing luminance beyond white, triggering Godot's bloom post-process and making the NPC visually distinct from palette colors at high heat. Do not clamp these values to [0, 1].

---

## Recon Action VFX

Defined in `scripts/recon_controller.gd`.

**Do not use Unicode emoji for VFX.** OS emoji rendering is full-color and incompatible with the ink-line pixel aesthetic.

| Action      | Glyph | Color token  | Godot `Color`              | Behavior                                              |
|-------------|-------|--------------|----------------------------|-------------------------------------------------------|
| Observe     | `*`   | `PARCH_L`    | `Color(0.894, 0.820, 0.659)` | 5-glyph starburst radiating outward, fade 1.2 s     |
| Eavesdrop   | `!`   | `FLAG_R`     | `Color(0.698, 0.149, 0.149)` | Single exclamation rising above NPC, fade 1.3 s     |

---

## NPC Social Event VFX

Defined in `scripts/npc.gd`.  These are distinct from the Recon Action VFX — they fire on social-graph events, not player input.

**Do not use Unicode emoji for VFX.** OS emoji rendering is full-color and incompatible with the ink-line pixel aesthetic.

| Function                        | Glyph | Color token  | Godot `Color`              | Behavior                                                        |
|---------------------------------|-------|--------------|----------------------------|-----------------------------------------------------------------|
| `show_reputation_change(delta)` | `+N` / `−N` | `MERCH_T` / `FLAG_R` | `Color(0.784,0.635,0.180)` / `Color(0.698,0.149,0.149)` | Floating score delta drifts up 18 px, fades 1.2 s |
| `show_suspicion_raised()`       | `!`   | `STONE_L`    | `Color(0.635, 0.612, 0.545)` | Single blink above NPC, 1.0 s — muted, not alarming        |

**Design rationale:** Reputation change uses gold/red high-contrast labels matching the MERCH_T / FLAG_R palette tokens.  Suspicion uses muted `STONE_L` to avoid visual noise — the heat shimmer VFX (defined above) already handles escalated-danger state.

---

## Props Atlas

File: `assets/textures/tiles_props.png` (896×32)  
Tile size: **64×32** (isometric ground tile, same as terrain layer)  
Generated by `tools/generate_assets.js` → `makePropsAtlas()`.

| Col | `world.gd` const    | Prop                      | Primary colour       |
|-----|---------------------|---------------------------|----------------------|
| 0   | `ATLAS_CRATE`       | Wooden crate              | `WOOD_M`             |
| 1   | `ATLAS_BARREL`      | Barrel                    | `WOOD_M`             |
| 2   | `ATLAS_SIGN`        | Post sign                 | `WOOD_M` / `PARCH_L` |
| 3   | `ATLAS_FENCE`       | Fence                     | `WOOD_M`             |
| 4   | `ATLAS_CART`        | Merchant cart             | `WOOD_M`             |
| 5   | `ATLAS_HAY_BALE`    | Hay bale                  | `THATCH_L`           |
| 6   | `ATLAS_FLOWER_POT`  | Flower pot                | `ROOF_TILE`          |
| 7   | `ATLAS_WELL_BUCKET` | Well bucket               | `WOOD_M`             |
| 8   | `ATLAS_OAK_TREE`    | Oak tree (SPA-526)        | `GRASS_M` / `WOOD_D` |
| 9   | `ATLAS_LANTERN_POST`| Lantern post (SPA-526)    | `STONE_M` / `CANVAS` |
| 10  | `ATLAS_GARDEN_BED`  | Raised garden bed (SPA-526)| `WOOD_D` / `DIRT_D` |
| 11  | `ATLAS_MARKET_STALL` | Market stall (SPA-551)        | `WOOD_M` / `CANVAS`         |
| 12  | `ATLAS_BENCH`        | Wooden bench (SPA-551)        | `WOOD_M`                    |
| 13  | `ATLAS_STONE_WELL`   | Stone well + A-frame (SPA-551)| `STONE_M` / `WOOD_D`        |
| 14  | `ATLAS_CHAPEL_CANDLE`| Ivory pillar candle (SPA-595) | `CHAPEL_STONE` / `FORGE`    |
| 15  | `ATLAS_WOODPILE`     | Stacked log pile (SPA-602)    | `WOOD_M` / `WOOD_D`         |
| 16  | `ATLAS_NOTICE_BOARD` | Post + parchment board (SPA-602) | `WOOD_D` / `PARCH_L`    |
| 17  | `ATLAS_IRON_TORCH`   | Iron bracket torch (SPA-602)  | `STONE_D` / `FORGE`         |

---

## UI Chrome

All modal panels and HUD elements use the **parchment palette**:

- Panel fill: `PARCH_M` at 96% opacity
- Panel border: `PARCH_D`
- Scroll / corner decoration: `INK` at 70% opacity
- Body text: `INK`
- Title text: warm dark brown `#501808` (R80 G24 B8)
- Hint text: `PARCH_D`
- Separator lines: `PARCH_D` at 80%

**Faction badge icons** (`ui_faction_badges.png`, 72×24, three 24×24 shields):

| X offset | Faction  | Symbol |
|----------|----------|--------|
| 0px      | Merchant | Coin   |
| 24px     | Noble    | Crown  |
| 48px     | Clergy   | Cross  |

**Claim type icons** (`ui_claim_icons.png`, 160×32, five 32×32 icons):

| X offset | Claim type    |
|----------|---------------|
| 0px      | Assassination |
| 32px     | Theft         |
| 64px     | Slander       |
| 96px     | Witness       |
| 128px    | Alliance      |

**NPC portraits** (`ui_npc_portraits.png`, 384×400, six 64×80 cols × 5 rows — Art Pass 12 / SPA-591):

30 individual portraits, one per NPC. Lookup: `portrait_id` field in `npcs.json`.
`col = portrait_id % 6`, `row = portrait_id / 6`.

| portrait_id | NPC | Faction | Hat Style | Expression |
|-------------|-----|---------|-----------|------------|
| 0  | Aldric Vane       | Merchant | wide          | smirk   |
| 1  | Sybil Oats        | Merchant | scarf         | neutral (F) |
| 2  | Oswin Tanner      | Merchant | cap           | neutral |
| 3  | Marta Coin        | Merchant | scarf         | neutral (F) |
| 4  | Rufus Bolt        | Merchant | bare          | stern   |
| 5  | Nell Picker       | Merchant | scarf         | smirk (F) |
| 6  | Cob Farrow        | Merchant | pilgrim_hat   | neutral |
| 7  | Idris Kemp        | Merchant | cap           | neutral |
| 8  | Bess Wicker       | Merchant | coif          | stern (F) |
| 9  | Sim Carter        | Merchant | cap           | neutral |
| 10 | Greta Flint       | Merchant | veil          | neutral (F) |
| 11 | Edric Fenn        | Noble    | coronet       | neutral (elder) |
| 12 | Isolde Fenn       | Noble    | veil          | neutral (F) |
| 13 | Calder Fenn       | Noble    | feathered_cap | smirk   |
| 14 | Bram Guard        | Noble    | helm          | stern (captain) |
| 15 | Wynn Gate         | Noble    | helm          | neutral |
| 16 | Pell Gate         | Noble    | helm          | worried |
| 17 | Annit Scribe      | Noble    | coif          | neutral (F scholar) |
| 18 | Tomas Reeve       | Noble    | cap           | stern   |
| 19 | Old Hugh          | Noble    | hood          | neutral (elder) |
| 20 | Aldous Prior      | Clergy   | mitre         | neutral (elder) |
| 21 | Maren Nun         | Clergy   | wimple        | neutral (F) |
| 22 | Finn Monk         | Clergy   | bare          | worried |
| 23 | Vera Midwife      | Clergy   | scarf         | neutral (F) |
| 24 | Old Piety         | Clergy   | wimple        | devout (F elder) |
| 25 | Jude Bellringer   | Clergy   | hood          | neutral |
| 26 | Constance Widow   | Clergy   | veil          | worried (F) |
| 27 | Thomas Pilgrim    | Clergy   | pilgrim_hat   | neutral |
| 28 | Alys Herbwife     | Clergy   | bare          | neutral (F) |
| 29 | Denny Gravedigger | Clergy   | bare          | stern   |

**Rumor state icons** (`ui_state_icons.png`, 144×16, nine 16×16 icons):

| Col | State        | Icon           |
|-----|-------------|----------------|
| 0   | Unaware     | Empty circle   |
| 1   | Evaluating  | Hourglass      |
| 2   | Believe     | Scroll + check |
| 3   | Rejecting   | Bold X         |
| 4   | Spread      | Speech bubble  |
| 5   | Act         | Lightning bolt |
| 6   | Contradicted| Crossed arrows |
| 7   | Expired     | Circle + X     |
| 8   | Defending   | Kite shield    |

---

## Time-of-Day Mood Boards (Art Pass 12 / SPA-591)

These are design targets for post-processing colour modulation applied at runtime. All sprites remain palette-locked; these values are applied as `CanvasLayer` modulate or `WorldEnvironment` adjustments, never baked into textures.

| Time of Day | Name         | Sky Tone        | Ambient Modulate  | Shadow Emphasis | Notes                                          |
|-------------|--------------|-----------------|-------------------|-----------------|------------------------------------------------|
| 0 (00:00)   | Night        | `#0C1428`       | `Color(0.55, 0.60, 0.80)` | deep, long | Existing `tiles_buildings_night.png` reference |
| 1 (04:00)   | Dawn         | `#C88040`       | `Color(1.05, 0.90, 0.75)` | long, warm gold | GRASS_L brightened; STONE_M warmed |
| 2 (08:00)   | Morning      | `#88C0D0`       | `Color(1.00, 1.00, 0.98)` | medium, crisp   | Near-neutral; baseline art-pass reference |
| 3 (12:00)   | Midday       | `#D8EAF0`       | `Color(1.02, 1.02, 1.00)` | short, bleached | STONE_L highlights dominant |
| 4 (16:00)   | Afternoon    | `#E0A060`       | `Color(1.02, 0.95, 0.85)` | medium, amber   | WOOD_M warms; GRASS_D cools |
| 5 (20:00)   | Evening      | `#602818`       | `Color(0.80, 0.65, 0.55)` | long, deep red  | FORGE glow visible; lanterns lit |

**Design rules:**
- Never saturate past `Color(1.1, 1.1, 1.1)` — palette desaturation is a core aesthetic.
- Night uses `tiles_buildings_night.png` (pre-darkened), daytime uses `tiles_buildings.png`.
- VFX (`HEAT_WARN`, `HEAT_ALARM`) are unaffected by modulate; they fire on top.

---

## Building Interior Panels

Scenes: `TavernInterior.tscn`, `ManorInterior.tscn`, `ChapelInterior.tscn`  
Script: `scripts/building_interior.gd` (shared)  
Layer: 14 (above world, below debug)  
Trigger: `E` key or × button to close.

To open from code:
```gdscript
$TavernInterior.show_interior()
```

---

## Asset Generation

All PNG assets are generated by `tools/generate_assets.js` (Node.js, no dependencies).

```bash
# From project root (rumor_mill/):
node tools/generate_assets.js
```

Re-run after any palette or shape changes, then reimport in the Godot editor.

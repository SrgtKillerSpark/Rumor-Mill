# Rumor Mill — Art Style Guide (Sprint 5 / SPA-41)

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

**Ground atlas** (`tiles_ground.png`, 192×32):

| Col | Const            | Description                  |
|-----|------------------|------------------------------|
| 0   | `ATLAS_VOID`     | Transparent / empty          |
| 1   | `ATLAS_GRASS`    | Standard grass               |
| 2   | `ATLAS_GRASS_DARK` | Shadow grass (under buildings) |

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

File: `assets/textures/npc_sprites.png` (224×144)  
Frame size: **32×48px**  
Sheet layout: 7 columns × 3 faction rows

| Row | Faction  | Body colour     | Trim colour    |
|-----|----------|-----------------|----------------|
| 0   | Merchant | `MERCH_BODY`    | `MERCH_TRIM`   |
| 1   | Noble    | `NOBLE_BODY`    | `NOBLE_TRIM`   |
| 2   | Clergy   | `CLERGY_BODY`   | `CLERGY_TRIM`  |

| Cols | Animation | Speed  | Loop |
|------|-----------|--------|------|
| 0–2  | `idle`    | 4 fps  | yes  |
| 3–6  | `walk`    | 8 fps  | yes  |

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

**Claim type icons** (`ui_claim_icons.png`, 80×16, five 16×16 icons):

| X offset | Claim type    |
|----------|---------------|
| 0px      | Assassination |
| 16px     | Theft         |
| 32px     | Slander       |
| 48px     | Witness       |
| 64px     | Alliance      |

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

# Phase 2 Sprite Upgrade — Shortlist

**Prepared:** 2026-05-08  
**Author:** Creative Director (SPA-2096)  
**Parent task:** SPA-2090 (CEO task assignment)  
**Feeds into:** SPA-871 art quality upgrade (in_review)

Engineering: once art delivers revised assets, swap the sprite row / building tile at the paths listed per item. No code changes are required beyond regenerating via `tools/generate_assets.js` with the direction notes below.

---

## Methodology

Ranking formula: **on-screen frequency × visual issues score** (silhouette clarity, palette distinctiveness vs. neighbors, scale legibility at game zoom).

- **On-screen frequency** assessed from: archetype headcount (how many NPCs share a row), NPC sociability + tick-override routing, and scenario appearance (all 4 scenarios surveyed).
- **Visual issues** assessed against locked palette, ART_STYLE_GUIDE Art Pass 19 baseline, and 48×72 NPC / 64×64 building game zoom.

---

## Top 5 NPC Sprites

### 1. Guard archetype — Row 3 (Bram Guard, Wynn Gate, Pell Gate, Tomas Reeve)

**Effort: M**

**What's wrong now:** Four NPCs (Guard Captain, two Town Guards, Tax Collector) share Row 3 — nasal helmet, `STONE_M` body, `STONE_D` trim. At game zoom on stone-cobble paths (`ATLAS_STONE_COBBLE`, `STONE_M` base) these sprites all but disappear; the grey-on-grey contrast is the lowest in the roster. Bram Guard is Guard Captain but carries zero visual rank marker — he is pixel-identical to Wynn Gate from the top-down isometric view.

**What to change:** Deepen the helmet contrast — add a steel-blue glint stripe (`STONE_L` highlight across the brow, `STONE_D` underline) so the nasal helm silhouette pops above stone ground. Differentiate Bram Guard via a `FLAG_R` captain's plume on the helmet (2px arc, cols 0–2 idle only — parallels the Merchant feather quill). Apply `clothing_var` to give Tomas Reeve a tax-collector tabard (PARCH_M over-tunic) rather than re-using the standard guard palette.

**Reference style:** Dwarf Fortress guard sprite helmet glint; medieval illuminated manuscript armored figure with heraldic flourish on captain.

---

### 2. Clergy archetype — Row 2 (Aldous Prior, Maren Nun, Finn Monk, Old Piety, Jude Bellringer, Constance Widow, Denny Gravedigger)

**Effort: M**

**What's wrong now:** Seven NPCs share Row 2. The `CLERGY_BODY` cream (#E4DECC) is tonally identical to `PLASTER` (#DECAA2) wall panels and the new `PARCH_L` ground shadow halo (Art Pass 19). On a tavern or mill exterior — which are PLASTER — Clergy NPCs visually dissolve into the building face behind them. Additionally, Denny Gravedigger should read as grim/earthy but he wears the same cream cassock as the Head Priest, which is narratively wrong and visually confusing.

**What to change:** Darken the Clergy body fill by one palette step to `PLASTER` (#DECAA2 → use as the new mid value) with `STONE_M` shadow zones — this gives the cassock a warm-stone tone that contrasts better against both grass and plaster walls without breaking the cream/devotional read. For `clothing_var 3` (Denny Gravedigger), override to a `DIRT_D` smock over `STONE_D` cloak — ash and earth tones — making him visually distinct while remaining palette-compliant.

**Reference style:** Pentiment monk figures — slightly warmer ivory than white, with ink-line folds; gravedigger reads like a labourer with a hood (not a priest).

---

### 3. Tavern Staff archetype — Row 5 (Sybil Oats, Nell Picker)

**Effort: S**

**What's wrong now:** Sybil and Nell are the two highest-sociability NPCs in the roster (both 0.9) and are permanently stationed at the tavern — the social hub every player visits every session. Yet their Row 5 sprite (`WOOD_M` body, `PLASTER` trim, parchment kerchief) has no strong faction color and the head-kerchief silhouette is nearly identical to the Commoner cloth cap at 48×72px. These are the most-clicked NPCs in the game and their visual weight doesn't reflect that importance.

**What to change:** Add a `CANVAS` (#C8963A gold-amber) apron band across the waist (4px horizontal stripe at 2/3 body height) — this introduces a warm, distinct pop color that reads clearly against WOOD_M tunic and anchors them as tavern workers rather than generic commoners. Widen the kerchief brim by 2px (currently 8px, increase to 10px upscaled) to produce a more readable horizontal silhouette line. These are S-effort changes regeneratable through `makeNPCSpriteSheet()` with adjusted pixel draws.

**Reference style:** Medieval tavern staff illustrations — linen apron with prominent tie, head-wrap slightly wider than peasant cap.

---

### 4. Noble archetype, Alderman variant — Row 1 (Edric Fenn, Calder Fenn)

**Effort: S**

**What's wrong now:** Edric Fenn is the primary target of Scenario 1 and the political anchor of all 4 scenarios. He uses Row 1 (Noble: `NOBLE_BODY` burgundy, `NOBLE_TRIM` silver, 3-spike coronet) — identical to Calder Fenn, his 19-year-old son. There is zero visual authority differential between them. Art Pass 16 added coronet gem catch-lights but didn't add a rank marker distinguishing Alderman (senior civic authority) from household noble (younger, reactive).

**What to change:** For `clothing_var 0` (Edric's variant), add a mayoral chain — a 3-link horizontal strand of `MERCH_TRIM` gold (#C8A22E) across the chest at 1/3 height. This is period-accurate (aldermen wore chains of office) and palette-compliant. Calder uses `clothing_var 0` as well — so reassign Calder to `clothing_var 1` (or introduce a new `clothing_var 0` reserved for civic-rank Nobles only). This is a single-row change in `generate_assets.js` clothing passes.

**Reference style:** Illuminated chronicle aldermanic figures — chain of office clearly readable at thumbnail size.

---

### 5. Independent archetype NPCs — specifically Vera Midwife and Alys Herbwife

**Effort: M**

**What's wrong now:** "Independent" is a data archetype but has no dedicated sprite row. Vera Midwife (Scenario 4 defended character) and Alys Herbwife (Scenario 2 target) both currently render via a fallback — likely Commoner Row 4 (`DIRT_M` body, `DIRT_D` trim, soft cloth cap). This is the most visually anonymous row in the sheet. Vera is a folk healer and Alys is a herbalist: both are key interactable scenario characters who need immediate visual readability as "someone unusual / someone with a function."

**What to change:** Introduce a proper Independent row (Row 9, or repurpose `clothing_var` slots within an existing row) with two sub-variants: (a) healer/herbalist — `GRASS_M` apron over `PLASTER` underdress, herb pouch prop at hip (2×3px bundle at waist-right), loose headscarf; (b) traveller/pilgrim — `DIRT_M` cloak, walking staff (like Elder but narrower hood, younger posture). This directly maps Vera/Alys to variant (a) and Thomas Pilgrim/Cob Farrow to variant (b). Alternatively, add these as `clothing_var 2` overrides in an extended Commoner row if a full new row is too large for this pass.

**Reference style:** Pentiment townswoman with healer props; herb bundles must read as distinct from the Scholar's scroll at game zoom.

---

## Top 3 Building Tiles

### 1. Chapel — `ATLAS_CHAPEL` col 2

**Effort: M**

**What's wrong now:** `CHAPEL_STONE` (#CECAC4) and `MANOR_STONE` (#C6BAA2) are 8 points apart in all three channels — effectively indistinguishable at game zoom. The Chapel's stained glass detail, which is the primary visual differentiator, is too fine to read at 64×64px (a 3×4px rectangle in the current spec). Players regularly mistake the Chapel for a stone manor annex. The Chapel is a key building in Scenarios 2 and 4.

**What to change:** Shift the Chapel wall fill from `CHAPEL_STONE` to `CHAPEL_STONE` + a visible rose window circle centered on the front face — 12px diameter, `WATER_L` + `WATER_D` petals (blue stained glass read). The spire peak should use `ROOF_SLATE` (#4C4C5A) rather than matching the wall stone — this creates an immediate dark-light contrast silhouette break at the top that reads at any zoom. Add a pale cross finial in `STONE_L` at the spire apex (3px vertical, 2px crossbar).

**Reference style:** Dwarf Fortress chapel tileset — roof contrast against body; Pentiment illuminated town vignettes — colored window light even at small scale.

---

### 2. Guardpost — `ATLAS_GUARDPOST` col 8

**Effort: S**

**What's wrong now:** The Guardpost uses the same `STONE_M`/`STONE_D` palette as the Guard sprites and the stone ground tiles. It's the only building that completely matches its associated NPC row in color — making guard patrols literally invisible against their home building. The torch accent should differentiate it but the current `FORGE` halo is small (same radius as pre-Art-Pass-19 blacksmith forge, not updated). The crenellation battlements that define a guardpost silhouette may not be tall enough to register.

**What to change:** Raise the crenellation teeth height by 4px (two full battlements instead of one row) to create a clear defensive-military silhouette break at the roofline. Increase the torch glow halo radius to match the Art Pass 19 blacksmith standard (r²≤16, alpha ceiling 70) — this is an S-effort copy of the already-merged blacksmith logic. Add a `FLAG_R` pendant hanging beneath the torch bracket: a 2×4px red flag that signals Noble-faction authority and makes the building readable as a law-enforcement presence from map overview.

**Reference style:** Medieval watchtower in illuminated chronicles — battlements taller than the wall height, torch bracket prominent.

---

### 3. Town Hall — `ATLAS_TOWN_HALL` col 9

**Effort: M**

**What's wrong now:** The Town Hall is the seat of civic power (Alderman Edric Fenn's domain, Town Hall appears in tick overrides for Aldous Prior on day 1), yet it currently reads as a slightly larger Manor variant. Art Pass 19 added dual flags to the Manor but did not add a reciprocal upgrade to Town Hall — the political center of the map now has less visual presence than a noble residence. The "ornate columns" are a design note but at 64×64px a column is 2–3px wide and nearly invisible.

**What to change:** Add bilateral `FLAG_R` pennants mirroring the Manor upgrade (Art Pass 19 dual-flag logic, same pixel placement pattern but on Town Hall left/right faces). Extend the central entry arch to a full-width portico shadow: a `STONE_D` trapezoid base step (8px wide, 4px tall, centered) that gives the building a civic plinth read. Add a `CANVAS`-colored horizontal banner across the facade at mid-height (faction-neutral gold, 4px stripe) to signal that this is an administrative/trade-regulation hub, distinct from the purely Noble Manor.

**Reference style:** Illuminated manuscript town-hall depictions — prominent central banner, stepped entrance, bilateral standards.

---

## Summary Table

| Asset | Type | Effort | On-Screen | Primary Issue | File to Regenerate |
|---|---|---|---|---|---|
| Guard row (Bram/Wynn/Pell/Tomas) | NPC row 3 | M | Very high | Grey-on-grey camouflage; no rank signal | `npc_sprites.png` |
| Clergy row (7 NPCs) | NPC row 2 | M | High | Cream dissolves into PLASTER walls; no body-role variation | `npc_sprites.png` |
| Tavern Staff (Sybil/Nell) | NPC row 5 | S | Very high | No faction color anchor; cap unreadable vs Commoner | `npc_sprites.png` |
| Noble/Alderman variant (Edric) | NPC row 1 var | S | High | No rank marker vs Calder; authority unreadable | `npc_sprites.png` |
| Independent NPCs (Vera/Alys) | NPC new row/var | M | Medium-high | Scenario leads look like background Commoners | `npc_sprites.png` |
| Chapel | Building col 2 | M | High | CHAPEL_STONE ≈ MANOR_STONE; window unreadable | `tiles_buildings.png` |
| Guardpost | Building col 8 | S | High | No silhouette contrast; torch halo pre-AP19 | `tiles_buildings.png` |
| Town Hall | Building col 9 | M | Medium | No civic grandeur; Manor now outranks it visually | `tiles_buildings.png` |

**Legend:** S = < 1 day art effort (palette/pixel tweak), M = 1–3 days (new detail pass or new variant row)

---

## Implementation Notes for Engineering

- All NPC rows regenerate from `tools/generate_assets.js` → `makeNPCSpriteSheet()`. Direction changes feed as pixel-draw deltas in that function.
- Building tiles regenerate from `makeBuildings()` in the same file.
- No scene or `.tscn` changes needed — sprite rows are looked up by archetype/body_type at runtime in `npc.gd`.
- The Independent row addition may require adding a new `archetype` → row mapping in `npc.gd:get_sprite_row()` if a Row 9 is introduced. If using `clothing_var` overrides instead, no code change is needed.
- Regeneration order: NPC sprites first (validate in-game), buildings second (independent of NPC pass).
- Night variants (`tiles_buildings_night.png`) need to be regenerated in parallel with any building tile changes.

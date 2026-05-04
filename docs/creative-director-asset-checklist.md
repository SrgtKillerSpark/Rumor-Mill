# Rumor Mill — Creative Director Asset Checklist

*Consolidated pre-launch capture list for store pages and social media.*
*Cross-reference: `docs/steam-store-page-final.md` §3, `marketing_brief.md` §3, `docs/social-media-launch-plan.md` Visual Asset List.*

**Status: Required before Steam EA publish (launch day: April 25).**

---

## Priority 1 — REQUIRED for Launch Day

These are blocking. Store pages and Day 0 social posts cannot go live without them.

| # | Asset | Format | Capture Instructions | Used In |
|---|---|---|---|---|
| A | Social Graph in motion | GIF, 5–8 sec, <5MB, 15fps | Scenario 1, Day 12–15, merchant faction fracturing. 8+ NPCs in varied states. Press G, let overlay animate. No UI labels in frame. | Steam hero capsule, itch.io header, Day −2 tweet, Day 0 Thread |
| B | Rumor mid-transmission | Screenshot or 3-sec GIF | Market, midday, high NPC density. Capture the exact moment an orange SPREAD NPC passes story to new node — speech bubble icon + ripple VFX both visible. | Day 0 Tweet 3, Day +3 propagation thread |
| C | Rumor Crafting Panel | Screenshot | Panel 2 or 3 open. SCANDAL or ACCUSATION selected, evidence attached, spread estimate visible. Clean composition — subject in frame, two NPCs in background. | Steam store key art, itch.io screenshot #3, mid-week mechanic explainer |
| D | Scenario select screen | Screenshot | All four scenarios visible, clean state, no in-progress save data showing. | Day +5 scenarios thread, any copy listing all scenarios |

---

## Priority 2 — Required within First Week Post-Launch

Good to have before launch; essential for Day +2 through Day +5 social posts.

| # | Asset | Format | Capture Instructions | Used In | Capture Status | Coverage as of 2026-05-03 |
|---|---|---|---|---|---|---|
| E | ACT state NPC | Screenshot | Magenta-tinted NPC with pulsing lightning icon, mid-movement, away from rumor subject. One or two surrounding NPCs visible for scale. | Evergreen reply-to-curiosity visual | PENDING — see capture guide below | **PARTIAL** — `rumor_mill/assets/textures/npc_sprites.png` contains NPC sprites (all states incl. ACT magenta tint); `ui_state_icons.png` has lightning/ACT icon. Source art present; no composed in-engine shot. Not shippable as-is. |
| F | Inquisitor pressure (S4) | Screenshot | Two protected NPCs, reputation ~42–45 (near fail floor). Inquisitor's HERESY rumor mid-propagation on Social Graph Overlay. Pressure HUD element visible. | S4 feature post, "stakes" hook content | PENDING — see capture guide below | **MISSING** — No partial art. Requires live in-engine capture of S4 mid-game HUD state. |
| G | Post-scenario analytics screen | Screenshot | End-state of S1 or S3. Spread timeline + mutation log both visible. Win-state preferred. | r/gamedev audience posts, replayability angle | PENDING — see capture guide below | **MISSING** — End-screen composed entirely in-engine. No static art equivalent. Requires completed scenario run. |
| H | DEFENDING cascade | Screenshot | 1–2 sky-blue DEFENDING NPCs near Edric Fenn, orange SPREAD cluster visible in same frame. Visual contrast is the point. | Counter-intelligence mechanic posts | PENDING — see capture guide below | **PARTIAL** — `npc_sprites.png` contains sky-blue DEFENDING NPC sprites; `ui_state_icons.png` includes DEFENDING icon. Source art present; no composed in-engine shot. Not shippable as-is. |
| I | Night at the Noble Estate | Screenshot | Incriminating Artifact acquisition window (post-6 PM). Estate lit, NPC silhouetted at entrance. Strong atmosphere. | Press kit, atmospheric social post | PENDING — see capture guide below | **PARTIAL (strongest)** — `rumor_mill/assets/textures/tiles_buildings_night.png` is the exact night tileset for this scene; `npc_sprites.png` has silhouette-capable NPC art. Night art pass complete as source assets. Still requires live capture for acquisition confirmation window and composed estate framing. |
| J | Scenario 3 dual-track split-screen | Screenshot | Calder's reputation tracker climbing while Tomas's falls, rival agent's rumor trail visible on overlay. | S3 feature post, AI rival angle | PENDING — see capture guide below | **MISSING** — ObjectiveHUD dual-tracker state is purely in-engine runtime. No static art equivalent. Requires live S3 mid-game capture. |

### Coverage Notes (2026-05-03)

**`marketing/screenshots/`** — No captured screenshots. Contains only `README.md` and `capture-manifest-2026-04-30.md` (the shot list for [SPA-1415](/SPA/issues/SPA-1415)).

**Store capsule art** — `rumor_mill/assets/store/` contains all 8 Steam/itch.io SVG capsule files (complete, ready for store page use — separate from screenshot slots):
- `steam-header-capsule-460x215.svg`, `steam-main-capsule-616x353.svg`, `steam-library-capsule-vertical-600x900.svg`, `steam-library-hero-3840x1240.svg`, `steam-small-capsule-231x87.svg`
- `itchio-cover-630x500.svg`, `itchio-page-header-1500x300.svg`
- `icon-512.svg`

**In-engine texture art** — `rumor_mill/assets/textures/` contains source sprite sheets (npc_sprites, tiles, ui icons) — raw source art for compositing, not marketing screenshots.

**What Marketing Lead can ship now:** The store SVG capsule art is ready. None of E–J are shippable as standalone marketing images from existing assets — all require an interactive game session capture once the screenshot blocker ([SPA-1415](/SPA/issues/SPA-1415) / [SPA-1300](/SPA/issues/SPA-1300)) clears.

### Priority 2 Capture Guide

All in-game states for E–J are confirmed implemented. Captures require an interactive game session with a display. Use `builds/RumorMill.exe` (post-SPA-410 art pass build).

**Asset E — ACT state NPC**
Start any scenario with active rumor spread. Wait until an NPC has processed a rumor for 3+ turns — ACT state triggers automatically (NPC turns magenta with pulsing lightning icon). Catch it mid-movement heading away from the originating NPC cluster. Use Social Graph Overlay off so the NPC sprite is unobscured. Target 2–3 NPCs in frame for scale.
Save as: `marketing/screenshots/asset-e-act-state-npc-YYYY-MM-DD.png`

**Asset F — Inquisitor pressure (S4)**
Load Scenario 4. Play until Day 7–10 with protected NPCs' reputation around 42–45 (visible in ReconHUD). Open Social Graph Overlay (press G). Wait for HERESY rumor propagation step — the orange spread icon should be mid-flight on the overlay. Confirm Pressure HUD element is visible in frame.
Save as: `marketing/screenshots/asset-f-inquisitor-pressure-s4-YYYY-MM-DD.png`

**Asset G — Post-scenario analytics screen**
Complete Scenario 1 or Scenario 3 with a win-state. On the end screen, navigate to the Replay tab (EndScreenReplayTab). Ensure both the Spread Timeline and Mutation Log panels are visible simultaneously. Capture the full end-screen layout.
Save as: `marketing/screenshots/asset-g-post-scenario-analytics-YYYY-MM-DD.png`

**Asset H — DEFENDING cascade**
Play Scenario 1, targeting Edric Fenn. When a counter-rumor is seeded near him, 1–2 sky-blue DEFENDING NPCs will appear around his location. Position camera so both the sky-blue DEFENDING cluster and an orange SPREAD cluster are visible in the same frame. SPREAD cluster should be 3–5 tiles away to make the colour contrast readable.
Save as: `marketing/screenshots/asset-h-defending-cascade-YYYY-MM-DD.png`

**Asset I — Night at the Noble Estate**
Play Scenario 1 or 2 to in-game time post-18:00. Navigate to the Noble Estate (Manor Interior — accessible from the world map). Trigger the Incriminating Artifact acquisition (recon action available when at estate after 18:00, per `recon_controller.gd:603`). Capture the acquisition confirmation window while the estate night lighting and silhouette NPC at entrance are visible in the background.
Save as: `marketing/screenshots/asset-i-noble-estate-night-YYYY-MM-DD.png`

**Asset J — Scenario 3 dual-track split-screen**
Play Scenario 3 to mid-game (Day 8–12). Open Social Graph Overlay. Frame so both Calder Fenn's reputation tracker (climbing) and Tomas Reeve's tracker (falling) are in the same shot. The rival agent's rumor trail should be visible as a thread on the overlay in the background.
Save as: `marketing/screenshots/asset-j-s3-dual-track-YYYY-MM-DD.png`

---

## Trailer / Video (Post-Launch, Phase 1)

No video required for EA launch — screenshots and GIFs are sufficient. Plan one 60–90 sec gameplay trailer for the Phase 2 build when S5/S6 are balanced and added.

**Suggested trailer beat order:**
1. Cold open — town wide shot, no UI (5 sec)
2. Social graph overlay activates — amber threads spreading (8 sec)
3. Rumor crafting panel sequence (5 sec)
4. SPREAD NPC passing story — ripple VFX (5 sec)
5. ACT state onset — magenta NPC moving (3 sec)
6. DEFENDING cascade — blue shields orange (4 sec)
7. Scenario fail screen → restart (2 sec)
8. Title card + Steam link (5 sec)

---

## Technical Capture Notes

- **Minimum resolution:** 1920×1080
- **GIF file size:** under 5MB for Twitter/X feed compatibility
- **GIF frame rate:** 15fps (smoother playback in social feeds than 30fps at equivalent size)
- **Teaser GIFs (Asset A):** no UI chrome in frame
- **Mechanic-explainer GIFs (Assets B, E):** UI elements are fine — they're the point
- **Build:** All captures must be from the post-SPA-410 art pass build. Do not use pre-art-pass screenshots.

---

## itch.io Page — Screenshot Slots

itch.io supports 6 screenshots + embedded GIF header. Priority mapping:

| Slot | Asset | Priority |
|---|---|---|
| Hero GIF (page header) | Asset A (social graph in motion) | **Must have at launch** |
| Screenshot 1 | Asset C (Rumor Crafting Panel) | Must have |
| Screenshot 2 | Asset B (rumor mid-transmission) | Must have |
| Screenshot 3 | Asset D (Scenario select screen) | Must have |
| Screenshot 4 | Asset E (ACT state NPC) | First week |
| Screenshot 5 | Asset H (DEFENDING cascade) | First week |
| Screenshot 6 | Asset G (post-scenario analytics) | First week |

---

## Steam Store — Capsule Art

Capsule art is separate from screenshots and requires graphic design work. Specs in `docs/store-art-specs.md`.

**Assets needed for capsule production:**
- [ ] Hero image with logo lockup (616×353px for small capsule, 460×215px for main capsule)
- [ ] Header capsule (3840×1240px for store page header)
- [ ] Library capsule (600×900px)
- [ ] Community icon (32×32px)

*Capsule art is typically designed from screenshots A or B as the background element.*

---

## What Is NOT Needed Before Launch

- Trailer video (schedule for Phase 1 post-launch)
- Press kit video (press kit at `docs/press-kit.md` uses screenshots only)
- Platform-specific promotional art beyond the above (can add in Phase 1)
- Mac/Linux screenshots (platform not confirmed for EA)

---

## Phase 2 HUD — Evidence Economy Iconography

*Added: 2026-05-03 — [SPA-1572](/SPA/issues/SPA-1572)*

Phase 2 introduces three spendable evidence items — Forged Document, Incriminating Artifact, and Witness Account — that will appear in the Rumor Crafting Panel and potentially as inventory indicators in scenario HUDs. This section specifies icon assets required before Phase 2 HUD implementation begins.

### Guiding Visual Language

All evidence icons must conform to the existing Pentiment × illuminated-manuscript pixel art style:
- **Grid:** 16×16px per icon, housed in a new sprite sheet `ui_evidence_icons.png` under `rumor_mill/assets/textures/`.
- **Palette:** Pull from the existing four-tone parchment palette already used in `ui_parchment.png` and `ui_claim_icons.png` — warm off-white (#E8D8B0), ink brown (#2A1A0A), faded ochre (#A07840), aged terracotta (#7A3820). No new hues introduced.
- **Line weight:** 1px outline only, consistent with `ui_state_icons.png` and `ui_claim_icons.png`.
- **No Unicode emoji.** All HUD icon slots must use `TextureRect` nodes pointing into sprite sheets, not emoji characters in `Label.text`. The `🛡` emoji currently in `scenario2_hud.gd` (SPA-1565) is a known tech-debt item and must be replaced in a future pass.

### Icon Specs

| # | Evidence Type | Icon Motif | Priority | Notes |
|---|---|---|---|---|
| EV-1 | **Forged Document** | Rolled parchment scroll with a broken wax seal mark at its base. Scroll should suggest "official" — tight roll, cord visible. 16×16px. | High — needed before evidence selection UI in Rumor Panel | Distinguish from `ui_claim_icons.png` claim glyphs: claims are flat pages; forged document is a 3D-perspective rolled scroll. |
| EV-2 | **Incriminating Artifact** | Small object silhouette — a jeweled brooch or signet ring (fits the noble-court setting). Object faces 3/4 perspective, heavy drop shadow to read as physical. 16×16px. | High — needed before evidence selection UI | Must read clearly at HUD icon size; avoid fine details that disappear at 16px. Test at 32px first then scale down. |
| EV-3 | **Witness Account** | Hooded figure silhouette (3/4 facing left) with a single speech-bubble tail pointing down-right. Silhouette-only treatment — no face detail. 16×16px. | High — needed before evidence selection UI | The speech bubble must be visually subordinate to the figure — not a chat icon, but a "testimony" icon. |
| EV-4 | **Evidence slot (empty)** | Greyed-out 16×16px placeholder matching EV-1 form factor. Used in the Rumor Panel when no evidence is selected or available. | Medium | Reuses the parchment scroll silhouette from EV-1, desaturated to ~30% opacity. |
| EV-5 | **DEFENDING state shield** (HUD strip) | Small shield with a halved design: left half plain, right half with a stylized cross mark. Replaces the `🛡` emoji in `scenario2_hud.gd`. Add to `ui_state_icons.png` as the next available row slot. 16×16px. | Medium — quality pass on SPA-1565 output | Must pair visually with existing SPREAD (orange) and ACT (lightning) icons in `ui_state_icons.png`. Use the same amber/ochre accent color as the existing icon row. |

### Delivery Notes

- All five icons land in a single Aseprite source file: `rumor_mill/assets/source/ui_evidence_icons.aseprite`
- Export as `rumor_mill/assets/textures/ui_evidence_icons.png`, 80×16px (5 icons × 16px wide)
- EV-5 (DEFENDING shield) exports separately to the existing `ui_state_icons.png` sprite sheet — coordinate exact row/column with the engineer implementing the `TextureRect` swap in `scenario2_hud.gd`
- No animation required at this stage; idle static only

### Acceptance Criteria

1. All five icons read legibly at native 16×16px and at 2× zoom.
2. No new palette colors introduced — match existing `ui_parchment.png` tones.
3. EV-1 through EV-3 are visually distinct from each other at a glance and from existing claim icons in `ui_claim_icons.png`.
4. EV-5 pairs harmoniously with adjacent state icons in `ui_state_icons.png`.

---

*Document version: 1.2 — 2026-05-03 (Phase 2 HUD iconography section added, SPA-1572)*
*Task: [SPA-973](/SPA/issues/SPA-973)*
*Cross-reference: `docs/steam-store-page-final.md`, `docs/itchio-game-page.md`, `marketing_brief.md` §3, `docs/social-media-launch-plan.md` Visual Asset List, `docs/store-art-specs.md`*

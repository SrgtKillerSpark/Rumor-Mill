# Rumor Mill — Store Art Specs & Art Direction Briefs

> **Purpose:** Exact pixel specs and detailed composition briefs for every icon and banner asset required to publish on itch.io and Steam. All art direction is derived from the visual identity established in `docs/visual-identity.md` (SPA-172). These briefs are production-ready for an artist or AI image generation workflow.

*Created: 2026-04-04 — SPA-189*

---

## Color Reference (from Visual Identity)

| Token | Hex | Use |
|---|---|---|
| Ink Black | `#0D0A06` | Primary background |
| Night Slate | `#1C1812` | Secondary background, panels |
| Aged Parchment | `#F2E8CE` | Primary text, light elements |
| Worn Vellum | `#D4C49A` | Secondary text |
| Stone Gray | `#4A4035` | Borders, inactive |
| Rumor Gold / Gold Scandal | `#C8A96E` | Accent, logo quill, icon emblem |
| Amber Flame | `#E8821A` | Warmth, lantern light |
| Burgundy Wax | `#6B1A1A` | Wax seal (icon outer ring) |
| Burnt Amber Sky | `#3D1C02` | Horizon gradient |
| Near-Black Indigo | `#0A0718` | Sky overhead |

---

## 1. Shared Game Icon — 512×512 px

> **Used by:** itch.io (game page icon), Steam (app icon, game library icon), Windows desktop shortcut.

### Spec

| Field | Value |
|---|---|
| Canvas size | 512 × 512 px |
| Format | PNG-32 (transparent background acceptable; opaque also fine) |
| Safe area | Keep key detail within inner 460×460 (26px margin all sides) |

### Composition: The Whispering Mill Seal

This is a circular wax-seal design on a near-black field. See `docs/visual-identity.md §4` for the full concept. Key elements:

**Background:**
- Solid near-black (`#0D0A06`) filling the full 512×512 canvas.
- A faint parchment texture (`#F2E8CE` at 10% opacity) radiates inward from all four corners, softening the background without distracting from the seal.

**Outer ring (wax border):**
- A circular ring of aged burgundy-red wax (`#6B1A1A`), outer diameter ≈ 480px, inner diameter ≈ 380px — ring width ≈ 50px.
- Surface texture: uneven, slightly cracked wax — not smooth. Imperfections give it a handmade, aged quality.
- Around the inner edge of the ring, embossed in the wax: alternating quill icons and speech-bubble-tail icons, 8 of each (16 total), evenly spaced. These are small — roughly 16px wide at 512px scale. Render them slightly lighter than the wax (`#8A3030`) to read as embossed rather than inlaid.

**Center emblem (mill wheel):**
- Centered in the seal, diameter ≈ 300px.
- A stylized 8-spoke wheel. Each spoke is a slightly curved scythe-blade shape — not a plain bar.
- Color: aged gold (`#C8A96E`). Apply subtle drop shadow inward (not outward — the seal face has depth).
- Hub of the wheel: a small open eye icon, also in gold. Diameter ≈ 48px. The pupil is a vertical slit (not a round pupil) — slightly unsettling, implying surveillance.
- Between the spokes, a very faint radial texture (like pressed paper fibres) fills the center circle. Color: `#1A1208` at 60% — dark but not flat black.

**Typography:**
- At the bottom arc of the seal (inside the outer wax ring): **RUMOR MILL** in small-caps serif (blackletter-adjacent), reading along the curve.
- Color: same embossed treatment as the outer motifs — `#8A3030` slightly lighter than the wax base.
- Character height ≈ 18px at 512px canvas scale.

**Readability ladder (required for Steam/itch.io submission):**
- 256×256: Drop the quill/bubble embossing from the outer ring. Keep the mill wheel, eye hub, wax border, and RUMOR MILL text.
- 128×128: Drop the text. Render as mill wheel (gold spokes + eye) centered on dark background within a simplified wax circle.
- 64×64 and below: Mill wheel silhouette in gold on `#0D0A06` only. No ring details.

**Tone check:** Should read as *official, secretive, slightly ominous*. Not cartoonish. Matches Crusader Kings III heraldry more than Stardew Valley.

---

## 2. itch.io Store Assets

### 2a. Cover Image (Game Thumbnail) — 630×500 px

> Displayed as the primary game thumbnail on itch.io browse, search results, collections, and game jams. This is the most-seen asset on the platform.

| Field | Value |
|---|---|
| Canvas size | 630 × 500 px |
| Minimum legible size | 315 × 250 px (itch.io scales down for grid views) |
| Format | PNG or JPG (PNG preferred for crisp text) |
| Safe area | Key text/logo within 570×440 inner zone (30px margin all sides) |

**Composition: The Whisper at Dusk — Wide Crop**

This adapts the title screen scene (visual identity §2) into a horizontal thumbnail format.

*Sky and atmosphere:*
- Upper 40% of canvas: sky gradient from near-black indigo (`#0A0718`) at the top, transitioning to burnt amber (`#3D1C02`) at the horizon line (approximately y=200px).
- Light fog at ground level: soft white at 10% opacity, drifting inward from both sides.

*Town silhouette:*
- Lower 60%: the town square scene in a slightly abstracted isometric view — not a full render, but evocative silhouettes.
- The watermill is the strongest mid-ground shape: its wheel partially visible, one blade catching a warm amber glow from the lantern below.
- Tavern facade on the left: shuttered windows with warm candlelight bleeding through.

*Foreground figures (essential):*
- Two cloaked figures in the lower-center of frame, heads inclined together in conversation. This is the visual hook.
- Figures are dark charcoal silhouettes with only a sliver of lantern light (`#FF7A1A` at 40%) catching their cloaks.
- A single lantern post between them. The lantern's warm circle of light is the brightest spot on the canvas — drawing the eye.

*Logo placement:*
- **RUMOR MILL** wordmark (primary parchment variant from visual identity §1) positioned in the upper-center of the canvas.
- Scale: "RUMOR MILL" stacked text block approximately 220px wide.
- Ensure the parchment plate (`#F2E8CE`) of the logo contrasts against the dark sky behind it.

*Tagline:*
- Below the logo, in the same blackletter serif, smaller — the line: **"No swords. Just whispers."**
- Color: Worn Vellum (`#D4C49A`), approximately 16px at full size.

**Mood reference:** The thumbnail should instantly communicate *medieval intrigue, darkness, and social strategy* — no combat imagery. The two whispering figures do the work.

---

### 2b. itch.io Game Page Header Banner — 1500×300 px *(optional but recommended)*

> Displayed at the very top of the game's itch.io page on wider screens. Purely atmospheric; no required text (the page title sits above it in itch.io's own UI).

| Field | Value |
|---|---|
| Canvas size | 1500 × 300 px |
| Format | PNG or JPG |
| Safe area | Treat as a cinematic letterbox — center 900px is always visible; left/right 300px may be cropped on narrow viewports |

**Composition: The Town at Night — Panoramic Strip**

- A wide panoramic silhouette of the medieval town skyline against the dusk-to-night sky gradient.
- Leftmost: rolling hills dissolving into dark sky. City wall silhouette with a single lit watchtower.
- Center: the market square rooftops, the watermill wheel visible above the other structures.
- Rightmost: more rooftops, a church tower, fading into atmospheric haze.
- The entire image is treated as a silhouette — dark shapes against the amber-to-indigo sky. No detailed rendering required; this works as pure shape language.
- The fog/mist layer sits at ground level, bleeding upward through the lower 60px of the canvas.
- No text. No logo. Let the atmosphere carry it.

---

## 3. Steam Store Assets

> **Important:** Steam has strict asset requirements. Do not combine assets across size categories. Each must be provided separately.

### 3a. Steam Header Capsule — 460×215 px

> Shown at the top of the Steam store page. Also used in "Featured" sections. The primary Steam storefront impression.

| Field | Value |
|---|---|
| Canvas size | 460 × 215 px |
| Format | JPG or PNG |
| Safe area | Text within 400×175 (30px all sides) |

**Composition: The Seal on Parchment**

A different compositional approach than the itch.io cover — more graphic, less illustrated.

- Background: Aged parchment texture (`#F2E8CE` as base with visible grain and slight foxing/age marks). This is the lightest, warmest Steam asset — intended to pop in the store shelf.
- Centered: The RUMOR MILL logo (parchment variant) at approximately 280px wide — dominant.
- Below the logo: tagline **"A medieval gossip simulation"** in a smaller, clean serif. Color: Stone Gray (`#4A4035`).
- Lower-left corner: the mill-wheel icon silhouette in aged gold (`#C8A96E`), approximately 64×64, partially clipped by the bottom edge for dynamic crop.
- Very subtle deckled shadow along the right and bottom edges — suggests the parchment is lying on a dark surface.

**Note:** The parchment approach is intentionally distinct from the dark/moody itch.io cover, making it recognizable across different Steam browsing contexts.

---

### 3b. Steam Main Capsule — 616×353 px

> Used in featured deals, recommended sections, and "What's New" panels. Higher-impact visual real estate.

| Field | Value |
|---|---|
| Canvas size | 616 × 353 px |
| Format | JPG or PNG |
| Safe area | Core content within 556×293 (30px margin) |

**Composition: The Whispering Figures — Cinematic Crop**

This is the most cinematic Steam asset. Treat it as a movie poster still.

- Background: The Lamplighter's Square dusk scene — rendered in full detail, cinematic 16:9 crop.
- Lighting: Everything keyed off the single lantern. Warm amber light pool in center-left of frame. Blue-indigo ambient from the sky above.
- Focus: The two cloaked figures in the mid-foreground — slightly left of center. One has a hand raised toward the other's ear. Their faces are in deep shadow.
- The watermill wheel is visible in the background right, one blade catching lantern glow.
- Logo placement: Upper-left of frame, using the dark variant (wordmark in parchment on near-black plate). Scale: approximately 200px wide.
- No tagline text in this asset — the imagery carries it.

**Mood:** Think a Vermeer painting at night. Intimate, conspiratorial, beautiful.

---

### 3c. Steam Small Capsule — 231×87 px

> Appears in search results, top-seller lists, wishlist rows, and DLC panels. Must read at tiny scale.

| Field | Value |
|---|---|
| Canvas size | 231 × 87 px |
| Format | JPG or PNG |
| Note | Text will not be legible — rely on imagery + strong silhouette |

**Composition: Seal Close-Up**

- Tight crop of the wax seal icon centered on a near-black background.
- The mill wheel and eye hub should fill approximately 70% of the height (≈60px).
- A sliver of the outer wax ring is visible on all sides, giving it a "stamp" framing.
- Bottom strip (lower 18px): "RUMOR MILL" in the smallest legible size of the blackletter font, in parchment against near-black.
- At this size, readability comes from the gold-on-dark contrast of the wheel, not the detail.

---

### 3d. Steam Library Capsule (Vertical) — 600×900 px

> Displayed in a player's Steam Library list — the most frequently seen asset for players who own the game.

| Field | Value |
|---|---|
| Canvas size | 600 × 900 px |
| Format | JPG or PNG |
| Safe area | Avoid critical content in bottom 80px (may be clipped by game title overlay) |

**Composition: The Town Portal — Vertical Scene**

The vertical format allows a full top-to-bottom atmosphere stack.

- Top third (0–300px): Full night sky. Near-black indigo (`#0A0718`) overhead deepening to burnt amber near the horizon midpoint. Stars visible as faint pin-point specks.
- Middle third (300–600px): The town. Rooftops, the mill wheel (centered in frame), candlelit tavern windows, lantern posts along the cobblestone path. The town is rendered in mid-darkness — shapes clearly legible but not brightly lit.
- Bottom third (600–900px): The cobblestone square foreground. The two cloaked figures are here — smaller in frame, seen from slightly above. A social network/graph visualization is subtly overlaid: thin lines in Rumor Gold (`#C8A96E` at 25% opacity) connecting the two figures to faint node-dots representing other townspeople. This visual metaphor of the social graph distinguishes the library art from other assets.
- Logo: RUMOR MILL wordmark (dark variant) centered at approximately y=820px — above the bottom safe zone. Scale: 320px wide.

---

### 3e. Steam Library Hero (Background) — 3840×1240 px

> Displayed as the full-bleed hero banner behind a game's library page (Steam's "game details" view). Seen when players click the game in their library. Should be atmospheric, not text-heavy.

| Field | Value |
|---|---|
| Canvas size | 3840 × 1240 px (deliver at this resolution; 1920×620 minimum acceptable) |
| Format | JPG (large PNG may exceed Steam's file limit) |
| Safe area | All meaningful content in the center 2560px wide. The outer 640px on each side may be obscured by UI chrome. Bottom 200px may be covered by game title bar. |
| Text | No required text — the transparent logo overlay (3f below) handles branding |

**Composition: Panoramic Lamplighter's Square — Full Bleed**

This is the widest, most ambient asset. Treat it as a wide-format painting.

- The entire Lamplighter's Square scene stretched to ultra-wide panoramic. The composition is anchored at center with the square, mill, and lantern — then the scene extends outward in both directions into the surrounding town.
- Left extension: the tavern district stretching into shadow, a merchant stall row partially visible.
- Right extension: the approach road to the city gate, a guard tower glimpsed at the far right edge.
- Lighting is the defining quality: the single lantern at center casts a warm radius. Beyond 600px from center, the image transitions to dark blue-black. This creates a strong center pull visually and allows Steam's UI overlays to sit on dark flanks without contrast conflict.
- The two whispering figures remain in the center, small relative to the grand scene — their intimacy contrasted against the vast dark town.
- At 3840px wide, individual cobblestones, cloth textures, and lantern glass can be rendered with high fidelity. The quality of material detail is a signal of production value to library browsers.

---

### 3f. Steam Logo Overlay (Transparent) — 640×360 px

> Overlaid onto the Library Hero and page background. Delivered as a transparent PNG — no background.

| Field | Value |
|---|---|
| Canvas size | 640 × 360 px |
| Format | PNG-32 (required — must have transparency) |
| Background | Fully transparent |

**Composition:**

- The RUMOR MILL wordmark (parchment variant) centered on the transparent canvas.
- Wordmark width: approximately 480px, leaving 80px margin on each side.
- The parchment logo plate behind the type is included with ≈90% opacity — it softens slightly against dark hero backgrounds without fully occluding the image beneath.
- The quill motif at 30° behind the type is included at 60% opacity for the same reason.
- Do NOT include drop shadows or glows. Steam composites this asset and adds its own adjustments.

---

## 4. Prompt Templates for AI-Assisted Generation

The following prompt templates are formatted for use with image generation tools (Midjourney, DALL-E, Stable Diffusion, etc.). Adapt as needed per tool.

### Prompt A — Game Icon (512×512 Wax Seal)

```
Circular wax seal on near-black background, medieval intrigue aesthetic.
Outer ring of aged dark burgundy wax with cracked texture,
embossed alternating quill and speech bubble motifs around the inner edge.
Center: stylized 8-spoke mill wheel with curved scythe-blade spokes in aged gold,
hub is a small open eye with vertical slit pupil.
Bottom arc text inside seal: "RUMOR MILL" in small-caps blackletter serif, embossed in wax.
Color palette: near-black background #0D0A06, burgundy wax #6B1A1A, aged gold #C8A96E.
Gothic, heraldic, not cartoonish. Comparable to Crusader Kings III iconography.
Flat circular composition on square canvas.
```

### Prompt B — itch.io Cover / Steam Main Capsule (Landscape Scene)

```
Medieval town square at dusk, isometric-adjacent perspective, painted style.
Two cloaked figures in foreground, heads inclined together in conspiratorial whisper,
faces in shadow, charcoal cloaks with worn hems.
Single lantern post between them casting warm amber-orange light pool.
Background: watermill with large wheel partially visible, tavern with candlelit shuttered windows,
stone well with NPC leaning against it.
Sky gradient: burnt amber #3D1C02 at horizon transitioning to near-black indigo #0A0718 overhead.
Low-lying fog at ground level.
Lighting is key: everything beyond the lantern radius falls to deep shadow.
Color palette: mostly dark — punctuated by warm lantern glow and faint amber sky.
Mood: intimate, secretive, noir medieval. No combat imagery.
Style influences: Inkle Studios 80 Days, Crusader Kings III, Vermeer nightscene.
```

### Prompt C — Library Hero (Ultra-Wide Panoramic)

```
Ultra-wide 3840x1240 panoramic painting, medieval town at night.
Central composition: town square with lantern post, two tiny cloaked figures conversing,
watermill wheel visible center-right, tavern on left.
Wide extensions: left side fades into dark tavern district shadows,
right side extends to city gate road with guard tower in far distance.
Strong center-weighted lighting: warm lantern circle at center, deep blue-black toward edges.
Style: high-fidelity atmospheric concept art. Individual cobblestone and cloth textures visible.
Palette: #0D0A06 deep background, #3D1C02 to #0A0718 sky gradient, #FF7A1A warm lantern.
No text, no UI. Pure atmosphere.
```

### Prompt D — Steam Header Capsule (Parchment Logo)

```
Game key art on aged parchment background, horizontal 460x215 format.
Center: blackletter medieval wordmark "RUMOR MILL" stacked two lines on parchment plate,
color palette parchment #F2E8CE with near-black ink #1A1208 letterforms.
Background: parchment texture with foxing marks (small age spots), warm off-white tones.
Lower left: partial mill wheel icon in aged gold #C8A96E, slightly clipped by frame edge.
Subtle deckled shadow along right and bottom edges.
No additional illustration — let the typography and texture carry it.
Clean, archival, premium. Comparable to historical document design.
```

---

## 5. Delivery Checklist

| Asset | Dimensions | Format | Status |
|---|---|---|---|
| Game icon | 512×512 | PNG | ☐ |
| itch.io cover image | 630×500 | PNG | ☐ |
| itch.io page header | 1500×300 | PNG/JPG | ☐ |
| Steam header capsule | 460×215 | JPG/PNG | ☐ |
| Steam main capsule | 616×353 | JPG/PNG | ☐ |
| Steam small capsule | 231×87 | JPG/PNG | ☐ |
| Steam library capsule (vertical) | 600×900 | JPG/PNG | ☐ |
| Steam library hero | 3840×1240 | JPG | ☐ |
| Steam logo overlay (transparent) | 640×360 | PNG-32 | ☐ |

---

## 6. Cross-Platform Consistency Notes

- **The lantern scene** (itch.io cover, Steam main capsule, library hero) must read as the same world. Consistent NPC silhouettes, mill wheel position, and lantern height.
- **The wax seal** (game icon, Steam small capsule) must read as the same seal at different scales. The gold mill wheel with eye hub is the core recognizable element.
- **Typography** is always the same blackletter-inspired serif (from visual identity §1). No mixing of styles.
- **Do not use** pure white `#FFFFFF` anywhere. All light elements use Aged Parchment `#F2E8CE` or Worn Vellum `#D4C49A`.
- **The social graph motif** (thin gold connection lines between nodes) is used sparingly — only in the library capsule (vertical). It is a gameplay hint, not a decorative element.

---

*Source reference: `docs/visual-identity.md` — SPA-172*
*Spec version: 1.0 — SPA-189*

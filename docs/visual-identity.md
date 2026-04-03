# Rumor Mill — Visual Identity Spec

> **This document is a design spec, not implementation.**
> All visuals described here are production targets for an artist to execute.
> File: `docs/visual-identity.md`

---

## 1. Logo Concept

### Typographic Treatment

The wordmark is set in two lines, stacked:

```
RUMOR
MILL
```

**RUMOR** uses a condensed, slightly weathered blackletter-inspired serif — evocative of a medieval town crier's broadsheet. The letterforms are tall and narrow with slight ink-bleed at the terminals (a distressed-print effect suggesting aged parchment).

**MILL** is set in a bolder, wider weight of the same typeface, acting as a visual anchor beneath "RUMOR." The double-L of MILL terminates in a subtle mill-wheel flourish: the two vertical strokes of the second L form the spokes of a stylized watermill wheel in silhouette, approximately 24px wide at final logo scale.

### Integrated Motif: Quill & Whisper

A single large quill is drawn diagonally across the full wordmark at roughly 30° — its nib pointing toward the lower-right, its feather fanning across the upper-left. The quill is rendered in pale gold / aged vellum tone (`#C8A96E`) and sits *behind* the type on a separate layer, acting as a compositional background element rather than a foreground icon.

A thin speech-bubble tail curls off the quill's nib, implying that the quill itself is "whispering" — the tail points toward empty space as if whispering off-screen.

### Background Treatment

The logo plate is a slightly irregular rectangle of parchment texture — warm off-white (`#F2E8CE`) with subtle foxing marks (small rust-brown age spots). Edges are deckled (rough-torn), not straight. A faint wax seal impression (not a full wax seal, just the ghost of one) sits in the lower-right corner at low opacity (~15%), suggesting official secrecy.

### Color Variants

| Variant | Background | Wordmark | Quill |
|---|---|---|---|
| Primary (parchment) | `#F2E8CE` (parchment) | `#1A1208` (near-black ink) | `#C8A96E` (aged gold) |
| Dark (UI overlay) | `#0D0A06` (deep black) | `#F2E8CE` (parchment) | `#C8A96E` (aged gold) |
| Monochrome | Transparent | `#1A1208` | Same |

### Logo Clearspace

Minimum clearspace around the logo plate: 1× the cap-height of "RUMOR" on all sides. Do not crowd with other UI elements.

---

## 2. Title Screen Layout

### Scene: The Lamplighter's Square at Dusk

The main menu background is a wide isometric view of the town's central square at the transition from dusk to night. The sky gradient runs from deep burnt amber (`#3D1C02`) at the horizon to near-black indigo (`#0A0718`) overhead.

**Foreground layer (closest to camera):**
Two cloaked figures stand at the lower-left of the scene, heads inclined toward each other in visible whispered conversation. One figure gestures with an open palm; the other has a hand raised to their mouth. Their cloaks are dark charcoal with worn hems. Their faces are in shadow — identities deliberately obscured. A single lantern on a post between them casts a warm pool of orange-amber light (`#FF7A1A` at ~40% opacity, soft radial).

**Mid-ground layer:**
The town square shows:
- A working watermill to the right of center — its wheel partially turning, one blade catching lamp-light
- A tavern facade on the left, warm candlelight bleeding through shuttered windows
- A stone well in the center; a third NPC leans against it, back turned, apparently listening
- Wooden market stalls (closed for evening), their canvas awnings slightly frayed
- Cobblestone paving with subtle moss in the gaps

**Background layer (far distance):**
City wall in silhouette, watchtower with a lit torch, rolling hills dissolving into the night sky.

**Atmospheric effects:**
- Light fog / mist at ground level (low-opacity white, ~8–12%)
- Floating dust motes in the lantern light (slow-moving particle system, if animated)
- The mill wheel turns on a very slow loop (if the background is animated)

### Menu Overlay

The UI menu panel is a semi-transparent parchment scroll anchored at screen center:
- Scroll top and bottom edges are illustrated (rolled curl)
- Buttons: **New Game**, **Load**, **Settings**, **Credits**, **Quit**
- Font: same blackletter-inspired serif as logo, at readable size
- Hover state: text glows faintly in rumor-gold (`#C8A96E`)

The game logo (primary parchment variant) sits above the scroll, centered.

---

## 3. Primary Color Palette

### Base UI Tones

| Name | Hex | Usage |
|---|---|---|
| **Ink Black** | `#0D0A06` | Primary background, deep shadows |
| **Night Slate** | `#1C1812` | Secondary background, panels |
| **Aged Parchment** | `#F2E8CE` | Primary text, light UI elements |
| **Worn Vellum** | `#D4C49A` | Secondary text, disabled states |
| **Stone Gray** | `#4A4035` | Borders, dividers, inactive elements |

### Accent: Rumor States

Each rumor in the game carries a visual state. These accent colors appear on rumor cards, map overlays, and the social graph edges.

| State | Name | Hex | Meaning |
|---|---|---|---|
| Unheard | **Whisper Gray** | `#7A7268` | Rumor not yet in circulation |
| Spreading | **Amber Flame** | `#E8821A` | Actively moving through the network |
| Believed | **Verdant Trust** | `#4A8C5C` | NPC has accepted the rumor as true |
| Doubted | **Rust Doubt** | `#8C3A2E` | NPC is skeptical or actively disputing |
| Peak / Viral | **Gold Scandal** | `#C8A96E` | Rumor is at maximum spread/impact |
| Debunked | **Ash Gray** | `#3D3830` | Rumor has been disproved; fades out |

### NPC Faction Colors (Social Graph)

Used as node tints on the social graph overlay and NPC name badges.

| Faction | Hex |
|---|---|
| Merchants' Guild | `#C8A04A` |
| Town Guard | `#3A5C8A` |
| Clergy | `#8A5C8A` |
| Common Folk | `#6A7A5A` |
| Nobility | `#8A2E2E` |

### Interaction / Feedback Colors

| Purpose | Hex |
|---|---|
| Positive feedback (action succeeded) | `#4A8C5C` (Verdant Trust) |
| Warning / caution | `#E8821A` (Amber Flame) |
| Negative / failure | `#8C3A2E` (Rust Doubt) |
| Selection / focus highlight | `#C8A96E` (Gold Scandal / Rumor Gold) |

---

## 4. App Icon (512×512)

### Concept: The Whispering Mill Seal

The icon is a circular wax-seal design on a near-black background.

**Outer ring:** A thick ring of deep burgundy-red wax (`#6B1A1A`) with an aged, slightly uneven surface. Around the inner edge of the ring, embossed in the wax: a chain of alternating quills and speech-bubble tails (8 of each, evenly spaced), suggesting both writing and whispers.

**Center emblem:** A stylized mill wheel — 8 spokes, each spoke shaped as a slightly curved scythe-blade. Rendered in aged gold (`#C8A96E`). The hub of the wheel is a small open eye, also in gold, implying surveillance and secrets.

**Typography:** At the bottom arc of the seal, inside the outer ring: the word **RUMOR MILL** in small-caps serif, embossed in the wax (slightly lighter than the wax base, ~`#8A3030`).

**Background:** The circle sits on pure near-black (`#0D0A06`). A very faint parchment texture bleeds in from the edges at low opacity (~10%), grounding the icon without competing with the seal.

**Readability at small sizes:**
- At 256×256: drop the quill/bubble outer ring detail; keep wheel + eye + wax border
- At 128×128 and below: reduce to mill wheel silhouette in gold on dark background only

### Icon Tone / Feeling

The icon should read as: *official, secretive, slightly ominous, handcrafted*. It belongs on a Steam library shelf next to games with serious gothic or intrigue aesthetics. Avoid cartoonishness — lean into the seal's authority.

---

## Reference Influences

For mood and tone, the following genres / works serve as visual references:

- **Inkle Studios' "80 Days" and "Heaven's Vault"** — aged paper UI, serif typography, historical intimacy
- **Crusader Kings III** — heraldic iconography, dark wood and parchment interfaces
- **Darkest Dungeon** — dramatic lighting, scratched/inked texture on UI elements, oppressive dark palette
- **Medieval manuscript illumination** — gold leaf accents, decorative initials, deckled parchment edges

The tone is *not* whimsical or fairy-tale. It is grounded, slightly grim, and rewards careful observation — matching the game's mechanics of surveillance and social manipulation.

---

*Last updated: 2026-04-03 — SPA-172*

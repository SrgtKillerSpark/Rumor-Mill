# Rumor Mill — Color Palette Reference

> **Source:** `docs/visual-identity.md` (SPA-172)  
> **For:** Artists, UI contributors, store art generation, social media assets  
> Shipped as part of SPA-1606 asset audit.

---

## Base UI Tones

| Token Name | Hex | RGB | Usage |
|---|---|---|---|
| Ink Black | `#0D0A06` | 13, 10, 6 | Primary background, deep shadows |
| Night Slate | `#1C1812` | 28, 24, 18 | Secondary background, panels |
| Aged Parchment | `#F2E8CE` | 242, 232, 206 | Primary text, light UI elements, logo plate |
| Worn Vellum | `#D4C49A` | 212, 196, 154 | Secondary text, disabled states, taglines |
| Stone Gray | `#4A4035` | 74, 64, 53 | Borders, dividers, inactive elements |

---

## Accent — Rumor State Colors

Each rumor in the game carries a visual state. These appear on rumor cards, map overlays, and social graph edges.

| State | Token Name | Hex | RGB | Meaning |
|---|---|---|---|---|
| Unheard | Whisper Gray | `#7A7268` | 122, 114, 104 | Rumor not yet in circulation |
| Spreading | Amber Flame | `#E8821A` | 232, 130, 26 | Actively moving through the network |
| Believed | Verdant Trust | `#4A8C5C` | 74, 140, 92 | NPC has accepted rumor as true |
| Doubted | Rust Doubt | `#8C3A2E` | 140, 58, 46 | NPC is skeptical or disputing |
| Peak / Viral | Gold Scandal | `#C8A96E` | 200, 169, 110 | Rumor at maximum spread/impact |
| Debunked | Ash Gray | `#3D3830` | 61, 56, 48 | Rumor disproved; fades out |

---

## NPC Faction Colors

Used as node tints on the social graph overlay and NPC name badges.

| Faction | Hex | RGB |
|---|---|---|
| Merchants' Guild | `#C8A04A` | 200, 160, 74 |
| Town Guard | `#3A5C8A` | 58, 92, 138 |
| Clergy | `#8A5C8A` | 138, 92, 138 |
| Common Folk | `#6A7A5A` | 106, 122, 90 |
| Nobility | `#8A2E2E` | 138, 46, 46 |

---

## Interaction / Feedback Colors

| Purpose | Hex | Token |
|---|---|---|
| Positive feedback (action succeeded) | `#4A8C5C` | Verdant Trust |
| Warning / caution | `#E8821A` | Amber Flame |
| Negative / failure | `#8C3A2E` | Rust Doubt |
| Selection / focus highlight | `#C8A96E` | Gold Scandal |

---

## Store Art / Key Art Specific

| Token | Hex | Usage |
|---|---|---|
| Rumor Gold | `#C8A96E` | Logo quill, icon emblem, social graph lines |
| Burgundy Wax | `#6B1A1A` | Icon outer wax ring |
| Burnt Amber Sky | `#3D1C02` | Horizon gradient in scene art |
| Near-Black Indigo | `#0A0718` | Sky overhead in scene art |
| Lantern Warm | `#FF7A1A` | Lantern light glow (use at 40% opacity) |
| Emboss Wax | `#8A3030` | Embossed text/motifs on wax seal |
| Near-Black Ink | `#1A1208` | Logo wordmark letterforms |

---

## Icon Readability Ladder

The icon must scale gracefully. Use this palette at each size:

| Size | Elements |
|---|---|
| 512×512 | Full seal: outer ring (#6B1A1A) + quill/bubble embossing (#8A3030) + mill wheel (#C8A96E) + eye hub + "RUMOR MILL" text |
| 256×256 | Drop outer embossing; keep wax ring + wheel + eye + text |
| 128×128 | Drop text; wax ring + wheel (gold on dark) |
| 64×64 and below | Mill wheel silhouette (#C8A96E) on Ink Black (#0D0A06) only |

---

## Do Not Use

- Pure white `#FFFFFF` — always use Aged Parchment `#F2E8CE` for light elements
- Pure black `#000000` — use Ink Black `#0D0A06`
- Bright saturated colors — the palette is intentionally desaturated and warm
- Cartoonish or pastels — tone is gothic, grounded, and slightly ominous

---

*Source: `docs/visual-identity.md` — SPA-172*

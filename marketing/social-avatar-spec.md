# Rumor Mill — Social Media Avatar & Banner Specs

> **Source:** `docs/visual-identity.md` §4, `docs/store-art-specs.md` §1 (SPA-172, SPA-189)  
> Shipped as part of SPA-1606 asset audit.

All social avatars use the **Whispering Mill Seal** concept from the game icon. The mill wheel + eye hub at center is the core recognizable element across all sizes.

---

## Twitter / X

### Profile Avatar — 400×400 px

| Field | Value |
|---|---|
| Canvas | 400×400 px |
| Format | PNG or JPG |
| Display shape | Circular (Twitter crops to circle) |
| Design target | `marketing/icon-512.png` scaled to 400×400 |

**Composition:**
- Use the 512×512 wax seal icon scaled down, or re-render native at 400×400.
- Twitter displays at ~73px in most views — ensure the mill wheel gold speaks at that size.
- At 73px: rely on mill wheel silhouette (gold on dark) only. Outer wax ring detail may disappear.
- At 400×400 (full header click-through): full seal detail is visible.

### Header Banner — 1500×500 px

| Field | Value |
|---|---|
| Canvas | 1500×500 px |
| Format | PNG or JPG |
| Safe area | Center 1260×360 (120px margin all sides — Twitter crops aggressively on mobile) |

**Composition:**
Use **Prompt E** (itch.io page header, panoramic silhouette) adapted to 1500×500. Same night-sky silhouette of the town. No text required — the profile avatar provides the logo. Optionally add "Rumor Mill" wordmark in upper-left of safe area in Aged Parchment (`#F2E8CE`).

---

## Discord

### Server Icon — 512×512 px (displayed at 96×96)

| Field | Value |
|---|---|
| Canvas | 512×512 px |
| Format | PNG-32 (transparent background recommended for Discord dark theme) |
| Display shape | Circular |

**Composition:**
Same wax seal as icon-512.png. Use transparent background (no `#0D0A06` fill) so Discord's dark/light theme backgrounds show through cleanly. The wax ring provides its own visual boundary.

### Server Banner — 960×540 px

| Field | Value |
|---|---|
| Canvas | 960×540 px |
| Format | PNG or JPG |

**Composition:**
Condensed version of the itch.io cover scene (Prompt B). Two cloaked figures in center, lantern glow. No required text. "RUMOR MILL" wordmark optional, upper-center in dark variant.

---

## YouTube

### Channel Icon — 800×800 px (displayed at 98×98)

| Field | Value |
|---|---|
| Canvas | 800×800 px |
| Format | PNG |
| Display shape | Circular |

**Composition:**
Same wax seal, rendered at 800×800 for maximum quality. YouTube displays at 98px in most contexts, so the icon needs strong gold-on-dark contrast at that size. The mill wheel + eye is sufficient.

### Channel Art / Banner — 2560×1440 px

| Field | Value |
|---|---|
| Canvas | 2560×1440 px |
| Format | PNG or JPG |
| Safe area | Center 1546×423 (the "TV safe area" YouTube defines) |
| Desktop visible | Center 2560×423 |

**Composition:**
Use **Prompt C** (Steam Library Hero, ultra-wide panoramic) scaled to 2560×1440 with letterboxing. The atmospheric town scene works well here. No required text in the safe zone — the channel name displays via YouTube's own UI. Optionally place the RUMOR MILL dark variant logo centered in the safe zone.

---

## itch.io (Already Specified)

| Asset | Size | Spec file |
|---|---|---|
| Cover Image | 630×500 | `docs/store-art-specs.md` §2a |
| Page Header | 1500×300 | `docs/store-art-specs.md` §2b |

---

## Steam (Already Specified)

| Asset | Size | Spec file |
|---|---|---|
| Header Capsule | 460×215 | `docs/store-art-specs.md` §3a |
| Main Capsule | 616×353 | `docs/store-art-specs.md` §3b |
| Small Capsule | 231×87 | `docs/store-art-specs.md` §3c |
| Library Capsule Vertical | 600×900 | `docs/store-art-specs.md` §3d |
| Library Hero | 3840×1240 | `docs/store-art-specs.md` §3e |
| Logo Overlay (transparent) | 640×360 | `docs/store-art-specs.md` §3f |

---

## Cross-Platform Consistency Rules

- **Mill wheel + eye hub** = the core recognizable element at all small sizes. Never sacrifice this.
- **Gold on dark** (`#C8A96E` on `#0D0A06`) is the signal color for the brand at tiny display sizes.
- **Never use pure white** (`#FFFFFF`) — use Aged Parchment `#F2E8CE` for all light text.
- **Tone check:** Every asset should read as *official, secretive, slightly ominous*. Not cartoonish.

---

*Source: `docs/visual-identity.md` — SPA-172 | `docs/store-art-specs.md` — SPA-189*

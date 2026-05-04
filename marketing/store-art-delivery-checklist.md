# Rumor Mill — Store Art Delivery Checklist

> **For:** Artist handoff, QA, and store submission tracking  
> **Source:** `docs/store-art-specs.md` (SPA-189)  
> Shipped as part of SPA-1606 asset audit.

Full art direction briefs and AI prompts: `docs/store-art-specs.md` | `marketing/ai-generation-prompts.md`

---

## Shared Game Icon

| Asset | File | Dimensions | Format | Safe Area | Status |
|---|---|---|---|---|---|
| Game icon | `marketing/icon-512.png` | 512×512 px | PNG-32 | 460×460 inner | ☐ |

**Readability ladder — required before submission:**

| Size | Elements required |
|---|---|
| 256×256 | Wax ring + wheel + eye + "RUMOR MILL" text (drop outer embossing) |
| 128×128 | Wax ring + wheel + eye (drop text) |
| 64×64 | Mill wheel silhouette in gold on dark only |

---

## itch.io Assets

| Asset | File | Dimensions | Format | Safe Area | Status |
|---|---|---|---|---|---|
| Cover image (thumbnail) | `marketing/itchio-cover-630x500.png` | 630×500 px | PNG | 570×440 inner | ☐ |
| Page header banner | `marketing/itchio-header-1500x300.png` | 1500×300 px | PNG/JPG | Center 900px always visible | ☐ |

**itch.io cover notes:**
- Include "RUMOR MILL" wordmark upper-center (~220px wide)
- Include tagline "No swords. Just whispers." in Worn Vellum (`#D4C49A`)
- Two cloaked figures + lantern are the mandatory foreground elements
- Must read at 315×250 (itch.io scales down for grid views)

---

## Steam Assets

| Asset | File | Dimensions | Format | Safe Area | Status |
|---|---|---|---|---|---|
| Header capsule | `marketing/steam-header-460x215.png` | 460×215 px | JPG/PNG | 400×175 inner | ☐ |
| Main capsule | `marketing/steam-main-616x353.png` | 616×353 px | JPG/PNG | 556×293 inner | ☐ |
| Small capsule | `marketing/steam-small-231x87.png` | 231×87 px | JPG/PNG | Text won't read — rely on imagery | ☐ |
| Library capsule (vertical) | `marketing/steam-library-600x900.png` | 600×900 px | JPG/PNG | Avoid bottom 80px (title overlay) | ☐ |
| Library hero | `marketing/steam-library-hero-3840x1240.jpg` | 3840×1240 px | JPG | Center 2560px; bottom 200px clear | ☐ |
| Logo overlay (transparent) | `marketing/steam-logo-overlay-640x360.png` | 640×360 px | PNG-32 | Fully transparent background | ☐ |

**Steam-specific notes:**
- Header capsule (460×215): parchment background, NOT dark scene — intentionally different from itch.io
- Main capsule (616×353): cinema crop of the whispering-figures scene; logo upper-left, dark variant
- Small capsule (231×87): tight seal crop; mill wheel ~60px tall; text strip bottom 18px
- Library capsule vertical (600×900): social graph overlay at 25% opacity in bottom third
- Library hero (3840×1240): minimum acceptable delivery 1920×620
- Logo overlay: parchment variant at 90% opacity; quill at 60%; NO drop shadows or glows

---

## Social Media Assets

| Asset | File | Dimensions | Format | Status |
|---|---|---|---|---|
| Twitter/X avatar | `marketing/social/twitter-avatar-400x400.png` | 400×400 px | PNG | ☐ |
| Twitter/X header | `marketing/social/twitter-header-1500x500.png` | 1500×500 px | PNG/JPG | ☐ |
| Discord server icon | `marketing/social/discord-icon-512x512.png` | 512×512 px | PNG-32 | ☐ |
| Discord server banner | `marketing/social/discord-banner-960x540.png` | 960×540 px | PNG/JPG | ☐ |
| YouTube channel icon | `marketing/social/youtube-icon-800x800.png` | 800×800 px | PNG | ☐ |
| YouTube channel art | `marketing/social/youtube-banner-2560x1440.png` | 2560×1440 px | PNG/JPG | ☐ |

Full specs: `marketing/social-avatar-spec.md`

---

## Cross-Platform Consistency Checks (required before final submission)

- [ ] The lantern scene reads as the same world across itch.io cover, Steam main capsule, and library hero (consistent NPC silhouettes, mill wheel position, lantern height)
- [ ] The wax seal reads as the same seal at all sizes (game icon → Steam small capsule → social avatars)
- [ ] Typography is always the same blackletter-inspired serif — no mixing
- [ ] No pure white (`#FFFFFF`) anywhere — all light elements use Aged Parchment `#F2E8CE` or Worn Vellum `#D4C49A`
- [ ] Social graph motif (thin gold connection lines) used ONLY in Steam library capsule vertical — not elsewhere
- [ ] Steam header capsule is the lightest/warmest asset (parchment background) — confirm it pops against dark Steam shelf

---

*Source: `docs/store-art-specs.md` — SPA-189 | Social specs: `marketing/social-avatar-spec.md`*

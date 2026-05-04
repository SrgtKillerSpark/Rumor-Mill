# Rumor Mill — Creative Director Asset Checklist

> **Maintained by:** Creative Director agent  
> **Last updated:** 2026-05-04 — SPA-1606  
> **Source specs:** `docs/visual-identity.md` (SPA-172), `docs/store-art-specs.md` (SPA-189), `docs/press-kit.md` (SPA-154)

---

## Overview

All marketing and press assets required for itch.io launch, Steam Coming Soon page, and press outreach. Items are partitioned into **Ship now** (no in-game capture required) and **Blocked on stable build** (requires a running, stable Godot build for in-game capture).

---

## Category A — SHIP NOW (no build dependency)

These items can be authored, spec'd, or drafted entirely from existing design documents.

| # | Asset | File Target | Status | Notes |
|---|---|---|---|---|
| A1 | Color palette reference sheet | `marketing/palette-reference.md` | ☑ Shipped (SPA-1606) | All hex codes from visual-identity.md |
| A2 | AI image generation prompts | `marketing/ai-generation-prompts.md` | ☑ Shipped (SPA-1606) | 4 prompts for icon, scene, library hero, Steam header |
| A3 | Press factsheet (no screenshots) | `marketing/press-factsheet.md` | ☑ Shipped (SPA-1606) | Game summary, features, factsheet — standalone press copy |
| A4 | Social avatar & banner spec | `marketing/social-avatar-spec.md` | ☑ Shipped (SPA-1606) | Twitter/X, Discord, YouTube specs derived from icon |
| A5 | Store art delivery checklist | `marketing/store-art-delivery-checklist.md` | ☑ Shipped (SPA-1606) | Pixel specs for all 9 store assets with format + safe area |
| A6 | Logo color variants spec | (documented in visual-identity.md §1) | ✓ Exists | 3 variants: parchment, dark overlay, monochrome |
| A7 | Key art composition briefs | (documented in store-art-specs.md) | ✓ Exists | 4 prompts + full briefs for every canvas size |
| A8 | NPC faction color reference | (documented in visual-identity.md §3) | ✓ Exists | 5 factions + rumor state colors |

---

## Category B — BLOCKED ON STABLE BUILD

These items require the game to boot cleanly and reach a playable state for in-game screen capture.

| # | Asset | File Target | Status | Unblocked by |
|---|---|---|---|---|
| B1 | Screenshot: Town Overview (1920×1080) | `marketing/screenshots/screenshot-01-town-overview.png` | ⏳ Blocked | SPA-1603 (parse-error guard) |
| B2 | Screenshot: Eavesdrop Moment (1920×1080) | `marketing/screenshots/screenshot-02-eavesdrop.png` | ⏳ Blocked | SPA-1603 |
| B3 | Screenshot: Rumor Crafting Panel (1920×1080) | `marketing/screenshots/screenshot-03-rumor-crafting.png` | ⏳ Blocked | SPA-1603 |
| B4 | Screenshot: Rumor Propagation Chain (1920×1080) | `marketing/screenshots/screenshot-04-propagation.png` | ⏳ Blocked | SPA-1603 |
| B5 | Screenshot: Reputation Collapsing (1920×1080) | `marketing/screenshots/screenshot-05-reputation.png` | ⏳ Blocked | SPA-1603 |
| B6 | Screenshot: Faction Social Graph (1920×1080) | `marketing/screenshots/screenshot-06-faction-graph.png` | ⏳ Blocked | SPA-1603 |
| B7 | Gameplay GIF / short video clip | `marketing/video/` | ⏳ Blocked | SPA-1603 + SPA-1300 |
| B8 | Rendered game icon (512×512 PNG) | `marketing/icon-512.png` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B9 | itch.io cover image (630×500 PNG) | `marketing/itchio-cover-630x500.png` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B10 | Steam header capsule (460×215) | `marketing/steam-header-460x215.png` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B11 | Steam main capsule (616×353) | `marketing/steam-main-616x353.png` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B12 | Steam small capsule (231×87) | `marketing/steam-small-231x87.png` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B13 | Steam library capsule vertical (600×900) | `marketing/steam-library-600x900.png` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B14 | Steam library hero (3840×1240 JPG) | `marketing/steam-library-hero-3840x1240.jpg` | ⏳ Blocked on artist | Needs artist / AI image tool |
| B15 | Steam logo overlay (640×360 PNG-32) | `marketing/steam-logo-overlay-640x360.png` | ⏳ Blocked on artist | Needs artist / AI image tool |

---

## Checklist Update Notes (SPA-1606)

The following items were missing from a pre-existing checklist and are now added:

- **Social media avatar specs** (A4) — Twitter/X, Discord, YouTube not previously listed as separate deliverables; they are derived from the icon and should be specced before artist handoff.
- **Store art delivery checklist** (A5) — a standalone condensed brief for artist handoff was missing; it's now shipped.
- **Rendered store art images (B8–B15)** — these were implicit in the store-art-specs.md but not tracked as discrete deliverables with file targets. Added as explicit blocked items.
- **Press factsheet standalone** (A3) — press-kit.md is the full press kit; a stripped, screenshot-free version is useful for early outreach before screenshots are available.

---

*Next action: B8–B15 unblock as soon as an artist or AI image tool can be engaged; B1–B7 unblock after SPA-1603 (parse-error guard) lands and the build is stable.*

# Rumor Mill — AI Image Generation Prompts

> **Source:** `docs/store-art-specs.md` (SPA-189), `docs/visual-identity.md` (SPA-172)  
> **For:** Artists using Midjourney, DALL-E, Stable Diffusion, or similar tools  
> Shipped as part of SPA-1606 asset audit.

These prompts are production-ready. Adapt aspect ratios and negative prompts per tool. Color palette reference: `marketing/palette-reference.md`.

---

## Prompt A — Game Icon (512×512 Wax Seal)

**Target file:** `marketing/icon-512.png`  
**Canvas:** 512×512 px, PNG-32  
**Use:** itch.io game icon, Steam app icon, Windows desktop shortcut

```
Circular wax seal on near-black background, medieval intrigue aesthetic.
Outer ring of aged dark burgundy wax (#6B1A1A) with cracked texture,
embossed alternating quill and speech bubble motifs around the inner edge.
Center: stylized 8-spoke mill wheel with curved scythe-blade spokes in aged gold (#C8A96E),
hub is a small open eye with vertical slit pupil.
Bottom arc text inside seal: "RUMOR MILL" in small-caps blackletter serif, embossed in wax.
Color palette: near-black background #0D0A06, burgundy wax #6B1A1A, aged gold #C8A96E.
Gothic, heraldic, not cartoonish. Comparable to Crusader Kings III iconography.
Flat circular composition on square canvas.
```

**Negative prompt:** cartoon, anime, bright colors, fantasy whimsy, round corners, flat design, modern UI

---

## Prompt B — itch.io Cover / Steam Main Capsule (Landscape Scene)

**Target files:**  
- `marketing/itchio-cover-630x500.png` (630×500 px)  
- `marketing/steam-main-616x353.png` (616×353 px)

**Use:** itch.io primary thumbnail, Steam featured section, recommended panels

```
Medieval town square at dusk, isometric-adjacent perspective, painted style.
Two cloaked figures in foreground, heads inclined together in conspiratorial whisper,
faces in shadow, charcoal cloaks with worn hems.
Single lantern post between them casting warm amber-orange light pool (#FF7A1A at 40% opacity).
Background: watermill with large wheel partially visible, tavern with candlelit shuttered windows,
stone well with NPC leaning against it.
Sky gradient: burnt amber #3D1C02 at horizon transitioning to near-black indigo #0A0718 overhead.
Low-lying fog at ground level, 10% opacity white.
Lighting is key: everything beyond the lantern radius falls to deep shadow.
Color palette: mostly dark — punctuated by warm lantern glow and faint amber sky.
Mood: intimate, secretive, noir medieval. No combat imagery.
Style influences: Inkle Studios 80 Days, Crusader Kings III, Vermeer nightscene.
```

**Negative prompt:** combat, swords, weapons, bright lighting, anime, cartoonish, fantasy creatures, modern elements

**For itch.io (630×500):** Place "RUMOR MILL" wordmark in upper-center, tagline "No swords. Just whispers." in worn vellum (#D4C49A) below it.  
**For Steam main capsule (616×353):** Place dark-variant logo upper-left, no tagline text.

---

## Prompt C — Steam Library Hero (Ultra-Wide Panoramic)

**Target file:** `marketing/steam-library-hero-3840x1240.jpg`  
**Canvas:** 3840×1240 px (minimum acceptable: 1920×620), JPG  
**Use:** Steam Library full-bleed hero banner (seen when players click the game in their library)

```
Ultra-wide 3840x1240 panoramic painting, medieval town at night.
Central composition: town square with lantern post, two tiny cloaked figures conversing,
watermill wheel visible center-right, tavern on left.
Wide extensions: left side fades into dark tavern district shadows,
right side extends to city gate road with guard tower in far distance.
Strong center-weighted lighting: warm lantern circle (#FF7A1A) at center, deep blue-black toward edges.
Style: high-fidelity atmospheric concept art. Individual cobblestone and cloth textures visible.
Palette: #0D0A06 deep background, #3D1C02 to #0A0718 sky gradient, #FF7A1A warm lantern.
No text, no UI. Pure atmosphere.
```

**Negative prompt:** text, UI elements, HUD, bright overall lighting, daytime, fantasy creatures

**Composition note:** All meaningful content within center 2560px. Outer 640px on each side may be obscured by Steam UI chrome. Bottom 200px may be covered by game title bar — keep it clear.

---

## Prompt D — Steam Header Capsule (Parchment Logo)

**Target file:** `marketing/steam-header-460x215.png`  
**Canvas:** 460×215 px, JPG or PNG  
**Use:** Steam store page header, "Featured" sections

```
Game key art on aged parchment background, horizontal 460x215 format.
Center: blackletter medieval wordmark "RUMOR MILL" stacked two lines on parchment plate,
color palette parchment #F2E8CE with near-black ink #1A1208 letterforms.
Background: parchment texture with foxing marks (small age spots), warm off-white tones.
Lower left: partial mill wheel icon in aged gold #C8A96E, slightly clipped by frame edge.
Tagline below wordmark: "A medieval gossip simulation" in Stone Gray (#4A4035) smaller serif.
Subtle deckled shadow along right and bottom edges.
No additional illustration — let the typography and texture carry it.
Clean, archival, premium. Comparable to historical document design.
```

**Negative prompt:** dark background, scene illustration, figures, night sky, combat, anime

**Note:** This asset is intentionally the lightest/warmest Steam asset — designed to contrast against dark Steam shelf neighbors.

---

## Prompt E — itch.io Page Header Banner (Panoramic Strip)

**Target file:** `marketing/itchio-header-1500x300.png`  
**Canvas:** 1500×300 px, PNG or JPG  
**Use:** itch.io game page top banner (atmospheric, no required text)

```
Wide panoramic silhouette strip of medieval town skyline, 1500x300 cinematic letterbox.
Pure silhouette style: dark shapes against dusk-to-night sky gradient.
Left: rolling hills, city wall silhouette, single lit watchtower.
Center: market square rooftops, watermill wheel visible above other structures.
Right: more rooftops, church tower, fading into atmospheric haze.
Sky: burnt amber #3D1C02 at horizon to near-black indigo #0A0718 overhead.
Fog/mist at ground level, bleeding upward through lower 60px.
No text, no logo, no figures. Pure shape language.
Ultra-wide cinematic composition.
```

**Negative prompt:** text, logo, figures, bright daylight, fantasy creatures, cartoonish

---

## Usage Notes

- **Midjourney:** Append `--ar 16:9` for landscape, `--ar 1:1` for icon. Use `--v 6` or later. Append `--style raw` for less stylization.
- **DALL-E 3:** Prompts above are compatible as-is. Use "natural" style preset for the scene art.
- **Stable Diffusion:** Use an architecture-focused or concept-art LoRA. Set CFG scale 7–9 for these prompts.
- **All tools:** Run multiple seeds. The parchment logo capsule (Prompt D) is the most consistent; the scene art (Prompt B) will require most iteration.

---

*Source: `docs/store-art-specs.md` — SPA-189*

# Rumor Mill — Launch-Week Screenshot Capture Manifest

*SPA-1415 — 2026-04-30*
*Feeds: SPA-871 (art quality review), SPA-1300 (press kit Priority 2 gate)*

**Build:** `builds/RumorMill.exe` (post-SPA-410 art pass)
**Target resolution:** 1920×1080
**Format:** PNG

Captures require an interactive display session. This manifest provides the exact game state and framing for each of the 8 shots.

---

## Shot List

### Shot 1 — S1 Peak Rumor Spread (Social Graph Overlay)
**File:** `asset-e-act-state-npc-2026-04-30.png`
**Scenario:** 1 — The Alderman's Ruin
**Game state:**
- Day 12–15. Active rumor in progress with 8+ NPCs in varied states.
- At least one NPC in ACT state (magenta tint, pulsing lightning icon), mid-movement away from originating cluster.
- Social Graph Overlay OFF (press G to toggle) — keep NPC sprites unobscured.
- 2–3 NPCs in frame for scale context.

**Framing:** Mid-town market tile. ACT NPC moving diagonally toward tavern. Orange SPREAD cluster visible 3–5 tiles behind.
**Quality bar (→ SPA-871):** Check that magenta tint is distinct from ambient warm lighting. Pulsing icon should not alias at 1080p.

---

### Shot 2 — S2 Counter-Intelligence Tension (DEFENDING Cascade)
**File:** `asset-h-defending-cascade-2026-04-30.png`
**Scenario:** 2 — The Plague Scare
**Game state:**
- Counter-rumor seeded near target NPC (business rival cluster).
- 1–2 sky-blue DEFENDING NPCs visible near target.
- Orange SPREAD cluster visible in same frame, 3–5 tiles away.
- Social Graph Overlay OFF for sprite clarity.

**Framing:** The visual contrast between sky-blue and orange is the story. Both clusters must be readable without cropping.
**Quality bar (→ SPA-871):** DEFENDING NPC blue must not read as purple under the dusk ambient tint. Check at 50% zoom.

---

### Shot 3 — S3 Dual-Objective HUD + Rival Agent
**File:** `asset-j-s3-dual-track-2026-04-30.png`
**Scenario:** 3 — The Succession
**Game state:**
- Day 8–12.
- Social Graph Overlay ON (press G).
- Frame so both Calder Fenn's reputation tracker (climbing) and Tomas Reeve's tracker (falling) are simultaneously visible in the ObjectiveHUD.
- Rival agent's rumor trail visible as a thread on the overlay in the background.

**Framing:** ObjectiveHUD lower-left. Overlay fills background. Both NPC portrait/tracker pairs readable.
**Quality bar (→ SPA-871):** Rival agent's thread color must distinguish from player rumor threads. Confirm color coding in-engine.

---

### Shot 4 — S4 Defense Moment (Accused NPC Under Heresy Threat)
**File:** `asset-f-inquisitor-pressure-s4-2026-04-30.png`
**Scenario:** 4 — The Holy Inquisition
**Game state:**
- Day 7–10. Two protected NPCs with reputation ~42–45 (visible in ReconHUD — near fail floor at 40).
- Social Graph Overlay ON.
- HERESY rumor mid-propagation — orange spread icon mid-flight on overlay.
- Pressure HUD element visible (shows inquisitor's active claims count).

**Framing:** ReconHUD panel visible showing near-fail reputation bars. Overlay shows HERESY propagation thread from inquisitor node.
**Quality bar (→ SPA-871):** "HERESY" label legibility at 1080p — check font rendering at the overlay scale.

---

### Shot 5 — Tutorial Banner (S1 Tutorial Moment)
**File:** `asset-k-tutorial-banner-s1-2026-04-30.png`
**Scenario:** 1 — The Alderman's Ruin (tutorial playthrough)
**Game state:**
- Early game (Day 1–3). Tutorial banner/prompt visible (the overlay that guides first-time players through the core loop).
- Banner should show a mid-tutorial instruction — ideally the rumor-crafting step or the social graph step (not the very first "welcome" screen).
- Town visible in background with at least 3 NPCs.

**Framing:** Tutorial banner centered or lower-third. Background shows active town, not empty.
**Quality bar (→ SPA-871):** Banner text legibility at 1920×1080 full resolution. Check that parchment banner background doesn't wash out against the town isometric tiles.

---

### Shot 6 — End-Screen Analytics
**File:** `asset-g-post-scenario-analytics-s1-2026-04-30.png`
**Scenario:** 1 or 3 — win-state preferred
**Game state:**
- End screen reached (scenario complete).
- Navigate to the Replay tab (EndScreenReplayTab).
- Both the Spread Timeline panel and Mutation Log panel visible simultaneously.

**Framing:** Full end-screen layout — don't crop either panel. Date/time visible in timeline to show full run duration.
**Quality bar (→ SPA-871):** Mutation log font rendering — this is text-dense. Confirm no line-height clipping at standard zoom.

---

### Shot 7 — Journal Reputation View
**File:** `asset-l-journal-reputation-2026-04-30.png`
**Scenario:** Any mid-game state with an active target NPC
**Game state:**
- Player Journal open (press J).
- Target NPC selected — reputation bar visibly low or actively dropping.
- Reputation timeline trending downward. At least one active rumor listed as contributing factor.
- Faction standing indicators visible.

**Framing:** Journal panel dominant. NPC portrait and reputation bar prominent. Day counter showing days remaining.
**Quality bar (→ SPA-871):** Check that the depleting reputation bar animation captures cleanly as a still (pick a frame mid-drain, not empty or full).

---

### Shot 8 — Night at the Noble Estate (Atmosphere)
**File:** `asset-i-noble-estate-night-2026-04-30.png`
**Scenario:** 1 or 2 — post 18:00 in-game time
**Game state:**
- Manor Interior accessible (world map navigation).
- Post-18:00: trigger Incriminating Artifact acquisition recon action (`recon_controller.gd:603`).
- Acquisition confirmation window open.
- Estate night lighting visible in background — NPC silhouetted at entrance.

**Framing:** Acquisition window in foreground. Manor night scene in background. Lantern glow visible. Strong atmosphere shot.
**Quality bar (→ SPA-871):** Night lighting darkness level — check that the manor silhouette reads against the sky, not just a black blob. The lantern glow radius is the key anchor.

---

## Naming Convention

```
asset-[letter]-[slug]-[YYYY-MM-DD].png
```

Letters continue from existing Priority 2 checklist (E–J). New shots for this press-kit refresh:
- `k` = tutorial-banner
- `l` = journal-reputation

---

## Quality Issues to Feed Back to SPA-871

Note any of the following during capture and include in SPA-1415 comment:

- [ ] ACT state magenta NPC tint vs. warm ambient lighting clash (Shot 1)
- [ ] DEFENDING blue NPC readability under dusk tint (Shot 2)
- [ ] Rival agent rumor thread color differentiation (Shot 3)
- [ ] "HERESY" label font rendering on overlay (Shot 4)
- [ ] Tutorial banner text legibility at 1080p (Shot 5)
- [ ] Mutation log line-height rendering (Shot 6)
- [ ] Reputation bar depletion still-frame pick (Shot 7)
- [ ] Manor silhouette vs. sky readability at night (Shot 8)

# Demo Readiness Review — Scenario 1: The Alderman's Ruin

**Reviewer:** Game Designer (SPA-170)
**Date:** 2026-04-03
**Scope:** First-time player experience, end-to-end Scenario 1

---

## Summary Verdict

**Overall: READY FOR DEMO — with three actionable fixes recommended before showing to new players.**

The game is content-complete and technically sound. All narrative text is final, tutorial systems are wired, and the HUD gives adequate real-time feedback. The three issues below are not blockers but will noticeably hurt a first-time player's confidence in the opening minutes if left unfixed.

---

## 1. Onboarding Flow

### What works

The four-phase main menu (MAIN → SELECT → BRIEFING → INTRO) is clean and well-paced:

- **Scenario card** shows title, teaser sentence, and day count at a glance.
- **Briefing screen** displays the full `startingText` — all three paragraphs are atmospheric and correctly frame the 30-day deadline and target.
- **Intro card** (italic `introText`) creates mood before gameplay starts.
- **Loading tip** (1.5 s) bridges the transition without dead silence.
- **How to Play** is accessible from both the main menu and the pause menu, covering controls, mechanics, and systems across three tabs.

### Issue 1 — Objective HUD doesn't surface the win condition

**File:** `scripts/objective_hud.gd:54`

The top-left HUD extracts the objective summary as the first sentence of `startingText`, which for Scenario 1 is:

> *"A foreign factor has entered the town quietly, carrying letters of introduction that may — or may not — be genuine."*

This is atmospheric flavour, not a win condition. A first-time player reading the HUD sees no numeric target. The actual threshold (`Edric Fenn reputation < 30`) only appears in the Journal → Objectives tab, which requires the player to discover the hotkey (J) and navigate there.

**Recommendation:** Add a second line to the Objective HUD showing the primary target's current reputation score against its threshold, e.g. `Edric Fenn reputation: 68 / need < 30`. Even a static label below the objective sentence — showing "Target: Discredit Edric Fenn (rep < 30)" — would give first-time players a concrete goal visible at all times without opening the Journal.

---

## 2. First Five Minutes

### What works

The non-blocking banner hint system (10 contextual hints, SPA-131) covers the full Scenario 1 core loop in the right sequence:

| Order | Hint | Trigger |
|-------|------|---------|
| 1 | Navigate the Town | Game start (immediate) |
| 2 | Inspect NPCs | After camera moved + NPC hovered |
| 3 | Observe a Location | First building hover |
| 4 | Eavesdrop | Valid eavesdrop target hovered, after first Observe |
| 5 | Review Intel (Journal) | After first successful Eavesdrop |
| 6 | Craft a Rumour | Day 2 tick if no rumour seeded |
| 7 | Choose Your Seed Target | Seed target panel opened |
| 8 | Watch the Rumour Spread | 5 s after first rumour seeded |
| 9 | Track Your Goal | First NPC reaches BELIEVE |
| 10 | Evidence Boosts Belief | First evidence item acquired |

The banner suppression system (paused when Journal / Rumour Panel / Pause Menu are open) prevents overlap. Auto-dismiss timers (7–9 s) are appropriate for hint length. Slide-in animations are polished and not distracting.

The `recon_actions` blocking tooltip (wired for S2/S3 only, not S1) is replaced by the banner system for Scenario 1, which is the right call — the banner doesn't interrupt moment-to-moment play.

### Issue 2 — No guidance pointing to Edric Fenn as the target NPC

The briefing correctly names the target. But once gameplay begins, the town contains ~25 NPCs, none visually distinguished as the primary target. HINT-03 ("Observe a Location") and HINT-04 ("Eavesdrop") explain mechanics but don't help new players find or identify Edric Fenn on the map.

A first-time player's expected path: read briefing → start game → look at many NPCs → hover until they find "Edric Fenn" → proceed. This is workable in a tutorial context but adds unnecessary friction in a demo where every minute counts.

**Recommendation:** Either (a) add a one-time hint that fires ~10 s after game start pointing to Fenn's location or marking him with a subtle indicator (e.g. a faint crest icon), or (b) have HINT-02 ("Inspect NPCs") explicitly say "...find and hover Lord Edric Fenn — he's your primary target." Low implementation cost, meaningful clarity gain.

### Issue 3 — "hint_objectives" references petitioners instead of a reputation threshold

**File:** `scripts/tutorial_system.gd:207–213`

The HINT-09 banner text reads:

> *"Press J and open the Objectives tab to see Lord Fenn's current reputation and **how many petitioners you still need**. You have 30 days."*

"How many petitioners you still need" implies a headcount objective. The actual win condition is a reputation score threshold (`rep < 30`), not a petition count. The victory narrative does mention seven signatories, but that's flavour — the mechanical condition is numeric reputation, not petition count.

A first-time player who reads this hint may spend time counting who believes the rumour rather than watching Fenn's score.

**Recommendation:** Replace "how many petitioners you still need" with "how far Edric Fenn's reputation has fallen". Suggested text:

> *"Press J and open the Objectives tab to track Edric Fenn's current reputation score. You need to bring it below 30. You have 30 days."*

---

## 3. Mid-Game Pacing

### What works

- **Day/time counter** updates every tick. Players always know where they are in the 30-day window.
- **Progress bar colour shift** (amber → orange-red after day 22/30) provides urgency cue without being alarming too early.
- **3 Recon Actions + 1 Whisper Token per day** creates meaningful resource tension without feeling punishing — the refresh-at-dawn cadence is well-explained in both the banner system and the How to Play screen.
- **Social graph edge weights** around Edric Fenn (Bram Guard 0.90, Calder 0.70, Isolde 0.75, Bram→Edric 0.85) create a realistic loyalty cluster that requires players to think about flanking paths rather than seeding Fenn directly. This is well-tuned for a tutorial scenario — the challenge is real but navigable.
- **Threshold raised from 25 to 30 (SPA-98)** is the correct call. Edric's credulity at 0.05 and loyalty at 0.80 mean direct attacks stall. The extra 5-point headroom gives new players room to experiment with indirect seeding paths without hitting a brick wall.

### Potential dead spot: Days 1–2 before social intel

New players have 0 eavesdrop intel at game start. Without knowing ally relationships, seed target selection in the Rumour Panel feels arbitrary. The HINT-06 "Craft a Rumour" banner fires on Day 2 tick, which means it nudges the player toward the panel before they may have gathered enough intel to make a meaningful seed choice. The result is players may seed into a low-sociability NPC and see no propagation, which reads as "the game isn't working."

**Recommendation (low priority):** Consider whether HINT-06 should instead fire after the player has at least one eavesdrop entry in their intel log, rather than strictly on Day 2. The existing `_banner_eavesdrop_gate` flag could guard this: fire the rumour panel hint only if `_banner_eavesdrop_gate == true`, falling back to the Day 2 tick otherwise.

---

## 4. Win/Lose Clarity

### What works

- **Win condition** (Edric rep < 30) is checked every tick and resolves immediately when met.
- **Fail conditions** — timeout (Day > 30) and player exposure — are unambiguous.
- **End screen** (SPA-138) is complete and polished: narrative summary, two-column stats card (Days, Rumors Seeded, NPCs Reached, Peak Belief), three key NPC final scores, and buttons for Play Again / Next Scenario / Main Menu.
- **Victory and fail narrative texts** are all final — no placeholder prose. The exposed-fail text ("The Guard Captain's eyes found you across the Market Square") and timeout-fail text ("The autumn tax rolls were signed. Lord Edric Fenn's seal was already dry.") are both evocative and clear about what happened.

### Stale code comment

**File:** `scripts/scenario_manager.gd:8`

The header comment reads:

```
## Scenario 1 — The Alderman's Ruin:
##   WIN:  reputation(edric_fenn) < 30
```

The actual constant on line 76 is `S1_WIN_EDRIC_BELOW := 30`. This discrepancy is harmless at runtime but will confuse anyone reading the code, and is a misleading reference for QA testing.

**Recommendation:** Update the header comment to `< 30` to match the constant. One-line fix.

---

## 5. Content Gaps

None found in Scenario 1 scope.

- All scenario narrative fields populated: `introText`, `startingText`, `victoryText`, `failTexts["exposed"]`, `failTexts["timeout"]` — all final.
- NPC dialogue JSON: 1083 lines reviewed; all NPC states (ambient, hear, believe, reject, spread, act, defending) have complete dialogue for all characters relevant to Scenario 1. No empty strings, no "TODO" markers.
- Tutorial hint and tooltip bodies: all 10 hints and 9 tooltips have complete body text. `[evidence_name]` in `hint_evidence` is a dynamic substitution handled at queue time — not a placeholder.
- How to Play tabs: controls, mechanics, and systems all documented. Reputation tiers, heat thresholds, and propagation states accurate.
- Loading tips: 10 tips, all present and pedagogically relevant.

---

## Prioritised Action Items

| Priority | Issue | File | Fix |
|----------|-------|------|-----|
| **High** | Win condition not visible on Objective HUD | `scripts/objective_hud.gd` | Add Edric Fenn rep score + threshold to HUD (always visible) |
| **High** | "hint_objectives" text references petitioners not rep score | `scripts/tutorial_system.gd:210` | Rewrite to say "how far Edric Fenn's reputation has fallen" |
| **Medium** | No visual pointer to target NPC at game start | `scripts/main.gd` or `scripts/tutorial_banner.gd` | Add one-time hint or subtle target marker for Edric Fenn |
| **Low** | HINT-06 fires on Day 2 regardless of intel gathered | `scripts/main.gd:476` | Gate behind `_banner_eavesdrop_gate` as soft prerequisite |
| **Low** | Stale win condition comment in scenario_manager.gd | `scripts/scenario_manager.gd:8` | Update `< 25` → `< 30` in header comment |

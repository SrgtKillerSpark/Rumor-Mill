# Phase 1 EA Balance Proposal — Day 5 Signals

**Issue:** SPA-1299
**Author:** Game Designer
**Date:** 2026-04-30
**Status:** Draft for CEO review
**Sources:** `docs/balance-reference.md` (pre-launch concerns), `docs/post-launch-telemetry-plan.md` (KPI framework), `docs/community-feedback-plan.md` (channel monitoring), `docs/scenario-difficulty-and-events.md`

---

## Context

We are at Day 5 of Early Access (launched April 25). Telemetry is opt-in NDJSON and collection volume is still low. This proposal is based on **pre-launch internal testing signals** cross-referenced with the balance concerns flagged before launch, the KPI thresholds defined in the telemetry plan, and the first days of community channel monitoring. Concrete telemetry numbers will refine or override these recommendations as data accumulates through the Week 1-2 review cadence.

---

## Top 2 Scenario Tuning Candidates

### 1. Scenario 2 — Sister Maren Counter-Intelligence Calibration

**Player-experience hypothesis:** Maren's instant-fail mechanic creates a binary, RNG-flavored difficulty spike that punishes players who understand the rumor system but get unlucky with propagation routing. Players who lose to Maren feel cheated; players who never trigger her feel the scenario lacks tension.

**Signal:** The Maren-Alys edge weights (0.35/0.30) were set conservatively but have not been validated with a broad player base. The balance reference flags this as HIGH risk — if Maren-triggered fails dominate (>60% of S2 losses), the scenario feels like a coin flip rather than a puzzle.

**Proposed Phase 1 action:**
- Monitor KPI #2 (day-of-quit histogram) and the Maren-fail vs. timeout-fail ratio for S2.
- **If Maren fails >60%:** Reduce Maren-Alys edge weights from 0.35/0.30 to 0.25/0.20. This lowers accidental chain propagation while preserving the threat if the player seeds recklessly near Maren's orbit.
- **If Maren fails <10%:** Raise edges to 0.45/0.40 to restore counter-intelligence tension.
- Either adjustment is a single `scenarios.json` change — low-risk, no code change, hot-fixable.

### 2. Scenario 4 — Finn Monk Vulnerability and Early Inquisitor Pressure

**Player-experience hypothesis:** Finn Monk (credulity 0.60, loyalty 0.45) is dramatically more vulnerable than Aldous Prior or Vera Midwife. Once the Inquisitor cycles to Finn, his low loyalty makes recovery sluggish, and the absence of bribery in S4 removes the player's safety valve. Players likely feel that S4 is "about keeping Finn alive" rather than defending all three — collapsing the scenario's strategic identity into a single-NPC triage.

**Signal:** Internal testing consistently identified Finn as the failure trigger. The balance reference flags this as HIGH priority and recommends tracking which NPC triggers fail most often.

**Proposed Phase 1 action:**
- Monitor KPI #1 (completion rate) and per-NPC fail distribution for S4.
- **If >60% of S4 failures come from Finn:** Raise Finn's starting loyalty from 0.45 to 0.55 via `npcs.json` personality override in `scenarios.json`. This improves his gamma recovery rate without changing his credulity (he should still *believe* rumors easily — the tension is whether he *recovers*). Alternatively, raise Finn's starting reputation from 68 to 72, giving him 4 extra points of buffer.
- **If failures cluster in days 1-5:** Reduce Inquisitor early-phase intensity from 2 to 1, giving players more setup time before the pressure ramps.

---

## Top 2 Mid-Game Engagement Adjustments

### 1. Scenario 3 — Late-Phase Rival Pacing

**Hypothesis:** Despite the SPA-471 fix capping late-phase rival intensity at 3, the daily seed cadence (cooldown 1) from day 16 onward may still make late-game recovery feel impossible. Players who fall behind by day 15 have no viable comeback path, which discourages experimentation in the mid-game and rewards conservative early play over creative risk-taking.

**Proposed action:**
- Monitor KPI #1 and win-rate correlation with day-15 reputation snapshot (Balance Reference Priority 3).
- **If 90%+ of wins require Calder >65 at day 15:** Extend late-phase rival cooldown from 1 to 2 days. This preserves the rival as a credible threat while opening a narrow window for late-game pivots. The change is a single constant in `rival_agent.gd`.

### 2. Spymaster Whisper Economy Floor

**Hypothesis:** At 1 whisper/day, Scenarios 3 and 4 on Spymaster difficulty may cross from "hard" to "helpless." S3 gives 20 whispers against an accelerated rival across two fronts. S4 gives 15 whispers for purely defensive play with no bribery. Players selecting Spymaster expect a challenge, not an impossible resource starvation.

**Proposed action:**
- Monitor KPI #10 (difficulty distribution) and per-scenario Spymaster completion rates.
- **If any scenario has <5% Spymaster completion after 500+ attempts:** Introduce a whisper floor of 2/day for that scenario on Spymaster. This still halves the Master economy but prevents the resource desert that makes strategic play impossible.
- This requires a small change in `game_state.gd` difficulty modifiers — adding a per-scenario override for `daily_whispers` on Spymaster.

---

## Explicit Non-Goal: Evidence Item Rebalancing

**What we are choosing NOT to touch in Phase 1:** The balance between Forged Document (+0.20 believability), Incriminating Artifact (+0.25), and Witness Account (+0.15, -0.15 mutability) will not be adjusted.

**Why:** The balance reference flags this as LOW priority. The concern — that Document and Artifact feel interchangeable — is a strategic depth issue, not a player-frustration issue. Players are not failing scenarios because of evidence balance. Differentiating these items meaningfully (e.g., giving Artifact a mutability reduction or expanding Document's claim compatibility) requires design iteration that would compete for bandwidth with the higher-impact scenario tuning above. We need telemetry on evidence usage patterns (KPI not yet defined — would require a new event) before making changes that could inadvertently nerf a tool players rely on. This is Phase 2 work at earliest.

---

## Implementation Notes

- All scenario tuning candidates involve data file or single-constant changes — no architectural work, no new systems.
- Each adjustment has a clear telemetry trigger threshold. We do not act until data confirms the hypothesis.
- The weekly review cadence (Monday/Wednesday/Friday per the telemetry plan) provides natural decision points.
- Target window for first balance patch: Day 10-14 (May 5-9), shipped separately from bug fixes per the community feedback plan.

---

*References: [SPA-920](/SPA/issues/SPA-920), [SPA-1140](/SPA/issues/SPA-1140), [SPA-1295](/SPA/issues/SPA-1295)*

**Telemetry watchlist:** [phase1-balance-watchlist.md](phase1-balance-watchlist.md) — per-proposal telemetry signals, thresholds, and actions (SPA-1413).

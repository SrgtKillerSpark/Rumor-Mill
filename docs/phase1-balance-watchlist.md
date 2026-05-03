# Phase 1 Balance Watchlist

**Issue:** SPA-1413
**Author:** Game Designer
**Date:** 2026-04-30
**Status:** Living document
**Sources:** [phase1-balance-proposal.md](phase1-balance-proposal.md), [post-launch-telemetry-plan.md](post-launch-telemetry-plan.md), AnalyticsManager (SPA-1241)

---

## How to Use This Watchlist

Each row maps a balance proposal to the telemetry signal that triggers action. During the Monday/Wednesday/Friday review cadence (per the telemetry plan), check each applicable row. When a threshold is crossed for 2+ consecutive review cycles, execute the listed action and log the change in the weekly telemetry digest.

**Event legend:** All events reference `AnalyticsManager` emissions logged to `user://analytics.json` as NDJSON.

---

## Scenario 2 — Sister Maren Counter-Intelligence Calibration

| # | Proposal | Telemetry Signal | How to Derive | Threshold | Action | Config Location | Owner |
|---|----------|-----------------|---------------|-----------|--------|-----------------|-------|
| 2-A | Reduce Maren edge weights if she dominates S2 losses | **Maren-fail ratio**: correlate `npc_state_changed` (npc_name contains "Maren", new_state = "REJECT") with `scenario_ended` (scenario_id = "scenario_2", outcome = "FAILED") in the same session | Count S2 failed sessions that contain a Maren REJECT event vs. those that don't (timeout-fails). Ratio = Maren-fails / total S2 fails. | Maren fails **>60%** of S2 losses | Reduce Maren-Alys edge weights from 0.35/0.30 to **0.25/0.20** in `scenarios.json` | `rumor_mill/data/scenarios.json` — S2 edge weights | Game Designer |
| 2-B | Raise Maren edge weights if she's a non-factor | Same as 2-A | Same derivation, opposite threshold | Maren fails **<10%** of S2 losses (after 50+ S2 sessions) | Raise Maren-Alys edge weights from 0.35/0.30 to **0.45/0.40** | `rumor_mill/data/scenarios.json` — S2 edge weights | Game Designer |
| 2-C | Detect S2 difficulty wall | KPI #2: `scenario_ended` (scenario_id = "scenario_2", outcome = "FAILED") — histogram `day_reached` | Group failed S2 sessions by `day_reached`. Flag if any single day concentrates >40% of failures. | Any day has **>40%** of S2 failure exits | Investigate: if wall is days 5-8 (early push), consider adjusting IllnessEscalationAgent initial cooldown; if wall is days 13-16 (Alys Fights Back event), review event balance | Depends on wall location | Game Designer |
| 2-D | Monitor S2 rumor propagation health | KPI #4 & #5: `rumor_seeded` + `npc_state_changed` for scenario_2 | Seed-to-first-believer time (median days). Adoption funnel: BELIEVE:SPREAD ratio, REJECT rate. | Seed-to-believe **>4 days** median OR REJECT rate **>80%** in S2 | Credulity tuning needed — review NPC credulity values in `npcs.json` for S2 cast | `rumor_mill/data/npcs.json` | Game Designer |

### Scenario 2 — Gap Analysis

**No missing events.** The Maren-fail ratio can be derived by correlating `npc_state_changed` (REJECT events for Maren) with `scenario_ended` (FAILED outcomes) within the same session file. The correlation requires matching events by `scenario_id` within a single NDJSON file (one file = one player's session history).

---

## Scenario 3 — Late-Phase Rival Pacing

| # | Proposal | Telemetry Signal | How to Derive | Threshold | Action | Config Location | Owner |
|---|----------|-----------------|---------------|-----------|--------|-----------------|-------|
| 3-A | Extend late-phase rival cooldown if day-15 reputation determines all outcomes | **Win-rate vs. day-15 Calder reputation**: `reputation_delta` (npc_id = "Calder", scenario_id = "scenario_3") + `scenario_ended` | Reconstruct Calder's reputation at day 15 by summing `reputation_delta` events from session start through day 15. Cross-reference with session outcome. **WARNING: lossy** — `reputation_delta` only fires when abs(delta) >= 3, so small daily shifts are invisible. See gap note below. | **90%+** of S3 wins have Calder >65 at day 15 | Extend late-phase rival cooldown from 1 to **2 days** in `rival_agent.gd` phase-3 config | `rumor_mill/scripts/rival_agent.gd` — phase 3 cooldown constant | Lead Engineer |
| 3-B | Detect S3 mid-game disengagement | KPI #2 + #3: `scenario_ended` (scenario_id = "scenario_3") | Day-of-quit histogram for failed S3 sessions. If failures cluster at days 15-19 (Crisis phase), players are giving up once the rival accelerates. | **>50%** of S3 failures have day_reached between 15-19 | Confirms the "no comeback" hypothesis — proceed with 3-A cooldown change | N/A (diagnostic) | Game Designer |
| 3-C | Monitor rival disruption impact | `reputation_delta` (scenario_id = "scenario_3") | Track frequency and magnitude of negative reputation deltas during days 16-27 (rival phase 3). High frequency of large negative deltas = rival is overwhelming. | Mean negative delta **> -6** per event in phase 3 AND **>1 event/day** | Rival intensity is too high — reduce phase-3 intensity cap (currently 3 per SPA-471 fix) to 2 | `rumor_mill/scripts/rival_agent.gd` — intensity cap | Lead Engineer |
| 3-D | Spymaster whisper economy floor (S3) | KPI #1 + #10: `scenario_selected` (difficulty = "spymaster", scenario_id = "scenario_3") + `scenario_ended` | Spymaster completion rate for S3 = WON / selected, filtered to spymaster difficulty. | **<5% completion** after **500+ Spymaster S3 attempts** | Introduce whisper floor of **2/day** for S3 on Spymaster difficulty | `rumor_mill/scripts/game_state.gd` — difficulty modifiers, add per-scenario `daily_whispers` override | Lead Engineer |

### Scenario 3 — Gap Analysis

**One gap identified:**

| Gap | Missing Signal | Why It Matters | Recommended New Event |
|-----|---------------|----------------|----------------------|
| **Day-15 reputation snapshot** | No point-in-time reputation snapshot event exists. `reputation_delta` only fires when abs(delta) >= 3, making day-15 reconstruction lossy. | Proposal 3-A's threshold ("90%+ of wins require Calder >65 at day 15") cannot be reliably evaluated without knowing exact reputation at the checkpoint. | **`reputation_snapshot`** — fire once per day (on `day_changed` signal) with payload: `{ npc_id, score, day, scenario_id }`. Scope to tracked NPCs only (win-condition NPCs for the active scenario) to limit volume. |

> **Follow-up issue needed:** File an engineering ticket for the `reputation_snapshot` event. Until it ships, use the lossy `reputation_delta` reconstruction as a directional signal — if even the incomplete data shows the pattern, the real data will only confirm it.

---

## Cross-Scenario: Spymaster Whisper Economy

| # | Proposal | Telemetry Signal | How to Derive | Threshold | Action | Config Location | Owner |
|---|----------|-----------------|---------------|-----------|--------|-----------------|-------|
| X-A | Whisper floor for any scenario on Spymaster | KPI #1 + #10: `scenario_selected` + `scenario_ended`, filtered to difficulty = "spymaster" | Per-scenario Spymaster completion rate. Compute separately for each scenario_id. | **<5% completion** on any scenario after **500+ Spymaster attempts** on that scenario | Add whisper floor of **2/day** for the affected scenario on Spymaster | `rumor_mill/scripts/game_state.gd` — per-scenario daily_whispers override | Lead Engineer |

**No missing events.** Existing `scenario_selected` and `scenario_ended` events carry both `difficulty` and `scenario_id` fields, which is sufficient.

---

## Priority Watch Order (First 3 Signals)

These are the signals to check first during Week 1-2 reviews, in order of impact:

1. **Maren-fail ratio (2-A/2-B)** — Highest confidence, most actionable. The Maren instant-fail mechanic is the single most complained-about balance concern from internal testing. The signal is clean (REJECT event + FAILED outcome = unambiguous), the threshold is clear (>60%), and the fix is a one-line JSON change. Check this every Monday review.

2. **S3 day-of-quit clustering (3-B)** — Second-highest impact. If S3 failures pile up at days 15-19, it directly validates the "no comeback" hypothesis and justifies the rival cooldown change. The signal is purely from `scenario_ended` (no reconstruction needed), making it reliable even at low data volumes. Check this every Monday review.

3. **Spymaster completion rates (X-A)** — Third priority. This is a slower burn — we need 500+ attempts to be statistically meaningful — but if any scenario hits <5% on Spymaster, it's an emergency for that difficulty tier. Check this every Friday review once volume permits.

---

## Review Schedule Alignment

| Review Day | Watchlist Rows to Check | Telemetry Plan KPIs |
|-----------|------------------------|---------------------|
| **Monday** | 2-A, 2-B, 2-C, 3-B | KPI #1 (completion rate), KPI #2 (quit histogram) |
| **Wednesday** | 2-D, 3-A, 3-C | KPI #4 (seed-to-believe), KPI #5 (adoption funnel), KPI #8 (rep volatility) |
| **Friday** | 3-D, X-A | KPI #10 (difficulty distribution), KPI #1 (Spymaster slice) |

---

---

## Trigger Spec (SPA-1514)

**Structured spec file:** [`phase1-balance-watchlist.spec.yaml`](phase1-balance-watchlist.spec.yaml)

The YAML spec defines each watchlist trigger in a format the `kpi_aggregate.js` CLI can ingest programmatically. Each trigger includes:

| Field | Purpose |
|-------|---------|
| `id` | Watchlist row reference (e.g., "2-A") |
| `events` | Source AnalyticsManager event type(s) |
| `filter` | Field-level predicates to select relevant events |
| `aggregation` | Reduction logic (human-readable + metric name) |
| `metric` | Named output value to evaluate |
| `threshold` | Operator + value that fires the trigger |
| `min_sample` | Minimum N before evaluating — avoids acting on noise |
| `action` | What to do when fired |
| `config_path` | File to edit (null if diagnostic-only) |
| `owner` | Responsible role |

### Minimum Sample Sizes

| Trigger | Minimum N | Rationale |
|---------|-----------|-----------|
| 2-A Maren dominates | 30 S2 failed sessions | Need enough failures to establish pattern vs. variance |
| 2-B Maren non-factor | 50 S2 failed sessions | Higher bar for "non-factor" claim (low-rate signals need more data) |
| 2-C S2 wall | 40 S2 failed sessions | Histogram needs breadth to distinguish walls from noise |
| 2-D S2 propagation | 20 seed→believe pairs | Pairs are rarer than sessions; 20 gives stable median |
| 3-A Calder day-15 | 25 S3 won sessions w/ Calder data | Lossy reconstruction needs more samples to compensate |
| 3-B S3 mid-quit | 30 S3 failed sessions | Same rationale as 2-A |
| 3-C Rival intensity | 20 S3 sessions reaching day 16 | Only late-game sessions count; lower bar for compound threshold |
| 3-D Spymaster S3 | 500 Spymaster S3 attempts | High bar because <5% is extreme; small N produces false alarms |
| 4-A Finn dominates | 30 S4 failed sessions | Mirror of 2-A |
| 4-B Finn non-factor | 50 S4 failed sessions | Mirror of 2-B |
| X-A Spymaster any | 500 Spymaster attempts per scenario | Same as 3-D |
| GEN-WALL any wall | 40 failed sessions per scenario | Same as 2-C |
| GEN-COMP completion | 30 sessions per scenario+difficulty | Stable completion rate estimate |

### Firing Protocol

A trigger fires only when **both** conditions are met:
1. `min_sample` threshold is satisfied (volume guard)
2. The metric crosses the threshold for **2+ consecutive review cycles** (MWF cadence per Review Schedule above)

Single-cycle spikes are logged but not actioned. This two-cycle rule prevents knee-jerk changes on noisy early data.

### Integration with kpi_aggregate.js

The engineer (SPA-1490) can load this spec via:
```js
const yaml = require('yaml'); // or inline parser
const spec = yaml.parse(fs.readFileSync('docs/phase1-balance-watchlist.spec.yaml', 'utf8'));
for (const trigger of spec.triggers) {
  // evaluate trigger.metric against trigger.threshold
  // skip if sample count < trigger.min_sample.min
}
```

The existing hardcoded `wlMarenFail`, `wlCalderDay15`, `wlS3MidQuit`, and `wlNpcRejectFail` functions in `kpi_aggregate.js` already implement triggers 2-A/2-B, 3-A, 3-B respectively. The spec file formalizes these plus adds 2-C, 2-D, 3-C, 3-D, 4-A, 4-B, X-A, GEN-WALL, and GEN-COMP as new evaluations.

---

*Cross-reference: [phase1-balance-proposal.md](phase1-balance-proposal.md) | [post-launch-telemetry-plan.md](post-launch-telemetry-plan.md) | [scenario-difficulty-and-events.md](scenario-difficulty-and-events.md)*

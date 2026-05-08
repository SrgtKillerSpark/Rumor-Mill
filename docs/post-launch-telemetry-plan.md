# Post-Launch Telemetry Plan

**Issue:** SPA-1140
**Status:** Draft for review
**Date:** 2026-04-30
**Data source:** `AnalyticsManager` + `AnalyticsLogger` (NDJSON to `user://analytics.json`)

---

## Current Event Surface

The existing `AnalyticsManager` emits six event types. All metrics below are derived from these events unless flagged as **[NEW EVENT NEEDED]**.

| # | Event | Key Fields |
|---|-------|-----------|
| 1 | `scenario_selected` | scenario_id, difficulty |
| 2 | `rumor_seeded` | subject_name, claim_id, seed_target, day, scenario_id |
| 3 | `npc_state_changed` | npc_name, rumor_id, new_state, day, scenario_id |
| 4 | `evidence_interaction` | action_type (observe/eavesdrop), success, day, scenario_id |
| 5 | `reputation_delta` | npc_id, from_score, to_score, delta, day, scenario_id |
| 6 | `scenario_ended` | scenario_id, difficulty, outcome (WON/FAILED), day_reached, duration_sec |

---

## KPI Definitions (12 Metrics)

### 1. Per-Scenario Completion Rate

| | |
|---|---|
| **Source events** | `scenario_selected`, `scenario_ended` |
| **Aggregation** | `COUNT(outcome=WON) / COUNT(scenario_selected)` grouped by scenario_id and difficulty |
| **Healthy** | 40-70% on Normal difficulty |
| **Unhealthy** | <25% (too hard) or >85% (too easy) |
| **Informs** | Scenario balance tuning, difficulty curve |

### 2. Day-of-Quit Histogram

| | |
|---|---|
| **Source events** | `scenario_ended` (outcome=FAILED) |
| **Aggregation** | Histogram of `day_reached` for failed sessions, per scenario_id |
| **Healthy** | Spread across multiple days with gradual tapering |
| **Unhealthy** | Sharp spike on a single day (wall), or >50% quit on day 1-2 |
| **Informs** | Identifying difficulty walls; scenario pacing fixes |

### 3. Session Duration by Outcome

| | |
|---|---|
| **Source events** | `scenario_ended` |
| **Aggregation** | Median and p90 `duration_sec` grouped by scenario_id, outcome |
| **Healthy** | Won sessions: 8-20 min; Failed sessions: 3-15 min |
| **Unhealthy** | Won sessions <4 min (trivial) or >30 min (slog); Failed <1 min (instant rage-quit) |
| **Informs** | Pacing, scenario length calibration |

### 4. Rumor Seed-to-First-Believer Time

| | |
|---|---|
| **Source events** | `rumor_seeded`, `npc_state_changed` (new_state=BELIEVE) |
| **Aggregation** | For each rumor seed, `MIN(day of first BELIEVE) - day of seed`. Median per scenario. |
| **Healthy** | 1-3 day gap |
| **Unhealthy** | >4 days median (rumor mechanics feel unresponsive) or 0 days consistently (too instant) |
| **Informs** | Rumor propagation speed balance, NPC credulity tuning |

### 5. Rumor Adoption Funnel

| | |
|---|---|
| **Source events** | `npc_state_changed` |
| **Aggregation** | Per rumor_id: count of NPCs reaching each state (BELIEVE -> SPREAD -> ACT), plus REJECT count |
| **Healthy** | BELIEVE:SPREAD ratio > 0.4; REJECT rate < 60% |
| **Unhealthy** | SPREAD rate < 20% of BELIEVE (rumors stall); REJECT > 80% (player feels powerless) |
| **Informs** | NPC resistance tuning, rumor mechanic satisfaction |

### 6. Recon Action Rate per Day

| | |
|---|---|
| **Source events** | `evidence_interaction` |
| **Aggregation** | Count of observe + eavesdrop actions per in-game day, per session |
| **Healthy** | 2-6 actions per day |
| **Unhealthy** | <1/day (players ignoring recon) or >10/day (spam-clicking, unclear feedback) |
| **Informs** | Recon UI clarity, action economy balance |

### 7. Recon Success Rate

| | |
|---|---|
| **Source events** | `evidence_interaction` |
| **Aggregation** | `COUNT(success=true) / COUNT(*)` per action_type, per scenario |
| **Healthy** | 50-80% |
| **Unhealthy** | <30% (frustrating) or >95% (no tension) |
| **Informs** | Difficulty of observe/eavesdrop mechanics |

### 8. Reputation Volatility Index

| | |
|---|---|
| **Source events** | `reputation_delta` |
| **Aggregation** | Mean absolute `delta` per scenario per session; count of reputation events per session |
| **Healthy** | 2-5 meaningful shifts per session; mean |delta| of 4-8 |
| **Unhealthy** | >10 shifts/session (chaotic) or <1 (static, player has no impact) |
| **Informs** | Reputation system responsiveness, balance of NPC opinion mechanics |

### 9. Scenario Attempt Sequence (Player Progression)

| | |
|---|---|
| **Source events** | `scenario_selected`, `scenario_ended` |
| **Aggregation** | Ordered list of scenario_ids per player session file; count retries of same scenario before moving on |
| **Healthy** | 1-3 retries before progressing; players reaching scenario 4+ |
| **Unhealthy** | >5 retries on one scenario (stuck); most players never attempt scenario 3+ (drop-off) |
| **Informs** | Unlock gating, difficulty progression, tutorial effectiveness |

### 10. Difficulty Distribution

| | |
|---|---|
| **Source events** | `scenario_selected` |
| **Aggregation** | Percentage of sessions by difficulty setting per scenario |
| **Healthy** | Normal: 50-70%, Easy: 15-30%, Hard: 10-25% |
| **Unhealthy** | Easy >50% (base game too hard, players self-selecting down) |
| **Informs** | Default difficulty calibration, whether Normal feels right |

### 11. Tutorial Step Abandonment

| | |
|---|---|
| **Source events** | **[NEW EVENT NEEDED]** `tutorial_step_completed(step_id, scenario_id)` |
| **Aggregation** | Drop-off rate between consecutive tutorial steps in scenario 1 |
| **Healthy** | <15% drop between any two consecutive steps |
| **Unhealthy** | >30% drop at any single step (confusing instruction) |
| **Informs** | Tutorial UX revision, tooltip clarity |

### 12. Settings-Touched Percentage

| | |
|---|---|
| **Source events** | **[NEW EVENT NEEDED]** `settings_changed(setting_key, old_value, new_value)` |
| **Aggregation** | % of sessions where at least one setting is changed; which settings are changed most |
| **Healthy** | 10-30% of sessions touch settings (options exist but defaults work) |
| **Unhealthy** | >50% (defaults are wrong) or 0% (players don't know settings exist) |
| **Informs** | Default configuration quality, settings discoverability |

---

## New Events Needed (Engineering Addendum)

Two new events are required. Both are lightweight fire-and-forget calls matching the existing `AnalyticsLogger.log_event()` pattern.

| Event | Payload | Where to Wire |
|-------|---------|---------------|
| `tutorial_step_completed` | `step_id: String, scenario_id: String` | Tutorial/onboarding controller, on each step dismiss |
| `settings_changed` | `setting_key: String, old_value: String, new_value: String` | `SettingsManager` on any value write |

These can be spun into a child engineering ticket.

---

## Weekly Review Cadence

| Day | Who | What | Action Types |
|-----|-----|------|-------------|
| **Monday** | Game Designer | Review per-scenario completion rates (#1), day-of-quit histograms (#2), difficulty distribution (#10) | Balance tweaks (NPC resistance, day limits, resource counts) |
| **Wednesday** | Game Designer + Lead Engineer | Review rumor funnel (#5), seed-to-believer time (#4), reputation volatility (#8) | Propagation tuning, NPC trait adjustments |
| **Friday** | Game Designer | Review recon rates (#6, #7), session duration (#3), progression (#9) | UI fixes, tutorial revision, pacing changes |
| **Friday** | Lead Engineer | Review tutorial abandonment (#11), settings-touched (#12) — once new events ship | UX polish, default settings adjustment |

**Process:**
1. Export `analytics.json` from itch.io feedback channel / direct submissions (players opt in via `SettingsManager.analytics_enabled`).
2. Run aggregation script against collected NDJSON files.
3. Flag any metric outside healthy thresholds.
4. Log findings in a weekly telemetry digest (short doc or issue comment).
5. Metrics outside thresholds for 2+ consecutive weeks trigger a dedicated fix ticket.

---

## First 72 Hours Dashboard

The obsessive-watch dashboard for launch days 1-3. All metrics computed on a rolling basis as data arrives.

```
+-----------------------------------------------------------------------+
|  FIRST 72 HOURS — RUMOR MILL LAUNCH DASHBOARD                        |
+-----------------------------------------------------------------------+
|                                                                       |
|  [1] SCENARIO FUNNEL            [2] QUIT WALLS                       |
|  +--------------------------+   +--------------------------+          |
|  | S1: ███████████ 68% win  |   | S1 quit-day histogram    |          |
|  | S2: ████████   52% win   |   |  D1 ██                   |          |
|  | S3: █████     38% win    |   |  D2 ████                 |          |
|  | S4: ████      31% win    |   |  D3 ██████               |          |
|  | S5: ███       24% win    |   |  D4 ███                  |          |
|  | S6: ██        18% win    |   |  D5 █                    |          |
|  +--------------------------+   +--------------------------+          |
|                                                                       |
|  [3] SESSION HEALTH             [4] RUMOR MECHANICS                   |
|  +--------------------------+   +--------------------------+          |
|  | Median duration: 12m     |   | Seed-to-believe: 1.8 days|          |
|  | p90 duration:    22m     |   | Adoption funnel:         |          |
|  | Rage-quit (<1m): 3%      |   |  BELIEVE  ██████████ 100%|          |
|  | Slog (>30m):     5%      |   |  SPREAD   ██████    58%  |          |
|  +--------------------------+   |  ACT      ███       27%  |          |
|                                 |  REJECT         34%      |          |
|  [5] PLAYER ACTIONS             +--------------------------+          |
|  +--------------------------+                                         |
|  | Recon/day avg:  3.4      |   [6] RED FLAGS (auto-alert)            |
|  | Recon success:  64%      |   +--------------------------+          |
|  | Rep shifts/ses: 3.1      |   | ! S3 completion < 25%    |          |
|  | Difficulty mix:           |   | ! S1 day-2 quit spike    |          |
|  |  Easy 22% Norm 61% Hrd 17|   | ! Recon success < 30%    |          |
|  +--------------------------+   +--------------------------+          |
|                                                                       |
|  [7] VOLUME                                                           |
|  Total sessions: ____  |  Unique analytics files: ____               |
|  Sessions today: ____  |  Scenarios attempted today: ____            |
+-----------------------------------------------------------------------+
```

**Red Flag auto-alerts** (check every 12 hours during first 72h):
- Any scenario completion rate drops below 25% on Normal
- Any single quit-day concentrates >40% of failures for a scenario
- Recon success rate drops below 30% (mechanic is broken/confusing)
- Rage-quit rate (sessions <60s) exceeds 10%
- Seed-to-first-believer median exceeds 4 days in any scenario
- REJECT rate exceeds 80% for any rumor type

---

## Notes

- All data is opt-in via `SettingsManager.analytics_enabled` and stored locally as NDJSON. Collection depends on players sharing their `analytics.json` (e.g., via feedback form or itch.io upload).
- No PII is collected; events use in-game identifiers only.
- This plan reuses the existing 6-event surface for 10 of 12 metrics. Only 2 lightweight new events are proposed.

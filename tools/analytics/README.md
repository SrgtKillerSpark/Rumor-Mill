# Rumor Mill — Telemetry KPI Aggregation

Offline script that consumes `analytics.json` NDJSON exports from the
`AnalyticsLogger` and computes the 12 KPIs defined in
[`docs/post-launch-telemetry-plan.md`](../../docs/post-launch-telemetry-plan.md)
([SPA-1140](/SPA/issues/SPA-1140)).

## Requirements

- Node.js 16+ (no external packages — stdlib only)

## Usage

```sh
# Single file
node tools/analytics/kpi_aggregate.js path/to/analytics.json

# Multiple files (one per player)
node tools/analytics/kpi_aggregate.js exports/player_*.ndjson

# Save digest to a file
node tools/analytics/kpi_aggregate.js exports/*.ndjson > digest-2026-04-30.md
```

## Input format

Each input file must be **NDJSON** (one JSON object per line) matching the
output of `AnalyticsLogger.log_event()`.  The logger writes to
`user://analytics.json`; collect this file from players via your feedback
channel.

Recognised event types and their required fields:

| Event | Key fields |
|-------|-----------|
| `scenario_selected` | `scenario_id`, `difficulty` |
| `scenario_ended` | `scenario_id`, `difficulty`, `outcome` (WON\|FAILED), `day_reached`, `duration_sec` |
| `rumor_seeded` | `claim_id`, `day`, `scenario_id` |
| `npc_state_changed` | `npc_name`, `rumor_id`, `new_state` (BELIEVE\|SPREAD\|ACT\|REJECT), `day`, `scenario_id` |
| `evidence_interaction` | `action_type` (observe\|eavesdrop), `success` (bool), `day`, `scenario_id` |
| `reputation_delta` | `npc_id`, `delta`, `day`, `scenario_id` |

> **Note on KPI 4 (seed-to-believer):** the join key between `rumor_seeded`
> and `npc_state_changed` is `claim_id` = `rumor_id`.  Both fields must carry
> the same rumor identifier for the gap calculation to work.

## Output

Markdown digest printed to stdout with sections:

1. **KPI 1–10** — one section per metric, tabular or histogram format
2. **KPI 11 & 12** — stubs until `tutorial_step_completed` / `settings_changed`
   events are wired in (Lead Engineer task, see SPA-1140 engineering addendum)
3. **Red Flags** — auto-detected threshold violations from the plan
4. **Volume** — total files / sessions / events processed

## Smoke fixture

Two synthetic player files live under `fixtures/`:

| File | Sessions | Notes |
|------|----------|-------|
| `player_a.ndjson` | 4 | S1 win, S2 win, S3 fail+win (retry) |
| `player_b.ndjson` | 4 | S1 easy win, S1 normal fail+win, S4 hard fail |

Run the smoke test:

```sh
node tools/analytics/kpi_aggregate.js tools/analytics/fixtures/*.ndjson
```

Expected output includes:
- S1 Normal completion 66.7% (healthy)
- S4 eavesdrop/observe success 0.0% (red flag — Hard scenario has no observe
  successes in the fixture, exercising the < 30% threshold)
- S4 funnel REJECT 100% red flag (all NPCs rejected the rumor)
- KPI 11 & 12 stub messages

> Quit-wall flags for single-failure scenarios in the fixture are expected —
> with only one failed session a single day always concentrates 100%.  With
> real multi-player data the histogram spreads naturally.

## Adding new events (KPIs 11 & 12)

Once `tutorial_step_completed` and `settings_changed` are emitted by the
runtime, extend `kpi11()` and `kpi12()` in `kpi_aggregate.js` following the
same session-grouping pattern used by the existing KPIs.

## Weekly review workflow

1. Collect `analytics.json` files from players (itch.io feedback form / direct
   submissions).
2. Run: `node tools/analytics/kpi_aggregate.js exports/*.ndjson > digest.md`
3. Review `digest.md` — any 🚨 lines need immediate triage.
4. Paste digest into the weekly telemetry comment on the active sprint issue.
5. Metrics outside thresholds for 2+ consecutive weeks → open a dedicated fix
   ticket.

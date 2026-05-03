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

Synthetic player files live under `fixtures/`:

| File | Sessions | Notes |
|------|----------|-------|
| `player_a.ndjson` | 4 | S1 win, S2 win, S3 fail+win (retry) |
| `player_b.ndjson` | 4 | S1 easy win, S1 normal fail+win, S4 hard fail |
| `player_c.ndjson` | 1 | S1 win with tutorial + settings events (KPI 11/12) |
| `player_d.ndjson` | 1 | S1 early fail |
| `watchlist_smoke.ndjson` | 4 | **Watchlist fixture** — S2 win, S2 Maren-fail, S3 win, S3 timeout-fail (day-17) |
| `evidence_events_smoke.ndjson` | 3 | Evidence smoke — S2 Normal/Hard + S3 Normal, mixed acquired + used |
| `evidence_happy_path.ndjson` | — | **Evidence regression** — happy path: 2 forged_document + 1 witness_account acquired and used, full field set |
| `evidence_acquired_only.ndjson` | — | **Evidence regression** — mixed: acquired but never used; acqToUseRatio should show ratio=0 |
| `evidence_malformed.ndjson` | — | **Evidence regression** — edge: invalid JSON lines + missing fields skipped without crash |

Run the full test suite (smoke + evidence aggregation regression tests):

```sh
bash tools/analytics/test_kpi_aggregate.sh
```

Run the full smoke test only:

```sh
node tools/analytics/kpi_aggregate.js tools/analytics/fixtures/*.ndjson
```

Run the watchlist-specific smoke test (SPA-1453):

```sh
node tools/analytics/kpi_aggregate.js tools/analytics/fixtures/watchlist_smoke.ndjson
```

Expected output from the watchlist smoke fixture:
- **Maren-fail ratio 100%** (1/1 S2 failures caused by Maren rejection) → `🚨 reduce edge weights` on row 2-A
- **Calder day-15 rep reconstruction**: med 65, 100% of S3 wins > 65 → `🚨 extend rival cooldown` on row 3-A
- **S3 mid-game quit 100%** (1/1 S3 failures at day 17, in range 15–19) → `🚨 mid-game disengagement` on row 3-B
- **Per-NPC REJECT table** showing Sister Maren at 100% fail correlation

Expected output from the full fixture set:
- S1 Normal completion 66.7% (healthy)
- S4 eavesdrop/observe success 0.0% (red flag — Hard scenario exercises the < 30% threshold)
- S4 funnel REJECT 100% red flag
- KPI 11 & 12 data from player_c / player_d

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

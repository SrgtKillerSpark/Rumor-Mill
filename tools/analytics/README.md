# Evidence Telemetry Aggregation

Cross-tab aggregation scripts for Phase 2 evidence economy telemetry, as specified in [SPA-1522](https://paperclip.ing/SPA/issues/SPA-1522#document-phase2-evidence-telemetry-spec).

## Prerequisites

- Node.js 18+

## Quick Start

```bash
# Generate synthetic fixtures (deterministic)
node tools/analytics/generate_fixtures.js

# Run aggregation against fixtures
node tools/analytics/aggregate_evidence.js

# Run against a custom data directory
node tools/analytics/aggregate_evidence.js /path/to/ndjson/dir

# Validate (regenerate + compare to golden snapshot)
node tools/analytics/validate.js
```

## Cross-Tabs Produced

The aggregation script (`aggregate_evidence.js`) produces the following tables:

| # | Cross-Tab | Question It Answers |
|---|-----------|-------------------|
| 1 | `evidence_type` × `scenario_id` × `difficulty` (acquisition) | Which evidence types are players acquiring, and in which contexts? |
| 2 | `day` histogram per evidence type | When in a run do players acquire each evidence type? |
| 3 | `source_action` ratio per type | What fraction of evidence comes from observe vs. eavesdrop? |
| 4 | `evidence_type` × `scenario_id` × `difficulty` (usage) | Which evidence types are players spending, and where? |
| 5 | `evidence_type` × `claim_id` | Which evidence types get paired with which claim types? |
| 6 | `evidence_type` × `seed_target` | Which NPCs receive evidence-boosted rumors? |
| 7 | Acquisition-to-use ratio per type | How much evidence goes unused (hoarding signal)? |

## Fixture Files

Located in `fixtures/`:

| File | Description |
|------|-------------|
| `sample_evidence_acquired.ndjson` | 90 synthetic events: 3 types × 3 scenarios × 2 difficulties × 5 per combo |
| `sample_evidence_used.ndjson` | 54 synthetic events: type × claim × target combos |
| `sample_scenario_ended.ndjson` | 36 synthetic events: win/loss outcomes for join analysis |
| `golden_output.txt` | Expected aggregation output snapshot for CI validation |

## Event Schemas

### `evidence_acquired`
```json
{"ts":"...","type":"evidence_acquired","evidence_type":"forged_document","source_action":"observe_building","day":3,"scenario_id":"scenario_2","difficulty":"master"}
```

Fields: `ts`, `type`, `evidence_type`, `source_action`, `day`, `scenario_id`, `difficulty`

### `evidence_used`
```json
{"ts":"...","type":"evidence_used","evidence_type":"witness_account","claim_id":"ACC-01","seed_target":"Alys","subject":"Maren","day":5,"scenario_id":"scenario_4","difficulty":"apprentice"}
```

Fields: `ts`, `type`, `evidence_type`, `claim_id`, `seed_target`, `subject`, `day`, `scenario_id`, `difficulty`

### `scenario_ended`
```json
{"ts":"...","type":"scenario_ended","scenario_id":"scenario_2","difficulty":"master","outcome":"WON","day_reached":12,"duration_sec":540}
```

Fields: `ts`, `type`, `scenario_id`, `difficulty`, `outcome`, `day_reached`, `duration_sec`

## Using with Real Data

Copy `user://analytics.json` from the Godot user data directory. Filter by event type:

```bash
# Extract evidence_acquired events from a real session log
grep '"type":"evidence_acquired"' analytics.json > real_evidence_acquired.ndjson
grep '"type":"evidence_used"' analytics.json > real_evidence_used.ndjson
grep '"type":"scenario_ended"' analytics.json > real_scenario_ended.ndjson

node tools/analytics/aggregate_evidence.js /path/to/filtered/dir
```

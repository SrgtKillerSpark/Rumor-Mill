# Phase 2 Evidence-Economy — Player-Facing Acceptance Tests

**Issue:** SPA-1573
**Author:** Game Designer
**Date:** 2026-05-03
**Refs:** [phase2-evidence-telemetry-spec.md](phase2-evidence-telemetry-spec.md)

---

## How to Read This Document

Each test is a one-line player-facing scenario that QA can verify by playing the game. Tests are grouped by workstream slice (see spec § 6). "Pass" means the described behavior is observable; "Fail" means it is not.

---

## Slice A — Telemetry Events

### evidence_acquired

| # | Test | Verify |
|---|---|---|
| A1 | Observe a building that drops a Forged Document → analytics NDJSON contains an `evidence_acquired` event with `evidence_type: "forged_document"` and `source_action: "observe_building"` | grep NDJSON |
| A2 | Eavesdrop an NPC pair that drops a Witness Account → NDJSON contains `evidence_acquired` with `evidence_type: "witness_account"` and `source_action: "eavesdrop_npc"` | grep NDJSON |
| A3 | Acquire evidence when inventory is full (3 items) → `evidence_acquired` still fires (oldest item is discarded, but acquisition is logged) | grep NDJSON, check count |
| A4 | Acquire evidence with analytics disabled in settings → no `evidence_acquired` event in NDJSON | grep NDJSON, confirm absence |
| A5 | Save and reload mid-scenario → evidence already in inventory does NOT re-fire `evidence_acquired` on load | grep NDJSON, compare event count before/after load |

### evidence_used

| # | Test | Verify |
|---|---|---|
| A6 | Attach a Forged Document to a rumor seed and confirm → NDJSON contains `evidence_used` with correct `evidence_type`, `claim_id`, `seed_target`, `subject`, `day` | grep NDJSON |
| A7 | Seed a rumor WITHOUT attaching evidence → no `evidence_used` event fires | grep NDJSON, confirm absence |
| A8 | Start seed confirmation (first click) then cancel → no `evidence_used` event fires | grep NDJSON, confirm absence |
| A9 | Attach evidence, confirm seed, then immediately save-load → exactly one `evidence_used` event (no double-fire) | grep NDJSON, check count |

---

## Slice B — Aggregation Scripts

| # | Test | Verify |
|---|---|---|
| B1 | Run `kpi_aggregate.js` against a sample NDJSON with both event types → output includes acquisition-rate table grouped by `evidence_type × scenario_id × difficulty` | Script output |
| B2 | Run aggregation → output includes hoarding ratio (`evidence_used / evidence_acquired`) per evidence type | Script output |
| B3 | Run aggregation on an NDJSON with zero evidence events → script completes without error, tables show 0 counts | Script output |

---

## Slice C — Shelf-Life Extension

| # | Test | Verify |
|---|---|---|
| C1 | Seed a rumor with a Witness Account attached → the rumor persists noticeably longer (~3.3 extra days) than an identical rumor seeded without evidence on the same target | Observe rumor expiry in HUD/intel panel |
| C2 | Seed a rumor with an Incriminating Artifact → the rumor does NOT last longer than an unbolstered rumor of the same initial believability (Artifact has +0 shelf-life extension) | Compare expiry timing |
| C3 | Seed a rumor with a Forged Document → the rumor lasts moderately longer (~1.7 extra days) vs. no evidence | Compare expiry timing |
| C4 | Load a Phase-1 save (no shelf-life extension fields) → game loads without error, existing rumors behave identically to before | Load old save, play 5 days |

---

## Slice D — Credulity Boost

| # | Test | Verify |
|---|---|---|
| D1 | Seed a rumor with Incriminating Artifact on a low-credulity NPC (e.g. credulity 0.20) → the NPC is more likely to believe than without evidence | Compare belief outcomes across multiple attempts |
| D2 | Seed a rumor with Witness Account on the same low-credulity NPC → belief rate increase is smaller than with Artifact | Compare belief outcomes |
| D3 | The credulity boost applies ONLY to the seed target for that specific rumor — other NPCs who hear the rumor through propagation are NOT affected by the evidence credulity boost | Observe propagation chain behavior |
| D4 | Seed two rumors on the same NPC, one with evidence and one without → only the evidence-backed rumor benefits from the credulity boost | Check belief state per rumor |

---

## Slice E — Target-Shift Cooldown

| # | Test | Verify |
|---|---|---|
| E1 | On Normal difficulty, use evidence to seed a rumor targeting NPC A → for the next 2 days, evidence items are greyed out in the rumor panel when selecting a DIFFERENT target NPC B | Visual check in rumor panel |
| E2 | After the 2-day cooldown expires → evidence items are available again for any target | Visual check in rumor panel |
| E3 | During cooldown, evidence is still available when targeting the SAME NPC A | Visual check |
| E4 | On Apprentice difficulty → no cooldown; evidence is always available for any target | Visual check |
| E5 | Seed a rumor WITHOUT evidence → no cooldown is triggered, evidence remains available for any target | Visual check |
| E6 | During cooldown, evidence items in inventory are still visible (not hidden) but greyed out with a tooltip explaining the cooldown | Visual check + tooltip text |

---

## Slice F — Feature Flag + Save Migration

| # | Test | Verify |
|---|---|---|
| F1 | With `evidence_economy_v2` flag OFF → shelf-life extension, credulity boost, and target-shift cooldown are all inactive; game plays identically to Phase 1 | Play a full scenario |
| F2 | With flag ON → all three mechanics are active | Play a full scenario, verify C1/D1/E1 |
| F3 | Toggle flag mid-session (via settings) → change takes effect on next rumor seed, not retroactively on existing rumors | Seed before and after toggle |
| F4 | Load a save created with flag OFF into a session with flag ON → new mechanics apply to new rumors only; existing rumors retain Phase-1 behavior | Load old save, seed new rumor |
| F5 | Save version is bumped to 1.2 → save files created in Phase 2 include `save_version: 1.2` in header | Inspect save file |

---

## Cross-Cutting

| # | Test | Verify |
|---|---|---|
| X1 | Complete a full scenario on each difficulty with all Phase 2 mechanics enabled → no crashes, no GDScript errors in console | Play S1–S4 on Normal |
| X2 | Evidence items still display correct names and icons in the rumor panel UI (no regression from snake_case normalization in telemetry — display names are unchanged) | Visual check |
| X3 | The telemetry events and tuning mechanics work correctly together: seed with evidence → `evidence_used` fires AND shelf-life/credulity/cooldown all apply | Combined scenario playthrough |

# Phase 2 Evidence-Telemetry Developer Notes

> Source: [SPA-1644] — companion to Devlog #5 ([SPA-1628])  
> Covers: [SPA-1613] `evidence_acquired` · [SPA-1614] `evidence_used` · [SPA-1617] smoke harness

---

## 1. Fire-Site Map

All emits route through `AnalyticsManager.log_evidence_acquired()` /
`log_evidence_used()` in `scripts/analytics_manager.gd`. The four production
call sites are:

| # | File | Line | Function | Event type | `evidence_type` | `source_action` |
|---|------|------|----------|------------|-----------------|-----------------|
| 1 | `scripts/recon_controller.gd` | 605 | `_try_observe()` | `evidence_acquired` | `forged_document` | `observe_building` |
| 2 | `scripts/recon_controller.gd` | 616 | `_try_observe()` | `evidence_acquired` | `incriminating_artifact` | `observe_building` |
| 3 | `scripts/recon_controller.gd` | 727 | `_try_eavesdrop()` | `evidence_acquired` | `witness_account` | `eavesdrop_npc` |
| 4 | `scripts/rumor_panel.gd` | 537 | `_try_confirm_seed()` | `evidence_used` | *(dynamic — see §2)* | — |

**Fire site 1 & 2 conditions** (`_try_observe()`):
- Site 1 fires when `forged_doc` is true (Market / Guild, ≥2 Recon Actions).
- Site 2 fires when `tick % 24 > 18` and location is `manor` or `chapel`
  (evening-only; mutually exclusive with site 1 via `elif`).

**Fire site 3 condition** (`_try_eavesdrop()`):
- Fires when `witness_account` is true after a successful eavesdrop on two
  NPCs in conversation with prior relationship intel ≥24 ticks old.

**Fire site 4 detail** — `rumor_panel.gd:537–542`:

```gdscript
_analytics_manager.log_evidence_used(
    _selected_evidence_item.type.to_lower().replace(" ", "_"),
    _selected_claim_id,
    _get_npc_name(_selected_seed_npc),
    _get_npc_name(_selected_subject)
)
```

Guard at `rumor_panel.gd:533`: `if _selected_evidence_item != null` — no emit
when a rumor is seeded without evidence.

---

## 2. Canonical `evidence_type` Strings

No central enum or const dictionary exists. Each type is a string literal at
its fire site; the player-facing display name is stored in `EvidenceItem.type`.

| `evidence_type` | Display name | Defined at |
|-----------------|--------------|------------|
| `forged_document` | `"Forged Document"` | `recon_controller.gd:605` |
| `incriminating_artifact` | `"Incriminating Artifact"` | `recon_controller.gd:616` |
| `witness_account` | `"Witness Account"` | `recon_controller.gd:727` |

Conversion rule applied at every `evidence_used` emit (`rumor_panel.gd:538`):

```
EvidenceItem.type.to_lower().replace(" ", "_")
```

If you rename a display name in `EvidenceItem`, the emitted `evidence_type`
string changes too. Update the fire-site literal and harness fixture together.

---

## 3. Harness Invocation

### Unit suites (editor: Scene → Run Script)

| Suite | File | Tests | SPA |
|-------|------|-------|-----|
| `evidence_acquired` shape | `tests/test_spa1613_evidence_acquired.gd` | 16 | SPA-1613 |
| `evidence_used` emission | `tests/test_spa1614_evidence_used_emission.gd` | 14 | SPA-1614 |

### Smoke harness (headless)

```
godot --headless --path rumor_mill --script tests/smoke_phase2_evidence.gd
```

Expected output on a clean run:

```
── Phase 2 evidence telemetry smoke (SPA-1617) ──
   seed: scenario_2 / apprentice (S2 Sister Maren on Apprentice)

  PASS  total event count == 4  (got 4)
  PASS  acquired[0] forged_document/observe_building — type == evidence_acquired
  ...
  45 passed, 0 failed
── Captured NDJSON sample (4 lines) ──
```

Sample NDJSON fixture: `tools/analytics/fixtures/smoke_capture_phase2.ndjson`.

### Acceptance criterion mapping

**SPA-1613 `evidence_acquired` (16 tests total):**

| ID | Assertion | Tests |
|----|-----------|-------|
| A1 | `type == "evidence_acquired"` for all 3 types | `test_*_event_type` (×3) |
| A2 | `evidence_type` field value matches fire-site string | `test_*_evidence_type_field` (×3) |
| A3 | `source_action` field value matches fire-site string | `test_*_source_action_field` (×3) |
| A4 | `day`, `scenario_id`, `difficulty` fields present | `test_has_*_field` (×3) |
| A5 | Two calls produce two independent events (no dedup) | `test_two_calls_emit_two_events` |
| A6 | Pre-setup queue preserves args for all 3 type/action pairs | `test_pre_setup_queue_*_args` (×3) |

**SPA-1614 `evidence_used` (14 tests total):**

| ID | Assertion | Tests |
|----|-----------|-------|
| A1 | Enabled → 1 event; disabled → 0 events | `test_enabled/disabled_used_*` (×2) |
| A2 | `type == "evidence_used"` | `test_event_type_is_evidence_used` |
| A3 | All 7 SPA-1522 fields present (`evidence_type`, `claim_id`, `seed_target`, `subject`, `day`, `scenario_id`, `difficulty`) | `test_payload_contains_*` (×7) |
| A4 | Field values match caller-supplied arguments verbatim | `test_payload_*_value` (×4) |
| A5 | No emit when seeding without evidence | Call-site guard `rumor_panel.gd:533` (structural) |

---

## 4. Adding a New Evidence Type

- [ ] **Choose a snake_case type string** (e.g. `stolen_ledger`).
- [ ] **Create the `EvidenceItem`** in the relevant action function — use the
      existing fire sites as a template (`recon_controller.gd:598–618`).
- [ ] **Add the fire site** immediately after `_intel_store.add_evidence(ev)`:
  ```gdscript
  if _analytics_manager != null:
      _analytics_manager.log_evidence_acquired("stolen_ledger", "source_action")
  ```
- [ ] **Update smoke harness** — add a row to `acquired_cases` in
      `smoke_phase2_evidence.gd` and update the `cap.lines.size() == N` check.
- [ ] **Add SPA-1613-style tests** — `test_*_event_type`,
      `test_*_evidence_type_field`, `test_*_source_action_field`, and
      `test_pre_setup_queue_*_args`.
- [ ] **Update §1 and §2 of this document** with the new fire-site row and
      type-string row.
- [ ] **Run smoke harness headless** before merging to stable — all checks must
      pass.

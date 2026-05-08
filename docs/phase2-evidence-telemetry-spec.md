# Phase 2 Evidence-Economy Implementation Spec v2.0

**Issue:** SPA-1522 (telemetry design), SPA-1573 (implementation spec)
**Author:** Game Designer
**Date:** 2026-05-03
**Status:** Implementation-ready (v2.0)
**Refs:** [phase1-balance-proposal.md](phase1-balance-proposal.md), [post-launch-telemetry-plan.md](post-launch-telemetry-plan.md), [scenario-difficulty-and-events.md](scenario-difficulty-and-events.md)

---

## 1. Overview

Phase 1 explicitly deferred evidence-item rebalancing (see phase1-balance-proposal.md § "Explicit Non-Goal"). Phase 2 adds the telemetry needed to answer whether Forged Document, Incriminating Artifact, and Witness Account are meaningfully differentiated, then introduces tuning levers to fix the problems the data reveals.

This spec covers **three workstreams**:
1. Five telemetry events (`evidence_acquired`, `evidence_used`, `target_shift_cooldown_blocked`, `witness_account_used`, `evidence_economy_v2_gated_off`)
2. Evidence-economy tuning curves (decay, confidence thresholds, target-shift cooldown)
3. Differentiation mechanics for the three evidence types

---

## 2. Telemetry Events — Engineering-Ready

### 2.1 `evidence_acquired`

**Question answered:** How often does each evidence type drop, from which source, and when in the run?

| Field | Type | Example | Source |
|---|---|---|---|
| `evidence_type` | `String` | `"forged_document"` | `ev.type` (snake_case, see § 2.3) |
| `source_action` | `String` | `"observe_building"` / `"eavesdrop_npc"` | Determined by call site |
| `day` | `int` | `5` | `_world.current_day` |
| `scenario_id` | `String` | `"scenario_3"` | `_world.scenario_id` |
| `difficulty` | `String` | `"normal"` | `_world.difficulty` |

**Fire sites (3 total):**

| # | File | Line(s) | Context | `source_action` value |
|---|---|---|---|---|
| 1 | `recon_controller.gd` | ~597 | After `_intel_store.add_evidence(ev)` in observe-building branch | `"observe_building"` |
| 2 | `recon_controller.gd` | ~605 | After `_intel_store.add_evidence(ev)` in observe-building (artifact variant) | `"observe_building"` |
| 3 | `recon_controller.gd` | ~713 | After `_intel_store.add_evidence(ev)` in eavesdrop-npc branch | `"eavesdrop_npc"` |

**Edge cases:**
- **Inventory full (MAX_EVIDENCE = 3):** The `add_evidence()` call discards the oldest item with `push_warning()`. Still fire `evidence_acquired` — we want to count generation rate, not just retention.
- **Save-load:** Evidence acquisition is a one-time action; no replay risk on load. No dedup guard needed.
- **Analytics disabled:** Existing `AnalyticsManager` guard (`if not analytics_enabled: return`) applies. No special handling.

**Implementation:**
```gdscript
# analytics_manager.gd — new method (~6 lines)
func log_evidence_acquired(evidence_type: String, source_action: String, day: int, scenario_id: String, difficulty: String) -> void:
    _log_event("evidence_acquired", {
        "evidence_type": evidence_type,
        "source_action": source_action,
        "day": day,
        "scenario_id": scenario_id,
        "difficulty": difficulty,
    })
```

At each fire site in `recon_controller.gd` (~2 lines each):
```gdscript
_analytics_manager.log_evidence_acquired(
    ev.type.to_snake_case(), source_action, _world.current_day, _world.scenario_id, _world.difficulty
)
```

---

### 2.2 `evidence_used`

**Question answered:** Which evidence type gets attached to which claim, targeting which NPC, and when?

| Field | Type | Example | Source |
|---|---|---|---|
| `evidence_type` | `String` | `"witness_account"` | `_selected_evidence_item.type` (snake_case) |
| `claim_id` | `String` | `"SCANDAL"` | `_selected_claim_id` |
| `seed_target` | `String` | `"Finn Monk"` | `_selected_seed_npc.display_name` |
| `subject` | `String` | `"Aldous Prior"` | `_selected_subject.display_name` |
| `day` | `int` | `12` | `_world.current_day` |
| `scenario_id` | `String` | `"scenario_4"` | `_world.scenario_id` |
| `difficulty` | `String` | `"hard"` | `_world.difficulty` |

**Fire site (1 total):**

| File | Line | Context |
|---|---|---|
| `rumor_panel.gd` | ~507 | After `_intel_store.consume_evidence(_selected_evidence_item)` in seed-confirmation block |

**Edge cases:**
- **Seed without evidence:** Player can seed a rumor without attaching evidence. This event does NOT fire in that case — only when `_selected_evidence_item != null`.
- **Double-fire on confirm click:** The two-click confirmation in rumor_panel.gd (lines 404–449) prevents double-fire. First click shows summary; second click triggers consumption. No extra guard needed.
- **Save-load mid-confirmation:** If player saves after first click but before confirmation, the panel state resets on load. No consumption occurs, so no event fires. Correct behavior.

**Implementation:**
```gdscript
# analytics_manager.gd — new method (~8 lines)
func log_evidence_used(evidence_type: String, claim_id: String, seed_target: String, subject: String, day: int, scenario_id: String, difficulty: String) -> void:
    _log_event("evidence_used", {
        "evidence_type": evidence_type,
        "claim_id": claim_id,
        "seed_target": seed_target,
        "subject": subject,
        "day": day,
        "scenario_id": scenario_id,
        "difficulty": difficulty,
    })
```

At fire site in `rumor_panel.gd` (~4 lines):
```gdscript
if _selected_evidence_item != null:
    _analytics_manager.log_evidence_used(
        _selected_evidence_item.type.to_snake_case(), _selected_claim_id,
        _selected_seed_npc.display_name, _selected_subject.display_name,
        _world.current_day, _world.scenario_id, _world.difficulty
    )
```

---

### 2.3 Type String Normalization

Evidence `type` field on `EvidenceItem` uses display names (e.g. `"Forged Document"`). Telemetry must emit snake_case (`"forged_document"`). Use GDScript's `String.to_snake_case()` at emission time. Do NOT modify the `EvidenceItem.type` field itself — UI rendering depends on the display form.

---

### 2.4 Aggregation Queries

These are the cross-tabs the aggregation scripts (`tools/analytics/kpi_aggregate.js`) should support:

| # | Query | Group-by | Metric |
|---|---|---|---|
| A1 | Acquisition rate | `evidence_type` × `scenario_id` × `difficulty` | `COUNT(evidence_acquired)` |
| A2 | Acquisition timing | `evidence_type` × `day` | Histogram |
| A3 | Source distribution | `evidence_type` × `source_action` | Ratio |
| U1 | Usage rate | `evidence_type` × `scenario_id` × `difficulty` | `COUNT(evidence_used)` |
| U2 | Evidence-claim affinity | `evidence_type` × `claim_id` | Cross-tab count |
| U3 | Target preference | `evidence_type` × `seed_target` | Cross-tab count |
| U4 | Usage timing | `evidence_type` × `day` | Histogram |
| U5 | Hoarding ratio | `evidence_type` | `COUNT(evidence_used) / COUNT(evidence_acquired)` |

---

### 2.5 `target_shift_cooldown_blocked` *(SPA-1772)*

**Question answered:** How often do players attempt to attach cooldown-locked evidence, and which evidence types are most commonly blocked?

| Field | Type | Example | Source |
|---|---|---|---|
| `evidence_type` | `String` | `"forged_document"` | `item.type.to_snake_case()` |
| `target_npc_id` | `String` | `"finn_monk"` | `intel_store.get_evidence_cooldown_info()["target_npc_id"]` |
| `cooldown_remaining_days` | `int` | `2` | `intel_store.get_evidence_cooldown_info()["days_remaining"]` |
| `day` | `int` | `7` | `_world_ref.current_day` |
| `scenario_id` | `String` | `"scenario_3"` | `_world_ref.scenario_id` |
| `difficulty` | `String` | `"normal"` | `GameState.selected_difficulty` |

**Fire site (1 total):**

| File | Line | Context |
|---|---|---|
| `rumor_panel.gd` | `_build_evidence_entry()` | `gui_input` handler on the disabled Attach button when `cooldown_locked == true` |

**Edge cases:**
- **Cooldown-bypass items (Witness Account):** `cooldown_bypass` is set instead of `cooldown_locked`. Those buttons are not disabled, so this event does NOT fire for them. The player can still attach at half effectiveness.
- **Multiple rapid clicks:** Each left-button press emits one event. No dedup guard; repeated clicks represent genuine player frustration and are analytically useful.
- **Analytics disabled:** Standard `SettingsManager.analytics_enabled` guard in `log_event()` prevents writes when analytics is off.

**Implementation (already landed — SPA-1772):**

In `rumor_panel.gd` `_build_evidence_entry()`, after `btn.disabled = true`:
```gdscript
# SPA-1772: Emit telemetry when the player taps/clicks the locked button.
var captured_item := item
btn.gui_input.connect(func(ev: InputEvent) -> void:
    if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
        if _analytics_ref != null:
            var info := _intel_store_ref.get_evidence_cooldown_info()
            _analytics_ref.log_target_shift_cooldown_blocked(
                captured_item.type.to_snake_case(),
                info.get("target_npc_id", ""),
                info.get("days_remaining", 0),
                _world_ref.current_day if _world_ref != null else 0,
                _world_ref.scenario_id if _world_ref != null else "",
                GameState.selected_difficulty
            )
)
```

In `analytics_logger.gd`:
```gdscript
func log_target_shift_cooldown_blocked(evidence_type: String, target_npc_id: String, cooldown_remaining_days: int, day: int, scenario_id: String, difficulty: String) -> void:
    log_event("target_shift_cooldown_blocked", {
        "evidence_type":           evidence_type,
        "target_npc_id":           target_npc_id,
        "cooldown_remaining_days": cooldown_remaining_days,
        "day":                     day,
        "scenario_id":             scenario_id,
        "difficulty":              difficulty,
    })
```

**GUT tests:** `test_rumor_panel_evidence_cooldown.gd` — T1 (event fires on click), T2 (correct `evidence_type`), T3 (no event when unlocked).

---

### 2.6 `witness_account_used` *(SPA-1773)*

**Question answered:** How often is Witness Account used in cooldown-bypass mode, and what are the actual (halved) bonus values being applied?

| Field | Type | Example | Source |
|---|---|---|---|
| `evidence_type` | `String` | `"witness_account"` | `evidence_item.type.to_snake_case()` |
| `bypass_mode` | `bool` | `true` | Always `true` — event only fires in bypass path |
| `effective_believability_bonus` | `float` | `0.075` | `evidence_item.believability_bonus × 0.5` |
| `effective_credulity_boost` | `float` | `0.025` | `evidence_item.credulity_boost × 0.5` |
| `target_npc_id` | `String` | `"npc_finn_monk"` | `seed_target_npc_id` |
| `cooldown_target_npc_id` | `String` | `"npc_finn_monk"` | Same as `target_npc_id` — the NPC whose cooldown triggered bypass |
| `day` | `int` | `8` | `_day_night.current_day` |
| `scenario_id` | `String` | `"scenario_3"` | `_analytics_scenario_id` |
| `difficulty` | `String` | `"normal"` | `GameState.selected_difficulty` |

**Fire site (1 total):**

| File | Context |
|---|---|
| `world.gd` `seed_rumor_from_player()` | After `bypass_active` is confirmed true and halved bonus values are computed |

**Mechanism:** `world.gd` emits the `witness_account_bypass_used` signal; `AnalyticsManager.setup()` wires it to `_on_witness_account_bypass_used()`, which delegates to `log_witness_account_used()`.

**Edge cases:**
- **Normal Witness Account usage (no bypass):** `bypass_active == false` so the signal is never emitted and this event does NOT fire. The existing `evidence_used` event continues to cover normal usage.
- **Non-bypass evidence types:** `is_evidence_bypass_active()` requires `supports_cooldown_bypass == true`, which only Witness Account has. Other evidence types can never trigger this event.
- **Analytics disabled:** Standard `SettingsManager.analytics_enabled` guard in `AnalyticsLogger.log_event()` prevents writes when analytics is off.

**Implementation (SPA-1773):**

In `world.gd`, new signal and emission after bypass detection:
```gdscript
signal witness_account_bypass_used(
    evidence_type: String, effective_bel_bonus: float,
    effective_cred_boost: float, target_npc_id: String
)

# Inside seed_rumor_from_player(), after halved bonus calculation:
if bypass_active:
    emit_signal("witness_account_bypass_used",
        evidence_item.type.to_snake_case(), bel_bonus, cred_boost, seed_target_npc_id)
```

In `analytics_manager.gd`, new method and signal wiring in `setup()`:
```gdscript
func log_witness_account_used(evidence_type, effective_bel_bonus, effective_cred_boost, target_npc_id):
    _analytics_logger.log_event("witness_account_used", {
        "evidence_type": evidence_type, "bypass_mode": true,
        "effective_believability_bonus": effective_bel_bonus,
        "effective_credulity_boost": effective_cred_boost,
        "target_npc_id": target_npc_id, "cooldown_target_npc_id": target_npc_id,
        "day": day, "scenario_id": ..., "difficulty": ...
    })
```

**GUT tests:** `test_spa1773_witness_account_used_emission.gd` — emission (enabled/disabled), event type, 9 field-presence assertions, bypass_mode always true, halved bonus value checks (0.075 / 0.025), bypass-only gate.

---

### 2.7 `evidence_economy_v2_gated_off` *(SPA-1774)*

**Question answered:** How often do Apprentice players attempt to use evidence bonuses that are silently gated off (shelf_life_extension and credulity_boost skipped)?

| Field | Type | Example | Source |
|---|---|---|---|
| `evidence_type` | `String` | `"witness_account"` | `evidence_item.type.to_snake_case()` |
| `gated_bonuses` | `Array[String]` | `["shelf_life_extension", "credulity_boost"]` | Hardcoded — always both bonuses |
| `difficulty` | `String` | `"apprentice"` | `GameState.selected_difficulty` |
| `day` | `int` | `4` | `_day_night.current_day` |
| `scenario_id` | `String` | `"scenario_2"` | `_analytics_scenario_id` |

**Fire site (1 total):**

| File | Context |
|---|---|
| `world.gd` `seed_rumor_from_player()` | `elif GameState.evidence_economy_v2:` branch — reached only when flag is ON and difficulty is `"apprentice"` |

**Mechanism:** `world.gd` emits the `evidence_economy_v2_gated_off` signal in the `elif` branch of the SPA-1757 difficulty gate; `AnalyticsManager.setup()` wires it to `_on_evidence_economy_v2_gated_off()`, which delegates to `log_evidence_economy_v2_gated_off()`.

**Edge cases:**
- **Flag OFF:** The `if/elif` condition is never entered when `evidence_economy_v2 == false`, so this event will not fire.
- **Normal/Master/Spymaster:** The `if` branch fires (bonuses applied) — `elif` is skipped; event does NOT fire.
- **Apprentice + flag OFF:** Neither branch taken; event does NOT fire.
- **Analytics disabled:** Standard `SettingsManager.analytics_enabled` guard in `AnalyticsLogger.log_event()` prevents writes.

**Implementation (SPA-1774):**

In `world.gd`, new signal declaration and emission:
```gdscript
signal evidence_economy_v2_gated_off(
    evidence_type: String, gated_bonuses: Array, difficulty: String
)

# Inside seed_rumor_from_player(), replacing the bare SPA-1757 if with if/elif:
if GameState.evidence_economy_v2 and GameState.selected_difficulty != "apprentice":
    rumor.shelf_life_ticks += evidence_item.shelf_life_extension
    rumor.evidence_credulity_boost = cred_boost
    rumor.seed_target_npc_id = seed_target_npc_id
elif GameState.evidence_economy_v2:
    emit_signal("evidence_economy_v2_gated_off",
        evidence_item.type.to_snake_case(),
        ["shelf_life_extension", "credulity_boost"],
        GameState.selected_difficulty)
```

In `analytics_manager.gd`, new methods and signal wiring in `setup()`:
```gdscript
func log_evidence_economy_v2_gated_off(evidence_type, gated_bonuses, difficulty):
    _analytics_logger.log_event("evidence_economy_v2_gated_off", {
        "evidence_type": evidence_type, "gated_bonuses": gated_bonuses,
        "difficulty": difficulty, "day": day, "scenario_id": ...
    })
```

**GUT tests:** `test_phase2_evidence_economy_v2_gating.gd` — 3 new tests: signal fires on Apprentice, does NOT fire on Normal, does NOT fire on Master. Uses `_would_emit_gated_off()` helper mirroring the `elif` condition.

---

## 3. Evidence-Economy Tuning Curves

### 3.1 Evidence Believability Decay

**Current behavior:** Evidence bonus is applied once at rumor creation. The rumor then decays at the standard rate (`1.0 / shelf_life_ticks`, default 330 ticks). Evidence does NOT slow decay.

**Problem:** A +0.25 Artifact bonus on a shelf_life of 330 ticks gives ~82 extra ticks of life. A +0.15 Witness Account gives ~50 extra ticks. The delta (32 ticks ≈ 1.3 days) is small enough that players rarely notice a strategic difference.

**Proposed change — evidence shelf-life extension:**

| Evidence Type | Believability Bonus | Shelf-life Extension (ticks) | Net Extra Life (ticks) | Net Extra Life (days) |
|---|---|---|---|---|
| Forged Document | +0.20 | +40 | ~106 | ~4.4 |
| Incriminating Artifact | +0.25 | +0 | ~82 | ~3.4 |
| Witness Account | +0.15 | +80 | ~130 | ~5.4 |

**Rationale:** Witness Account's -0.15 mutability cost already differentiates it, but the payoff needs to be visible. Giving it the longest shelf-life extension makes it the "slow burn" evidence: lower initial boost but the rumor persists longer. Forged Document becomes the "medium" all-rounder. Incriminating Artifact keeps its role as the "spike" — highest initial boost, no durability bonus.

**Implementation:** In `world.gd` `seed_rumor_from_player()`, after applying `evidence_item.believability_bonus`, also apply:
```gdscript
rumor.shelf_life_ticks += evidence_item.shelf_life_extension
```

Add `shelf_life_extension: int` to `EvidenceItem` class in `intel_store.gd`. Set values in `recon_controller.gd` at each creation site.

---

### 3.2 Evidence Confidence Thresholds

**Context:** NPCs have a `credulity` stat (0.0–1.0) that determines how easily they believe rumors. Evidence currently bypasses this by directly boosting believability. There is no "confidence" system — NPCs either believe or don't based on the rumor's believability vs. their credulity threshold.

**Proposed mechanic — evidence confidence modifier:**

When a rumor is bolstered by evidence, the seed target's effective credulity for that rumor is increased:

| Evidence Type | Credulity Boost on Seed Target |
|---|---|
| Forged Document | +0.10 |
| Incriminating Artifact | +0.15 |
| Witness Account | +0.05 |

**Rationale:** This makes evidence meaningfully affect propagation, not just duration. Artifact becomes the "convincer" — high initial boost AND credulity override. Document is balanced. Witness Account trades propagation strength for persistence (shelf-life extension above).

**Implementation:** In `world.gd` `seed_rumor_from_player()`, apply a temporary credulity modifier to the seed target NPC for this specific rumor. Store as `rumor.evidence_credulity_boost` and check in `propagation_engine.gd` during the belief check.

**Tuning range:** 0.0–0.20. Values above 0.20 risk making evidence-backed rumors auto-believed even by resistant NPCs (credulity 0.30 + 0.20 = 0.50, above median).

---

### 3.3 Target-Shift Cooldown

**Current behavior:** Players can seed rumors on different targets every day with no cooldown. Evidence can be attached to any eligible seed.

**Proposed mechanic — evidence target memory:**

After using evidence on a seed targeting NPC X, the player cannot use evidence on a different target NPC for `N` days. They CAN still seed rumors without evidence on any target.

| Difficulty | Cooldown (days) |
|---|---|
| Apprentice | 0 (disabled) |
| Normal | 2 |
| Master | 3 |
| Spymaster | 4 |

**Rationale:** Prevents the "evidence spam" pattern where players attach evidence to every seed regardless of strategy. Forces commitment: once you evidence-boost a rumor against Finn, you're locked into that target for 2+ days. Creates meaningful evidence budgeting without reducing the total evidence supply.

**Implementation:** Add `_evidence_target_cooldown: Dictionary` to `intel_store.gd` mapping `target_npc_id → cooldown_remaining_days`. Decrement on day advance. Check in `rumor_panel.gd` when filtering compatible evidence — grey out evidence items if cooldown is active for a different target.

**Edge case:** If `MAX_EVIDENCE = 3` and all items are locked behind cooldown, the player still has them in inventory but cannot use them. This is intentional — it's the cost of switching targets. The cooldown is on *evidence use targeting*, not on evidence itself.

---

## 4. Evidence Differentiation Summary

After Phase 2 tuning (including M5 baseline fixes — SPA-1756), the three evidence types have distinct strategic identities:

| | Forged Document | Incriminating Artifact | Witness Account |
|---|---|---|---|
| **Believability boost** | +0.20 | +0.25 | +0.15 (½ during bypass) |
| **Mutability modifier** | 0.0 | 0.0 | -0.15 |
| **Shelf-life extension** | +40 ticks (~1.7 days) | +0 | +80 ticks (~3.3 days) |
| **Credulity boost** | +0.10 | +0.15 | +0.05 (½ during bypass) |
| **Cooldown bypass** | No | No | **Yes — usable at ½ effect during active cooldown** |
| **Claim compatibility** | ACCUSATION, SCANDAL, HERESY | SCANDAL, HERESY | Any |
| **Acquisition source** | Market/Guild observe (double-spend) | Manor/Chapel evening observe | Eavesdrop (prior intel ≥24 ticks) |
| **Strategic identity** | All-rounder: moderate boost, moderate duration, wide claim pool | Spike: highest boost + credulity override, but no durability and narrow claims | Slow burn: low initial impact but longest duration + temporal flexibility via cooldown bypass |

**Player-facing heuristic:**
- **Document** = safe default. Works on most claims, decent boost, decent duration.
- **Artifact** = high-value play. Best for convincing resistant NPCs of scandals/heresies. Short-lived.
- **Witness Account** = long game *and* flexible timing. Best for persistent pressure campaigns. The mutability cost means the target can't easily shake the rumor. Uniquely, it can be used during a target-shift cooldown at half effectiveness — giving the "any claim" advantage a temporal dimension unavailable to other evidence types.

### 4.1 Cooldown-Bypass Mechanic (SPA-1756)

**Problem (M5 baseline):** Witness Account usage rate (57%) equalled Forged Document and trailed Artifact (75%) in S3 Normal and S5 Master. The 3-day Master cooldown blocked the intended evidence window in S5; the item was displaced unused. Its "any claim" breadth provided no differentiation in tight-cooldown scenarios.

**Solution:** `EvidenceItem.supports_cooldown_bypass = true` on Witness Account only. When `is_evidence_bypass_active()` returns true (active cooldown + item supports bypass), `world.gd`'s `seed_rumor_from_player` applies `believability_bonus × 0.5` (+0.075) and `credulity_boost × 0.5` (+0.025). Shelf-life extension (+80) and mutability modifier (-0.15) are unaffected.

**UI:** Bypass-capable items show amber tint (not grey) in `rumor_panel.gd` with button text "Attach (½ Effect)" and tooltip showing cooldown days remaining. Hard-locked items (Document, Artifact) remain greyed out as before.

**Implementation files:** `intel_store.gd` (`EvidenceItem.supports_cooldown_bypass`, `is_evidence_bypass_active()`), `recon_controller.gd` (Witness Account creation), `world.gd` (`seed_rumor_from_player`), `rumor_panel.gd` (`_build_evidence_entry`).

**Tests:** 10 new regression tests in `test_phase2_evidence_economy.gd` covering field values, bypass activation conditions, half-effectiveness math, and shelf/mutability invariants.

---

## 5. Risk Register

### Risk 1: Scope Creep — New Mechanics Cascading Beyond Evidence

**Impact:** Medium-High. The credulity boost and shelf-life extension touch `propagation_engine.gd` and `rumor.gd`, which are core systems. Feature creep into these systems risks regressions in propagation balance validated during Phase 1.

**Mitigation:**
- All new fields (`shelf_life_extension`, `evidence_credulity_boost`) default to 0/null. Existing rumors and non-evidence seeds are unaffected.
- Ship telemetry events (Workstream 1) first, independently. Telemetry has zero gameplay impact.
- Ship tuning mechanics (Workstreams 2-3) behind a feature flag `evidence_economy_v2` in `game_state.gd`. Default OFF until telemetry confirms the differentiation gap.
- Code review gate: changes to `propagation_engine.gd` require Lead Engineer sign-off.

### Risk 2: Balance Regression — Evidence Becomes Dominant Strategy

**Impact:** High. If evidence-backed rumors are too strong (especially Artifact with +0.25 believability AND +0.15 credulity boost), players may feel forced to always use evidence, reducing strategic variety.

**Mitigation:**
- Target-shift cooldown (§ 3.3) limits evidence spam frequency.
- MAX_EVIDENCE = 3 caps total evidence in play. Combined with cooldown, a player can use at most 1 evidence item per 2 days on Normal.
- All tuning values in this spec are initial proposals. The telemetry from Workstream 1 provides the data to validate or adjust before wide rollout.
- **Fallback:** If post-launch data shows evidence usage >80% of seeds (healthy target: 30-50%), reduce all bonuses by 30% as a single-pass nerf.

### Risk 3: Save-Compatibility Breakage

**Impact:** Medium. Adding `shelf_life_extension` to `EvidenceItem` and `evidence_credulity_boost` to `Rumor` changes the serialized save format.

**Mitigation:**
- Both new fields default to `0` / `0.0`. Existing saves that lack these fields deserialize safely with defaults.
- Add a `save_version` bump (e.g., `1.1 → 1.2`) in `save_manager.gd` migration table. Migration function: no-op (defaults are correct for pre-Phase-2 saves).
- Test: load a Phase-1 save, play 5 days, verify no errors or gameplay drift. Include in acceptance tests.

---

## 6. Sequencing Recommendation

| Slice | Workstream | Dependencies | Assignable To | Est. Scope |
|---|---|---|---|---|
| **Slice A** | Telemetry events | None | Any engineer | ~30 lines new code, 4 fire sites |
| **Slice B** | Aggregation scripts | Slice A (needs event schema) | Any engineer | kpi_aggregate.js additions |
| **Slice C** | Shelf-life extension | None (additive field) | Any engineer | ~15 lines across 3 files |
| **Slice D** | Credulity boost | None (additive field) | Senior engineer | ~25 lines, touches propagation_engine |
| **Slice E** | Target-shift cooldown | None | Any engineer | ~40 lines, UI grey-out in rumor_panel |
| **Slice F** | Feature flag + save migration | Slices C/D/E | Lead Engineer | ~20 lines, migration table entry |

**Recommended parallel assignment:**
- Slice A + B → Software Engineer (telemetry, no gameplay risk)
- Slice C + E → Software Engineer II (additive fields + UI, moderate complexity)
- Slice D + F → Lead Engineer or review gate (propagation engine, save compat)

Slices A–B can ship independently and immediately. Slices C–E ship behind the feature flag (Slice F). Flag is flipped after telemetry data validates the differentiation gap.

---

*Previous version (v1.0) covered telemetry design only. v2.0 adds tuning curves, differentiation mechanics, acceptance criteria (see [phase2-acceptance-tests.md](phase2-acceptance-tests.md)), risk register, and engineering sequencing.*

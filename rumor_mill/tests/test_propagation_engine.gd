## test_propagation_engine.gd — Unit tests for PropagationEngine (SPA-957).
##
## Covers:
##   • β (spread probability) — faction modifiers, heat modifier, day-phase, location mods
##   • γ (recovery) — loyalty / temperament combinations and clamping
##   • Rumor registration — idempotent, lineage entry created correctly
##   • Shelf-life decay — expired rumors removed; live rumors preserved
##   • Chain detection — NONE, SAME_TYPE, ESCALATION, CONTRADICTION, priority ordering
##   • Chain bonus application — believability / intensity / mutability changes
##   • Lineage chain queries — ancestor-first ordering
##   • Day-phase and location susceptibility helpers — bounds and unknown keys
##
## Run from the Godot editor:  Scene → Run Script (or call run() from any autoload).
## All tests use synthetic in-memory data — no live game nodes required.

class_name TestPropagationEngine
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_subject_index_populated_on_register",
		"test_subject_index_cleared_after_expiry",
		"test_subject_index_idempotent_on_double_register",
		"test_calc_beta_same_faction_clamped",
		"test_calc_beta_opposing_faction",
		"test_calc_beta_neutral_faction",
		"test_calc_beta_heat_modifier_reduces_credulity",
		"test_calc_beta_day_phase_and_location_additive",
		"test_calc_beta_result_always_in_range",
		"test_calc_gamma_high_loyalty_low_temperament",
		"test_calc_gamma_zero_loyalty",
		"test_calc_gamma_result_clamped",
		"test_register_rumor_idempotent",
		"test_register_rumor_creates_lineage_entry",
		"test_tick_decay_removes_expired_rumor",
		"test_tick_decay_preserves_live_rumor",
		"test_detect_chain_none_when_no_rumors",
		"test_detect_chain_same_type",
		"test_detect_chain_escalation_scandal_to_heresy",
		"test_detect_chain_escalation_illness_to_death",
		"test_detect_chain_contradiction_positive_vs_negative",
		"test_detect_chain_escalation_priority_over_contradiction",
		"test_detect_chain_different_subject_returns_none",
		"test_apply_chain_bonus_same_type",
		"test_apply_chain_bonus_escalation",
		"test_apply_chain_bonus_contradiction",
		"test_apply_chain_bonus_none_is_noop",
		"test_get_lineage_chain_root_only",
		"test_get_lineage_chain_parent_child",
		"test_get_lineage_chain_unknown_id",
		"test_calc_day_phase_mod_slot_0_night",
		"test_calc_day_phase_mod_slot_5_evening",
		"test_calc_day_phase_mod_out_of_range",
		"test_calc_location_susceptibility_tavern",
		"test_calc_location_susceptibility_home_negative",
		"test_calc_location_susceptibility_unknown",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPropagationEngine tests: %d passed, %d failed" % [passed, failed])


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_rumor(
		rumor_id: String,
		subject: String = "npc_a",
		claim: Rumor.ClaimType = Rumor.ClaimType.ACCUSATION,
		intensity: int = 3,
		mutability: float = 0.5,
		tick: int = 0,
		shelf: int = 100
) -> Rumor:
	return Rumor.create(rumor_id, subject, claim, intensity, mutability, tick, shelf)


# ── Subject index consistency tests ──────────────────────────────────────────

## After register_rumor(), _subject_index maps the subject to an array containing the rumor id.
static func test_subject_index_populated_on_register() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_idx", "npc_subject")
	engine.register_rumor(r)
	if not engine._subject_index.has("npc_subject"):
		push_error("test_subject_index_populated_on_register: subject key missing")
		return false
	var ids: Array = engine._subject_index["npc_subject"]
	return ids.size() == 1 and ids[0] == "r_idx"


## After a rumor expires (tick_decay removes it), its id is removed from _subject_index.
## If it was the only rumor for that subject, the subject key itself is removed.
static func test_subject_index_cleared_after_expiry() -> bool:
	var engine := PropagationEngine.new()
	# shelf_life_ticks=1, intensity=1 → expires on first tick_decay call.
	var r := _make_rumor("r_exp_idx", "npc_expire_subj", Rumor.ClaimType.ACCUSATION, 1, 0.5, 0, 1)
	engine.register_rumor(r)
	engine.tick_decay()
	# Rumor must be gone from live_rumors and subject key must be absent from index.
	if engine.live_rumors.has("r_exp_idx"):
		push_error("test_subject_index_cleared_after_expiry: rumor still in live_rumors")
		return false
	return not engine._subject_index.has("npc_expire_subj")


## Calling register_rumor() twice with the same rumor does not add a duplicate index entry.
static func test_subject_index_idempotent_on_double_register() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_idem_idx", "npc_idem_subj")
	engine.register_rumor(r)
	engine.register_rumor(r)
	if not engine._subject_index.has("npc_idem_subj"):
		push_error("test_subject_index_idempotent_on_double_register: subject key missing")
		return false
	return engine._subject_index["npc_idem_subj"].size() == 1


# ── β (spread probability) tests ──────────────────────────────────────────────

## Same-faction: 1.0 × 1.0 × 1.0 × FACTION_MOD_SAME(1.2) × 1.8 = 2.16 → clamped to 1.0.
static func test_calc_beta_same_faction_clamped() -> bool:
	var engine := PropagationEngine.new()
	var beta := engine.calc_beta(1.0, 1.0, 1.0, "merchant", "merchant")
	return beta == 1.0


## Opposing-faction: 1.0 × 1.0 × 1.0 × FACTION_MOD_OPPOSING(0.5) × 1.8 = 0.90.
static func test_calc_beta_opposing_faction() -> bool:
	var engine := PropagationEngine.new()
	var beta := engine.calc_beta(1.0, 1.0, 1.0, "merchant", "noble")
	return absf(beta - 0.9) < 0.001


## Neutral-faction: 1.0 × 1.0 × 1.0 × FACTION_MOD_NEUTRAL(0.8) × 1.8 = 1.44 → clamped to 1.0.
static func test_calc_beta_neutral_faction() -> bool:
	var engine := PropagationEngine.new()
	# "unknown" faction pair is neither same nor opposing → FACTION_MOD_NEUTRAL
	var beta := engine.calc_beta(1.0, 1.0, 1.0, "merchant", "unknown_faction")
	return beta == 1.0


## Heat modifier reduces effective credulity before the β computation.
## credulity=0.5, heat_modifier=0.3 → effective_credulity=0.2.
## base = 1.0 × 0.2 × 1.0 × 1.2 × 1.8 = 0.432.
static func test_calc_beta_heat_modifier_reduces_credulity() -> bool:
	var engine := PropagationEngine.new()
	var beta_no_heat := engine.calc_beta(1.0, 0.5, 1.0, "merchant", "merchant")
	var beta_heated  := engine.calc_beta(1.0, 0.5, 1.0, "merchant", "merchant", 0.3)
	var expected := clampf(1.0 * clampf(0.5 - 0.3, 0.0, 1.0) * 1.0
			* PropagationEngine.FACTION_MOD_SAME * 1.8, 0.0, 1.0)
	return beta_heated < beta_no_heat and absf(beta_heated - expected) < 0.001


## Day-phase and location mods are added after the clamped base, increasing β.
static func test_calc_beta_day_phase_and_location_additive() -> bool:
	var engine := PropagationEngine.new()
	# Low inputs so base is below 1.0 and there is room to add the mods.
	var base_only  := engine.calc_beta(0.4, 0.4, 0.4, "a", "b")
	var with_mods  := engine.calc_beta(0.4, 0.4, 0.4, "a", "b", 0.0, 0.10, 0.20)
	return with_mods > base_only


## β is always in [0.0, 1.0] for any combination of extreme inputs.
static func test_calc_beta_result_always_in_range() -> bool:
	var engine := PropagationEngine.new()
	var cases := [
		engine.calc_beta(5.0, 5.0, 5.0, "merchant", "merchant"),
		engine.calc_beta(0.0, 0.0, 0.0, "merchant", "noble"),
		engine.calc_beta(1.0, 1.0, 1.0, "x", "y", 1.0, 0.5, 0.5),
	]
	for b in cases:
		if b < 0.0 or b > 1.0:
			push_error("test_calc_beta_result_always_in_range: β out of range: %f" % b)
			return false
	return true


# ── γ (recovery probability) tests ───────────────────────────────────────────

## loyalty=1.0, temperament=0.0 → γ = 1.0 × 1.0 × 0.30 = 0.30.
static func test_calc_gamma_high_loyalty_low_temperament() -> bool:
	var engine := PropagationEngine.new()
	var gamma := engine.calc_gamma(1.0, 0.0)
	return absf(gamma - 0.30) < 0.001


## loyalty=0.0 → γ = 0.0 regardless of temperament.
static func test_calc_gamma_zero_loyalty() -> bool:
	var engine := PropagationEngine.new()
	var gamma := engine.calc_gamma(0.0, 0.9)
	return gamma == 0.0


## γ is always in [0.0, 1.0] even for extreme input values.
static func test_calc_gamma_result_clamped() -> bool:
	var engine := PropagationEngine.new()
	var gamma := engine.calc_gamma(10.0, -5.0)
	return gamma >= 0.0 and gamma <= 1.0


# ── Registration tests ────────────────────────────────────────────────────────

## Registering the same rumor id twice does not create duplicate entries.
static func test_register_rumor_idempotent() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_idem")
	engine.register_rumor(r)
	engine.register_rumor(r)
	return engine.live_rumors.size() == 1 and engine.lineage.size() == 1


## Registering a root rumor (no parent) creates a lineage entry with mutation_type="original".
static func test_register_rumor_creates_lineage_entry() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_root")
	engine.register_rumor(r)
	if not engine.lineage.has("r_root"):
		push_error("test_register_rumor_creates_lineage_entry: missing lineage entry")
		return false
	var entry: Dictionary = engine.lineage["r_root"]
	return entry.get("mutation_type") == "original" and entry.get("parent_id", "ERR") == ""


# ── Shelf-life decay tests ────────────────────────────────────────────────────

## A rumor with shelf_life_ticks=1 (intensity=1 → believability=0.2) expires after
## one tick because decay_one_tick() subtracts 1/shelf_life = 1.0 ≥ believability.
static func test_tick_decay_removes_expired_rumor() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_short", "npc_a", Rumor.ClaimType.ACCUSATION, 1, 0.5, 0, 1)
	engine.register_rumor(r)
	engine.tick_decay()
	return not engine.live_rumors.has("r_short")


## A rumor with shelf_life_ticks=200 (intensity=5 → believability=1.0) is still live
## after one tick (decay per tick = 1/200 = 0.005).
static func test_tick_decay_preserves_live_rumor() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_long", "npc_a", Rumor.ClaimType.ACCUSATION, 5, 0.5, 0, 200)
	engine.register_rumor(r)
	engine.tick_decay()
	return engine.live_rumors.has("r_long")


# ── Chain detection tests ─────────────────────────────────────────────────────

## No live rumors → detect_chain returns NONE.
static func test_detect_chain_none_when_no_rumors() -> bool:
	var engine := PropagationEngine.new()
	var info := engine.detect_chain("npc_a", Rumor.ClaimType.ACCUSATION)
	return info.get("chain_type") == PropagationEngine.ChainType.NONE


## Existing ACCUSATION on "npc_target" + new ACCUSATION → SAME_TYPE.
static func test_detect_chain_same_type() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_acc", "npc_target", Rumor.ClaimType.ACCUSATION))
	var info := engine.detect_chain("npc_target", Rumor.ClaimType.ACCUSATION)
	return info.get("chain_type") == PropagationEngine.ChainType.SAME_TYPE


## Existing SCANDAL + seeding HERESY on same subject → ESCALATION (defined escalation pair).
static func test_detect_chain_escalation_scandal_to_heresy() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_scandal", "npc_target", Rumor.ClaimType.SCANDAL))
	var info := engine.detect_chain("npc_target", Rumor.ClaimType.HERESY)
	return info.get("chain_type") == PropagationEngine.ChainType.ESCALATION


## Existing ILLNESS + seeding DEATH on same subject → ESCALATION (second defined pair).
static func test_detect_chain_escalation_illness_to_death() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_ill", "npc_target", Rumor.ClaimType.ILLNESS))
	var info := engine.detect_chain("npc_target", Rumor.ClaimType.DEATH)
	return info.get("chain_type") == PropagationEngine.ChainType.ESCALATION


## Existing PRAISE (positive) + new ACCUSATION (negative) on same subject → CONTRADICTION.
static func test_detect_chain_contradiction_positive_vs_negative() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_praise", "npc_target", Rumor.ClaimType.PRAISE))
	var info := engine.detect_chain("npc_target", Rumor.ClaimType.ACCUSATION)
	return info.get("chain_type") == PropagationEngine.ChainType.CONTRADICTION


## ESCALATION takes priority over a simultaneous CONTRADICTION match.
## Setup: SCANDAL (existing) + PROPHECY (positive existing) → seeding HERESY.
## SCANDAL→HERESY is an escalation pair; PROPHECY vs HERESY would be a contradiction.
## Result must be ESCALATION.
static func test_detect_chain_escalation_priority_over_contradiction() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_scandal", "npc_t", Rumor.ClaimType.SCANDAL))
	engine.register_rumor(_make_rumor("r_proph",   "npc_t", Rumor.ClaimType.PROPHECY))
	var info := engine.detect_chain("npc_t", Rumor.ClaimType.HERESY)
	return info.get("chain_type") == PropagationEngine.ChainType.ESCALATION


## A live ACCUSATION about "npc_a" does NOT form a chain when seeding about "npc_b".
static func test_detect_chain_different_subject_returns_none() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_acc", "npc_a", Rumor.ClaimType.ACCUSATION))
	var info := engine.detect_chain("npc_b", Rumor.ClaimType.ACCUSATION)
	return info.get("chain_type") == PropagationEngine.ChainType.NONE


# ── Chain bonus application tests ────────────────────────────────────────────

## SAME_TYPE: believability += 0.15 (capped 1.0), intensity += 1 (capped 5).
static func test_apply_chain_bonus_same_type() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_bonus", "npc_t", Rumor.ClaimType.ACCUSATION, 3)
	r.current_believability = 0.5
	var chain_info := {"chain_type": PropagationEngine.ChainType.SAME_TYPE, "existing_rumor": null}
	engine.apply_chain_bonus(r, chain_info)
	return absf(r.current_believability - 0.65) < 0.001 and r.intensity == 4


## ESCALATION: believability += 0.25 (capped 1.0), mutability halved.
static func test_apply_chain_bonus_escalation() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_esc", "npc_t", Rumor.ClaimType.HERESY, 2)
	r.current_believability = 0.4
	r.mutability = 0.8
	var chain_info := {"chain_type": PropagationEngine.ChainType.ESCALATION, "existing_rumor": null}
	engine.apply_chain_bonus(r, chain_info)
	return absf(r.current_believability - 0.65) < 0.001 and absf(r.mutability - 0.4) < 0.001


## CONTRADICTION: believability -= 0.10 (clamped ≥ 0.0).
static func test_apply_chain_bonus_contradiction() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_contra", "npc_t", Rumor.ClaimType.ACCUSATION, 2)
	r.current_believability = 0.5
	var chain_info := {"chain_type": PropagationEngine.ChainType.CONTRADICTION, "existing_rumor": null}
	engine.apply_chain_bonus(r, chain_info)
	return absf(r.current_believability - 0.4) < 0.001


## NONE: apply_chain_bonus does not modify the rumor.
static func test_apply_chain_bonus_none_is_noop() -> bool:
	var engine := PropagationEngine.new()
	var r := _make_rumor("r_noop", "npc_t", Rumor.ClaimType.ACCUSATION, 2)
	r.current_believability = 0.5
	var before_bel := r.current_believability
	var before_int := r.intensity
	var chain_info := {"chain_type": PropagationEngine.ChainType.NONE, "existing_rumor": null}
	engine.apply_chain_bonus(r, chain_info)
	return r.current_believability == before_bel and r.intensity == before_int


# ── Lineage chain query tests ─────────────────────────────────────────────────

## A root rumor with no parent has a chain of exactly [root_id].
static func test_get_lineage_chain_root_only() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_root"))
	var chain := engine.get_lineage_chain("r_root")
	return chain.size() == 1 and chain[0] == "r_root"


## A mutated child's chain is [parent_id, child_id] in ancestor-first order.
static func test_get_lineage_chain_parent_child() -> bool:
	var engine := PropagationEngine.new()
	engine.register_rumor(_make_rumor("r_parent"))
	## Manually inject the child without triggering random mutation.
	var child := Rumor.create("r_child", "npc_a", Rumor.ClaimType.ACCUSATION, 3, 0.5, 1, 99, "r_parent")
	engine.live_rumors["r_child"] = child
	engine.lineage["r_child"] = {"parent_id": "r_parent", "mutation_type": "exaggerate", "tick": 1}
	var chain := engine.get_lineage_chain("r_child")
	return chain.size() == 2 and chain[0] == "r_parent" and chain[1] == "r_child"


## An unknown id returns an array containing just that id (not in lineage → no traversal).
static func test_get_lineage_chain_unknown_id() -> bool:
	var engine := PropagationEngine.new()
	var chain := engine.get_lineage_chain("unknown_rumor")
	return chain.size() == 1 and chain[0] == "unknown_rumor"


# ── Day-phase / location helper tests ────────────────────────────────────────

## Slot 0 (night) = -0.15 penalty.
static func test_calc_day_phase_mod_slot_0_night() -> bool:
	var engine := PropagationEngine.new()
	return absf(engine.calc_day_phase_mod(0) - (-0.15)) < 0.001


## Slot 5 (evening) = +0.15 bonus.
static func test_calc_day_phase_mod_slot_5_evening() -> bool:
	var engine := PropagationEngine.new()
	return absf(engine.calc_day_phase_mod(5) - 0.15) < 0.001


## Out-of-range slots (negative or ≥ 6) return 0.0 without crash.
static func test_calc_day_phase_mod_out_of_range() -> bool:
	var engine := PropagationEngine.new()
	return engine.calc_day_phase_mod(-1) == 0.0 and engine.calc_day_phase_mod(6) == 0.0


## Tavern returns +0.20 (highest susceptibility location).
static func test_calc_location_susceptibility_tavern() -> bool:
	var engine := PropagationEngine.new()
	return absf(engine.calc_location_susceptibility("tavern") - 0.20) < 0.001


## Home returns -0.10 (lowest susceptibility location).
static func test_calc_location_susceptibility_home_negative() -> bool:
	var engine := PropagationEngine.new()
	return absf(engine.calc_location_susceptibility("home") - (-0.10)) < 0.001


## Unknown location key returns 0.0.
static func test_calc_location_susceptibility_unknown() -> bool:
	var engine := PropagationEngine.new()
	return engine.calc_location_susceptibility("dungeon") == 0.0

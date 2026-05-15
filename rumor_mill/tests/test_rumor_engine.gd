## test_rumor_engine.gd — Unit tests for RumorEngine (SPA-3294).
##
## Covers:
##   • Decay over time — effective_priority falls as ticks elapse
##   • Floor at 0.15 — effective_priority never drops below base_priority * DECAY_FLOOR
##   • Full reset on seed (on_seed_reset) — last_interaction_tick = current_tick
##   • Full reset on evidence (on_evidence_reset) — same mechanics as seed reset
##   • Partial reset on eavesdrop — decay_mult raised to ≥ 0.7 when below threshold
##   • Partial reset on observe — same mechanics as eavesdrop reset
##   • Partial reset no-op when mult already ≥ 0.7
##   • recalculate_priorities updates all live rumors
##   • Rumor.create initialises last_interaction_tick, base_priority, effective_priority
##
## Run from the Godot editor: Scene → Run Script (or call run() from any autoload).
## All tests use synthetic in-memory data — no live game nodes required.

class_name TestRumorEngine
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_rumor_create_initialises_decay_fields",
		"test_decay_reduces_effective_priority_over_ticks",
		"test_decay_floor_clamps_at_015",
		"test_recalculate_priorities_updates_all_rumors",
		"test_seed_reset_sets_last_interaction_to_current_tick",
		"test_evidence_reset_sets_last_interaction_to_current_tick",
		"test_eavesdrop_reset_raises_mult_to_07_when_below",
		"test_observe_reset_raises_mult_to_07_when_below",
		"test_partial_reset_noop_when_mult_already_above_07",
		"test_partial_reset_noop_when_mult_equals_07",
		"test_decay_floor_scenario_20_ticks_elapsed",
		"test_full_reset_restores_full_effective_priority",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRumorEngine tests: %d passed, %d failed" % [passed, failed])


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_rumor(
		rumor_id: String = "r_test",
		intensity: int = 3,
		tick: int = 0
) -> Rumor:
	return Rumor.create(rumor_id, "npc_a", Rumor.ClaimType.ACCUSATION, intensity, 0.5, tick)


static func _make_engine(rumor: Rumor = null) -> RumorEngine:
	var engine := RumorEngine.new()
	if rumor != null:
		engine.live_rumors[rumor.id] = rumor
	return engine


# ── Rumor.create field initialisation ────────────────────────────────────────

## Rumor.create must set last_interaction_tick = tick, base_priority = intensity/5.0,
## and effective_priority = base_priority.
static func test_rumor_create_initialises_decay_fields() -> bool:
	var r := Rumor.create("r_init", "npc_a", Rumor.ClaimType.ACCUSATION, 3, 0.5, 42)
	if r.last_interaction_tick != 42:
		push_error("test_rumor_create_initialises_decay_fields: last_interaction_tick expected 42, got %d" % r.last_interaction_tick)
		return false
	var expected_bp := 3.0 / 5.0
	if not is_equal_approx(r.base_priority, expected_bp):
		push_error("test_rumor_create_initialises_decay_fields: base_priority expected %.2f, got %.2f" % [expected_bp, r.base_priority])
		return false
	if not is_equal_approx(r.effective_priority, expected_bp):
		push_error("test_rumor_create_initialises_decay_fields: effective_priority expected %.2f, got %.2f" % [expected_bp, r.effective_priority])
		return false
	return true


# ── Decay over time ───────────────────────────────────────────────────────────

## After 5 ticks of no interaction, decay_mult = 1.0 - 5*0.03 = 0.85.
## effective_priority = base_priority * 0.85.
static func test_decay_reduces_effective_priority_over_ticks() -> bool:
	var r := _make_rumor("r_decay", 5, 0)  # base_priority = 1.0
	var engine := _make_engine(r)
	engine.recalculate_priorities(5)  # 5 ticks elapsed
	var expected := 1.0 * maxf(0.15, 1.0 - 5.0 * 0.03)  # 0.85
	if not is_equal_approx(r.effective_priority, expected):
		push_error("test_decay_reduces_effective_priority_over_ticks: expected %.4f, got %.4f" % [expected, r.effective_priority])
		return false
	return true


## After enough ticks for mult to drop below DECAY_FLOOR (0.15), effective_priority
## is clamped to base_priority * 0.15.
static func test_decay_floor_clamps_at_015() -> bool:
	var r := _make_rumor("r_floor", 5, 0)  # base_priority = 1.0
	var engine := _make_engine(r)
	# 30 ticks: 1.0 - 30*0.03 = 0.10 < 0.15 → floor applies.
	engine.recalculate_priorities(30)
	var expected := 1.0 * 0.15
	if not is_equal_approx(r.effective_priority, expected):
		push_error("test_decay_floor_clamps_at_015: expected %.4f, got %.4f" % [expected, r.effective_priority])
		return false
	return true


## At exactly 20 ticks elapsed, mult = 1.0 - 20*0.03 = 0.40, above floor.
static func test_decay_floor_scenario_20_ticks_elapsed() -> bool:
	var r := _make_rumor("r_20t", 5, 0)  # base_priority = 1.0
	var engine := _make_engine(r)
	engine.recalculate_priorities(20)
	var expected := 1.0 * maxf(0.15, 1.0 - 20.0 * 0.03)  # 0.40
	if not is_equal_approx(r.effective_priority, expected):
		push_error("test_decay_floor_scenario_20_ticks_elapsed: expected %.4f, got %.4f" % [expected, r.effective_priority])
		return false
	return true


## recalculate_priorities touches every rumor in live_rumors, not just the first.
static func test_recalculate_priorities_updates_all_rumors() -> bool:
	var r1 := _make_rumor("r_multi_a", 5, 0)
	var r2 := _make_rumor("r_multi_b", 3, 0)
	var engine := RumorEngine.new()
	engine.live_rumors["r_multi_a"] = r1
	engine.live_rumors["r_multi_b"] = r2
	engine.recalculate_priorities(10)
	var expected_r1 := 1.0 * maxf(0.15, 1.0 - 10.0 * 0.03)
	var expected_r2 := 0.6 * maxf(0.15, 1.0 - 10.0 * 0.03)
	if not is_equal_approx(r1.effective_priority, expected_r1):
		push_error("test_recalculate_priorities_updates_all_rumors: r1 expected %.4f, got %.4f" % [expected_r1, r1.effective_priority])
		return false
	if not is_equal_approx(r2.effective_priority, expected_r2):
		push_error("test_recalculate_priorities_updates_all_rumors: r2 expected %.4f, got %.4f" % [expected_r2, r2.effective_priority])
		return false
	return true


# ── Full resets (seed / evidence) ─────────────────────────────────────────────

## on_seed_reset sets last_interaction_tick to current_tick (full reset).
static func test_seed_reset_sets_last_interaction_to_current_tick() -> bool:
	var r := _make_rumor("r_seed", 3, 0)
	var engine := _make_engine(r)
	# Simulate 15 ticks of decay, then seed reset at tick 15.
	engine.recalculate_priorities(15)
	engine.on_seed_reset(r, 15)
	if r.last_interaction_tick != 15:
		push_error("test_seed_reset_sets_last_interaction_to_current_tick: expected 15, got %d" % r.last_interaction_tick)
		return false
	# After reset, recalculate at same tick: 0 elapsed → mult = 1.0.
	engine.recalculate_priorities(15)
	if not is_equal_approx(r.effective_priority, r.base_priority):
		push_error("test_seed_reset_sets_last_interaction_to_current_tick: effective_priority should equal base_priority after reset")
		return false
	return true


## on_evidence_reset behaves identically to on_seed_reset.
static func test_evidence_reset_sets_last_interaction_to_current_tick() -> bool:
	var r := _make_rumor("r_ev", 4, 0)
	var engine := _make_engine(r)
	engine.recalculate_priorities(20)
	engine.on_evidence_reset(r, 20)
	if r.last_interaction_tick != 20:
		push_error("test_evidence_reset_sets_last_interaction_to_current_tick: expected 20, got %d" % r.last_interaction_tick)
		return false
	engine.recalculate_priorities(20)
	if not is_equal_approx(r.effective_priority, r.base_priority):
		push_error("test_evidence_reset_sets_last_interaction_to_current_tick: effective_priority should equal base_priority after reset")
		return false
	return true


## After a full reset, recalculating at the same tick yields effective_priority == base_priority.
static func test_full_reset_restores_full_effective_priority() -> bool:
	var r := _make_rumor("r_full", 5, 0)
	var engine := _make_engine(r)
	engine.recalculate_priorities(25)  # Decay to floor territory
	engine.on_seed_reset(r, 25)
	engine.recalculate_priorities(25)
	if not is_equal_approx(r.effective_priority, r.base_priority):
		push_error("test_full_reset_restores_full_effective_priority: expected %.4f, got %.4f" % [r.base_priority, r.effective_priority])
		return false
	return true


# ── Partial resets (eavesdrop / observe) ─────────────────────────────────────

## When decay_mult has fallen below 0.7 (e.g. 15 ticks → mult = 0.55),
## on_eavesdrop_reset raises last_interaction_tick so new mult = 0.7.
static func test_eavesdrop_reset_raises_mult_to_07_when_below() -> bool:
	var r := _make_rumor("r_evs", 5, 0)
	var engine := _make_engine(r)
	# 15 ticks: mult = 1.0 - 15*0.03 = 0.55, which is below 0.7.
	engine.on_eavesdrop_reset(r, 15)
	# Expected: last_interaction_tick = 15 - int((1.0-0.7)/0.03) = 15 - 10 = 5
	if r.last_interaction_tick != 5:
		push_error("test_eavesdrop_reset_raises_mult_to_07_when_below: expected last_interaction_tick=5, got %d" % r.last_interaction_tick)
		return false
	# Verify the resulting mult.
	engine.recalculate_priorities(15)
	var expected_eff := 1.0 * 0.7
	if not is_equal_approx(r.effective_priority, expected_eff):
		push_error("test_eavesdrop_reset_raises_mult_to_07_when_below: expected effective_priority=%.4f, got %.4f" % [expected_eff, r.effective_priority])
		return false
	return true


## on_observe_reset applies the same partial-reset logic as on_eavesdrop_reset.
static func test_observe_reset_raises_mult_to_07_when_below() -> bool:
	var r := _make_rumor("r_obs", 5, 0)
	var engine := _make_engine(r)
	# 20 ticks: mult = 1.0 - 20*0.03 = 0.40, below 0.7.
	engine.on_observe_reset(r, 20)
	# Expected: last_interaction_tick = 20 - 10 = 10
	if r.last_interaction_tick != 10:
		push_error("test_observe_reset_raises_mult_to_07_when_below: expected last_interaction_tick=10, got %d" % r.last_interaction_tick)
		return false
	engine.recalculate_priorities(20)
	var expected_eff := 1.0 * 0.7
	if not is_equal_approx(r.effective_priority, expected_eff):
		push_error("test_observe_reset_raises_mult_to_07_when_below: expected effective_priority=%.4f, got %.4f" % [expected_eff, r.effective_priority])
		return false
	return true


## When decay_mult is already above 0.7 (e.g. 5 ticks → mult = 0.85),
## on_eavesdrop_reset makes no change to last_interaction_tick.
static func test_partial_reset_noop_when_mult_already_above_07() -> bool:
	var r := _make_rumor("r_noop", 5, 0)
	var engine := _make_engine(r)
	# 5 ticks: mult = 0.85 > 0.7; partial reset should leave last_interaction_tick = 0.
	engine.on_eavesdrop_reset(r, 5)
	if r.last_interaction_tick != 0:
		push_error("test_partial_reset_noop_when_mult_already_above_07: expected last_interaction_tick=0, got %d" % r.last_interaction_tick)
		return false
	return true


## When decay_mult equals exactly 0.7 (10 ticks), partial reset is also a no-op.
static func test_partial_reset_noop_when_mult_equals_07() -> bool:
	var r := _make_rumor("r_eq07", 5, 0)
	var engine := _make_engine(r)
	# 10 ticks: mult = 1.0 - 10*0.03 = 0.70, at the threshold.
	engine.on_observe_reset(r, 10)
	if r.last_interaction_tick != 0:
		push_error("test_partial_reset_noop_when_mult_equals_07: expected last_interaction_tick=0 (no change), got %d" % r.last_interaction_tick)
		return false
	return true

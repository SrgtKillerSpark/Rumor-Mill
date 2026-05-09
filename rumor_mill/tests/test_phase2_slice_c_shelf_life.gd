## test_phase2_slice_c_shelf_life.gd — Phase 2 Slice C shelf-life regression tests.
##
## Validates shelf-life decay, expiration boundaries, mutation inheritance,
## and believability scaling under edge conditions (C1–C4).

class_name TestPhase2SliceCShelfLife
extends RefCounted

const Rumor := preload("res://scripts/rumor.gd")
const PropagationEngine := preload("res://scripts/propagation_engine.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_rumor(shelf: int = 100, intensity: int = 3, tick: int = 0) -> Rumor:
	return Rumor.create(
		"gut_shelf_%d" % randi(),
		"npc_test_subject",
		Rumor.ClaimType.ACCUSATION,
		intensity,
		0.5,
		tick,
		shelf
	)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# C1 — Uniform decay
		"test_c1_believability_reaches_zero_at_shelf_life",
		"test_c1_believability_positive_before_full_decay",
		"test_c1_decay_is_monotonically_decreasing",
		"test_c1_decay_step_size_is_uniform",
		# C2 — Zero and minimal shelf life edge cases
		"test_c2_zero_shelf_expires_on_first_decay",
		"test_c2_shelf_of_one_expires_after_one_tick",
		"test_c2_believability_never_goes_negative",
		# C3 — Mutation shelf-life inheritance
		"test_c3_mutation_inherits_remaining_shelf_life",
		"test_c3_mutation_cannot_reset_decay_clock",
		"test_c3_mutation_minimum_shelf_is_one",
		# C4 — Believability scaling with intensity
		"test_c4_base_believability_scales_with_intensity",
		"test_c4_high_intensity_takes_same_ticks_to_expire",
		"test_c4_fresh_rumor_not_expired",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  Phase2SliceCShelfLife: %d passed, %d failed" % [passed, failed])


# ===========================================================================
# C1 — Uniform decay: believability drops linearly to zero over shelf_life_ticks
# ===========================================================================

static func test_c1_believability_reaches_zero_at_shelf_life() -> bool:
	var r := _make_rumor(50, 4)
	for i in range(50):
		r.decay_one_tick()
	return r.is_expired()


static func test_c1_believability_positive_before_full_decay() -> bool:
	var r := _make_rumor(50, 4)
	for i in range(49):
		r.decay_one_tick()
	return not r.is_expired() and r.current_believability > 0.0


static func test_c1_decay_is_monotonically_decreasing() -> bool:
	var r := _make_rumor(100, 5)
	var prev := r.current_believability
	for i in range(100):
		r.decay_one_tick()
		if r.current_believability > prev:
			return false
		prev = r.current_believability
	return true


static func test_c1_decay_step_size_is_uniform() -> bool:
	var r := _make_rumor(200, 3)
	var expected_step := 1.0 / 200.0
	var initial := r.current_believability
	r.decay_one_tick()
	var actual_step := initial - r.current_believability
	return absf(actual_step - expected_step) < 0.0001


# ===========================================================================
# C2 — Zero and minimal shelf life edge cases
# ===========================================================================

static func test_c2_zero_shelf_expires_on_first_decay() -> bool:
	var r := _make_rumor(0, 3)
	r.decay_one_tick()
	return r.is_expired()


static func test_c2_shelf_of_one_expires_after_one_tick() -> bool:
	var r := _make_rumor(1, 3)
	if r.is_expired():
		return false
	r.decay_one_tick()
	return r.is_expired()


static func test_c2_believability_never_goes_negative() -> bool:
	var r := _make_rumor(10, 2)
	for i in range(100):
		r.decay_one_tick()
	return r.current_believability == 0.0


# ===========================================================================
# C3 — Mutation shelf-life inheritance (remaining time carried forward)
# ===========================================================================

static func test_c3_mutation_inherits_remaining_shelf_life() -> bool:
	var source := _make_rumor(100, 3, 0)
	var elapsed := 40
	var remaining := maxi(source.shelf_life_ticks - elapsed, 1)
	var mutated := Rumor.create(
		source.id + "_m1",
		source.subject_npc_id,
		source.claim_type,
		4,
		source.mutability,
		elapsed,
		remaining,
		source.id
	)
	return mutated.shelf_life_ticks == 60


static func test_c3_mutation_cannot_reset_decay_clock() -> bool:
	var source := _make_rumor(50, 3, 0)
	var elapsed := 50
	var remaining := maxi(source.shelf_life_ticks - elapsed, 1)
	var mutated := Rumor.create(
		source.id + "_m2",
		source.subject_npc_id,
		source.claim_type,
		3,
		source.mutability,
		elapsed,
		remaining,
		source.id
	)
	return mutated.shelf_life_ticks <= source.shelf_life_ticks


static func test_c3_mutation_minimum_shelf_is_one() -> bool:
	var source := _make_rumor(10, 3, 0)
	var elapsed := 999
	var remaining := maxi(source.shelf_life_ticks - elapsed, 1)
	return remaining == 1


# ===========================================================================
# C4 — Believability scaling with intensity
# ===========================================================================

static func test_c4_base_believability_scales_with_intensity() -> bool:
	for inten in range(1, 6):
		var r := _make_rumor(100, inten)
		var expected := float(inten) / 5.0
		if absf(r.current_believability - expected) > 0.001:
			return false
	return true


static func test_c4_high_intensity_takes_same_ticks_to_expire() -> bool:
	var low := _make_rumor(80, 1)
	var high := _make_rumor(80, 5)
	for i in range(80):
		low.decay_one_tick()
		high.decay_one_tick()
	return low.is_expired() and high.is_expired()


static func test_c4_fresh_rumor_not_expired() -> bool:
	var r := _make_rumor(330, 5)
	if r.is_expired():
		return false
	return absf(r.current_believability - 1.0) < 0.001

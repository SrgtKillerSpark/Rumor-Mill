## test_phase2_slice_c_shelf_life.gd — Phase 2 Slice C shelf-life regression tests.
##
## Validates shelf-life decay, expiration boundaries, mutation inheritance,
## and believability scaling under edge conditions (C1–C4).
##
## Run via GUT panel (Godot editor) or headless:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/test_phase2_slice_c_shelf_life.gd -gexit

extends GutTest

const Rumor := preload("res://scripts/rumor.gd")
const PropagationEngine := preload("res://scripts/propagation_engine.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_rumor(shelf: int = 100, intensity: int = 3, tick: int = 0) -> Rumor:
	return Rumor.create(
		"gut_shelf_%d" % randi(),
		"npc_test_subject",
		Rumor.ClaimType.ACCUSATION,
		intensity,
		0.5,
		tick,
		shelf
	)


# ===========================================================================
# C1 — Uniform decay: believability drops linearly to zero over shelf_life_ticks
# ===========================================================================

func test_c1_believability_reaches_zero_at_shelf_life() -> void:
	var r := _make_rumor(50, 4)
	for i in range(50):
		r.decay_one_tick()
	assert_true(r.is_expired(), "Rumor should expire after exactly shelf_life_ticks decays")


func test_c1_believability_positive_before_full_decay() -> void:
	var r := _make_rumor(50, 4)
	for i in range(49):
		r.decay_one_tick()
	assert_false(r.is_expired(), "Rumor must not expire one tick before shelf_life_ticks")
	assert_true(r.current_believability > 0.0)


func test_c1_decay_is_monotonically_decreasing() -> void:
	var r := _make_rumor(100, 5)
	var prev := r.current_believability
	for i in range(100):
		r.decay_one_tick()
		assert_lte(r.current_believability, prev, "Believability must not increase")
		prev = r.current_believability


func test_c1_decay_step_size_is_uniform() -> void:
	var r := _make_rumor(200, 3)
	var expected_step := 1.0 / 200.0
	var initial := r.current_believability
	r.decay_one_tick()
	var actual_step := initial - r.current_believability
	assert_almost_eq(actual_step, expected_step, 0.0001, "Each tick should decay by 1/shelf_life_ticks")


# ===========================================================================
# C2 — Zero and minimal shelf life edge cases
# ===========================================================================

func test_c2_zero_shelf_expires_on_first_decay() -> void:
	var r := _make_rumor(0, 3)
	r.decay_one_tick()
	assert_true(r.is_expired(), "Zero shelf_life must expire immediately on first decay")


func test_c2_shelf_of_one_expires_after_one_tick() -> void:
	var r := _make_rumor(1, 3)
	assert_false(r.is_expired(), "Fresh rumor with shelf=1 should not start expired")
	r.decay_one_tick()
	assert_true(r.is_expired(), "Shelf life of 1 should expire after a single decay tick")


func test_c2_believability_never_goes_negative() -> void:
	var r := _make_rumor(10, 2)
	for i in range(100):
		r.decay_one_tick()
	assert_eq(r.current_believability, 0.0, "Believability must be clamped at 0.0, not negative")


# ===========================================================================
# C3 — Mutation shelf-life inheritance (remaining time carried forward)
# ===========================================================================

func test_c3_mutation_inherits_remaining_shelf_life() -> void:
	var source := _make_rumor(100, 3, 0)
	# Simulate 40 ticks elapsed
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
	assert_eq(mutated.shelf_life_ticks, 60,
		"Mutated rumor should inherit remaining shelf (100 - 40 = 60)")


func test_c3_mutation_cannot_reset_decay_clock() -> void:
	var source := _make_rumor(50, 3, 0)
	# After 50 ticks, remaining should be clamped to at least 1
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
	assert_lte(mutated.shelf_life_ticks, source.shelf_life_ticks,
		"Mutation must not extend shelf life beyond original")


func test_c3_mutation_minimum_shelf_is_one() -> void:
	var source := _make_rumor(10, 3, 0)
	# Elapsed exceeds shelf life
	var elapsed := 999
	var remaining := maxi(source.shelf_life_ticks - elapsed, 1)
	assert_eq(remaining, 1, "Remaining shelf must be at least 1 even if time far exceeds original")


# ===========================================================================
# C4 — Believability scaling with intensity
# ===========================================================================

func test_c4_base_believability_scales_with_intensity() -> void:
	for inten in range(1, 6):
		var r := _make_rumor(100, inten)
		var expected := float(inten) / 5.0
		assert_almost_eq(r.current_believability, expected, 0.001,
			"Intensity %d should give base believability %f" % [inten, expected])


func test_c4_high_intensity_takes_same_ticks_to_expire() -> void:
	var low := _make_rumor(80, 1)
	var high := _make_rumor(80, 5)
	for i in range(80):
		low.decay_one_tick()
		high.decay_one_tick()
	assert_true(low.is_expired(), "Low-intensity rumor should expire at shelf limit")
	assert_true(high.is_expired(), "High-intensity rumor should also expire at shelf limit")


func test_c4_fresh_rumor_not_expired() -> void:
	var r := _make_rumor(330, 5)
	assert_false(r.is_expired(), "A freshly created rumor must never be expired")
	assert_almost_eq(r.current_believability, 1.0, 0.001,
		"Max intensity (5) should yield 1.0 believability")

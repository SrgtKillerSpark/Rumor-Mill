## test_milestone_tracker.gd — Unit tests for milestone_tracker.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_PROGRESS, C_WARNING, C_DANGER, C_NEUTRAL
##   • Initial state: _fired empty, _scenario_id=0, refs null,
##                    _show_milestone is invalid Callable
##   • _fire() deduplication guard: same ID fires at most once
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMilestoneTracker
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_mt() -> MilestoneTracker:
	return MilestoneTracker.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_progress_is_green",
		"test_c_warning_is_amber",
		"test_c_danger_is_red",
		"test_c_neutral_is_parchment",
		# Initial state
		"test_initial_fired_empty",
		"test_initial_scenario_id_zero",
		"test_initial_rep_system_null",
		"test_initial_scenario_mgr_null",
		"test_initial_intel_store_null",
		"test_initial_show_milestone_invalid",
		# _fire() dedup guard
		"test_fire_dedup_only_fires_once",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMilestoneTracker tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_progress_is_green() -> bool:
	var mt := _make_mt()
	var ok := mt.C_PROGRESS.g > 0.90 and mt.C_PROGRESS.r < 0.60
	mt.free()
	return ok


static func test_c_warning_is_amber() -> bool:
	var mt := _make_mt()
	var ok := mt.C_WARNING.r > 0.90 and mt.C_WARNING.g > 0.65 and mt.C_WARNING.b < 0.35
	mt.free()
	return ok


static func test_c_danger_is_red() -> bool:
	var mt := _make_mt()
	var ok := mt.C_DANGER.r > 0.85 and mt.C_DANGER.g < 0.40
	mt.free()
	return ok


static func test_c_neutral_is_parchment() -> bool:
	var mt := _make_mt()
	# parchment: high r, high g, moderate b — all fairly close
	var ok := mt.C_NEUTRAL.r > 0.75 and mt.C_NEUTRAL.g > 0.70 and mt.C_NEUTRAL.b > 0.45
	mt.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_fired_empty() -> bool:
	var mt := _make_mt()
	var ok := mt._fired.is_empty()
	mt.free()
	return ok


static func test_initial_scenario_id_zero() -> bool:
	var mt := _make_mt()
	var ok := mt._scenario_id == 0
	mt.free()
	return ok


static func test_initial_rep_system_null() -> bool:
	var mt := _make_mt()
	var ok := mt._rep_system == null
	mt.free()
	return ok


static func test_initial_scenario_mgr_null() -> bool:
	var mt := _make_mt()
	var ok := mt._scenario_mgr == null
	mt.free()
	return ok


static func test_initial_intel_store_null() -> bool:
	var mt := _make_mt()
	var ok := mt._intel_store == null
	mt.free()
	return ok


static func test_initial_show_milestone_invalid() -> bool:
	var mt := _make_mt()
	var ok := not mt._show_milestone.is_valid()
	mt.free()
	return ok


# ── _fire() deduplication guard ───────────────────────────────────────────────
#
# _fire(id, text, color) marks _fired[id]=true.
# A second call with the same id must return early — _fired stays with one entry.

static func test_fire_dedup_only_fires_once() -> bool:
	var mt := _make_mt()
	# _show_milestone is invalid, so no crash even if called.
	mt._fire("test_id", "Test text", Color.WHITE)
	var after_first: int = mt._fired.size()
	mt._fire("test_id", "Test text again", Color.WHITE)
	var after_second: int = mt._fired.size()
	var ok := after_first == 1 and after_second == 1 and mt._fired.has("test_id")
	mt.free()
	return ok

## test_end_screen_scoring.gd — Unit tests for end_screen_scoring.gd (SPA-1026).
##
## Covers:
##   • PEAK_BELIEF_TARGET: 6 entries, one per scenario; correct NPC ids
##   • NPC_OUTCOMES: 6 scenario keys, each with 3 NPC entries
##   • Color palette constants
##   • Initial instance state: all refs null, tween/arrow arrays empty
##   • setup(): stores world, day_night, and container refs
##   • Accessors: get_tween_targets(), get_bonus_lbl(), get_rating_row(),
##     get_arrow_labels() return correct initial values
##
## EndScreenScoring extends RefCounted — safe to instantiate without scene tree.
## populate_stats() and populate_npc_outcomes() require live world and container
## nodes and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenScoring
extends RefCounted

const EndScreenScoringScript := preload("res://scripts/end_screen_scoring.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_esc() -> RefCounted:
	return EndScreenScoringScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# PEAK_BELIEF_TARGET
		"test_peak_belief_target_has_six_entries",
		"test_peak_belief_target_scenario_1_is_edric",
		"test_peak_belief_target_scenario_3_is_calder",
		"test_peak_belief_target_scenario_6_is_marta",
		# NPC_OUTCOMES
		"test_npc_outcomes_has_six_scenario_keys",
		"test_npc_outcomes_scenario_1_has_three_npcs",
		"test_npc_outcomes_scenario_1_first_npc_is_edric",
		"test_npc_outcomes_scenario_4_has_aldous",
		"test_npc_outcomes_scenario_6_has_marta",
		# Color constants
		"test_c_win_colour",
		"test_c_fail_colour",
		"test_c_stat_label_colour",
		"test_c_stat_value_colour",
		# Initial state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_stats_container_null",
		"test_initial_npc_container_null",
		"test_initial_tween_targets_empty",
		"test_initial_bonus_lbl_null",
		"test_initial_rating_row_null",
		"test_initial_arrow_labels_empty",
		# Accessors
		"test_get_tween_targets_returns_empty",
		"test_get_bonus_lbl_returns_null",
		"test_get_rating_row_returns_null",
		"test_get_arrow_labels_returns_empty",
		# setup()
		"test_setup_stores_world_ref",
		"test_setup_stores_day_night_ref",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenScoring tests: %d passed, %d failed" % [passed, failed])


# ── PEAK_BELIEF_TARGET ────────────────────────────────────────────────────────

static func test_peak_belief_target_has_six_entries() -> bool:
	var count := _make_esc().PEAK_BELIEF_TARGET.size()
	if count != 6:
		push_error("test_peak_belief_target_has_six_entries: expected 6, got %d" % count)
		return false
	return true


static func test_peak_belief_target_scenario_1_is_edric() -> bool:
	var entry: Dictionary = _make_esc().PEAK_BELIEF_TARGET.get(1, {})
	return entry.get("id", "") == "edric_fenn"


static func test_peak_belief_target_scenario_3_is_calder() -> bool:
	var entry: Dictionary = _make_esc().PEAK_BELIEF_TARGET.get(3, {})
	return entry.get("id", "") == "calder_fenn"


static func test_peak_belief_target_scenario_6_is_marta() -> bool:
	var entry: Dictionary = _make_esc().PEAK_BELIEF_TARGET.get(6, {})
	return entry.get("id", "") == "marta_coin"


# ── NPC_OUTCOMES ──────────────────────────────────────────────────────────────

static func test_npc_outcomes_has_six_scenario_keys() -> bool:
	var count := _make_esc().NPC_OUTCOMES.size()
	if count != 6:
		push_error("test_npc_outcomes_has_six_scenario_keys: expected 6, got %d" % count)
		return false
	return true


static func test_npc_outcomes_scenario_1_has_three_npcs() -> bool:
	var npcs: Array = _make_esc().NPC_OUTCOMES.get("scenario_1", [])
	if npcs.size() != 3:
		push_error("test_npc_outcomes_scenario_1_has_three_npcs: expected 3, got %d" % npcs.size())
		return false
	return true


static func test_npc_outcomes_scenario_1_first_npc_is_edric() -> bool:
	var npcs: Array = _make_esc().NPC_OUTCOMES.get("scenario_1", [])
	return (npcs as Array)[0].get("id", "") == "edric_fenn"


static func test_npc_outcomes_scenario_4_has_aldous() -> bool:
	var npcs: Array = _make_esc().NPC_OUTCOMES.get("scenario_4", [])
	var found := false
	for npc in npcs:
		if npc.get("id", "") == "aldous_prior":
			found = true
			break
	return found


static func test_npc_outcomes_scenario_6_has_marta() -> bool:
	var npcs: Array = _make_esc().NPC_OUTCOMES.get("scenario_6", [])
	var found := false
	for npc in npcs:
		if npc.get("id", "") == "marta_coin":
			found = true
			break
	return found


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_win_colour() -> bool:
	return _make_esc().C_WIN == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_fail_colour() -> bool:
	return _make_esc().C_FAIL == Color(0.85, 0.18, 0.12, 1.0)


static func test_c_stat_label_colour() -> bool:
	return _make_esc().C_STAT_LABEL == Color(0.75, 0.65, 0.50, 1.0)


static func test_c_stat_value_colour() -> bool:
	return _make_esc().C_STAT_VALUE == Color(0.91, 0.85, 0.70, 1.0)


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	return _make_esc()._world_ref == null


static func test_initial_day_night_ref_null() -> bool:
	return _make_esc()._day_night_ref == null


static func test_initial_stats_container_null() -> bool:
	return _make_esc()._stats_container == null


static func test_initial_npc_container_null() -> bool:
	return _make_esc()._npc_container == null


static func test_initial_tween_targets_empty() -> bool:
	return _make_esc()._tween_targets.is_empty()


static func test_initial_bonus_lbl_null() -> bool:
	return _make_esc()._bonus_lbl == null


static func test_initial_rating_row_null() -> bool:
	return _make_esc()._rating_row == null


static func test_initial_arrow_labels_empty() -> bool:
	return _make_esc()._arrow_labels.is_empty()


# ── Accessors ─────────────────────────────────────────────────────────────────

static func test_get_tween_targets_returns_empty() -> bool:
	return _make_esc().get_tween_targets().is_empty()


static func test_get_bonus_lbl_returns_null() -> bool:
	return _make_esc().get_bonus_lbl() == null


static func test_get_rating_row_returns_null() -> bool:
	return _make_esc().get_rating_row() == null


static func test_get_arrow_labels_returns_empty() -> bool:
	return _make_esc().get_arrow_labels().is_empty()


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_world_ref() -> bool:
	var esc := _make_esc()
	var stub := Node2D.new()
	esc.setup(stub, null, null, null)
	var ok := esc._world_ref == stub
	stub.free()
	return ok


static func test_setup_stores_day_night_ref() -> bool:
	var esc := _make_esc()
	var stub := Node.new()
	esc.setup(null, stub, null, null)
	var ok := esc._day_night_ref == stub
	stub.free()
	return ok

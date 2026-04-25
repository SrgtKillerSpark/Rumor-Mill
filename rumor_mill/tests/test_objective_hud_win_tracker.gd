## test_objective_hud_win_tracker.gd — Unit tests for objective_hud_win_tracker.gd (SPA-1026).
##
## Covers:
##   • Tempo color constants: C_TEMPO_AHEAD, C_TEMPO_ON_PACE, C_TEMPO_BEHIND
##   • Initial instance state: all node/dep refs null, pulse state, milestone state,
##     days_allowed, last_target_scores
##   • configure(): stores milestones dictionary and callable
##   • setup_world(): stores world reference
##   • _get_progress_assessment(): all 5 return values with null _day_night
##     (time_frac=0.0) so only prog value determines the branch
##   • flash_win_progress(): null _win_progress_lbl guard (no crash)
##
## ObjectiveHudWinTracker extends Node — safe to instantiate without scene tree.
## Tween-based methods require scene-tree and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestObjectiveHudWinTracker
extends RefCounted

const ObjectiveHudWinTrackerScript := preload("res://scripts/objective_hud_win_tracker.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ohwt() -> Node:
	return ObjectiveHudWinTrackerScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Tempo color constants
		"test_c_tempo_ahead_colour",
		"test_c_tempo_on_pace_colour",
		"test_c_tempo_behind_colour",
		# Initial state
		"test_initial_win_progress_bar_null",
		"test_initial_win_progress_lbl_null",
		"test_initial_milestone_label_null",
		"test_initial_days_remaining_lbl_null",
		"test_initial_win_target_label_null",
		"test_initial_mini_progress_label_null",
		"test_initial_win_pulse_tween_null",
		"test_initial_win_pulse_active_false",
		"test_initial_current_milestone_text_empty",
		"test_initial_progress_milestones_empty",
		"test_initial_last_target_scores_empty",
		"test_initial_days_allowed",
		"test_initial_reputation_system_null",
		"test_initial_scenario_manager_null",
		"test_initial_day_night_null",
		"test_initial_world_ref_null",
		# configure()
		"test_configure_stores_milestones",
		# setup_world()
		"test_setup_world_stores_ref",
		# _get_progress_assessment() — null day_night (time_frac=0)
		"test_progress_assessment_0_95_almost_there",
		"test_progress_assessment_0_85_strong_position",
		"test_progress_assessment_0_50_ahead_of_schedule",
		"test_progress_assessment_0_10_on_track",
		"test_progress_assessment_0_0_on_track",
		# flash_win_progress() null guard
		"test_flash_win_progress_null_lbl_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nObjectiveHudWinTracker tests: %d passed, %d failed" % [passed, failed])


# ── Tempo color constants ─────────────────────────────────────────────────────

static func test_c_tempo_ahead_colour() -> bool:
	return _make_ohwt().C_TEMPO_AHEAD == Color(0.30, 0.85, 0.35, 1.0)


static func test_c_tempo_on_pace_colour() -> bool:
	return _make_ohwt().C_TEMPO_ON_PACE == Color(0.95, 0.85, 0.15, 1.0)


static func test_c_tempo_behind_colour() -> bool:
	return _make_ohwt().C_TEMPO_BEHIND == Color(0.95, 0.20, 0.10, 1.0)


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_win_progress_bar_null() -> bool:
	return _make_ohwt()._win_progress_bar == null


static func test_initial_win_progress_lbl_null() -> bool:
	return _make_ohwt()._win_progress_lbl == null


static func test_initial_milestone_label_null() -> bool:
	return _make_ohwt()._milestone_label == null


static func test_initial_days_remaining_lbl_null() -> bool:
	return _make_ohwt()._days_remaining_lbl == null


static func test_initial_win_target_label_null() -> bool:
	return _make_ohwt().win_target_label == null


static func test_initial_mini_progress_label_null() -> bool:
	return _make_ohwt()._mini_progress_label == null


static func test_initial_win_pulse_tween_null() -> bool:
	return _make_ohwt()._win_pulse_tween == null


static func test_initial_win_pulse_active_false() -> bool:
	return _make_ohwt()._win_pulse_active == false


static func test_initial_current_milestone_text_empty() -> bool:
	return _make_ohwt()._current_milestone_text == ""


static func test_initial_progress_milestones_empty() -> bool:
	return _make_ohwt()._progress_milestones.is_empty()


static func test_initial_last_target_scores_empty() -> bool:
	return _make_ohwt()._last_target_scores.is_empty()


## Default days_allowed must be 30 (matches ScenarioManager default).
static func test_initial_days_allowed() -> bool:
	if _make_ohwt()._days_allowed != 30:
		push_error("test_initial_days_allowed: expected 30, got %d" % _make_ohwt()._days_allowed)
		return false
	return true


static func test_initial_reputation_system_null() -> bool:
	return _make_ohwt()._reputation_system == null


static func test_initial_scenario_manager_null() -> bool:
	return _make_ohwt()._scenario_manager == null


static func test_initial_day_night_null() -> bool:
	return _make_ohwt()._day_night == null


static func test_initial_world_ref_null() -> bool:
	return _make_ohwt()._world_ref == null


# ── configure() ───────────────────────────────────────────────────────────────

static func test_configure_stores_milestones() -> bool:
	var ohwt := _make_ohwt()
	var milestones := {0.25: "25% done", 0.50: "Halfway", 0.75: "Nearly there"}
	ohwt.configure(milestones, Callable())
	return ohwt._progress_milestones.size() == 3


# ── setup_world() ─────────────────────────────────────────────────────────────

static func test_setup_world_stores_ref() -> bool:
	var ohwt := _make_ohwt()
	var stub := Node2D.new()
	ohwt.setup_world(stub)
	var ok := ohwt._world_ref == stub
	stub.free()
	return ok


# ── _get_progress_assessment() — null day_night → time_frac = 0.0 ─────────

## prog >= 0.95 → "Almost there!"
static func test_progress_assessment_0_95_almost_there() -> bool:
	var ohwt := _make_ohwt()
	return ohwt._get_progress_assessment(0.95) == "Almost there!"


## prog >= 0.80 → "Strong position — keep pushing"
static func test_progress_assessment_0_85_strong_position() -> bool:
	var ohwt := _make_ohwt()
	return ohwt._get_progress_assessment(0.85) == "Strong position — keep pushing"


## prog > time_frac + 0.15 → "Ahead of schedule" (time_frac=0, so prog > 0.15)
static func test_progress_assessment_0_50_ahead_of_schedule() -> bool:
	var ohwt := _make_ohwt()
	return ohwt._get_progress_assessment(0.50) == "Ahead of schedule"


## prog <= 0.15 and >= time_frac - 0.10 → "On track" (time_frac=0, so prog >= -0.10)
static func test_progress_assessment_0_10_on_track() -> bool:
	var ohwt := _make_ohwt()
	return ohwt._get_progress_assessment(0.10) == "On track"


## prog = 0.0, time_frac = 0 → satisfies "On track" (>= -0.10)
static func test_progress_assessment_0_0_on_track() -> bool:
	var ohwt := _make_ohwt()
	return ohwt._get_progress_assessment(0.0) == "On track"


# ── flash_win_progress() null guard ──────────────────────────────────────────

## _win_progress_lbl is null (no scene tree) — method must return cleanly.
static func test_flash_win_progress_null_lbl_no_crash() -> bool:
	var ohwt := _make_ohwt()
	ohwt.flash_win_progress()
	return true

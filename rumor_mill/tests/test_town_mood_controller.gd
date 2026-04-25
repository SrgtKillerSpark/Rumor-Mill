## test_town_mood_controller.gd — Unit tests for TownMoodController constants and initial state (SPA-1041).
##
## Covers:
##   • Tuning constants: _SPREAD_THRESHOLD, _HEAT_THRESHOLD, _TENSION_THRESHOLD,
##     _GUARD_SPEED_SCALE, _DIM_ALPHA, _DIM_FADE_SEC, _FLICKER_RANGE,
##     _MILESTONES (3 elements: 0.25, 0.50, 0.75)
##   • Initial state: _spread_audio_active, _tension_audio_active, _guards_alerted
##     all false; _fired_milestones empty; all external refs null
##   • set_camera(): stores the camera ref
##
## Strategy: TownMoodController extends RefCounted (no Node). All methods that
## require world/rep/sm refs are guarded by null checks — on_game_tick() returns
## immediately when _world is null, so it is safe to call without scene tree.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestTownMoodController
extends RefCounted

const TownMoodControllerScript := preload("res://scripts/town_mood_controller.gd")


static func _make_tmc() -> TownMoodController:
	return TownMoodControllerScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_spread_threshold_is_5",
		"test_heat_threshold_is_50",
		"test_tension_threshold_is_075",
		"test_guard_speed_scale_is_15",
		"test_dim_alpha_is_035",
		"test_dim_fade_sec_is_1",
		"test_milestones_has_3_entries",
		"test_milestones_are_025_050_075",
		"test_flicker_range_is_007",

		# ── initial state ──
		"test_initial_spread_audio_inactive",
		"test_initial_tension_audio_inactive",
		"test_initial_guards_not_alerted",
		"test_initial_fired_milestones_empty",
		"test_initial_world_ref_null",
		"test_initial_camera_null",

		# ── set_camera ──
		"test_set_camera_stores_ref",

		# ── on_game_tick guard ──
		"test_on_game_tick_noop_when_world_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_spread_threshold_is_5() -> bool:
	return TownMoodControllerScript._SPREAD_THRESHOLD == 5


func test_heat_threshold_is_50() -> bool:
	return absf(TownMoodControllerScript._HEAT_THRESHOLD - 50.0) < 0.001


func test_tension_threshold_is_075() -> bool:
	return absf(TownMoodControllerScript._TENSION_THRESHOLD - 0.75) < 0.001


func test_guard_speed_scale_is_15() -> bool:
	return absf(TownMoodControllerScript._GUARD_SPEED_SCALE - 1.5) < 0.001


func test_dim_alpha_is_035() -> bool:
	return absf(TownMoodControllerScript._DIM_ALPHA - 0.35) < 0.001


func test_dim_fade_sec_is_1() -> bool:
	return absf(TownMoodControllerScript._DIM_FADE_SEC - 1.0) < 0.001


func test_milestones_has_3_entries() -> bool:
	return TownMoodControllerScript._MILESTONES.size() == 3


func test_milestones_are_025_050_075() -> bool:
	var m: Array[float] = TownMoodControllerScript._MILESTONES
	return absf(m[0] - 0.25) < 0.001 \
		and absf(m[1] - 0.50) < 0.001 \
		and absf(m[2] - 0.75) < 0.001


func test_flicker_range_is_007() -> bool:
	return absf(TownMoodControllerScript._FLICKER_RANGE - 0.07) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_spread_audio_inactive() -> bool:
	return _make_tmc()._spread_audio_active == false


func test_initial_tension_audio_inactive() -> bool:
	return _make_tmc()._tension_audio_active == false


func test_initial_guards_not_alerted() -> bool:
	return _make_tmc()._guards_alerted == false


func test_initial_fired_milestones_empty() -> bool:
	return _make_tmc()._fired_milestones.is_empty()


func test_initial_world_ref_null() -> bool:
	return _make_tmc()._world == null


func test_initial_camera_null() -> bool:
	return _make_tmc()._camera == null


# ══════════════════════════════════════════════════════════════════════════════
# set_camera
# ══════════════════════════════════════════════════════════════════════════════

func test_set_camera_stores_ref() -> bool:
	var tmc := _make_tmc()
	var cam := Camera2D.new()
	tmc.set_camera(cam)
	var ok := tmc._camera == cam
	cam.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# on_game_tick guard clause
# ══════════════════════════════════════════════════════════════════════════════

func test_on_game_tick_noop_when_world_null() -> bool:
	var tmc := _make_tmc()
	# All external refs are null — on_game_tick returns at the guard check.
	# No error should fire.
	tmc.on_game_tick(0)
	return true  # reaching here means no crash

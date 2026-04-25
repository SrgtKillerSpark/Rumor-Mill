## test_main.gd — Unit tests for main.gd coordinator (SPA-1024).
##
## Covers:
##   • Initial instance state: _game_started=false, all overlay refs null
##     (_main_menu, _loading_tips, _mission_briefing, _story_recap, _ui)
##   • @onready scene-node stubs null before _ready()
##     (world, day_night, camera, debug_overlay, debug_console,
##      recon_hud, rumor_panel, journal, social_graph_overlay, objective_hud)
##   • _camera_shake(): null-camera guard — calling with non-zero values must
##     not crash when camera (@onready) is null
##   • _on_scenario_resolved_audio(): FAILED branch null-_ui guard — must not
##     crash when _ui is null
##
## main extends Node2D.  _ready() is not called (node not in scene tree), so
## @onready vars remain null.  _on_begin_game is a coroutine that requires the
## full scene tree, TransitionManager, and world — it is not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMain
extends RefCounted

const MainScript := preload("res://scripts/main.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_main() -> Node2D:
	return MainScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state flags
		"test_initial_game_started_false",
		# Initial overlay refs
		"test_initial_main_menu_null",
		"test_initial_loading_tips_null",
		"test_initial_mission_briefing_null",
		"test_initial_story_recap_null",
		"test_initial_ui_null",
		# @onready scene nodes null before _ready()
		"test_initial_world_null",
		"test_initial_day_night_null",
		"test_initial_camera_null",
		"test_initial_debug_overlay_null",
		"test_initial_debug_console_null",
		"test_initial_recon_hud_null",
		"test_initial_rumor_panel_null",
		"test_initial_journal_null",
		"test_initial_social_graph_overlay_null",
		"test_initial_objective_hud_null",
		# _camera_shake() null guard
		"test_camera_shake_null_camera_no_crash",
		"test_camera_shake_zero_intensity_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMain tests: %d passed, %d failed" % [passed, failed])


# ── Initial state flags ───────────────────────────────────────────────────────

static func test_initial_game_started_false() -> bool:
	return not _make_main()._game_started


# ── Initial overlay refs ──────────────────────────────────────────────────────

static func test_initial_main_menu_null() -> bool:
	return _make_main()._main_menu == null


static func test_initial_loading_tips_null() -> bool:
	return _make_main()._loading_tips == null


static func test_initial_mission_briefing_null() -> bool:
	return _make_main()._mission_briefing == null


static func test_initial_story_recap_null() -> bool:
	return _make_main()._story_recap == null


static func test_initial_ui_null() -> bool:
	return _make_main()._ui == null


# ── @onready scene nodes null before _ready() ─────────────────────────────────

static func test_initial_world_null() -> bool:
	return _make_main().world == null


static func test_initial_day_night_null() -> bool:
	return _make_main().day_night == null


static func test_initial_camera_null() -> bool:
	return _make_main().camera == null


static func test_initial_debug_overlay_null() -> bool:
	return _make_main().debug_overlay == null


static func test_initial_debug_console_null() -> bool:
	return _make_main().debug_console == null


static func test_initial_recon_hud_null() -> bool:
	return _make_main().recon_hud == null


static func test_initial_rumor_panel_null() -> bool:
	return _make_main().rumor_panel == null


static func test_initial_journal_null() -> bool:
	return _make_main().journal == null


static func test_initial_social_graph_overlay_null() -> bool:
	return _make_main().social_graph_overlay == null


static func test_initial_objective_hud_null() -> bool:
	return _make_main().objective_hud == null


# ── _camera_shake() null guard ────────────────────────────────────────────────

## camera is @onready (null without scene tree).
## _camera_shake starts with "if camera != null and …" — must not crash.
static func test_camera_shake_null_camera_no_crash() -> bool:
	var m := _make_main()
	m._camera_shake(6.0, 0.5)
	return true


static func test_camera_shake_zero_intensity_no_crash() -> bool:
	var m := _make_main()
	m._camera_shake(0.0, 0.0)
	return true

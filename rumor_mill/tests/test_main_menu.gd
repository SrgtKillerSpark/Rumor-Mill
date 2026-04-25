## test_main_menu.gd — Unit tests for main_menu.gd (SPA-1042).
##
## Covers:
##   • Palette constants (characteristic colour assertions)
##   • Phase enum ordinals: MAIN=0, SELECT=1, BRIEFING=2, INTRO=3,
##                          SETTINGS=4, CREDITS=5, STATS=6
##   • Initial state: _phase=Phase.MAIN, _scenarios empty
##   • Initial node refs null (no scene tree, _ready() not called)
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMainMenu
extends RefCounted

const MainMenuScript := preload("res://scripts/main_menu.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_menu() -> CanvasLayer:
	return MainMenuScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_backdrop_near_black",
		"test_c_title_is_gold",
		"test_c_btn_text_near_white",
		"test_c_sky_top_is_dark_purple",
		# Phase enum ordinals
		"test_phase_main_is_zero",
		"test_phase_select_is_one",
		"test_phase_briefing_is_two",
		"test_phase_intro_is_three",
		"test_phase_settings_is_four",
		"test_phase_credits_is_five",
		"test_phase_stats_is_six",
		# Initial state
		"test_initial_phase_is_main",
		"test_initial_scenarios_empty",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_panel_main_null",
		"test_initial_panel_credits_null",
		"test_initial_version_label_null",
		"test_initial_settings_module_null",
		"test_initial_stats_module_null",
		"test_initial_select_module_null",
		"test_initial_briefing_module_null",
		"test_initial_phase_tween_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMainMenu tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var m := _make_menu()
	var ok := m.C_BACKDROP.r < 0.10 and m.C_BACKDROP.g < 0.05 and m.C_BACKDROP.a > 0.90
	m.free()
	return ok


static func test_c_title_is_gold() -> bool:
	var m := _make_menu()
	# gold: high r, high g, low b
	var ok := m.C_TITLE.r > 0.85 and m.C_TITLE.g > 0.70 and m.C_TITLE.b < 0.20
	m.free()
	return ok


static func test_c_btn_text_near_white() -> bool:
	var m := _make_menu()
	var ok := m.C_BTN_TEXT.r > 0.90 and m.C_BTN_TEXT.g > 0.85 and m.C_BTN_TEXT.b > 0.75
	m.free()
	return ok


static func test_c_sky_top_is_dark_purple() -> bool:
	var m := _make_menu()
	# dark purple: low r, very low g, moderate b
	var ok := m.C_SKY_TOP.b > m.C_SKY_TOP.g and m.C_SKY_TOP.r > m.C_SKY_TOP.g
	m.free()
	return ok


# ── Phase enum ordinals ───────────────────────────────────────────────────────

static func test_phase_main_is_zero() -> bool:
	var ok := MainMenuScript.Phase.MAIN == 0
	return ok


static func test_phase_select_is_one() -> bool:
	var ok := MainMenuScript.Phase.SELECT == 1
	return ok


static func test_phase_briefing_is_two() -> bool:
	var ok := MainMenuScript.Phase.BRIEFING == 2
	return ok


static func test_phase_intro_is_three() -> bool:
	var ok := MainMenuScript.Phase.INTRO == 3
	return ok


static func test_phase_settings_is_four() -> bool:
	var ok := MainMenuScript.Phase.SETTINGS == 4
	return ok


static func test_phase_credits_is_five() -> bool:
	var ok := MainMenuScript.Phase.CREDITS == 5
	return ok


static func test_phase_stats_is_six() -> bool:
	var ok := MainMenuScript.Phase.STATS == 6
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_phase_is_main() -> bool:
	var m := _make_menu()
	var ok := m._phase == MainMenuScript.Phase.MAIN
	m.free()
	return ok


static func test_initial_scenarios_empty() -> bool:
	var m := _make_menu()
	var ok := m._scenarios.is_empty()
	m.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var m := _make_menu()
	var ok := m._backdrop == null
	m.free()
	return ok


static func test_initial_panel_main_null() -> bool:
	var m := _make_menu()
	var ok := m._panel_main == null
	m.free()
	return ok


static func test_initial_panel_credits_null() -> bool:
	var m := _make_menu()
	var ok := m._panel_credits == null
	m.free()
	return ok


static func test_initial_version_label_null() -> bool:
	var m := _make_menu()
	var ok := m._version_label == null
	m.free()
	return ok


static func test_initial_settings_module_null() -> bool:
	var m := _make_menu()
	var ok := m._settings_module == null
	m.free()
	return ok


static func test_initial_stats_module_null() -> bool:
	var m := _make_menu()
	var ok := m._stats_module == null
	m.free()
	return ok


static func test_initial_select_module_null() -> bool:
	var m := _make_menu()
	var ok := m._select_module == null
	m.free()
	return ok


static func test_initial_briefing_module_null() -> bool:
	var m := _make_menu()
	var ok := m._briefing_module == null
	m.free()
	return ok


static func test_initial_phase_tween_null() -> bool:
	var m := _make_menu()
	var ok := m._phase_tween == null
	m.free()
	return ok

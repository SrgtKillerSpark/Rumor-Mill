## test_end_screen_panel_builder.gd — Unit tests for end_screen_panel_builder.gd (SPA-1026).
##
## Covers:
##   • Panel dimension constants: PANEL_W, PANEL_H
##   • Color palette constants
##   • Initial state of all public node-ref vars (null before build())
##   • Initial private state: _what_went_wrong_lbl
##
## EndScreenPanelBuilder extends RefCounted — safe to instantiate without scene tree.
## build() requires a live CanvasLayer parent and is not exercised here; tab-switch
## methods and the defeat insert also require live nodes.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenPanelBuilder
extends RefCounted

const EndScreenPanelBuilderScript := preload("res://scripts/end_screen_panel_builder.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_espb() -> RefCounted:
	return EndScreenPanelBuilderScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Dimension constants
		"test_panel_w",
		"test_panel_h",
		# Color constants
		"test_c_backdrop_colour",
		"test_c_panel_bg_colour",
		"test_c_panel_border_colour",
		"test_c_win_colour",
		"test_c_fail_colour",
		"test_c_tab_active_colour",
		"test_c_tab_inactive_colour",
		# Initial public node refs (all null before build())
		"test_initial_backdrop_null",
		"test_initial_panel_null",
		"test_initial_result_banner_null",
		"test_initial_scenario_title_null",
		"test_initial_narrative_lbl_null",
		"test_initial_stats_container_null",
		"test_initial_npc_container_null",
		"test_initial_btn_again_null",
		"test_initial_btn_next_null",
		"test_initial_btn_main_menu_null",
		"test_initial_tease_lbl_null",
		"test_initial_tab_results_null",
		"test_initial_tab_replay_null",
		"test_initial_results_container_null",
		"test_initial_replay_container_null",
		# Private state
		"test_initial_what_went_wrong_lbl_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenPanelBuilder tests: %d passed, %d failed" % [passed, failed])


# ── Dimension constants ───────────────────────────────────────────────────────

static func test_panel_w() -> bool:
	if _make_espb().PANEL_W != 760:
		push_error("test_panel_w: expected 760, got %d" % _make_espb().PANEL_W)
		return false
	return true


static func test_panel_h() -> bool:
	if _make_espb().PANEL_H != 640:
		push_error("test_panel_h: expected 640, got %d" % _make_espb().PANEL_H)
		return false
	return true


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_backdrop_colour() -> bool:
	return _make_espb().C_BACKDROP == Color(0.04, 0.02, 0.02, 0.90)


static func test_c_panel_bg_colour() -> bool:
	return _make_espb().C_PANEL_BG == Color(0.13, 0.09, 0.07, 1.0)


static func test_c_panel_border_colour() -> bool:
	return _make_espb().C_PANEL_BORDER == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_win_colour() -> bool:
	return _make_espb().C_WIN == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_fail_colour() -> bool:
	return _make_espb().C_FAIL == Color(0.85, 0.18, 0.12, 1.0)


static func test_c_tab_active_colour() -> bool:
	return _make_espb().C_TAB_ACTIVE == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_tab_inactive_colour() -> bool:
	return _make_espb().C_TAB_INACTIVE == Color(0.20, 0.14, 0.10, 1.0)


# ── Initial public node refs ──────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	return _make_espb().backdrop == null


static func test_initial_panel_null() -> bool:
	return _make_espb().panel == null


static func test_initial_result_banner_null() -> bool:
	return _make_espb().result_banner == null


static func test_initial_scenario_title_null() -> bool:
	return _make_espb().scenario_title == null


static func test_initial_narrative_lbl_null() -> bool:
	return _make_espb().narrative_lbl == null


static func test_initial_stats_container_null() -> bool:
	return _make_espb().stats_container == null


static func test_initial_npc_container_null() -> bool:
	return _make_espb().npc_container == null


static func test_initial_btn_again_null() -> bool:
	return _make_espb().btn_again == null


static func test_initial_btn_next_null() -> bool:
	return _make_espb().btn_next == null


static func test_initial_btn_main_menu_null() -> bool:
	return _make_espb().btn_main_menu == null


static func test_initial_tease_lbl_null() -> bool:
	return _make_espb().tease_lbl == null


static func test_initial_tab_results_null() -> bool:
	return _make_espb().tab_results == null


static func test_initial_tab_replay_null() -> bool:
	return _make_espb().tab_replay == null


static func test_initial_results_container_null() -> bool:
	return _make_espb().results_container == null


static func test_initial_replay_container_null() -> bool:
	return _make_espb().replay_container == null


# ── Private state ─────────────────────────────────────────────────────────────

static func test_initial_what_went_wrong_lbl_null() -> bool:
	return _make_espb()._what_went_wrong_lbl == null

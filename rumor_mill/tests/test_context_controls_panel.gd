## test_context_controls_panel.gd — Unit tests for context_controls_panel.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Mode enum ordinals: EXPLORE=0..PAUSED=4
##   • MODE_BINDINGS: 5 entries, one per Mode value
##   • Initial state: _panel/_hbox/_help_btn null, _current_mode=EXPLORE
##
## Run from the Godot editor: Scene → Run Script.

class_name TestContextControlsPanel
extends RefCounted

const ContextControlsPanelScript := preload("res://scripts/context_controls_panel.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ccp() -> CanvasLayer:
	return ContextControlsPanelScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark_semi",
		"test_c_key_gold",
		"test_c_active_green",
		# Mode enum ordinals
		"test_mode_explore_is_zero",
		"test_mode_rumor_panel_is_one",
		"test_mode_journal_is_two",
		"test_mode_social_graph_is_three",
		"test_mode_paused_is_four",
		# MODE_BINDINGS
		"test_mode_bindings_count",
		# Initial state
		"test_initial_panel_null",
		"test_initial_hbox_null",
		"test_initial_help_btn_null",
		"test_initial_current_mode_explore",
		"test_initial_controls_ref_null",
		"test_initial_has_actions_true",
		"test_initial_has_whispers_true",
		"test_initial_action_indicators_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nContextControlsPanel tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark_semi() -> bool:
	var ccp := _make_ccp()
	var ok := ccp.C_BG.r < 0.15 and ccp.C_BG.a < 0.90
	ccp.free()
	return ok


static func test_c_key_gold() -> bool:
	var ccp := _make_ccp()
	var ok := ccp.C_KEY.r > 0.85 and ccp.C_KEY.g > 0.70 and ccp.C_KEY.b < 0.20
	ccp.free()
	return ok


static func test_c_active_green() -> bool:
	var ccp := _make_ccp()
	var ok := ccp.C_ACTIVE.g > 0.90 and ccp.C_ACTIVE.r < 0.50
	ccp.free()
	return ok


# ── Mode enum ordinals ────────────────────────────────────────────────────────

static func test_mode_explore_is_zero() -> bool:
	var ok := ContextControlsPanelScript.Mode.EXPLORE == 0
	return ok


static func test_mode_rumor_panel_is_one() -> bool:
	var ok := ContextControlsPanelScript.Mode.RUMOR_PANEL == 1
	return ok


static func test_mode_journal_is_two() -> bool:
	var ok := ContextControlsPanelScript.Mode.JOURNAL == 2
	return ok


static func test_mode_social_graph_is_three() -> bool:
	var ok := ContextControlsPanelScript.Mode.SOCIAL_GRAPH == 3
	return ok


static func test_mode_paused_is_four() -> bool:
	var ok := ContextControlsPanelScript.Mode.PAUSED == 4
	return ok


# ── MODE_BINDINGS ─────────────────────────────────────────────────────────────

static func test_mode_bindings_count() -> bool:
	var ccp := _make_ccp()
	var ok := ccp.MODE_BINDINGS.size() == 5
	ccp.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._panel == null
	ccp.free()
	return ok


static func test_initial_hbox_null() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._hbox == null
	ccp.free()
	return ok


static func test_initial_help_btn_null() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._help_btn == null
	ccp.free()
	return ok


static func test_initial_current_mode_explore() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._current_mode == ContextControlsPanelScript.Mode.EXPLORE
	ccp.free()
	return ok


static func test_initial_controls_ref_null() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._controls_ref == null
	ccp.free()
	return ok


static func test_initial_has_actions_true() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._has_actions == true
	ccp.free()
	return ok


static func test_initial_has_whispers_true() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._has_whispers == true
	ccp.free()
	return ok


static func test_initial_action_indicators_empty() -> bool:
	var ccp := _make_ccp()
	var ok := ccp._action_indicators.is_empty()
	ccp.free()
	return ok

## test_objective_hud_nudge_manager.gd — Unit tests for objective_hud_nudge_manager.gd (SPA-1026).
##
## Covers:
##   • Color palette constants: C_NUDGE, C_MIDGAME_NUDGE, C_MIDGAME_NUDGE_BG
##   • _NUDGE_TEXTS: 4 entries, expected content for first and last items
##   • Initial instance state: nudge phase counters, budget counters, all UI/dep refs null
##
## ObjectiveHudNudgeManager extends Node — safe to instantiate without scene tree.
## _ready() and _process() are NOT called (node not in scene tree).
## UI build methods (setup, build_budget_label, build_midgame_nudge) require live
## VBoxContainer parents and scene-tree Tweens — not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestObjectiveHudNudgeManager
extends RefCounted

const ObjectiveHudNudgeManagerScript := preload("res://scripts/objective_hud_nudge_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ohnm() -> Node:
	return ObjectiveHudNudgeManagerScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Color constants
		"test_c_nudge_colour",
		"test_c_midgame_nudge_colour",
		"test_c_midgame_nudge_bg_colour",
		# _NUDGE_TEXTS
		"test_nudge_texts_count",
		"test_nudge_texts_first_is_observe",
		"test_nudge_texts_last_is_watch_spread",
		# Initial state — nudge subsystem
		"test_initial_nudge_phase_zero",
		"test_initial_nudge_last_phase_minus_one",
		"test_initial_nudge_panel_null",
		"test_initial_nudge_label_null",
		"test_initial_nudge_pulse_tween_null",
		# Initial state — budget subsystem
		"test_initial_budget_last_actions_minus_one",
		"test_initial_budget_last_whispers_minus_one",
		"test_initial_lbl_budget_null",
		"test_initial_delta_layer_null",
		# Initial state — mid-game nudge
		"test_initial_midgame_nudge_label_null",
		"test_initial_midgame_nudge_bg_null",
		"test_initial_midgame_nudge_last_phase_key_empty",
		# Initial state — dependencies
		"test_initial_vbox_null",
		"test_initial_intel_store_null",
		"test_initial_day_night_null",
		"test_initial_scenario_manager_null",
		"test_initial_world_ref_null",
		# Public label ref
		"test_initial_o_hint_label_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nObjectiveHudNudgeManager tests: %d passed, %d failed" % [passed, failed])


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_nudge_colour() -> bool:
	return _make_ohnm().C_NUDGE == Color(0.40, 1.0, 0.50, 1.0)


static func test_c_midgame_nudge_colour() -> bool:
	return _make_ohnm().C_MIDGAME_NUDGE == Color(0.80, 0.90, 0.65, 1.0)


static func test_c_midgame_nudge_bg_colour() -> bool:
	return _make_ohnm().C_MIDGAME_NUDGE_BG == Color(0.08, 0.06, 0.04, 0.85)


# ── _NUDGE_TEXTS ──────────────────────────────────────────────────────────────

static func test_nudge_texts_count() -> bool:
	var count := _make_ohnm()._NUDGE_TEXTS.size()
	if count != 4:
		push_error("test_nudge_texts_count: expected 4, got %d" % count)
		return false
	return true


static func test_nudge_texts_first_is_observe() -> bool:
	var first: String = _make_ohnm()._NUDGE_TEXTS[0]
	return first.contains("Observe")


static func test_nudge_texts_last_is_watch_spread() -> bool:
	var last: String = _make_ohnm()._NUDGE_TEXTS[3]
	return last.contains("spread")


# ── Initial state — nudge subsystem ──────────────────────────────────────────

static func test_initial_nudge_phase_zero() -> bool:
	return _make_ohnm()._nudge_phase == 0


static func test_initial_nudge_last_phase_minus_one() -> bool:
	return _make_ohnm()._nudge_last_phase == -1


static func test_initial_nudge_panel_null() -> bool:
	return _make_ohnm()._nudge_panel == null


static func test_initial_nudge_label_null() -> bool:
	return _make_ohnm()._nudge_label == null


static func test_initial_nudge_pulse_tween_null() -> bool:
	return _make_ohnm()._nudge_pulse_tween == null


# ── Initial state — budget subsystem ─────────────────────────────────────────

static func test_initial_budget_last_actions_minus_one() -> bool:
	return _make_ohnm()._budget_last_actions == -1


static func test_initial_budget_last_whispers_minus_one() -> bool:
	return _make_ohnm()._budget_last_whispers == -1


static func test_initial_lbl_budget_null() -> bool:
	return _make_ohnm()._lbl_budget == null


static func test_initial_delta_layer_null() -> bool:
	return _make_ohnm()._delta_layer == null


# ── Initial state — mid-game nudge ───────────────────────────────────────────

static func test_initial_midgame_nudge_label_null() -> bool:
	return _make_ohnm()._midgame_nudge_label == null


static func test_initial_midgame_nudge_bg_null() -> bool:
	return _make_ohnm()._midgame_nudge_bg == null


static func test_initial_midgame_nudge_last_phase_key_empty() -> bool:
	return _make_ohnm()._midgame_nudge_last_phase_key == ""


# ── Initial state — dependencies ─────────────────────────────────────────────

static func test_initial_vbox_null() -> bool:
	return _make_ohnm()._vbox == null


static func test_initial_intel_store_null() -> bool:
	return _make_ohnm()._intel_store == null


static func test_initial_day_night_null() -> bool:
	return _make_ohnm()._day_night == null


static func test_initial_scenario_manager_null() -> bool:
	return _make_ohnm()._scenario_manager == null


static func test_initial_world_ref_null() -> bool:
	return _make_ohnm()._world_ref == null


# ── Public label ref ──────────────────────────────────────────────────────────

static func test_initial_o_hint_label_null() -> bool:
	return _make_ohnm().o_hint_label == null

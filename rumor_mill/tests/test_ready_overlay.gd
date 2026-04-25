## test_ready_overlay.gd — Unit tests for ready_overlay.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Initial node refs null (setup() calls _build_shell() — not called here)
##   • Initial state: _objective_card={}, _scenario_title="", _recall_mode=false,
##                    _current_phase=0
##
## Run from the Godot editor: Scene → Run Script.

class_name TestReadyOverlay
extends RefCounted

const ReadyOverlayScript := preload("res://scripts/ready_overlay.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ro() -> CanvasLayer:
	return ReadyOverlayScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_backdrop_near_black",
		"test_c_title_warm_gold",
		"test_c_hint_soft_green",
		"test_c_action_blue",
		"test_c_danger_red",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_card_null",
		"test_initial_vbox_null",
		"test_initial_prompt_label_null",
		"test_initial_pulse_tween_null",
		# Initial state
		"test_initial_objective_card_empty",
		"test_initial_scenario_title_empty",
		"test_initial_recall_mode_false",
		"test_initial_current_phase_zero",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nReadyOverlay tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var ro := _make_ro()
	var ok := ro.C_BACKDROP.r < 0.10 and ro.C_BACKDROP.a > 0.65
	ro.free()
	return ok


static func test_c_title_warm_gold() -> bool:
	var ro := _make_ro()
	var ok := ro.C_TITLE.r > 0.90 and ro.C_TITLE.g > 0.75 and ro.C_TITLE.b < 0.50
	ro.free()
	return ok


static func test_c_hint_soft_green() -> bool:
	var ro := _make_ro()
	var ok := ro.C_HINT.g > 0.75 and ro.C_HINT.r < 0.75
	ro.free()
	return ok


static func test_c_action_blue() -> bool:
	var ro := _make_ro()
	var ok := ro.C_ACTION.b > 0.90 and ro.C_ACTION.r < 0.60
	ro.free()
	return ok


static func test_c_danger_red() -> bool:
	var ro := _make_ro()
	var ok := ro.C_DANGER.r > 0.85 and ro.C_DANGER.g < 0.45
	ro.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var ro := _make_ro()
	var ok := ro._backdrop == null
	ro.free()
	return ok


static func test_initial_card_null() -> bool:
	var ro := _make_ro()
	var ok := ro._card == null
	ro.free()
	return ok


static func test_initial_vbox_null() -> bool:
	var ro := _make_ro()
	var ok := ro._vbox == null
	ro.free()
	return ok


static func test_initial_prompt_label_null() -> bool:
	var ro := _make_ro()
	var ok := ro._prompt_label == null
	ro.free()
	return ok


static func test_initial_pulse_tween_null() -> bool:
	var ro := _make_ro()
	var ok := ro._pulse_tween == null
	ro.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_objective_card_empty() -> bool:
	var ro := _make_ro()
	var ok := ro._objective_card.is_empty()
	ro.free()
	return ok


static func test_initial_scenario_title_empty() -> bool:
	var ro := _make_ro()
	var ok := ro._scenario_title == ""
	ro.free()
	return ok


static func test_initial_recall_mode_false() -> bool:
	var ro := _make_ro()
	var ok := ro._recall_mode == false
	ro.free()
	return ok


static func test_initial_current_phase_zero() -> bool:
	var ro := _make_ro()
	var ok := ro._current_phase == 0
	ro.free()
	return ok

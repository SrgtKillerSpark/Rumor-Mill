## test_scenario2_hud.gd — Unit tests for scenario2_hud.gd (SPA-1042).
##
## Covers:
##   • C_ILLNESS palette constant
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT, MAX_NAMES_SHOWN
##   • _scenario_number(): returns 2
##   • Initial node refs null (no scene tree, _ready() not called)
##   • Initial state: _maren_neighbours = {}
##   • Inherited state: _world_ref, _day_night_ref, _result_lbl, _days_lbl
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario2Hud
extends RefCounted

const Scenario2HudScript := preload("res://scripts/scenario2_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario2HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_illness_is_sickly_green",
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		"test_max_names_shown",
		# _scenario_number()
		"test_scenario_number_is_two",
		# Initial node refs
		"test_initial_count_lbl_null",
		"test_initial_bar_null",
		"test_initial_bar_bg_null",
		"test_initial_believers_lbl_null",
		"test_initial_rejecters_lbl_null",
		"test_initial_maren_warning_lbl_null",
		"test_initial_escalation_lbl_null",
		"test_initial_pip_lbl_null",
		"test_initial_quarantine_btn_null",
		"test_initial_quarantine_dropdown_null",
		"test_initial_quarantine_status_lbl_null",
		# Initial state
		"test_initial_maren_neighbours_empty",
		# Inherited state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_result_lbl_null",
		"test_initial_days_lbl_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenario2Hud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_illness_is_sickly_green() -> bool:
	var h := _make_hud()
	# sickly green: moderate r, high g, low-moderate b
	var ok := h.C_ILLNESS.r > 0.40 and h.C_ILLNESS.g > 0.70 and h.C_ILLNESS.b < 0.40
	h.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_bar_width() -> bool:
	var h := _make_hud()
	var ok := h.BAR_WIDTH == 160
	h.free()
	return ok


static func test_bar_height() -> bool:
	var h := _make_hud()
	var ok := h.BAR_HEIGHT == 12
	h.free()
	return ok


static func test_max_names_shown() -> bool:
	var h := _make_hud()
	var ok := h.MAX_NAMES_SHOWN == 5
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_two() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 2
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_count_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._count_lbl == null
	h.free()
	return ok


static func test_initial_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._bar == null
	h.free()
	return ok


static func test_initial_bar_bg_null() -> bool:
	var h := _make_hud()
	var ok := h._bar_bg == null
	h.free()
	return ok


static func test_initial_believers_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._believers_lbl == null
	h.free()
	return ok


static func test_initial_rejecters_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._rejecters_lbl == null
	h.free()
	return ok


static func test_initial_maren_warning_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._maren_warning_lbl == null
	h.free()
	return ok


static func test_initial_escalation_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._escalation_lbl == null
	h.free()
	return ok


static func test_initial_pip_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._pip_lbl == null
	h.free()
	return ok


static func test_initial_quarantine_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._quarantine_btn == null
	h.free()
	return ok


static func test_initial_quarantine_dropdown_null() -> bool:
	var h := _make_hud()
	var ok := h._quarantine_dropdown == null
	h.free()
	return ok


static func test_initial_quarantine_status_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._quarantine_status_lbl == null
	h.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_maren_neighbours_empty() -> bool:
	var h := _make_hud()
	var ok := h._maren_neighbours.is_empty()
	h.free()
	return ok


# ── Inherited state ───────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var h := _make_hud()
	var ok := h._world_ref == null
	h.free()
	return ok


static func test_initial_day_night_ref_null() -> bool:
	var h := _make_hud()
	var ok := h._day_night_ref == null
	h.free()
	return ok


static func test_initial_result_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._result_lbl == null
	h.free()
	return ok


static func test_initial_days_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._days_lbl == null
	h.free()
	return ok

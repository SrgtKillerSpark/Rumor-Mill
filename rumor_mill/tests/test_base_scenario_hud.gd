## test_base_scenario_hud.gd — Unit tests for base_scenario_hud.gd (SPA-1042).
##
## Covers:
##   • Shared palette constants: C_PANEL_BG, C_HEADING, C_BODY, C_WIN, C_FAIL, C_NEUTRAL
##   • Initial instance state: _world_ref, _day_night_ref, _result_lbl, _days_lbl, _diff_lbl, _title_lbl
##   • _has_world_deps(): returns false when _world_ref is null
##   • _scenario_number(): base returns 0
##   • _display_name(): snake_case → Title Case conversion
##   • _phase_for_hour(): returns correct phase string for each time band
##
## BaseScenarioHud extends CanvasLayer. _ready() is NOT called (node is not
## added to the scene tree), so UI nodes built by _build_ui() remain null.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestBaseScenarioHud
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> BaseScenarioHud:
	return BaseScenarioHud.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_panel_bg_colour",
		"test_c_heading_colour",
		"test_c_body_colour",
		"test_c_win_colour",
		"test_c_fail_colour",
		"test_c_neutral_colour",
		# Initial state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_result_lbl_null",
		"test_initial_days_lbl_null",
		"test_initial_diff_lbl_null",
		"test_initial_title_lbl_null",
		# _has_world_deps()
		"test_has_world_deps_false_when_world_null",
		# _scenario_number()
		"test_scenario_number_base_returns_zero",
		# _display_name()
		"test_display_name_single_word",
		"test_display_name_two_words",
		"test_display_name_three_words",
		"test_display_name_no_underscores",
		# _phase_for_hour()
		"test_phase_for_hour_night_pre_dawn",
		"test_phase_for_hour_morning",
		"test_phase_for_hour_afternoon",
		"test_phase_for_hour_evening",
		"test_phase_for_hour_night_late",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nBaseScenarioHud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_panel_bg_colour() -> bool:
	var h := _make_hud()
	var ok := h.C_PANEL_BG.is_equal_approx(Color(0.15, 0.10, 0.08, 0.92))
	h.free()
	return ok


static func test_c_heading_colour() -> bool:
	var h := _make_hud()
	var ok := h.C_HEADING.is_equal_approx(Color(0.91, 0.85, 0.70, 1.0))
	h.free()
	return ok


static func test_c_body_colour() -> bool:
	var h := _make_hud()
	var ok := h.C_BODY.is_equal_approx(Color(0.75, 0.70, 0.60, 1.0))
	h.free()
	return ok


static func test_c_win_colour() -> bool:
	var h := _make_hud()
	var ok := h.C_WIN.g > 0.60 and h.C_WIN.r < 0.20   # green dominant
	h.free()
	return ok


static func test_c_fail_colour() -> bool:
	var h := _make_hud()
	var ok := h.C_FAIL.r > 0.70 and h.C_FAIL.g < 0.30   # red dominant
	h.free()
	return ok


static func test_c_neutral_colour() -> bool:
	var h := _make_hud()
	var ok := h.C_NEUTRAL.r > 0.70 and h.C_NEUTRAL.g > 0.40 and h.C_NEUTRAL.b < 0.20   # amber
	h.free()
	return ok


# ── Initial instance state ────────────────────────────────────────────────────

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


static func test_initial_diff_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._diff_lbl == null
	h.free()
	return ok


static func test_initial_title_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._title_lbl == null
	h.free()
	return ok


# ── _has_world_deps() ─────────────────────────────────────────────────────────

## With _world_ref == null the guard must return false immediately.
static func test_has_world_deps_false_when_world_null() -> bool:
	var h := _make_hud()
	var ok := h._has_world_deps() == false
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

## Base class returns 0; subclasses override with 1–6.
static func test_scenario_number_base_returns_zero() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 0
	h.free()
	return ok


# ── _display_name() ───────────────────────────────────────────────────────────

static func test_display_name_single_word() -> bool:
	var h := _make_hud()
	var ok := h._display_name("aldric") == "Aldric"
	h.free()
	return ok


static func test_display_name_two_words() -> bool:
	var h := _make_hud()
	var ok := h._display_name("tomas_reeve") == "Tomas Reeve"
	h.free()
	return ok


static func test_display_name_three_words() -> bool:
	var h := _make_hud()
	var ok := h._display_name("aldous_the_prior") == "Aldous The Prior"
	h.free()
	return ok


static func test_display_name_no_underscores() -> bool:
	var h := _make_hud()
	var ok := h._display_name("marta") == "Marta"
	h.free()
	return ok


# ── _phase_for_hour() ────────────────────────────────────────────────────────

static func test_phase_for_hour_night_pre_dawn() -> bool:
	var h := _make_hud()
	var ok := h._phase_for_hour(3) == "Night"
	h.free()
	return ok


static func test_phase_for_hour_morning() -> bool:
	var h := _make_hud()
	var ok := h._phase_for_hour(8) == "Morning"
	h.free()
	return ok


static func test_phase_for_hour_afternoon() -> bool:
	var h := _make_hud()
	var ok := h._phase_for_hour(14) == "Afternoon"
	h.free()
	return ok


static func test_phase_for_hour_evening() -> bool:
	var h := _make_hud()
	var ok := h._phase_for_hour(17) == "Evening"
	h.free()
	return ok


static func test_phase_for_hour_night_late() -> bool:
	var h := _make_hud()
	var ok := h._phase_for_hour(22) == "Night"
	h.free()
	return ok

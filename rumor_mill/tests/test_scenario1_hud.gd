## test_scenario1_hud.gd — Unit tests for scenario1_hud.gd (SPA-1042).
##
## Covers:
##   • S1-specific palette constants: C_SAFE, C_DANGER, C_CAUTION
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT
##   • _scenario_number(): returns 1
##   • Initial node refs null (no scene tree, _ready() not called)
##   • Inherited initial state: _world_ref, _day_night_ref, _result_lbl, _days_lbl
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario1Hud
extends RefCounted

const Scenario1HudScript := preload("res://scripts/scenario1_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario1HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_safe_is_amber",
		"test_c_danger_is_orange_red",
		"test_c_caution_is_yellow",
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		# _scenario_number()
		"test_scenario_number_is_one",
		# Initial node refs
		"test_initial_score_lbl_null",
		"test_initial_bar_null",
		"test_initial_bar_bg_null",
		"test_initial_caution_lbl_null",
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

	print("\nScenario1Hud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_safe_is_amber() -> bool:
	var h := _make_hud()
	# amber: high r, moderate g, low b
	var ok := h.C_SAFE.r > 0.70 and h.C_SAFE.g > 0.40 and h.C_SAFE.b < 0.20
	h.free()
	return ok


static func test_c_danger_is_orange_red() -> bool:
	var h := _make_hud()
	# orange-red: high r, low-moderate g, very low b
	var ok := h.C_DANGER.r > 0.80 and h.C_DANGER.g < 0.40 and h.C_DANGER.b < 0.20
	h.free()
	return ok


static func test_c_caution_is_yellow() -> bool:
	var h := _make_hud()
	# yellow: high r, high g, low b
	var ok := h.C_CAUTION.r > 0.80 and h.C_CAUTION.g > 0.70 and h.C_CAUTION.b < 0.30
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


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_one() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 1
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._score_lbl == null
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


static func test_initial_caution_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._caution_lbl == null
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

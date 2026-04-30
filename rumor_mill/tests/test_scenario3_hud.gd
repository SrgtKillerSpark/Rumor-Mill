## test_scenario3_hud.gd — Unit tests for scenario3_hud.gd (SPA-1042).
##
## Covers:
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT
##   • _scenario_number(): returns 3
##   • Initial node refs null (no scene tree, _ready() not called)
##   • _bar_color_for_score(): all three return values (WIN / NEUTRAL / FAIL)
##     for both higher_is_better=true and higher_is_better=false modes
##
## _bar_color_for_score logic recap:
##   effective     := score if higher_is_better else (100 - score)
##   win_effective := win_target if higher_is_better else (100 - win_target)
##   effective >= win_effective         → C_WIN
##   effective >= win_effective / 2     → C_NEUTRAL  (integer division)
##   else                               → C_FAIL
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario3Hud
extends RefCounted

const Scenario3HudScript := preload("res://scripts/scenario3_hud.gd")

# Color references from BaseScenarioHud (inherited by scenario3).
const C_WIN     := Color(0.10, 0.75, 0.22, 1.0)
const C_NEUTRAL := Color(0.85, 0.55, 0.10, 1.0)
const C_FAIL    := Color(0.85, 0.15, 0.15, 1.0)


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario3HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		# _scenario_number()
		"test_scenario_number_is_three",
		# Initial node refs
		"test_initial_calder_score_lbl_null",
		"test_initial_tomas_score_lbl_null",
		"test_initial_calder_bar_null",
		"test_initial_tomas_bar_null",
		"test_initial_rival_lbl_null",
		"test_initial_disrupt_btn_null",
		"test_initial_scout_btn_null",
		"test_initial_scout_lbl_null",
		"test_initial_degrade_lbl_null",
		# Inherited state
		"test_initial_world_ref_null",
		"test_initial_result_lbl_null",
		# _bar_color_for_score() — higher_is_better=true
		"test_bar_color_hib_at_target_returns_win",
		"test_bar_color_hib_above_target_returns_win",
		"test_bar_color_hib_halfway_returns_neutral",
		"test_bar_color_hib_below_half_returns_fail",
		# _bar_color_for_score() — higher_is_better=false
		"test_bar_color_lib_at_target_returns_win",
		"test_bar_color_lib_halfway_returns_neutral",
		"test_bar_color_lib_above_target_returns_fail",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenario3Hud tests: %d passed, %d failed" % [passed, failed])


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

static func test_scenario_number_is_three() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 3
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_calder_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._calder_score_lbl == null
	h.free()
	return ok


static func test_initial_tomas_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._tomas_score_lbl == null
	h.free()
	return ok


static func test_initial_calder_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._calder_bar == null
	h.free()
	return ok


static func test_initial_tomas_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._tomas_bar == null
	h.free()
	return ok


static func test_initial_rival_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._rival_lbl == null
	h.free()
	return ok


static func test_initial_disrupt_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._disrupt_btn == null
	h.free()
	return ok


static func test_initial_scout_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._scout_btn == null
	h.free()
	return ok


static func test_initial_scout_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._scout_lbl == null
	h.free()
	return ok


static func test_initial_degrade_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._degrade_lbl == null
	h.free()
	return ok


# ── Inherited state ───────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var h := _make_hud()
	var ok := h._world_ref == null
	h.free()
	return ok


static func test_initial_result_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._result_lbl == null
	h.free()
	return ok


# ── _bar_color_for_score() — higher_is_better=true ───────────────────────────
#
# win_target=75 → win_effective=75, half=37 (integer division)

static func test_bar_color_hib_at_target_returns_win() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(75, true, 75)
	var ok := got.is_equal_approx(C_WIN)
	if not ok:
		push_error("test_bar_color_hib_at_target: got %s, expected C_WIN %s" % [got, C_WIN])
	h.free()
	return ok


static func test_bar_color_hib_above_target_returns_win() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(90, true, 75)
	var ok := got.is_equal_approx(C_WIN)
	h.free()
	return ok


## score=50, target=75: effective=50, win_eff=75, half=37 → 50>=37 → NEUTRAL
static func test_bar_color_hib_halfway_returns_neutral() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(50, true, 75)
	var ok := got.is_equal_approx(C_NEUTRAL)
	if not ok:
		push_error("test_bar_color_hib_halfway: got %s, expected C_NEUTRAL %s" % [got, C_NEUTRAL])
	h.free()
	return ok


## score=30, target=75: effective=30 < 37 → FAIL
static func test_bar_color_hib_below_half_returns_fail() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(30, true, 75)
	var ok := got.is_equal_approx(C_FAIL)
	h.free()
	return ok


# ── _bar_color_for_score() — higher_is_better=false ──────────────────────────
#
# win_target=35 → win_effective=(100-35)=65, half=32 (integer division)

## score=30 → effective=(100-30)=70 >= 65 → WIN
static func test_bar_color_lib_at_target_returns_win() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(30, false, 35)
	var ok := got.is_equal_approx(C_WIN)
	h.free()
	return ok


## score=55 → effective=45, 45 >= 32 (65/2) → NEUTRAL
static func test_bar_color_lib_halfway_returns_neutral() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(55, false, 35)
	var ok := got.is_equal_approx(C_NEUTRAL)
	if not ok:
		push_error("test_bar_color_lib_halfway: got %s, expected C_NEUTRAL %s" % [got, C_NEUTRAL])
	h.free()
	return ok


## score=80 → effective=20, 20 < 32 → FAIL
static func test_bar_color_lib_above_target_returns_fail() -> bool:
	var h := _make_hud()
	var got := h._bar_color_for_score(80, false, 35)
	var ok := got.is_equal_approx(C_FAIL)
	h.free()
	return ok

## test_objective_hud_metrics.gd — Unit tests for objective_hud_metrics.gd (SPA-1026).
##
## Covers:
##   • Initial instance state: all UI refs null, all dependency refs null,
##     _last_avg_rep, _displayed_avg_rep
##   • _threat_word(): boundary values for Low/Moderate/High/Critical
##   • _threat_color(): correct colour band per threshold
##   • refresh(): null _reputation_system guard — returns without crashing
##
## ObjectiveHudMetrics extends Node — safe to instantiate without scene tree.
## _ready() and _process() are NOT called (node not in scene tree).
## Tween-based animations require the scene tree and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestObjectiveHudMetrics
extends RefCounted

const ObjectiveHudMetricsScript := preload("res://scripts/objective_hud_metrics.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ohm() -> Node:
	return ObjectiveHudMetricsScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state
		"test_initial_metrics_row_null",
		"test_initial_lbl_rep_avg_null",
		"test_initial_lbl_believers_null",
		"test_initial_lbl_rumors_active_null",
		"test_initial_lbl_threat_null",
		"test_initial_last_avg_rep_minus_one",
		"test_initial_displayed_avg_rep_minus_one",
		"test_initial_avg_rep_tween_null",
		"test_initial_reputation_system_null",
		"test_initial_intel_store_null",
		"test_initial_scenario_manager_null",
		"test_initial_day_night_null",
		# _threat_word() boundary tests
		"test_threat_word_zero_is_low",
		"test_threat_word_0_24_is_low",
		"test_threat_word_0_25_is_moderate",
		"test_threat_word_0_49_is_moderate",
		"test_threat_word_0_50_is_high",
		"test_threat_word_0_74_is_high",
		"test_threat_word_0_75_is_critical",
		"test_threat_word_1_0_is_critical",
		# _threat_color() band checks
		"test_threat_color_low_is_green",
		"test_threat_color_moderate_is_yellow",
		"test_threat_color_high_is_orange",
		"test_threat_color_critical_is_red",
		# refresh() null guard
		"test_refresh_null_rep_system_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nObjectiveHudMetrics tests: %d passed, %d failed" % [passed, failed])


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_metrics_row_null() -> bool:
	return _make_ohm()._metrics_row == null


static func test_initial_lbl_rep_avg_null() -> bool:
	return _make_ohm()._lbl_rep_avg == null


static func test_initial_lbl_believers_null() -> bool:
	return _make_ohm()._lbl_believers == null


static func test_initial_lbl_rumors_active_null() -> bool:
	return _make_ohm()._lbl_rumors_active == null


static func test_initial_lbl_threat_null() -> bool:
	return _make_ohm()._lbl_threat == null


static func test_initial_last_avg_rep_minus_one() -> bool:
	return _make_ohm()._last_avg_rep == -1


static func test_initial_displayed_avg_rep_minus_one() -> bool:
	return absf(_make_ohm()._displayed_avg_rep - (-1.0)) < 0.001


static func test_initial_avg_rep_tween_null() -> bool:
	return _make_ohm()._avg_rep_tween == null


static func test_initial_reputation_system_null() -> bool:
	return _make_ohm()._reputation_system == null


static func test_initial_intel_store_null() -> bool:
	return _make_ohm()._intel_store == null


static func test_initial_scenario_manager_null() -> bool:
	return _make_ohm()._scenario_manager == null


static func test_initial_day_night_null() -> bool:
	return _make_ohm()._day_night == null


# ── _threat_word() boundary tests ─────────────────────────────────────────────

static func test_threat_word_zero_is_low() -> bool:
	return _make_ohm()._threat_word(0.0) == "Low"


static func test_threat_word_0_24_is_low() -> bool:
	return _make_ohm()._threat_word(0.24) == "Low"


static func test_threat_word_0_25_is_moderate() -> bool:
	return _make_ohm()._threat_word(0.25) == "Moderate"


static func test_threat_word_0_49_is_moderate() -> bool:
	return _make_ohm()._threat_word(0.49) == "Moderate"


static func test_threat_word_0_50_is_high() -> bool:
	return _make_ohm()._threat_word(0.50) == "High"


static func test_threat_word_0_74_is_high() -> bool:
	return _make_ohm()._threat_word(0.74) == "High"


static func test_threat_word_0_75_is_critical() -> bool:
	return _make_ohm()._threat_word(0.75) == "Critical"


static func test_threat_word_1_0_is_critical() -> bool:
	return _make_ohm()._threat_word(1.0) == "Critical"


# ── _threat_color() band checks ───────────────────────────────────────────────

## t < 0.25 → green-ish (high green channel).
static func test_threat_color_low_is_green() -> bool:
	var c: Color = _make_ohm()._threat_color(0.0)
	return c.g > 0.70 and c.r < 0.50


## t in [0.25, 0.50) → yellow (high r + g, low b).
static func test_threat_color_moderate_is_yellow() -> bool:
	var c: Color = _make_ohm()._threat_color(0.30)
	return c.r > 0.70 and c.g > 0.70 and c.b < 0.40


## t in [0.50, 0.75) → orange (high r, moderate g, low b).
static func test_threat_color_high_is_orange() -> bool:
	var c: Color = _make_ohm()._threat_color(0.60)
	return c.r > 0.80 and c.g < 0.70 and c.b < 0.25


## t >= 0.75 → red (high r, low g + b).
static func test_threat_color_critical_is_red() -> bool:
	var c: Color = _make_ohm()._threat_color(0.80)
	return c.r > 0.80 and c.g < 0.35 and c.b < 0.25


# ── refresh() null guard ──────────────────────────────────────────────────────

## refresh() starts with "if _reputation_system == null: return" so a bare
## instance must not crash.
static func test_refresh_null_rep_system_no_crash() -> bool:
	var ohm := _make_ohm()
	ohm.refresh()
	return true

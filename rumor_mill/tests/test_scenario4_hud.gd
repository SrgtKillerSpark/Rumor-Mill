## test_scenario4_hud.gd — Unit tests for scenario4_hud.gd (SPA-1042).
##
## Covers:
##   • S4-specific palette constants: C_DEFEND, C_MERCHANT, C_BISHOP, C_CLERGY
##   • NPC_DISPLAY_NAMES dictionary entries
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT, FACTION_BAR_W, FACTION_BAR_H
##   • _scenario_number(): returns 4
##   • Initial phase booleans: _phase_merchant_fired, _phase_bishop_fired, _phase_clergy_fired
##   • Initial danger-pulse state: _danger_pulse_active
##   • Initial dict state: _score_labels, _bars, _faction_bar_fills
##   • Inherited state: _world_ref, _result_lbl
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario4Hud
extends RefCounted

const Scenario4HudScript := preload("res://scripts/scenario4_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario4HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_defend_is_sky_blue",
		"test_c_merchant_is_green",
		"test_c_bishop_is_red",
		"test_c_clergy_is_violet",
		# NPC display names
		"test_npc_display_names_aldous",
		"test_npc_display_names_vera",
		"test_npc_display_names_finn",
		"test_npc_display_names_count",
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		"test_faction_bar_w",
		"test_faction_bar_h",
		# _scenario_number()
		"test_scenario_number_is_four",
		# Initial phase booleans
		"test_initial_phase_merchant_fired_false",
		"test_initial_phase_bishop_fired_false",
		"test_initial_phase_clergy_fired_false",
		# Initial danger-pulse state
		"test_initial_danger_pulse_active_false",
		# Initial dict state
		"test_initial_score_labels_empty",
		"test_initial_bars_empty",
		"test_initial_faction_bar_fills_empty",
		# Inherited state
		"test_initial_world_ref_null",
		"test_initial_result_lbl_null",
		# Initial tween refs
		"test_initial_inquisitor_lbl_null",
		"test_initial_faction_shift_lbl_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenario4Hud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_defend_is_sky_blue() -> bool:
	var h := _make_hud()
	# sky blue: moderate r, high g, max b
	var ok := h.C_DEFEND.b > 0.90 and h.C_DEFEND.g > 0.70 and h.C_DEFEND.r < 0.65
	h.free()
	return ok


static func test_c_merchant_is_green() -> bool:
	var h := _make_hud()
	var ok := h.C_MERCHANT.g > 0.65 and h.C_MERCHANT.r < 0.50
	h.free()
	return ok


static func test_c_bishop_is_red() -> bool:
	var h := _make_hud()
	var ok := h.C_BISHOP.r > 0.75 and h.C_BISHOP.g < 0.45 and h.C_BISHOP.b < 0.30
	h.free()
	return ok


static func test_c_clergy_is_violet() -> bool:
	var h := _make_hud()
	# violet: moderate r, moderate g, high b
	var ok := h.C_CLERGY.b > 0.75 and h.C_CLERGY.r > 0.50
	h.free()
	return ok


# ── NPC_DISPLAY_NAMES ─────────────────────────────────────────────────────────

static func test_npc_display_names_aldous() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.get("aldous_prior", "") == "Aldous Prior"
	h.free()
	return ok


static func test_npc_display_names_vera() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.get("vera_midwife", "") == "Vera Midwife"
	h.free()
	return ok


static func test_npc_display_names_finn() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.get("finn_monk", "") == "Finn Monk"
	h.free()
	return ok


static func test_npc_display_names_count() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.size() == 3
	h.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_bar_width() -> bool:
	var h := _make_hud()
	var ok := h.BAR_WIDTH == 120
	h.free()
	return ok


static func test_bar_height() -> bool:
	var h := _make_hud()
	var ok := h.BAR_HEIGHT == 10
	h.free()
	return ok


static func test_faction_bar_w() -> bool:
	var h := _make_hud()
	var ok := h.FACTION_BAR_W == 60
	h.free()
	return ok


static func test_faction_bar_h() -> bool:
	var h := _make_hud()
	var ok := h.FACTION_BAR_H == 7
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_four() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 4
	h.free()
	return ok


# ── Initial phase booleans ────────────────────────────────────────────────────

static func test_initial_phase_merchant_fired_false() -> bool:
	var h := _make_hud()
	var ok := h._phase_merchant_fired == false
	h.free()
	return ok


static func test_initial_phase_bishop_fired_false() -> bool:
	var h := _make_hud()
	var ok := h._phase_bishop_fired == false
	h.free()
	return ok


static func test_initial_phase_clergy_fired_false() -> bool:
	var h := _make_hud()
	var ok := h._phase_clergy_fired == false
	h.free()
	return ok


# ── Initial danger-pulse state ────────────────────────────────────────────────

static func test_initial_danger_pulse_active_false() -> bool:
	var h := _make_hud()
	var ok := h._danger_pulse_active == false
	h.free()
	return ok


# ── Initial dict state ────────────────────────────────────────────────────────

static func test_initial_score_labels_empty() -> bool:
	var h := _make_hud()
	var ok := h._score_labels.is_empty()
	h.free()
	return ok


static func test_initial_bars_empty() -> bool:
	var h := _make_hud()
	var ok := h._bars.is_empty()
	h.free()
	return ok


static func test_initial_faction_bar_fills_empty() -> bool:
	var h := _make_hud()
	var ok := h._faction_bar_fills.is_empty()
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


# ── Initial UI refs (built in _build_ui, null without scene tree) ─────────────

static func test_initial_inquisitor_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._inquisitor_lbl == null
	h.free()
	return ok


static func test_initial_faction_shift_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._faction_shift_lbl == null
	h.free()
	return ok

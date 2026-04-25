## test_scenario5_hud.gd — Unit tests for scenario5_hud.gd (SPA-1042).
##
## Covers:
##   • NPC_DISPLAY_NAMES dictionary entries (Aldric, Edric, Tomas)
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT
##   • CAMPAIGN_REP_BOOST, CAMPAIGN_COOLDOWN (sourced from ScenarioConfig)
##   • _scenario_number(): returns 5
##   • Initial momentum trackers: _prev_aldric_score, _prev_edric_score, _prev_tomas_score
##   • Initial node refs null (no scene tree, _ready() not called)
##   • _momentum_arrow(): all four branches (no-data, rising, falling, flat)
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario5Hud
extends RefCounted

const Scenario5HudScript := preload("res://scripts/scenario5_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario5HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# NPC display names
		"test_npc_display_names_aldric",
		"test_npc_display_names_edric",
		"test_npc_display_names_tomas",
		"test_npc_display_names_count",
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		# Campaign constants
		"test_campaign_rep_boost_positive",
		"test_campaign_cooldown_positive",
		# _scenario_number()
		"test_scenario_number_is_five",
		# Initial momentum trackers
		"test_initial_prev_aldric_score",
		"test_initial_prev_edric_score",
		"test_initial_prev_tomas_score",
		# Initial node refs
		"test_initial_aldric_score_lbl_null",
		"test_initial_edric_score_lbl_null",
		"test_initial_tomas_score_lbl_null",
		"test_initial_endorse_lbl_null",
		"test_initial_campaign_btn_null",
		"test_initial_campaign_lbl_null",
		# Inherited state
		"test_initial_world_ref_null",
		"test_initial_result_lbl_null",
		# _momentum_arrow()
		"test_momentum_arrow_no_data",
		"test_momentum_arrow_rising",
		"test_momentum_arrow_falling",
		"test_momentum_arrow_flat",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenario5Hud tests: %d passed, %d failed" % [passed, failed])


# ── NPC_DISPLAY_NAMES ─────────────────────────────────────────────────────────

static func test_npc_display_names_aldric() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.get("aldric_vane", "") == "Aldric Vane"
	h.free()
	return ok


static func test_npc_display_names_edric() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.get("edric_fenn", "") == "Edric Fenn"
	h.free()
	return ok


static func test_npc_display_names_tomas() -> bool:
	var h := _make_hud()
	var ok := h.NPC_DISPLAY_NAMES.get("tomas_reeve", "") == "Tomas Reeve"
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


# ── Campaign constants ────────────────────────────────────────────────────────

static func test_campaign_rep_boost_positive() -> bool:
	var h := _make_hud()
	var ok := h.CAMPAIGN_REP_BOOST > 0
	h.free()
	return ok


static func test_campaign_cooldown_positive() -> bool:
	var h := _make_hud()
	var ok := h.CAMPAIGN_COOLDOWN > 0
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_five() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 5
	h.free()
	return ok


# ── Initial momentum trackers ─────────────────────────────────────────────────

static func test_initial_prev_aldric_score() -> bool:
	var h := _make_hud()
	var ok := h._prev_aldric_score == -1
	h.free()
	return ok


static func test_initial_prev_edric_score() -> bool:
	var h := _make_hud()
	var ok := h._prev_edric_score == -1
	h.free()
	return ok


static func test_initial_prev_tomas_score() -> bool:
	var h := _make_hud()
	var ok := h._prev_tomas_score == -1
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_aldric_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._aldric_score_lbl == null
	h.free()
	return ok


static func test_initial_edric_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._edric_score_lbl == null
	h.free()
	return ok


static func test_initial_tomas_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._tomas_score_lbl == null
	h.free()
	return ok


static func test_initial_endorse_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._endorse_lbl == null
	h.free()
	return ok


static func test_initial_campaign_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._campaign_btn == null
	h.free()
	return ok


static func test_initial_campaign_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._campaign_lbl == null
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


# ── _momentum_arrow() ─────────────────────────────────────────────────────────
#
# if prev < 0      → ""
# current > prev   → " ↑"
# current < prev   → " ↓"
# current == prev  → " →"

## prev=-1 (sentinel) → no data yet → empty string
static func test_momentum_arrow_no_data() -> bool:
	var h := _make_hud()
	var ok := h._momentum_arrow(50, -1) == ""
	h.free()
	return ok


## current > prev → rising
static func test_momentum_arrow_rising() -> bool:
	var h := _make_hud()
	var ok := h._momentum_arrow(60, 50) == " ↑"
	h.free()
	return ok


## current < prev → falling
static func test_momentum_arrow_falling() -> bool:
	var h := _make_hud()
	var ok := h._momentum_arrow(40, 50) == " ↓"
	h.free()
	return ok


## current == prev → flat
static func test_momentum_arrow_flat() -> bool:
	var h := _make_hud()
	var ok := h._momentum_arrow(50, 50) == " →"
	h.free()
	return ok

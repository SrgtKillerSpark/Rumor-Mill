## test_scenario6_hud.gd — Unit tests for scenario6_hud.gd (SPA-1042).
##
## Covers:
##   • Heat-bar palette constants: C_HEAT_YELLOW, C_HEAT_ORANGE
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT
##   • Blackmail constants (sourced from ScenarioConfig): all non-zero
##   • _scenario_number(): returns 6
##   • Guild-defense initial state: _guild_last_defense_day=-1, _guild_defenses_this_run=0
##   • Initial node refs null (no scene tree, _ready() not called)
##   • Inherited state: _world_ref, _result_lbl
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario6Hud
extends RefCounted

const Scenario6HudScript := preload("res://scripts/scenario6_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario6HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Heat-bar palette
		"test_c_heat_yellow_is_yellow",
		"test_c_heat_orange_is_orange",
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		# Blackmail constants
		"test_blackmail_whisper_cost_positive",
		"test_blackmail_rep_hit_nonzero",
		"test_blackmail_heat_add_positive",
		"test_blackmail_max_uses_positive",
		"test_blackmail_heat_npcs_nonempty",
		# _scenario_number()
		"test_scenario_number_is_six",
		# Guild defense initial state
		"test_initial_guild_last_defense_day",
		"test_initial_guild_defenses_this_run",
		# Initial node refs
		"test_initial_aldric_score_lbl_null",
		"test_initial_marta_score_lbl_null",
		"test_initial_heat_lbl_null",
		"test_initial_aldric_bar_null",
		"test_initial_aldric_bar_bg_null",
		"test_initial_marta_bar_null",
		"test_initial_marta_bar_bg_null",
		"test_initial_heat_bar_null",
		"test_initial_heat_bar_bg_null",
		"test_initial_guild_defense_lbl_null",
		"test_initial_guild_threat_bar_null",
		"test_initial_guild_threat_bg_null",
		"test_initial_guild_defense_agent_ref_null",
		"test_initial_event_lbl_null",
		"test_initial_blackmail_btn_null",
		"test_initial_blackmail_lbl_null",
		# Inherited state
		"test_initial_world_ref_null",
		"test_initial_result_lbl_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenario6Hud tests: %d passed, %d failed" % [passed, failed])


# ── Heat-bar palette constants ────────────────────────────────────────────────

static func test_c_heat_yellow_is_yellow() -> bool:
	var h := _make_hud()
	# yellow: high r, high g, low b
	var ok := h.C_HEAT_YELLOW.r > 0.90 and h.C_HEAT_YELLOW.g > 0.80 and h.C_HEAT_YELLOW.b < 0.20
	h.free()
	return ok


static func test_c_heat_orange_is_orange() -> bool:
	var h := _make_hud()
	# orange: high r, moderate g, near-zero b
	var ok := h.C_HEAT_ORANGE.r > 0.85 and h.C_HEAT_ORANGE.g > 0.40 and h.C_HEAT_ORANGE.b < 0.15
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
	var ok := h.BAR_HEIGHT == 10
	h.free()
	return ok


# ── Blackmail constants ───────────────────────────────────────────────────────

static func test_blackmail_whisper_cost_positive() -> bool:
	var h := _make_hud()
	var ok := h.BLACKMAIL_WHISPER_COST > 0
	h.free()
	return ok


## REP_HIT is a signed delta — just verify it is non-zero
static func test_blackmail_rep_hit_nonzero() -> bool:
	var h := _make_hud()
	var ok := h.BLACKMAIL_REP_HIT != 0
	h.free()
	return ok


static func test_blackmail_heat_add_positive() -> bool:
	var h := _make_hud()
	var ok := h.BLACKMAIL_HEAT_ADD > 0
	h.free()
	return ok


static func test_blackmail_max_uses_positive() -> bool:
	var h := _make_hud()
	var ok := h.BLACKMAIL_MAX_USES > 0
	h.free()
	return ok


static func test_blackmail_heat_npcs_nonempty() -> bool:
	var h := _make_hud()
	var ok := h.BLACKMAIL_HEAT_NPCS.size() > 0
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_six() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 6
	h.free()
	return ok


# ── Guild defense initial state ───────────────────────────────────────────────

static func test_initial_guild_last_defense_day() -> bool:
	var h := _make_hud()
	var ok := h._guild_last_defense_day == -1
	h.free()
	return ok


static func test_initial_guild_defenses_this_run() -> bool:
	var h := _make_hud()
	var ok := h._guild_defenses_this_run == 0
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_aldric_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._aldric_score_lbl == null
	h.free()
	return ok


static func test_initial_marta_score_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._marta_score_lbl == null
	h.free()
	return ok


static func test_initial_heat_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._heat_lbl == null
	h.free()
	return ok


static func test_initial_aldric_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._aldric_bar == null
	h.free()
	return ok


static func test_initial_aldric_bar_bg_null() -> bool:
	var h := _make_hud()
	var ok := h._aldric_bar_bg == null
	h.free()
	return ok


static func test_initial_marta_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._marta_bar == null
	h.free()
	return ok


static func test_initial_marta_bar_bg_null() -> bool:
	var h := _make_hud()
	var ok := h._marta_bar_bg == null
	h.free()
	return ok


static func test_initial_heat_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._heat_bar == null
	h.free()
	return ok


static func test_initial_heat_bar_bg_null() -> bool:
	var h := _make_hud()
	var ok := h._heat_bar_bg == null
	h.free()
	return ok


static func test_initial_guild_defense_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._guild_defense_lbl == null
	h.free()
	return ok


static func test_initial_guild_threat_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._guild_threat_bar == null
	h.free()
	return ok


static func test_initial_guild_threat_bg_null() -> bool:
	var h := _make_hud()
	var ok := h._guild_threat_bg == null
	h.free()
	return ok


static func test_initial_guild_defense_agent_ref_null() -> bool:
	var h := _make_hud()
	var ok := h._guild_defense_agent_ref == null
	h.free()
	return ok


static func test_initial_event_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._event_lbl == null
	h.free()
	return ok


static func test_initial_blackmail_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._blackmail_btn == null
	h.free()
	return ok


static func test_initial_blackmail_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._blackmail_lbl == null
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

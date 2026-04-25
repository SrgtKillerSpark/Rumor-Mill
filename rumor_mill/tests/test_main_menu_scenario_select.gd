## test_main_menu_scenario_select.gd — Unit tests for main_menu_scenario_select.gd (SPA-1042).
##
## Covers:
##   • SCENARIO_ACCENT: 6 entries, each a valid Color
##   • SCENARIO_DIFFICULTY: 6 entries, string values for each scenario
##   • SCENARIO_DESCRIPTOR: 6 entries, non-empty strings
##   • Initial state: panel null, selected_scenario empty, selected_idx=-1
##   • Initial internal arrays empty
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMainMenuScenarioSelect
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ss() -> MainMenuScenarioSelect:
	return MainMenuScenarioSelect.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# SCENARIO_ACCENT
		"test_scenario_accent_count",
		"test_scenario_accent_s1_is_green",
		"test_scenario_accent_s4_is_red",
		# SCENARIO_DIFFICULTY
		"test_scenario_difficulty_count",
		"test_scenario_difficulty_s1_introductory",
		"test_scenario_difficulty_s2_moderate",
		"test_scenario_difficulty_s3_challenging",
		"test_scenario_difficulty_s4_expert",
		"test_scenario_difficulty_s5_advanced",
		"test_scenario_difficulty_s6_master",
		# SCENARIO_DESCRIPTOR
		"test_scenario_descriptor_count",
		"test_scenario_descriptor_all_nonempty",
		# Initial state
		"test_initial_panel_null",
		"test_initial_selected_scenario_empty",
		"test_initial_selected_idx_minus_one",
		"test_initial_scenario_cards_empty",
		"test_initial_scenarios_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMainMenuScenarioSelect tests: %d passed, %d failed" % [passed, failed])


# ── SCENARIO_ACCENT ───────────────────────────────────────────────────────────

static func test_scenario_accent_count() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_ACCENT.size() == 6
	ss.free()
	return ok


static func test_scenario_accent_s1_is_green() -> bool:
	var ss := _make_ss()
	var c: Color = ss.SCENARIO_ACCENT.get("scenario_1", Color.BLACK)
	var ok := c.g > 0.60 and c.r < 0.55
	ss.free()
	return ok


static func test_scenario_accent_s4_is_red() -> bool:
	var ss := _make_ss()
	var c: Color = ss.SCENARIO_ACCENT.get("scenario_4", Color.BLACK)
	var ok := c.r > 0.75 and c.g < 0.30
	ss.free()
	return ok


# ── SCENARIO_DIFFICULTY ───────────────────────────────────────────────────────

static func test_scenario_difficulty_count() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.size() == 6
	ss.free()
	return ok


static func test_scenario_difficulty_s1_introductory() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.get("scenario_1", "") == "Introductory"
	ss.free()
	return ok


static func test_scenario_difficulty_s2_moderate() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.get("scenario_2", "") == "Moderate"
	ss.free()
	return ok


static func test_scenario_difficulty_s3_challenging() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.get("scenario_3", "") == "Challenging"
	ss.free()
	return ok


static func test_scenario_difficulty_s4_expert() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.get("scenario_4", "") == "Expert"
	ss.free()
	return ok


static func test_scenario_difficulty_s5_advanced() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.get("scenario_5", "") == "Advanced"
	ss.free()
	return ok


static func test_scenario_difficulty_s6_master() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DIFFICULTY.get("scenario_6", "") == "Master"
	ss.free()
	return ok


# ── SCENARIO_DESCRIPTOR ───────────────────────────────────────────────────────

static func test_scenario_descriptor_count() -> bool:
	var ss := _make_ss()
	var ok := ss.SCENARIO_DESCRIPTOR.size() == 6
	ss.free()
	return ok


static func test_scenario_descriptor_all_nonempty() -> bool:
	var ss := _make_ss()
	var ok := true
	for key in ["scenario_1", "scenario_2", "scenario_3", "scenario_4", "scenario_5", "scenario_6"]:
		if ss.SCENARIO_DESCRIPTOR.get(key, "").is_empty():
			ok = false
			break
	ss.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var ss := _make_ss()
	var ok := ss.panel == null
	ss.free()
	return ok


static func test_initial_selected_scenario_empty() -> bool:
	var ss := _make_ss()
	var ok := ss.selected_scenario.is_empty()
	ss.free()
	return ok


static func test_initial_selected_idx_minus_one() -> bool:
	var ss := _make_ss()
	var ok := ss.selected_idx == -1
	ss.free()
	return ok


static func test_initial_scenario_cards_empty() -> bool:
	var ss := _make_ss()
	var ok := ss._scenario_cards.is_empty()
	ss.free()
	return ok


static func test_initial_scenarios_empty() -> bool:
	var ss := _make_ss()
	var ok := ss._scenarios.is_empty()
	ss.free()
	return ok

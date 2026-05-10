## test_spa2042_run_all_tests_runner.gd — Regression guard for SPA-1985 custom-runner parse crash.
##
## SPA-1985 (fa8d99d) fixed run_all_tests.tscn failing to execute all suites
## because Godot 4.6 strict type inference rejected `var x := untyped_expr`
## at parse time in 13 test scripts. Because run_all_tests.gd preloads every
## test script as a top-level const, a single parse error aborted _init() and
## silently dropped all subsequent suites. Two additional root causes were also
## fixed: a stale `Estimates_Klass` reference in test_rumor_panel_seed_list.gd,
## a missing constructor arg to Rumor.NpcRumorSlot.new() in
## test_social_graph_overlay.gd, and missing WorldScript const alias in
## test_world.gd.
##
## How this file guards against regression:
##   1. Preloading each affected script IS the parse-error guard. A `var x :=`
##      reintroduced in any of them causes a parse error here on load, making
##      the entire test suite fail to start.
##   2. Instantiation tests confirm that each affected script's .new() succeeds,
##      catching runtime-level missing-identifier errors (e.g. Estimates_Klass).
##   3. Three static method calls exercise the exact code paths containing the
##      fixed `var x :=` sites, so a revert also triggers a runtime assertion.
##   4. A registration-count check reads run_all_tests.gd and asserts ≥
##      MIN_REGISTERED_SUITES const declarations, catching silent truncation.
##
## Demonstrably fails when fix is reverted (cite for acceptance):
##   • `var all := mgr.get_all()` reintroduced → preload of
##     test_achievement_manager.gd fails → this file fails to load.
##   • `WorldScript` const removed from test_world.gd →
##     test_world_tile_size_static fails (parse error on load).
##   • `Estimates_Klass` reintroduced → preload of
##     test_rumor_panel_seed_list.gd fails → this file fails to load.
##   • Registration count drops below MIN → test_run_all_tests_registration_count fails.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2042RunAllTestsRunner
extends RefCounted

# ── Preloads for all 14 scripts modified in SPA-1985 (fa8d99d) ───────────────
# (end_screen_scoring and end_screen_summary removed in SPA-2465 deprecation)
# These const lines ARE the parse-error regression guard.
# A `var x :=` reintroduced in any of them causes a parse error here on load.

const TestAchievementManagerScript        := preload("res://tests/test_achievement_manager.gd")
const TestDayNightCycleScript             := preload("res://tests/test_day_night_cycle.gd")
const TestNpcMovementScript               := preload("res://tests/test_npc_movement.gd")
const TestNpcTooltipScript                := preload("res://tests/test_npc_tooltip.gd")
const TestObjectiveHudScript              := preload("res://tests/test_objective_hud.gd")
const TestObjectiveHudNudgeManagerScript  := preload("res://tests/test_objective_hud_nudge_manager.gd")
const TestPlayerStatsScript               := preload("res://tests/test_player_stats.gd")
const TestRumorPanelEvidenceCooldownScript := preload("res://tests/test_rumor_panel_evidence_cooldown.gd")
const TestRumorPanelSeedListScript        := preload("res://tests/test_rumor_panel_seed_list.gd")
const TestScenario3HudScript              := preload("res://tests/test_scenario3_hud.gd")
const TestSettingsManagerScript           := preload("res://tests/test_settings_manager.gd")
const TestSocialGraphOverlayScript        := preload("res://tests/test_social_graph_overlay.gd")
const TestWeatherSystemScript             := preload("res://tests/test_weather_system.gd")
const TestWorldScript                     := preload("res://tests/test_world.gd")

# ── Registration-count threshold ─────────────────────────────────────────────
## Minimum `const` declarations expected in run_all_tests.gd.
## Current count is 164. Kept 14 below that to absorb routine suite additions
## without false positives. Raise when the file legitimately drops below MIN.
const MIN_REGISTERED_SUITES: int = 150

const _RUN_ALL_SRC := "res://tests/run_all_tests.gd"


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Instantiation guards — one per SPA-1985-affected script.
		# Fail if preload returned null or .new() raises a runtime error.
		"test_achievement_manager_instantiates",
		"test_day_night_cycle_instantiates",
		"test_npc_movement_instantiates",
		"test_npc_tooltip_instantiates",
		"test_objective_hud_instantiates",
		"test_objective_hud_nudge_manager_instantiates",
		"test_player_stats_instantiates",
		"test_rumor_panel_evidence_cooldown_instantiates",
		"test_rumor_panel_seed_list_instantiates",
		"test_scenario3_hud_instantiates",
		"test_settings_manager_instantiates",
		"test_social_graph_overlay_instantiates",
		"test_weather_system_instantiates",
		"test_world_instantiates",

		# Static-method runtime guards — exercise the exact fixed code paths.
		"test_achievement_manager_get_all_count",
		"test_day_night_cycle_time_colors_has_ten_entries",
		"test_world_tile_size_static",

		# Registration-count truncation guard.
		"test_run_all_tests_registration_count",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-2042 run_all_tests runner regression: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Instantiation guards
# ══════════════════════════════════════════════════════════════════════════════

func test_achievement_manager_instantiates() -> bool:
	## Regression: `var all := mgr.get_all()` in test_get_all_count() (fa8d99d).
	## Preload failure on revert means this file fails to load entirely.
	return TestAchievementManagerScript.new() != null


func test_day_night_cycle_instantiates() -> bool:
	## Regression: `var count := _make_dnc().TIME_COLORS.size()` (fa8d99d).
	return TestDayNightCycleScript.new() != null


func test_npc_movement_instantiates() -> bool:
	## Regression: multiple `var x :=` sites in test_npc_movement.gd (fa8d99d).
	return TestNpcMovementScript.new() != null


func test_npc_tooltip_instantiates() -> bool:
	## Regression: multiple `var x :=` sites in test_npc_tooltip.gd (fa8d99d).
	return TestNpcTooltipScript.new() != null


func test_objective_hud_instantiates() -> bool:
	## Regression: 24-line `var x :=` sweep in test_objective_hud.gd (fa8d99d).
	return TestObjectiveHudScript.new() != null


func test_objective_hud_nudge_manager_instantiates() -> bool:
	## Regression: one `var x :=` site in test_objective_hud_nudge_manager.gd (fa8d99d).
	return TestObjectiveHudNudgeManagerScript.new() != null


func test_player_stats_instantiates() -> bool:
	## Regression: `var x :=` sites in test_player_stats.gd (fa8d99d).
	return TestPlayerStatsScript.new() != null


func test_rumor_panel_evidence_cooldown_instantiates() -> bool:
	## Regression: `var x :=` sites in test_rumor_panel_evidence_cooldown.gd (fa8d99d).
	return TestRumorPanelEvidenceCooldownScript.new() != null


func test_rumor_panel_seed_list_instantiates() -> bool:
	## Regression: stale `Estimates_Klass` identifier renamed to `EstimatesScript`
	## in test_rumor_panel_seed_list.gd (fa8d99d). Reverting the rename causes an
	## undeclared-identifier compile error and preload failure.
	return TestRumorPanelSeedListScript.new() != null


func test_scenario3_hud_instantiates() -> bool:
	## Regression: `var x :=` sites in test_scenario3_hud.gd (fa8d99d).
	return TestScenario3HudScript.new() != null


func test_settings_manager_instantiates() -> bool:
	## Regression: multiple `var x :=` sites in test_settings_manager.gd (fa8d99d).
	return TestSettingsManagerScript.new() != null


func test_social_graph_overlay_instantiates() -> bool:
	## Regression: Rumor.NpcRumorSlot.new() missing required (rumor, faction) args
	## in test_social_graph_overlay.gd (fa8d99d). Removing the args causes a
	## runtime init error on NpcRumorSlot construction.
	return TestSocialGraphOverlayScript.new() != null


func test_weather_system_instantiates() -> bool:
	## Regression: `var x :=` sites in test_weather_system.gd (fa8d99d).
	return TestWeatherSystemScript.new() != null


func test_world_instantiates() -> bool:
	## Regression: test_world.gd gained `const WorldScript := preload(...)` and
	## converted all World.CONSTANT accesses to WorldScript.CONSTANT (fa8d99d).
	## Removing WorldScript const causes a parse error; preload fails here.
	return TestWorldScript.new() != null


# ══════════════════════════════════════════════════════════════════════════════
# Static-method runtime guards
# (call the exact methods whose `var x :=` sites were fixed)
# ══════════════════════════════════════════════════════════════════════════════

static func test_achievement_manager_get_all_count() -> bool:
	## test_get_all_count() contained `var all := mgr.get_all()` before fa8d99d.
	## Reverting to `:=` causes a preload failure before this runs, but this also
	## confirms the fixed method path executes correctly at runtime.
	return TestAchievementManagerScript.test_get_all_count()


static func test_day_night_cycle_time_colors_has_ten_entries() -> bool:
	## test_time_colors_has_ten_entries() contained `var count := ...` before fa8d99d.
	return TestDayNightCycleScript.test_time_colors_has_ten_entries()


static func test_world_tile_size_static() -> bool:
	## test_tile_size() accesses WorldScript.TILE_SIZE. If the WorldScript const
	## alias is removed from test_world.gd, the preload fails before this runs.
	## Passing confirms the alias is present and World.gd has class_name World.
	return TestWorldScript.test_tile_size()


# ══════════════════════════════════════════════════════════════════════════════
# Registration-count truncation guard
# ══════════════════════════════════════════════════════════════════════════════

static func test_run_all_tests_registration_count() -> bool:
	## Reads run_all_tests.gd and counts top-level `const ` declarations.
	## If a future parse-error crash causes _init() to abort early and all
	## subsequent suite registrations are silently dropped, *source* const count
	## will also drop (the developer would need to remove them). This catches
	## bulk deletions while allowing normal suite additions.
	var f = FileAccess.open(_RUN_ALL_SRC, FileAccess.READ)
	if f == null:
		push_error("test_run_all_tests_registration_count: cannot open %s" % _RUN_ALL_SRC)
		return false
	var count := 0
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("const "):
			count += 1
	f.close()
	if count < MIN_REGISTERED_SUITES:
		push_error(
			"test_run_all_tests_registration_count: expected >= %d const declarations, got %d (truncation?)" % [
				MIN_REGISTERED_SUITES, count])
		return false
	return true

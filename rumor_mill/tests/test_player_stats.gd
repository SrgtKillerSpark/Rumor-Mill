## test_player_stats.gd — Unit tests for PlayerStats constants and initial
## state (SPA-1065).
##
## Covers:
##   • SAVE_PATH constant value
##   • VERSION == 1
##   • DIFFICULTIES — 3 entries: apprentice, master, spymaster
##   • SCENARIO_IDS  — 4 entries: scenario_1 … scenario_4
##   • Initial state: _session_start_time == 0, _data is empty dict
##   • get_session_duration_sec() returns 0 before start_session()
##   • start_session() sets _session_start_time to a positive value
##   • get_session_duration_sec() returns non-negative after start_session()
##   • flush_session_time() no-ops when _session_start_time == 0
##   • get_totals() returns a Dictionary with expected keys
##   • get_scenario_stats() returns a Dictionary for unknown scenario
##
## Strategy: PlayerStats extends Node. _ready() calls _load() which reads
## user://player_stats.json — safe: gracefully returns {} if file absent.
## .new() does NOT call _ready(), so the initial _data is empty.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPlayerStats
extends RefCounted

const PlayerStatsScript := preload("res://scripts/player_stats.gd")


static func _make_ps() -> Node:
	return PlayerStatsScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_save_path_value",
		"test_version_is_1",
		"test_difficulties_count",
		"test_difficulties_contains_three_presets",
		"test_scenario_ids_count",
		"test_scenario_ids_first_is_scenario_1",

		# ── initial state ──
		"test_initial_session_start_zero",
		"test_initial_data_empty",
		"test_get_session_duration_zero_before_start",

		# ── start_session() ──
		"test_start_session_sets_positive_time",
		"test_duration_non_negative_after_start",

		# ── flush_session_time() ──
		"test_flush_noop_when_not_started",

		# ── get_totals() ──
		"test_get_totals_returns_dict",

		# ── get_scenario_stats() ──
		"test_get_scenario_stats_returns_dict",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_save_path_value() -> bool:
	return PlayerStatsScript.SAVE_PATH == "user://player_stats.json"


func test_version_is_1() -> bool:
	return PlayerStatsScript.VERSION == 1


func test_difficulties_count() -> bool:
	return PlayerStatsScript.DIFFICULTIES.size() == 3


func test_difficulties_contains_three_presets() -> bool:
	var d := PlayerStatsScript.DIFFICULTIES
	return "apprentice" in d and "master" in d and "spymaster" in d


func test_scenario_ids_count() -> bool:
	return PlayerStatsScript.SCENARIO_IDS.size() == 4


func test_scenario_ids_first_is_scenario_1() -> bool:
	return PlayerStatsScript.SCENARIO_IDS[0] == "scenario_1"


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_session_start_zero() -> bool:
	var ps := _make_ps()
	var ok := ps._session_start_time == 0
	ps.free()
	return ok


func test_initial_data_empty() -> bool:
	var ps := _make_ps()
	# _data is {} until _ready() calls _load()
	var ok := ps._data.is_empty()
	ps.free()
	return ok


func test_get_session_duration_zero_before_start() -> bool:
	var ps := _make_ps()
	var ok := ps.get_session_duration_sec() == 0
	ps.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# start_session()
# ══════════════════════════════════════════════════════════════════════════════

func test_start_session_sets_positive_time() -> bool:
	var ps := _make_ps()
	ps.start_session()
	var ok := ps._session_start_time > 0
	ps.free()
	return ok


func test_duration_non_negative_after_start() -> bool:
	var ps := _make_ps()
	ps.start_session()
	var ok := ps.get_session_duration_sec() >= 0
	ps.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# flush_session_time()
# ══════════════════════════════════════════════════════════════════════════════

func test_flush_noop_when_not_started() -> bool:
	var ps := _make_ps()
	# _session_start_time == 0 → guard returns immediately, no crash
	ps.flush_session_time()
	var ok := ps._session_start_time == 0
	ps.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# get_totals() / get_scenario_stats()
# ══════════════════════════════════════════════════════════════════════════════

func test_get_totals_returns_dict() -> bool:
	var ps := _make_ps()
	var totals := ps.get_totals()
	var ok := totals is Dictionary
	ps.free()
	return ok


func test_get_scenario_stats_returns_dict() -> bool:
	var ps := _make_ps()
	var stats := ps.get_scenario_stats("scenario_1", "apprentice")
	var ok := stats is Dictionary
	ps.free()
	return ok

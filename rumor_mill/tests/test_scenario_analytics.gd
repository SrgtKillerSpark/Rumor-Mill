## test_scenario_analytics.gd — Unit tests for ScenarioAnalytics (SPA-1041).
##
## Covers:
##   • Initial state: timeline empty, key_moments empty, _started false, peak 0
##   • _on_rumor_transmitted(): increments spread_count / received_count correctly
##   • _on_rumor_event(): first-seed key moment, DEFENDING state change, CONTRADICTED
##   • _on_socially_dead(): adds social_death key moment with correct fields
##   • get_timeline_data(): returns timeline reference
##   • get_key_moments(): returns key_moments reference
##   • get_influence_ranking(): sorted by spread_count, top-N slicing
##   • finalize(): adds peak key moment when _peak_live_count > 0; sorts by day
##
## Strategy: ScenarioAnalytics extends RefCounted — no Node, no scene tree.
## Signal handlers are called directly as regular methods.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenarioAnalytics
extends RefCounted

const ScenarioAnalyticsScript := preload("res://scripts/scenario_analytics.gd")


static func _make_analytics() -> ScenarioAnalytics:
	return ScenarioAnalyticsScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── initial state ──
		"test_initial_timeline_is_empty",
		"test_initial_key_moments_is_empty",
		"test_initial_started_is_false",
		"test_initial_peak_live_count_is_zero",
		"test_initial_first_seed_not_recorded",

		# ── _on_rumor_transmitted ──
		"test_transmitted_increments_spread_count",
		"test_transmitted_increments_received_count",
		"test_transmitted_multiple_spreads_accumulate",
		"test_transmitted_new_npc_initialises_to_zero",

		# ── _on_rumor_event ──
		"test_rumor_event_first_seed_adds_key_moment",
		"test_rumor_event_second_seed_does_not_add_again",
		"test_rumor_event_defending_adds_state_change",
		"test_rumor_event_contradicted_adds_contradiction",
		"test_rumor_event_reject_adds_contradiction",

		# ── _on_socially_dead ──
		"test_socially_dead_adds_key_moment",
		"test_socially_dead_key_moment_type_is_social_death",
		"test_socially_dead_key_moment_has_npc_name_in_text",

		# ── public getters ──
		"test_get_timeline_data_returns_timeline",
		"test_get_key_moments_returns_key_moments",

		# ── get_influence_ranking ──
		"test_influence_ranking_sorted_by_spread_count",
		"test_influence_ranking_top_n_sliced",
		"test_influence_ranking_empty_when_no_transmissions",

		# ── finalize ──
		"test_finalize_adds_peak_when_peak_nonzero",
		"test_finalize_no_peak_when_peak_zero",
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
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_timeline_is_empty() -> bool:
	return _make_analytics().timeline.is_empty()


func test_initial_key_moments_is_empty() -> bool:
	return _make_analytics().key_moments.is_empty()


func test_initial_started_is_false() -> bool:
	return _make_analytics()._started == false


func test_initial_peak_live_count_is_zero() -> bool:
	return _make_analytics()._peak_live_count == 0


func test_initial_first_seed_not_recorded() -> bool:
	return _make_analytics()._first_seed_recorded == false


# ══════════════════════════════════════════════════════════════════════════════
# _on_rumor_transmitted
# ══════════════════════════════════════════════════════════════════════════════

func test_transmitted_increments_spread_count() -> bool:
	var a := _make_analytics()
	a._on_rumor_transmitted("Alice", "Bob", "r1", "believed")
	return a._npc_transmission["Alice"]["spread_count"] == 1


func test_transmitted_increments_received_count() -> bool:
	var a := _make_analytics()
	a._on_rumor_transmitted("Alice", "Bob", "r1", "believed")
	return a._npc_transmission["Bob"]["received_count"] == 1


func test_transmitted_multiple_spreads_accumulate() -> bool:
	var a := _make_analytics()
	a._on_rumor_transmitted("Alice", "Bob", "r1", "believed")
	a._on_rumor_transmitted("Alice", "Carol", "r2", "evaluating")
	return a._npc_transmission["Alice"]["spread_count"] == 2


func test_transmitted_new_npc_initialises_to_zero() -> bool:
	var a := _make_analytics()
	a._on_rumor_transmitted("Alice", "Bob", "r1", "believed")
	# Bob was new — his spread_count starts at 0, received was incremented
	return a._npc_transmission["Bob"]["spread_count"] == 0 \
		and a._npc_transmission["Bob"]["received_count"] == 1


# ══════════════════════════════════════════════════════════════════════════════
# _on_rumor_event
# ══════════════════════════════════════════════════════════════════════════════

func test_rumor_event_first_seed_adds_key_moment() -> bool:
	var a := _make_analytics()
	a._on_rumor_event("player seeded r1 about npc", 5)
	return a.key_moments.size() == 1 and a.key_moments[0]["type"] == "seed"


func test_rumor_event_second_seed_does_not_add_again() -> bool:
	var a := _make_analytics()
	a._on_rumor_event("player seeded r1 about npc", 5)
	a._on_rumor_event("player seeded r2 about npc", 6)  # first_seed already true
	return a.key_moments.size() == 1  # only the first seed moment


func test_rumor_event_defending_adds_state_change() -> bool:
	var a := _make_analytics()
	a._first_seed_recorded = true  # skip seed detection
	a._on_rumor_event("Maren → DEFENDING r1", 10)
	return a.key_moments.size() == 1 and a.key_moments[0]["type"] == "state_change"


func test_rumor_event_contradicted_adds_contradiction() -> bool:
	var a := _make_analytics()
	a._first_seed_recorded = true
	a._on_rumor_event("Edric → CONTRADICTED", 8)
	return a.key_moments.size() == 1 and a.key_moments[0]["type"] == "contradiction"


func test_rumor_event_reject_adds_contradiction() -> bool:
	var a := _make_analytics()
	a._first_seed_recorded = true
	a._on_rumor_event("Tomas → REJECT r2", 9)
	return a.key_moments.size() == 1 and a.key_moments[0]["type"] == "contradiction"


# ══════════════════════════════════════════════════════════════════════════════
# _on_socially_dead
# ══════════════════════════════════════════════════════════════════════════════

func test_socially_dead_adds_key_moment() -> bool:
	var a := _make_analytics()
	a._on_socially_dead("edric_fenn", "Edric Fenn", 42)
	return a.key_moments.size() == 1


func test_socially_dead_key_moment_type_is_social_death() -> bool:
	var a := _make_analytics()
	a._on_socially_dead("edric_fenn", "Edric Fenn", 42)
	return a.key_moments[0]["type"] == "social_death"


func test_socially_dead_key_moment_has_npc_name_in_text() -> bool:
	var a := _make_analytics()
	a._on_socially_dead("edric_fenn", "Edric Fenn", 42)
	return "Edric Fenn" in a.key_moments[0]["text"]


# ══════════════════════════════════════════════════════════════════════════════
# Public getters
# ══════════════════════════════════════════════════════════════════════════════

func test_get_timeline_data_returns_timeline() -> bool:
	var a := _make_analytics()
	a.timeline.append({"day": 1, "live_count": 2, "believer_count": 1})
	return a.get_timeline_data() == a.timeline


func test_get_key_moments_returns_key_moments() -> bool:
	var a := _make_analytics()
	a._on_socially_dead("x", "X", 0)
	return a.get_key_moments() == a.key_moments


# ══════════════════════════════════════════════════════════════════════════════
# get_influence_ranking
# ══════════════════════════════════════════════════════════════════════════════

func test_influence_ranking_sorted_by_spread_count() -> bool:
	var a := _make_analytics()
	a._on_rumor_transmitted("Alice", "Bob",   "r1", "believed")
	a._on_rumor_transmitted("Alice", "Carol", "r2", "believed")
	a._on_rumor_transmitted("Bob",   "Carol", "r3", "believed")
	var ranking := a.get_influence_ranking(5)
	# Alice spread 2, Bob spread 1 → Alice first
	return ranking[0]["name"] == "Alice" and ranking[1]["name"] == "Bob"


func test_influence_ranking_top_n_sliced() -> bool:
	var a := _make_analytics()
	a._on_rumor_transmitted("A", "B", "r1", "x")
	a._on_rumor_transmitted("B", "C", "r2", "x")
	a._on_rumor_transmitted("C", "D", "r3", "x")
	var ranking := a.get_influence_ranking(2)
	return ranking.size() == 2


func test_influence_ranking_empty_when_no_transmissions() -> bool:
	var a := _make_analytics()
	return a.get_influence_ranking(5).is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# finalize
# ══════════════════════════════════════════════════════════════════════════════

func test_finalize_adds_peak_when_peak_nonzero() -> bool:
	var a := _make_analytics()
	a._peak_live_count = 5
	a._peak_day = 3
	a.finalize()
	var has_peak := false
	for m in a.key_moments:
		if m["type"] == "peak":
			has_peak = true
			break
	return has_peak


func test_finalize_no_peak_when_peak_zero() -> bool:
	var a := _make_analytics()
	a.finalize()
	var has_peak := false
	for m in a.key_moments:
		if m["type"] == "peak":
			has_peak = true
			break
	return has_peak == false

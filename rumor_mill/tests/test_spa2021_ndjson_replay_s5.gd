## test_spa2021_ndjson_replay_s5.gd — X1 NDJSON-replay regression tests for S5
## baseline scenario (SPA-2021).
##
## Extends the SPA-1780 regression net to S5 (multi-faction politics, Normal
## difficulty). Fixture: tests/fixtures/playthrough_s5_normal_post_phase2.ndjson
##
## Asserts:
##   1. Fixture is readable and parseable (non-empty)
##   2. Opening event has evidence_economy_v2: true
##   3. scenario_ended event present with a clean outcome field
##   4. All four Phase 2 mechanic event types fired
##   5. endorsement_fired event present (S5-specific faction-phase advancement)
##   6. endorsement_fired fires at or after day 13 (ScenarioConfig.S5_ENDORSEMENT_DAY)
##   7. scenario_ended outcome is "WON" in captured baseline
##   8. aldric_final_rep in scenario_ended meets S5 win threshold (≥ 65)
##   9. edric_final_rep in scenario_ended is below S5 rival cap (< 45)
##  10. tomas_final_rep in scenario_ended is below S5 rival cap (< 45)
##
## Feature-flag guard: tests pass trivially when evidence_economy_v2 is OFF so
## this suite never fails in flag-disabled environments.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2021NdjsonReplayS5
extends RefCounted

const _FIXTURE := "res://tests/fixtures/playthrough_s5_normal_post_phase2.ndjson"

## S5 win constants (mirrors ScenarioConfig — no import needed for pure assertions).
const _S5_WIN_ALDRIC_MIN := 65
const _S5_WIN_RIVALS_MAX := 45
const _S5_ENDORSEMENT_DAY := 13


# ── Test runner ────────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_x1_s5_baseline_parseable",
		"test_x1_s5_flag_on",
		"test_x1_s5_scenario_ends_cleanly",
		"test_x1_s5_all_phase2_mechanics_fired",
		"test_x1_s5_endorsement_event_present",
		"test_x1_s5_endorsement_fires_on_or_after_day_13",
		"test_x1_s5_outcome_is_won",
		"test_x1_s5_aldric_final_rep_meets_win_threshold",
		"test_x1_s5_edric_final_rep_below_rival_cap",
		"test_x1_s5_tomas_final_rep_below_rival_cap",
	]

	var _saved_flag: bool = GameState.evidence_economy_v2

	for method_name in tests:
		GameState.evidence_economy_v2 = true  ## before_each
		var result: bool = call(method_name)
		GameState.evidence_economy_v2 = _saved_flag  ## after_each

		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSpa2021NdjsonReplayS5 tests: %d passed, %d failed" % [passed, failed])


# ── NDJSON helper ──────────────────────────────────────────────────────────────

static func _parse_ndjson_file(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("_parse_ndjson_file: cannot open '%s' (FileAccess error %d)" \
			% [path, FileAccess.get_open_error()])
		return result
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			result.append(parsed)
	return result


# ── Tests ──────────────────────────────────────────────────────────────────────

static func test_x1_s5_baseline_parseable() -> bool:
	## X1/S5: Fixture file is readable and contains at least one event.
	return _parse_ndjson_file(_FIXTURE).size() > 0


static func test_x1_s5_flag_on() -> bool:
	## X1/S5: The opening scenario_selected event has evidence_economy_v2: true.
	var events := _parse_ndjson_file(_FIXTURE)
	if events.is_empty():
		return false
	return events[0].get("evidence_economy_v2", false) == true


static func test_x1_s5_scenario_ends_cleanly() -> bool:
	## X1/S5: A scenario_ended event is present with an outcome field (clean exit).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			return ev.has("outcome")
	push_error("test_x1_s5_scenario_ends_cleanly: no scenario_ended event in S5 fixture")
	return false


static func test_x1_s5_all_phase2_mechanics_fired() -> bool:
	## X1/S5: All four Phase 2 tuning mechanic event types are present in the
	## baseline fixture — evidence_used, shelf_life_extended,
	## credulity_boost_applied, and target_cooldown_start.
	var required_types := [
		"evidence_used",
		"evidence_shelf_life_extended",
		"evidence_credulity_boost_applied",
		"evidence_target_cooldown_start",
	]
	var found: Dictionary = {}
	for ev in _parse_ndjson_file(_FIXTURE):
		var t: String = ev.get("type", "")
		if t in required_types:
			found[t] = true
	for req in required_types:
		if not found.has(req):
			push_error(
				"test_x1_s5_all_phase2_mechanics_fired: missing '%s' in S5 fixture" % req)
			return false
	return true


static func test_x1_s5_endorsement_event_present() -> bool:
	## X1/S5: An endorsement_fired event is present — S5's defining faction-phase
	## advancement mechanic (Prior Aldous endorses the leading candidate).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "endorsement_fired":
			return true
	push_error("test_x1_s5_endorsement_event_present: no endorsement_fired in S5 fixture")
	return false


static func test_x1_s5_endorsement_fires_on_or_after_day_13() -> bool:
	## X1/S5: endorsement_fired must occur at or after day 13
	## (ScenarioConfig.S5_ENDORSEMENT_DAY). An earlier fire would indicate
	## the win condition was reachable before the endorsement gate opened.
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "endorsement_fired":
			var day: int = ev.get("day", 0)
			if day < _S5_ENDORSEMENT_DAY:
				push_error(
					"test_x1_s5_endorsement_fires_on_or_after_day_13: endorsement on day %d (expected ≥ %d)" \
					% [day, _S5_ENDORSEMENT_DAY])
				return false
			return true
	push_error("test_x1_s5_endorsement_fires_on_or_after_day_13: no endorsement_fired event")
	return false


static func test_x1_s5_outcome_is_won() -> bool:
	## X1/S5: The captured baseline ended with outcome "WON".
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			return ev.get("outcome", "") == "WON"
	push_error("test_x1_s5_outcome_is_won: no scenario_ended event in S5 fixture")
	return false


static func test_x1_s5_aldric_final_rep_meets_win_threshold() -> bool:
	## X1/S5: aldric_final_rep in scenario_ended ≥ S5_WIN_ALDRIC_MIN (65).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			var rep: int = ev.get("aldric_final_rep", -1)
			if rep < _S5_WIN_ALDRIC_MIN:
				push_error(
					"test_x1_s5_aldric_final_rep_meets_win_threshold: rep=%d < threshold=%d" \
					% [rep, _S5_WIN_ALDRIC_MIN])
				return false
			return true
	push_error("test_x1_s5_aldric_final_rep_meets_win_threshold: no scenario_ended event")
	return false


static func test_x1_s5_edric_final_rep_below_rival_cap() -> bool:
	## X1/S5: edric_final_rep in scenario_ended < S5_WIN_RIVALS_MAX (45).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			var rep: int = ev.get("edric_final_rep", 999)
			if rep >= _S5_WIN_RIVALS_MAX:
				push_error(
					"test_x1_s5_edric_final_rep_below_rival_cap: rep=%d >= cap=%d" \
					% [rep, _S5_WIN_RIVALS_MAX])
				return false
			return true
	push_error("test_x1_s5_edric_final_rep_below_rival_cap: no scenario_ended event")
	return false


static func test_x1_s5_tomas_final_rep_below_rival_cap() -> bool:
	## X1/S5: tomas_final_rep in scenario_ended < S5_WIN_RIVALS_MAX (45).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			var rep: int = ev.get("tomas_final_rep", 999)
			if rep >= _S5_WIN_RIVALS_MAX:
				push_error(
					"test_x1_s5_tomas_final_rep_below_rival_cap: rep=%d >= cap=%d" \
					% [rep, _S5_WIN_RIVALS_MAX])
				return false
			return true
	push_error("test_x1_s5_tomas_final_rep_below_rival_cap: no scenario_ended event")
	return false

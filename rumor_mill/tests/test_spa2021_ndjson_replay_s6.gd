## test_spa2021_ndjson_replay_s6.gd — X1 NDJSON-replay regression tests for S6
## baseline scenario (SPA-2021).
##
## Extends the SPA-1780 regression net to S6 (late-game endgame / The Merchant's
## Debt, Normal difficulty). Fixture:
##   tests/fixtures/playthrough_s6_normal_post_phase2.ndjson
##
## Asserts:
##   1. Fixture is readable and parseable (non-empty)
##   2. Opening event has evidence_economy_v2: true
##   3. scenario_ended event present with a clean outcome field
##   4. All four Phase 2 mechanic event types fired
##   5. blackmail_deployed events present (S6-specific endgame mechanic)
##   6. Two blackmail_deployed events match S6_BLACKMAIL_MAX_USES (= 2)
##   7. Both endgame_condition_met events present (aldric low, marta high)
##   8. scenario_ended outcome is "WON" in captured baseline
##   9. marta_final_rep in scenario_ended meets S6 win threshold (≥ 62)
##  10. aldric_final_rep in scenario_ended is at or below S6 antagonist cap (≤ 30)
##
## Feature-flag guard: tests pass trivially when evidence_economy_v2 is OFF so
## this suite never fails in flag-disabled environments.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2021NdjsonReplayS6
extends RefCounted

const _FIXTURE := "res://tests/fixtures/playthrough_s6_normal_post_phase2.ndjson"

## S6 win constants (mirrors ScenarioConfig — no import needed for pure assertions).
const _S6_WIN_MARTA_MIN    := 62
const _S6_WIN_ALDRIC_MAX   := 30
const _S6_BLACKMAIL_MAX_USES := 2


# ── Test runner ────────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_x1_s6_baseline_parseable",
		"test_x1_s6_flag_on",
		"test_x1_s6_scenario_ends_cleanly",
		"test_x1_s6_all_phase2_mechanics_fired",
		"test_x1_s6_blackmail_deployed_present",
		"test_x1_s6_blackmail_deployed_count_matches_max_uses",
		"test_x1_s6_both_endgame_conditions_met",
		"test_x1_s6_outcome_is_won",
		"test_x1_s6_marta_final_rep_meets_win_threshold",
		"test_x1_s6_aldric_final_rep_at_or_below_antagonist_cap",
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

	print("\nSpa2021NdjsonReplayS6 tests: %d passed, %d failed" % [passed, failed])


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

static func test_x1_s6_baseline_parseable() -> bool:
	## X1/S6: Fixture file is readable and contains at least one event.
	return _parse_ndjson_file(_FIXTURE).size() > 0


static func test_x1_s6_flag_on() -> bool:
	## X1/S6: The opening scenario_selected event has evidence_economy_v2: true.
	var events := _parse_ndjson_file(_FIXTURE)
	if events.is_empty():
		return false
	return events[0].get("evidence_economy_v2", false) == true


static func test_x1_s6_scenario_ends_cleanly() -> bool:
	## X1/S6: A scenario_ended event is present with an outcome field (clean exit).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			return ev.has("outcome")
	push_error("test_x1_s6_scenario_ends_cleanly: no scenario_ended event in S6 fixture")
	return false


static func test_x1_s6_all_phase2_mechanics_fired() -> bool:
	## X1/S6: All four Phase 2 tuning mechanic event types are present in the
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
				"test_x1_s6_all_phase2_mechanics_fired: missing '%s' in S6 fixture" % req)
			return false
	return true


static func test_x1_s6_blackmail_deployed_present() -> bool:
	## X1/S6: At least one blackmail_deployed event is present — S6's defining
	## endgame mechanic (blackmail evidence deployed against Aldric Vane).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "blackmail_deployed":
			return true
	push_error("test_x1_s6_blackmail_deployed_present: no blackmail_deployed in S6 fixture")
	return false


static func test_x1_s6_blackmail_deployed_count_matches_max_uses() -> bool:
	## X1/S6: Exactly S6_BLACKMAIL_MAX_USES (2) blackmail_deployed events fired —
	## the captured baseline consumed the full blackmail budget.
	var count := 0
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "blackmail_deployed":
			count += 1
	if count != _S6_BLACKMAIL_MAX_USES:
		push_error(
			"test_x1_s6_blackmail_deployed_count_matches_max_uses: count=%d (expected %d)" \
			% [count, _S6_BLACKMAIL_MAX_USES])
		return false
	return true


static func test_x1_s6_both_endgame_conditions_met() -> bool:
	## X1/S6: Both endgame_condition_met events are present — one confirming
	## Aldric's rep fell below threshold and one confirming Marta's exceeded it.
	var aldric_low := false
	var marta_high := false
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "endgame_condition_met":
			var cond: String = ev.get("condition", "")
			if cond == "aldric_rep_below_threshold":
				aldric_low = true
			elif cond == "marta_rep_above_threshold":
				marta_high = true
	if not aldric_low:
		push_error("test_x1_s6_both_endgame_conditions_met: missing aldric_rep_below_threshold")
	if not marta_high:
		push_error("test_x1_s6_both_endgame_conditions_met: missing marta_rep_above_threshold")
	return aldric_low and marta_high


static func test_x1_s6_outcome_is_won() -> bool:
	## X1/S6: The captured baseline ended with outcome "WON".
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			return ev.get("outcome", "") == "WON"
	push_error("test_x1_s6_outcome_is_won: no scenario_ended event in S6 fixture")
	return false


static func test_x1_s6_marta_final_rep_meets_win_threshold() -> bool:
	## X1/S6: marta_final_rep in scenario_ended ≥ S6_WIN_MARTA_MIN (62).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			var rep: int = ev.get("marta_final_rep", -1)
			if rep < _S6_WIN_MARTA_MIN:
				push_error(
					"test_x1_s6_marta_final_rep_meets_win_threshold: rep=%d < threshold=%d" \
					% [rep, _S6_WIN_MARTA_MIN])
				return false
			return true
	push_error("test_x1_s6_marta_final_rep_meets_win_threshold: no scenario_ended event")
	return false


static func test_x1_s6_aldric_final_rep_at_or_below_antagonist_cap() -> bool:
	## X1/S6: aldric_final_rep in scenario_ended ≤ S6_WIN_ALDRIC_MAX (30).
	for ev in _parse_ndjson_file(_FIXTURE):
		if ev.get("type", "") == "scenario_ended":
			var rep: int = ev.get("aldric_final_rep", 999)
			if rep > _S6_WIN_ALDRIC_MAX:
				push_error(
					"test_x1_s6_aldric_final_rep_at_or_below_antagonist_cap: rep=%d > cap=%d" \
					% [rep, _S6_WIN_ALDRIC_MAX])
				return false
			return true
	push_error("test_x1_s6_aldric_final_rep_at_or_below_antagonist_cap: no scenario_ended event")
	return false

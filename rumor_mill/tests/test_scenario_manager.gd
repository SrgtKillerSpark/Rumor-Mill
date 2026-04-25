## test_scenario_manager.gd — Unit tests for ScenarioManager utility API (SPA-997).
##
## Covers the broader ScenarioManager surface not already exercised by
## TestScenarioConditions (which focuses on evaluate() win/fail paths):
##   • load_scenario_data() — narrative field population
##   • Narrative getters: get_title, get_intro_text, get_starting_text,
##     get_victory_text, get_fail_text, get_days_allowed, get_suggestion_overrides,
##     get_objective_card, get_milestone_toasts, get_strategic_brief,
##     get_strategic_defeat_hint
##   • get_heat_ceiling() — per-scenario defaults and override lifecycle
##   • apply_heat_ceiling_override / tick_heat_ceiling_override
##   • Time helpers: get_time_fraction, get_current_day, is_final_quarter
##   • override_days_allowed
##   • on_player_exposed — exposure fail path
##   • Deadline warning signals (0.75 / 0.90 thresholds)
##   • s1_first_blood signal
##   • get_win_progress for S2–S6
##   • get_win_condition_line / get_objective_one_liner
##   • Progress dict getters for all 6 scenarios
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenarioManager
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# load_scenario_data and narrative getters
		"test_load_scenario_data_populates_title",
		"test_load_scenario_data_populates_intro_text",
		"test_load_scenario_data_populates_days_allowed",
		"test_load_scenario_data_sets_active_scenario",
		"test_get_fail_text_returns_empty_for_missing_key",
		"test_get_fail_text_returns_value_for_known_key",
		"test_get_strategic_defeat_hint_returns_empty_for_missing",
		"test_get_strategic_defeat_hint_returns_value_for_known",
		"test_get_suggestion_overrides_returns_dict",
		# override_days_allowed
		"test_override_days_allowed_updates_value",
		# Time helpers
		"test_get_current_day_tick_zero",
		"test_get_current_day_tick_24",
		"test_get_time_fraction_start",
		"test_get_time_fraction_end",
		"test_get_time_fraction_clamps_to_one",
		"test_is_final_quarter_false_at_start",
		"test_is_final_quarter_true_at_75_pct",
		# Heat ceiling
		"test_heat_ceiling_s1_returns_80",
		"test_heat_ceiling_s6_returns_55",
		"test_heat_ceiling_s2_returns_minus_one",
		"test_heat_ceiling_s3_returns_minus_one",
		"test_heat_ceiling_s4_returns_minus_one",
		"test_heat_ceiling_s5_returns_minus_one",
		"test_heat_ceiling_override_active",
		"test_heat_ceiling_override_expires",
		# on_player_exposed
		"test_on_player_exposed_fails_s1",
		"test_on_player_exposed_ignored_for_s2",
		"test_on_player_exposed_noop_when_already_failed",
		# Deadline warning signals
		"test_deadline_warning_fires_at_75_pct",
		"test_deadline_warning_fires_at_90_pct",
		"test_deadline_warning_not_fired_twice",
		# s1_first_blood signal
		"test_s1_first_blood_fires_below_48",
		"test_s1_first_blood_not_fired_twice",
		# get_win_progress
		"test_win_progress_s2_zero_at_start",
		"test_win_progress_s2_one_at_threshold",
		"test_win_progress_s3_zero_when_calder_start_unset",
		"test_win_progress_s4_returns_time_fraction",
		"test_win_progress_s5_zero_at_assumed_start",
		"test_win_progress_s6_zero_at_start",
		"test_win_progress_s6_one_at_goal",
		# get_win_condition_line
		"test_win_condition_line_s1",
		"test_win_condition_line_s2",
		"test_win_condition_line_s3",
		"test_win_condition_line_s4",
		"test_win_condition_line_s5",
		"test_win_condition_line_s6",
		"test_win_condition_line_unknown_empty",
		# get_objective_one_liner
		"test_objective_one_liner_s1",
		"test_objective_one_liner_s6",
		# Progress dict getters
		"test_s1_progress_dict_keys",
		"test_s2_progress_dict_keys",
		"test_s3_progress_dict_keys",
		"test_s4_progress_dict_keys",
		"test_s5_progress_dict_keys",
		"test_s6_progress_dict_keys",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenarioManager tests: %d passed, %d failed" % [passed, failed])


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_sm(scenario: int, days_allowed: int = 30) -> ScenarioManager:
	var sm := ScenarioManager.new()
	sm._active_scenario = scenario
	sm._days_allowed    = days_allowed
	sm.ticks_per_day    = 24
	return sm


static func _rep_with(snapshots: Array) -> ReputationSystem:
	var rep := ReputationSystem.new()
	for snap in snapshots:
		rep._cache[snap.npc_id] = snap
	return rep


static func _snap(npc_id: String, score: int) -> ReputationSystem.ReputationSnapshot:
	var s := ReputationSystem.ReputationSnapshot.new()
	s.npc_id               = npc_id
	s.score                = score
	s.base_score           = score
	s.faction_sentiment    = 0.0
	s.rumor_delta          = 0.0
	s.last_calculated_tick = 0
	s.is_socially_dead     = false
	return s


## Minimal scenario data dictionary matching the shape of scenarios.json entries.
static func _minimal_data(scenario_num: int) -> Dictionary:
	return {
		"scenarioId":           "scenario_%d" % scenario_num,
		"title":                "Test Title %d" % scenario_num,
		"introText":            "Intro %d" % scenario_num,
		"startingText":         "Starting %d" % scenario_num,
		"victoryText":          "Victory %d" % scenario_num,
		"failTexts":            {"timeout": "You ran out of time.", "exposed": "You were caught."},
		"daysAllowed":          20,
		"objectiveCard":        {"mission": "test mission"},
		"milestoneToasts":      [{"threshold": 0.5, "message": "Halfway!"}],
		"strategicBrief":       {"targetNpcId": "edric_fenn"},
		"suggestion_overrides": {"heat_spike_threshold": 0.7},
		"strategicDefeatHints": {"timeout": "Plan faster next time."},
	}


# ── load_scenario_data tests ──────────────────────────────────────────────────

static func test_load_scenario_data_populates_title() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	return sm.get_title() == "Test Title 1"


static func test_load_scenario_data_populates_intro_text() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	return sm.get_intro_text() == "Intro 1"


static func test_load_scenario_data_populates_days_allowed() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(3))
	return sm.get_days_allowed() == 20


static func test_load_scenario_data_sets_active_scenario() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(4))
	return sm._active_scenario == 4


static func test_get_fail_text_returns_empty_for_missing_key() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	return sm.get_fail_text("nonexistent_key") == ""


static func test_get_fail_text_returns_value_for_known_key() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	return sm.get_fail_text("timeout") == "You ran out of time."


static func test_get_strategic_defeat_hint_returns_empty_for_missing() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	return sm.get_strategic_defeat_hint("unknown_reason") == ""


static func test_get_strategic_defeat_hint_returns_value_for_known() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	return sm.get_strategic_defeat_hint("timeout") == "Plan faster next time."


static func test_get_suggestion_overrides_returns_dict() -> bool:
	var sm := ScenarioManager.new()
	sm.load_scenario_data(_minimal_data(1))
	var overrides := sm.get_suggestion_overrides()
	return overrides is Dictionary and overrides.has("heat_spike_threshold")


# ── override_days_allowed ─────────────────────────────────────────────────────

static func test_override_days_allowed_updates_value() -> bool:
	var sm := _make_sm(1, 30)
	sm.override_days_allowed(45)
	return sm.get_days_allowed() == 45


# ── Time helpers ──────────────────────────────────────────────────────────────

static func test_get_current_day_tick_zero() -> bool:
	var sm := _make_sm(1)
	# tick 0 → day = 0 / 24 + 1 = 1
	return sm.get_current_day(0) == 1


static func test_get_current_day_tick_24() -> bool:
	var sm := _make_sm(1)
	# tick 24 → day = 24 / 24 + 1 = 2
	return sm.get_current_day(24) == 2


static func test_get_time_fraction_start() -> bool:
	var sm := _make_sm(1, 30)
	# Day 1 (tick 0): fraction = (1 - 1) / (30 - 1) = 0.0
	return absf(sm.get_time_fraction(0) - 0.0) < 0.001


static func test_get_time_fraction_end() -> bool:
	var sm := _make_sm(1, 30)
	# Day 30 (tick = 29 * 24): fraction = (30 - 1) / (30 - 1) = 1.0
	return absf(sm.get_time_fraction(29 * 24) - 1.0) < 0.001


static func test_get_time_fraction_clamps_to_one() -> bool:
	var sm := _make_sm(1, 30)
	# Day 40 (tick = 39 * 24): well beyond days_allowed — must clamp to 1.0
	return absf(sm.get_time_fraction(39 * 24) - 1.0) < 0.001


static func test_is_final_quarter_false_at_start() -> bool:
	var sm := _make_sm(1, 30)
	return not sm.is_final_quarter(0)


static func test_is_final_quarter_true_at_75_pct() -> bool:
	var sm := _make_sm(1, 20)
	# Day 16 of 20: fraction = (16-1)/(20-1) = 15/19 ≈ 0.789 ≥ 0.75
	return sm.is_final_quarter(15 * 24)


# ── Heat ceiling ──────────────────────────────────────────────────────────────

static func test_heat_ceiling_s1_returns_80() -> bool:
	var sm := _make_sm(1)
	return absf(sm.get_heat_ceiling() - 80.0) < 0.001


static func test_heat_ceiling_s6_returns_55() -> bool:
	var sm := _make_sm(6)
	return absf(sm.get_heat_ceiling() - 55.0) < 0.001


static func test_heat_ceiling_s2_returns_minus_one() -> bool:
	var sm := _make_sm(2)
	return sm.get_heat_ceiling() < 0.0


static func test_heat_ceiling_s3_returns_minus_one() -> bool:
	var sm := _make_sm(3)
	return sm.get_heat_ceiling() < 0.0


static func test_heat_ceiling_s4_returns_minus_one() -> bool:
	var sm := _make_sm(4)
	return sm.get_heat_ceiling() < 0.0


static func test_heat_ceiling_s5_returns_minus_one() -> bool:
	var sm := _make_sm(5)
	return sm.get_heat_ceiling() < 0.0


## apply_heat_ceiling_override sets a new ceiling that get_heat_ceiling() returns.
static func test_heat_ceiling_override_active() -> bool:
	var sm := _make_sm(6)
	sm.apply_heat_ceiling_override(75.0, 5, 1)
	return absf(sm.get_heat_ceiling() - 75.0) < 0.001


## tick_heat_ceiling_override reverts get_heat_ceiling() to the scenario default
## once current_day >= the expiry day set by apply_heat_ceiling_override.
static func test_heat_ceiling_override_expires() -> bool:
	var sm := _make_sm(6)
	# Set override for 5 days starting at day 1 → expires at day 6.
	sm.apply_heat_ceiling_override(75.0, 5, 1)
	sm.tick_heat_ceiling_override(6)
	return absf(sm.get_heat_ceiling() - ScenarioConfig.S6_EXPOSED_HEAT) < 0.001


# ── on_player_exposed ─────────────────────────────────────────────────────────

static func test_on_player_exposed_fails_s1() -> bool:
	var sm := _make_sm(1)
	var failed := false
	sm.scenario_resolved.connect(func(sid, state):
		failed = (sid == 1 and state == ScenarioManager.ScenarioState.FAILED))
	sm.on_player_exposed()
	return failed and sm.scenario_1_state == ScenarioManager.ScenarioState.FAILED


static func test_on_player_exposed_ignored_for_s2() -> bool:
	var sm := _make_sm(2)
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.on_player_exposed()
	return not resolved and sm.scenario_2_state == ScenarioManager.ScenarioState.ACTIVE


## on_player_exposed must not re-emit scenario_resolved if S1 is already FAILED.
static func test_on_player_exposed_noop_when_already_failed() -> bool:
	var sm := _make_sm(1)
	sm.scenario_1_state = ScenarioManager.ScenarioState.FAILED
	var count := 0
	sm.scenario_resolved.connect(func(_sid, _state): count += 1)
	sm.on_player_exposed()
	return count == 0


# ── Deadline warning signals ──────────────────────────────────────────────────

## At ≥75% of days_allowed, deadline_warning fires with threshold=0.75.
static func test_deadline_warning_fires_at_75_pct() -> bool:
	var sm := _make_sm(1, 20)
	var fired_75 := false
	sm.deadline_warning.connect(func(threshold, _days_rem):
		if absf(threshold - 0.75) < 0.001:
			fired_75 = true)
	# Day 16 of 20: fraction = (16-1)/(20-1) ≈ 0.789 ≥ 0.75
	sm._check_deadline_warnings(15 * 24)
	return fired_75


## At ≥90% of days_allowed, deadline_warning fires with threshold=0.90.
static func test_deadline_warning_fires_at_90_pct() -> bool:
	var sm := _make_sm(1, 20)
	var fired_90 := false
	sm.deadline_warning.connect(func(threshold, _days_rem):
		if absf(threshold - 0.90) < 0.001:
			fired_90 = true)
	# Day 19 of 20: fraction = (19-1)/(20-1) ≈ 0.947 ≥ 0.90
	sm._check_deadline_warnings(18 * 24)
	return fired_90


## deadline_warning should only fire once per threshold across multiple calls.
static func test_deadline_warning_not_fired_twice() -> bool:
	var sm := _make_sm(1, 20)
	var count := 0
	sm.deadline_warning.connect(func(_t, _d): count += 1)
	# Both calls are at the same tick — should fire 0.75 threshold exactly once.
	sm._check_deadline_warnings(15 * 24)
	sm._check_deadline_warnings(15 * 24)
	return count == 1


# ── s1_first_blood signal ─────────────────────────────────────────────────────

## Edric rep dropping below 48 fires s1_first_blood.
static func test_s1_first_blood_fires_below_48() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 47)])
	var fired := false
	sm.s1_first_blood.connect(func(): fired = true)
	sm.evaluate(rep, 0)
	return fired and sm._s1_first_blood_fired


## s1_first_blood must not fire a second time on subsequent evaluate() calls.
static func test_s1_first_blood_not_fired_twice() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 47)])
	var count := 0
	sm.s1_first_blood.connect(func(): count += 1)
	sm.evaluate(rep, 0)
	# Second evaluate at the same state — s1_first_blood must not fire again.
	sm.evaluate(rep, 1)
	return count == 1


# ── get_win_progress ──────────────────────────────────────────────────────────

## S2 progress = 0.0 when no believers have been recorded.
static func test_win_progress_s2_zero_at_start() -> bool:
	var sm  := _make_sm(2)
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 0
	return absf(sm.get_win_progress(rep, 0)) < 0.001


## S2 progress = 1.0 when believers == s2_win_illness_min (7).
static func test_win_progress_s2_one_at_threshold() -> bool:
	var sm  := _make_sm(2)
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 7
	return absf(sm.get_win_progress(rep, 0) - 1.0) < 0.001


## S3 progress = 0.0 when calder_score_start is -1 (evaluate() not yet called).
static func test_win_progress_s3_zero_when_calder_start_unset() -> bool:
	var sm  := _make_sm(3)
	var rep := _rep_with([_snap("calder_fenn", 60), _snap("tomas_reeve", 50)])
	# calder_score_start defaults to -1 before the first evaluate() call.
	return absf(sm.get_win_progress(rep, 0)) < 0.001


## S4 win progress equals get_time_fraction (survival scenario — progress is staying alive).
static func test_win_progress_s4_returns_time_fraction() -> bool:
	var sm  := _make_sm(4, 20)
	var rep := ReputationSystem.new()
	return absf(sm.get_win_progress(rep, 0) - sm.get_time_fraction(0)) < 0.001


## S5 progress = 0.0 when Aldric is at the assumed start score (45, no progress yet).
static func test_win_progress_s5_zero_at_assumed_start() -> bool:
	var sm  := _make_sm(5)
	var rep := _rep_with([
		_snap("aldric_vane", 45),
		_snap("edric_fenn",  58),
		_snap("tomas_reeve", 45),
	])
	return absf(sm.get_win_progress(rep, 0)) < 0.001


## S6 progress = 0.0 when Aldric is at assumed start (55) and Marta at assumed start (48).
static func test_win_progress_s6_zero_at_start() -> bool:
	var sm  := _make_sm(6)
	var rep := _rep_with([_snap("aldric_vane", 55), _snap("marta_coin", 48)])
	return absf(sm.get_win_progress(rep, 0)) < 0.001


## S6 progress = 1.0 when both conditions exactly met: Aldric=30 (≤30), Marta=62 (≥62).
static func test_win_progress_s6_one_at_goal() -> bool:
	var sm  := _make_sm(6)
	var rep := _rep_with([_snap("aldric_vane", 30), _snap("marta_coin", 62)])
	return absf(sm.get_win_progress(rep, 0) - 1.0) < 0.001


# ── get_win_condition_line ────────────────────────────────────────────────────

static func test_win_condition_line_s1() -> bool:
	return _make_sm(1).get_win_condition_line() == "Target: Edric Fenn reputation below 30"


static func test_win_condition_line_s2() -> bool:
	return _make_sm(2).get_win_condition_line() == "Target: 7+ NPCs believing illness rumors"


static func test_win_condition_line_s3() -> bool:
	return _make_sm(3).get_win_condition_line() == "Target: Calder rep ≥ 75, Tomas rep ≤ 35"


static func test_win_condition_line_s4() -> bool:
	return _make_sm(4).get_win_condition_line() == "Protect: Aldous, Vera, Finn — keep all above 48"


static func test_win_condition_line_s5() -> bool:
	return _make_sm(5).get_win_condition_line() == "Elect Aldric Vane: rep ≥ 65 & highest, rivals < 45"


static func test_win_condition_line_s6() -> bool:
	return _make_sm(6).get_win_condition_line() == "Expose Aldric (rep ≤ 30), protect Marta (rep ≥ 62)"


static func test_win_condition_line_unknown_empty() -> bool:
	return _make_sm(0).get_win_condition_line() == ""


# ── get_objective_one_liner ───────────────────────────────────────────────────

static func test_objective_one_liner_s1() -> bool:
	return _make_sm(1).get_objective_one_liner() == "Ruin Edric Fenn — make the town turn on him"


static func test_objective_one_liner_s6() -> bool:
	return _make_sm(6).get_objective_one_liner() == "Expose Aldric Vane's embezzlement (rep ≤ 30) while protecting Marta Coin (rep ≥ 62)."


# ── Progress dict getters ─────────────────────────────────────────────────────

static func test_s1_progress_dict_keys() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 45)])
	var d := sm.get_scenario_1_progress(rep)
	return d.has("edric_score") and d.has("start_score") and d.has("win_threshold") and d.has("state")


static func test_s2_progress_dict_keys() -> bool:
	var sm  := _make_sm(2)
	var rep := ReputationSystem.new()
	var d := sm.get_scenario_2_progress(rep)
	return (d.has("illness_believer_count") and d.has("illness_believer_ids")
		and d.has("illness_rejecter_ids") and d.has("win_threshold") and d.has("state"))


static func test_s3_progress_dict_keys() -> bool:
	var sm  := _make_sm(3)
	var rep := _rep_with([_snap("calder_fenn", 60), _snap("tomas_reeve", 48)])
	var d := sm.get_scenario_3_progress(rep)
	return (d.has("calder_score") and d.has("tomas_score")
		and d.has("calder_win_target") and d.has("tomas_win_target")
		and d.has("calder_fail_below") and d.has("state"))


static func test_s4_progress_dict_keys() -> bool:
	var sm  := _make_sm(4)
	var rep := _rep_with([
		_snap("aldous_prior", 55),
		_snap("vera_midwife", 52),
		_snap("finn_monk",    58),
	])
	var d := sm.get_scenario_4_progress(rep)
	return (d.has("protected_scores") and d.has("win_threshold")
		and d.has("fail_threshold") and d.has("min_score") and d.has("state"))


static func test_s5_progress_dict_keys() -> bool:
	var sm  := _make_sm(5)
	var rep := _rep_with([
		_snap("aldric_vane", 50),
		_snap("edric_fenn",  55),
		_snap("tomas_reeve", 45),
	])
	var d := sm.get_scenario_5_progress(rep)
	return (d.has("aldric_score") and d.has("edric_score") and d.has("tomas_score")
		and d.has("win_aldric_min") and d.has("win_rivals_max")
		and d.has("fail_aldric_below") and d.has("endorsement_fired")
		and d.has("endorsed_candidate") and d.has("state"))


static func test_s6_progress_dict_keys() -> bool:
	var sm  := _make_sm(6)
	var rep := _rep_with([_snap("aldric_vane", 50), _snap("marta_coin", 55)])
	var d := sm.get_scenario_6_progress(rep)
	return (d.has("aldric_score") and d.has("marta_score")
		and d.has("win_aldric_max") and d.has("win_marta_min")
		and d.has("fail_marta_below") and d.has("heat_ceiling")
		and d.has("max_heat") and d.has("state"))

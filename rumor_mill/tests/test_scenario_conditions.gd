## test_scenario_conditions.gd — Unit tests for ScenarioManager win/fail logic (SPA-957).
##
## Tests the evaluate() path for Scenarios 1–6 by constructing lightweight
## ReputationSystem snapshots in-memory (no live NPCs or scene tree required).
##
## Strategy:
##   • Create a bare ScenarioManager and configure the active scenario.
##   • Inject pre-built ReputationSnapshot objects directly into rep._cache.
##   • For Scenario 2 illness checks, also seed rep._illness_believer_counts
##     and rep._illness_rejecter_ids directly.
##   • Track signal emissions via lambda closures.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenarioConditions
extends RefCounted


static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Scenario 1 — The Alderman's Ruin
		"test_s1_win_when_edric_rep_below_30",
		"test_s1_no_win_when_edric_rep_exactly_30",
		"test_s1_fail_on_timeout",
		"test_s1_no_double_resolve",
		# Scenario 2 — The Plague Scare
		"test_s2_win_when_illness_believers_meet_threshold",
		"test_s2_no_win_below_threshold",
		"test_s2_grace_signal_on_first_maren_rejection",
		"test_s2_fail_after_grace_expires",
		"test_s2_fail_on_timeout",
		# Scenario 3 — The Succession
		"test_s3_win_when_calder_high_tomas_low",
		"test_s3_fail_when_calder_below_floor",
		"test_s3_fail_on_timeout",
		"test_s3_records_calder_start_score",
		# Scenario 4 — The Holy Inquisition
		"test_s4_fail_when_protected_npc_below_40",
		"test_s4_win_at_deadline_all_above_48",
		"test_s4_fail_at_deadline_npc_below_48",
		# Scenario 5 — The Election
		"test_s5_win_aldric_leads_rivals_below_45",
		"test_s5_fail_on_timeout",
		# Scenario 6 — The Merchant's Debt
		"test_s6_win_aldric_exposed_marta_safe",
		"test_s6_fail_on_timeout",
		# get_win_progress helpers
		"test_win_progress_s1_returns_zero_at_start",
		"test_win_progress_s1_returns_one_at_goal",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenarioConditions tests: %d passed, %d failed" % [passed, failed])


# ── helpers ───────────────────────────────────────────────────────────────────

## Build a minimal ReputationSystem with a pre-seeded snapshot for one NPC.
static func _rep_with(snapshots: Array) -> ReputationSystem:
	var rep := ReputationSystem.new()
	for snap in snapshots:
		rep._cache[snap.npc_id] = snap
	return rep


## Build a snapshot with score only (other fields at safe defaults).
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


## Build a ScenarioManager configured for a specific scenario number.
## ticks_per_day=24, days_allowed=30 unless overridden.
static func _make_sm(scenario: int, days_allowed: int = 30) -> ScenarioManager:
	var sm := ScenarioManager.new()
	sm._active_scenario = scenario
	sm._days_allowed    = days_allowed
	sm.ticks_per_day    = 24
	return sm


# ── Scenario 1 tests ──────────────────────────────────────────────────────────

## edric_fenn.score = 25 (< 30) → WIN.
static func test_s1_win_when_edric_rep_below_30() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 25)])
	var won := false
	sm.scenario_resolved.connect(func(sid, state): won = (sid == 1 and state == ScenarioManager.ScenarioState.WON))
	sm.evaluate(rep, 0)
	return won and sm.scenario_1_state == ScenarioManager.ScenarioState.WON


## edric_fenn.score = 30 (exactly at threshold, not below) → still ACTIVE, no signal.
static func test_s1_no_win_when_edric_rep_exactly_30() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 30)])
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_1_state == ScenarioManager.ScenarioState.ACTIVE


## Day 31 (tick = 30 * 24 + 1) with days_allowed=30 → timeout FAIL.
static func test_s1_fail_on_timeout() -> bool:
	var sm  := _make_sm(1, 30)
	var rep := _rep_with([_snap("edric_fenn", 50)])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 1 and state == ScenarioManager.ScenarioState.FAILED))
	# tick = 30 * 24 + 1 → current_day = 31 > days_allowed
	sm.evaluate(rep, 30 * 24 + 1)
	return failed_state and sm.scenario_1_state == ScenarioManager.ScenarioState.FAILED


## Once resolved, a second evaluate() call must not emit scenario_resolved again.
static func test_s1_no_double_resolve() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 20)])
	var count := 0
	sm.scenario_resolved.connect(func(_sid, _state): count += 1)
	sm.evaluate(rep, 0)
	sm.evaluate(rep, 0)
	return count == 1


# ── Scenario 2 tests ──────────────────────────────────────────────────────────

## 7 illness believers meets s2_win_illness_min (7) → WIN.
static func test_s2_win_when_illness_believers_meet_threshold() -> bool:
	var sm  := _make_sm(2)
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 7
	var won := false
	sm.scenario_resolved.connect(func(sid, state): won = (sid == 2 and state == ScenarioManager.ScenarioState.WON))
	sm.evaluate(rep, 0)
	return won and sm.scenario_2_state == ScenarioManager.ScenarioState.WON


## 6 illness believers (one short of 7) → still ACTIVE.
static func test_s2_no_win_below_threshold() -> bool:
	var sm  := _make_sm(2)
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 6
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_2_state == ScenarioManager.ScenarioState.ACTIVE


## Maren rejecting first time emits s2_maren_grace_started and records tick.
static func test_s2_grace_signal_on_first_maren_rejection() -> bool:
	var sm  := _make_sm(2)
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 3  ## below win
	rep._illness_rejecter_ids["alys_herbwife"] = {"maren_nun": true}
	var grace_fired := false
	sm.s2_maren_grace_started.connect(func(_days): grace_fired = true)
	sm.evaluate(rep, 0)
	return grace_fired and sm._s2_maren_first_reject_tick == 0


## Grace window expired: evaluate at tick ≥ (first_reject_tick + ticks_per_day * 2) → FAIL.
static func test_s2_fail_after_grace_expires() -> bool:
	var sm  := _make_sm(2)
	sm._s2_maren_first_reject_tick = 0   ## grace started at tick 0
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 3
	rep._illness_rejecter_ids["alys_herbwife"] = {"maren_nun": true}
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 2 and state == ScenarioManager.ScenarioState.FAILED))
	# tick = S2_MAREN_GRACE_DAYS(2) * ticks_per_day(24) = 48
	sm.evaluate(rep, 48)
	return failed_state and sm.scenario_2_state == ScenarioManager.ScenarioState.FAILED


## Timeout at day 31 with days_allowed=30 → FAIL.
static func test_s2_fail_on_timeout() -> bool:
	var sm  := _make_sm(2, 30)
	var rep := ReputationSystem.new()
	rep._illness_believer_counts["alys_herbwife"] = 2
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 2 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 30 * 24 + 1)
	return failed_state and sm.scenario_2_state == ScenarioManager.ScenarioState.FAILED


# ── Scenario 3 tests ──────────────────────────────────────────────────────────

## calder_fenn ≥ 75 AND tomas_reeve ≤ 35 → WIN.
static func test_s3_win_when_calder_high_tomas_low() -> bool:
	var sm  := _make_sm(3)
	var rep := _rep_with([_snap("calder_fenn", 75), _snap("tomas_reeve", 35)])
	var won := false
	sm.scenario_resolved.connect(func(sid, state): won = (sid == 3 and state == ScenarioManager.ScenarioState.WON))
	sm.evaluate(rep, 0)
	return won and sm.scenario_3_state == ScenarioManager.ScenarioState.WON


## calder_fenn.score < 35 (fail floor) → instant FAIL.
static func test_s3_fail_when_calder_below_floor() -> bool:
	var sm  := _make_sm(3)
	var rep := _rep_with([_snap("calder_fenn", 34), _snap("tomas_reeve", 50)])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 3 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 0)
	return failed_state and sm.scenario_3_state == ScenarioManager.ScenarioState.FAILED


## Timeout at day 31 → FAIL.
static func test_s3_fail_on_timeout() -> bool:
	var sm  := _make_sm(3, 30)
	var rep := _rep_with([_snap("calder_fenn", 60), _snap("tomas_reeve", 50)])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 3 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 30 * 24 + 1)
	return failed_state


## calder_score_start is recorded on the first evaluate() call.
static func test_s3_records_calder_start_score() -> bool:
	var sm  := _make_sm(3)
	var rep := _rep_with([_snap("calder_fenn", 62), _snap("tomas_reeve", 48)])
	sm.evaluate(rep, 0)
	return sm.calder_score_start == 62


# ── Scenario 4 tests ──────────────────────────────────────────────────────────

## Any protected NPC below 40 → instant FAIL.
static func test_s4_fail_when_protected_npc_below_40() -> bool:
	var sm  := _make_sm(4)
	var rep := _rep_with([
		_snap("aldous_prior", 50),
		_snap("vera_midwife", 39),   ## below S4_FAIL_REP_BELOW = 40
		_snap("finn_monk", 55),
	])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 4 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 0)
	return failed_state and sm.scenario_4_state == ScenarioManager.ScenarioState.FAILED


## All protected NPCs ≥ 48 at deadline → WIN.
static func test_s4_win_at_deadline_all_above_48() -> bool:
	var sm  := _make_sm(4, 20)
	var rep := _rep_with([
		_snap("aldous_prior", 55),
		_snap("vera_midwife", 50),
		_snap("finn_monk", 60),
	])
	var won := false
	sm.scenario_resolved.connect(func(sid, state):
		won = (sid == 4 and state == ScenarioManager.ScenarioState.WON))
	# Tick at day 21 > 20 allowed
	sm.evaluate(rep, 20 * 24 + 1)
	return won and sm.scenario_4_state == ScenarioManager.ScenarioState.WON


## At deadline with one NPC at 47 (below win threshold 48) → FAIL.
static func test_s4_fail_at_deadline_npc_below_48() -> bool:
	var sm  := _make_sm(4, 20)
	var rep := _rep_with([
		_snap("aldous_prior", 55),
		_snap("vera_midwife", 47),   ## just below S4_WIN_REP_MIN = 48
		_snap("finn_monk", 60),
	])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 4 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 20 * 24 + 1)
	return failed_state and sm.scenario_4_state == ScenarioManager.ScenarioState.FAILED


# ── Scenario 5 tests ──────────────────────────────────────────────────────────

## aldric_vane ≥ 65, edric_fenn < 45, tomas_reeve < 45 → WIN.
static func test_s5_win_aldric_leads_rivals_below_45() -> bool:
	var sm  := _make_sm(5)
	var rep := _rep_with([
		_snap("aldric_vane", 65),
		_snap("edric_fenn",  40),
		_snap("tomas_reeve", 38),
	])
	var won := false
	sm.scenario_resolved.connect(func(sid, state):
		won = (sid == 5 and state == ScenarioManager.ScenarioState.WON))
	sm.evaluate(rep, 0)
	return won and sm.scenario_5_state == ScenarioManager.ScenarioState.WON


## Timeout at day 31 → FAIL.
static func test_s5_fail_on_timeout() -> bool:
	var sm  := _make_sm(5, 30)
	var rep := _rep_with([
		_snap("aldric_vane", 50),
		_snap("edric_fenn",  55),
		_snap("tomas_reeve", 48),
	])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 5 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 30 * 24 + 1)
	return failed_state and sm.scenario_5_state == ScenarioManager.ScenarioState.FAILED


# ── Scenario 6 tests ──────────────────────────────────────────────────────────

## aldric_vane ≤ 30 AND marta_coin ≥ 62 → WIN.
static func test_s6_win_aldric_exposed_marta_safe() -> bool:
	var sm  := _make_sm(6)
	var rep := _rep_with([
		_snap("aldric_vane", 28),
		_snap("marta_coin",  65),
	])
	var won := false
	sm.scenario_resolved.connect(func(sid, state):
		won = (sid == 6 and state == ScenarioManager.ScenarioState.WON))
	sm.evaluate(rep, 0)
	return won and sm.scenario_6_state == ScenarioManager.ScenarioState.WON


## Timeout at day 31 → FAIL.
static func test_s6_fail_on_timeout() -> bool:
	var sm  := _make_sm(6, 30)
	var rep := _rep_with([
		_snap("aldric_vane", 50),
		_snap("marta_coin",  55),
	])
	var failed_state := false
	sm.scenario_resolved.connect(func(sid, state):
		failed_state = (sid == 6 and state == ScenarioManager.ScenarioState.FAILED))
	sm.evaluate(rep, 30 * 24 + 1)
	return failed_state


# ── get_win_progress tests ────────────────────────────────────────────────────

## S1 progress = 0.0 when Edric's score equals the starting score (50).
static func test_win_progress_s1_returns_zero_at_start() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 50)])
	var prog := sm.get_win_progress(rep, 0)
	return absf(prog) < 0.001


## S1 progress = 1.0 when Edric's score equals the win threshold (30) — range = 50-30 = 20.
static func test_win_progress_s1_returns_one_at_goal() -> bool:
	var sm  := _make_sm(1)
	var rep := _rep_with([_snap("edric_fenn", 30)])
	var prog := sm.get_win_progress(rep, 0)
	return absf(prog - 1.0) < 0.001

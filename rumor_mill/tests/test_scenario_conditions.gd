## test_scenario_conditions.gd — Regression tests for scenario win/fail evaluation.
##
## SPA-1098: Validates that no scenario resolves on the first tick (tick 0)
## and that win/fail conditions require actual gameplay state changes.
##
## Run via GUT test runner or manually in the Godot editor.

extends GutTest


# ── Helpers ──────────────────────────────────────────────────────────────────

## Minimal mock ReputationSystem that returns configurable snapshots.
class MockReputationSystem extends ReputationSystem:
	var _mock_snapshots: Dictionary = {}

	func set_mock_snapshot(npc_id: String, score: int) -> void:
		var snap := ReputationSnapshot.new()
		snap.npc_id    = npc_id
		snap.score     = score
		snap.base_score = score
		_mock_snapshots[npc_id] = snap

	func get_snapshot(npc_id: String) -> ReputationSnapshot:
		return _mock_snapshots.get(npc_id, null)

	func get_illness_believer_count(_npc_id: String) -> int:
		return 0

	func has_illness_rejecter(_subject_id: String, _observer_id: String) -> bool:
		return false


func _build_scenario_manager(scenario_num: int, days_allowed: int = 30) -> ScenarioManager:
	var sm := ScenarioManager.new()
	sm.load_scenario_data({
		"scenarioId": "scenario_%d" % scenario_num,
		"daysAllowed": days_allowed,
		"title": "Test Scenario %d" % scenario_num,
	})
	return sm


func _build_default_rep() -> MockReputationSystem:
	## All NPCs at default score 50.
	var rep := MockReputationSystem.new()
	rep.set_mock_snapshot("edric_fenn", 50)
	rep.set_mock_snapshot("alys_herbwife", 50)
	rep.set_mock_snapshot("maren_nun", 50)
	rep.set_mock_snapshot("calder_fenn", 65)
	rep.set_mock_snapshot("tomas_reeve", 52)
	rep.set_mock_snapshot("aldous_prior", 50)
	rep.set_mock_snapshot("vera_midwife", 50)
	rep.set_mock_snapshot("finn_monk", 50)
	return rep


# ── SPA-1098: No scenario resolves at tick 0 ────────────────────────────────

func test_scenario_1_no_resolve_at_tick_0() -> void:
	var sm := _build_scenario_manager(1)
	var rep := _build_default_rep()
	var resolved := false
	sm.scenario_resolved.connect(func(_id, _state): resolved = true)
	sm.evaluate(rep, 0)
	assert_false(resolved, "S1 must not resolve at tick 0")
	assert_eq(sm.scenario_1_state, ScenarioManager.ScenarioState.ACTIVE)


func test_scenario_2_no_resolve_at_tick_0() -> void:
	var sm := _build_scenario_manager(2)
	var rep := _build_default_rep()
	var resolved := false
	sm.scenario_resolved.connect(func(_id, _state): resolved = true)
	sm.evaluate(rep, 0)
	assert_false(resolved, "S2 must not resolve at tick 0")
	assert_eq(sm.scenario_2_state, ScenarioManager.ScenarioState.ACTIVE)


func test_scenario_3_no_resolve_at_tick_0() -> void:
	var sm := _build_scenario_manager(3)
	var rep := _build_default_rep()
	var resolved := false
	sm.scenario_resolved.connect(func(_id, _state): resolved = true)
	sm.evaluate(rep, 0)
	assert_false(resolved, "S3 must not resolve at tick 0")
	assert_eq(sm.scenario_3_state, ScenarioManager.ScenarioState.ACTIVE)


func test_scenario_4_no_resolve_at_tick_0() -> void:
	var sm := _build_scenario_manager(4, 20)
	var rep := _build_default_rep()
	var resolved := false
	sm.scenario_resolved.connect(func(_id, _state): resolved = true)
	sm.evaluate(rep, 0)
	assert_false(resolved, "S4 must not resolve at tick 0")
	assert_eq(sm.scenario_4_state, ScenarioManager.ScenarioState.ACTIVE)


# ── S1 win requires Edric below threshold ────────────────────────────────────

func test_scenario_1_no_win_at_default_score() -> void:
	var sm := _build_scenario_manager(1)
	var rep := _build_default_rep()
	var won := false
	sm.scenario_resolved.connect(func(_id, state):
		if state == ScenarioManager.ScenarioState.WON: won = true
	)
	sm.evaluate(rep, 1)
	assert_false(won, "S1 must not win when Edric score is 50 (above threshold 30)")


func test_scenario_1_wins_when_edric_below_threshold() -> void:
	var sm := _build_scenario_manager(1)
	var rep := _build_default_rep()
	rep.set_mock_snapshot("edric_fenn", 29)
	var won := false
	sm.scenario_resolved.connect(func(_id, state):
		if state == ScenarioManager.ScenarioState.WON: won = true
	)
	sm.evaluate(rep, 24)  # tick 24 = day 2
	assert_true(won, "S1 should win when Edric score is 29 (below threshold 30)")
	assert_eq(sm.scenario_1_state, ScenarioManager.ScenarioState.WON)


func test_scenario_1_no_win_at_exact_threshold() -> void:
	var sm := _build_scenario_manager(1)
	var rep := _build_default_rep()
	rep.set_mock_snapshot("edric_fenn", 30)
	var won := false
	sm.scenario_resolved.connect(func(_id, state):
		if state == ScenarioManager.ScenarioState.WON: won = true
	)
	sm.evaluate(rep, 24)
	assert_false(won, "S1 must not win when Edric score equals threshold (30)")


# ── S1 timeout fail ──────────────────────────────────────────────────────────

func test_scenario_1_timeout_fail() -> void:
	var sm := _build_scenario_manager(1, 30)
	var rep := _build_default_rep()
	var failed := false
	sm.scenario_resolved.connect(func(_id, state):
		if state == ScenarioManager.ScenarioState.FAILED: failed = true
	)
	# Day 30: tick = (30-1)*24 = 696 → current_day = 696/24+1 = 30
	sm.evaluate(rep, 696)
	assert_true(failed, "S1 should fail at day limit")


# ── S4 does not auto-win at default scores ──────────────────────────────────

func test_scenario_4_no_instant_win_all_above_threshold() -> void:
	## Regression: all protected NPCs start above S4_WIN_REP_MIN (45).
	## Even at the deadline, the first tick guard prevents tick-0 resolution,
	## and at any later tick, the game should only resolve at the deadline.
	var sm := _build_scenario_manager(4, 20)
	var rep := _build_default_rep()
	var resolved_state: ScenarioManager.ScenarioState = ScenarioManager.ScenarioState.ACTIVE
	sm.scenario_resolved.connect(func(_id, state): resolved_state = state)
	# Tick 1: well before deadline (day 1).
	sm.evaluate(rep, 1)
	assert_eq(resolved_state, ScenarioManager.ScenarioState.ACTIVE,
		"S4 must not resolve on day 1 even with all NPCs above threshold")


# ── All difficulties × all scenarios: no resolve on first tick ───────────────

func test_all_scenarios_all_difficulties_no_instant_resolve() -> void:
	## Validates all 4 scenarios with all 3 difficulty day bonuses.
	var day_bonuses := [5, 0, -5]  # apprentice, master, spymaster
	for scenario_num in range(1, 5):
		for bonus in day_bonuses:
			var base_days: int = [0, 30, 22, 27, 20][scenario_num]
			var adjusted: int = maxi(1, base_days + bonus)
			var sm := _build_scenario_manager(scenario_num, adjusted)
			var rep := _build_default_rep()
			var resolved := false
			sm.scenario_resolved.connect(func(_id, _state): resolved = true)
			sm.evaluate(rep, 0)
			assert_false(resolved,
				"S%d (days=%d) must not resolve at tick 0" % [scenario_num, adjusted])
			sm.evaluate(rep, 1)
			assert_false(resolved,
				"S%d (days=%d) must not resolve at tick 1 with default scores" % [scenario_num, adjusted])

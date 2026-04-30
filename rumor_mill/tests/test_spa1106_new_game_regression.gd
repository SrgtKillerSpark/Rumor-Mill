## test_spa1106_new_game_regression.gd — Regression suite for SPA-1106.
##
## Guards against fresh New Game triggering instant victory or defeat.
## Parent bug: SPA-862 (board-reproduced instant-victory on Scenario 1 / apprentice).
## Root-cause investigations: SPA-1098 (evaluate() audit), SPA-1102 (save-state lifecycle).
##
## Three guarantee classes:
##
##   FRESH_START — For every (scenario_id, difficulty) pair, a fresh ScenarioManager
##                 seeded with canonical starting reputations must not resolve at tick 0.
##                 Covers apprentice (+5 days), master (baseline), and spymaster (-5 days).
##
##   STALE_STATE — Explicitly priming scenario_N_state to WON/FAILED, then resetting it
##                 to ACTIVE (simulating a New Game reset), must not cause evaluate() to
##                 re-resolve when seeded with starting scores at tick 0.
##
##   SPA862_REPRO — edric_fenn.score = 50, S1 win target < 30: evaluate() must NOT emit
##                  a win resolution.  This is the exact state the board reproduced in
##                  SPA-862.
##
## Starting-reputation values are the canonical data/scenarios.json defaults:
##   S1: edric_fenn = 50  (S1_EDRIC_START_SCORE, scenarios.json startingReputations: {})
##   S2: illness_believer_count = 0
##   S3: calder_fenn = 62, tomas_reeve = 48  (spymaster: 60 / 52)
##   S4: aldous_prior = 70, vera_midwife = 68, finn_monk = 68
##       (apprentice: 75/73/77 | spymaster: 62/60/63)
##   S5: edric_fenn = 58, aldric_vane = 45, tomas_reeve = 45
##       (spymaster: 62/38/48)
##   S6: aldric_vane = 55, marta_coin = 48  (spymaster: 63/44)
##
## TODO SPA-1098 / SPA-1102: if either fix changes evaluate() semantics or the
## initial-state hydration path such that any test below begins failing, re-evaluate
## whether it should be temporarily marked pending.  As of the suite's creation the
## evaluate() logic itself is correct for these inputs; the bug manifests upstream in
## New Game initialisation, which these unit tests exercise indirectly by asserting the
## final in-process guarantee.

class_name TestSpa1106NewGameRegression
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── FRESH_START: Scenario 1 (The Alderman's Ruin) ─────────────────────
		"test_s1_fresh_master_no_instant_resolve",
		"test_s1_fresh_apprentice_no_instant_resolve",
		"test_s1_fresh_spymaster_no_instant_resolve",
		# ── FRESH_START: Scenario 2 (The Plague Scare) ────────────────────────
		"test_s2_fresh_master_no_instant_resolve",
		"test_s2_fresh_apprentice_no_instant_resolve",
		"test_s2_fresh_spymaster_no_instant_resolve",
		# ── FRESH_START: Scenario 3 (The Succession) ──────────────────────────
		"test_s3_fresh_master_no_instant_resolve",
		"test_s3_fresh_apprentice_no_instant_resolve",
		"test_s3_fresh_spymaster_no_instant_resolve",
		# ── FRESH_START: Scenario 4 (The Holy Inquisition) ────────────────────
		"test_s4_fresh_master_no_instant_resolve",
		"test_s4_fresh_apprentice_no_instant_resolve",
		"test_s4_fresh_spymaster_no_instant_resolve",
		# ── FRESH_START: Scenario 5 (The Election) ────────────────────────────
		"test_s5_fresh_master_no_instant_resolve",
		"test_s5_fresh_apprentice_no_instant_resolve",
		"test_s5_fresh_spymaster_no_instant_resolve",
		# ── FRESH_START: Scenario 6 (The Merchant's Debt) ─────────────────────
		"test_s6_fresh_master_no_instant_resolve",
		"test_s6_fresh_apprentice_no_instant_resolve",
		"test_s6_fresh_spymaster_no_instant_resolve",
		# ── STALE_STATE: state flags reset before New Game ─────────────────────
		"test_stale_s1_state_reset_to_active_no_instant_win",
		"test_stale_s1_state_reset_to_active_no_instant_fail",
		"test_stale_s3_state_reset_to_active_no_instant_resolve",
		"test_stale_s5_state_reset_to_active_no_instant_resolve",
		"test_stale_s6_state_reset_to_active_no_instant_resolve",
		# ── SPA-862 exact reproduction ─────────────────────────────────────────
		"test_spa862_s1_edric_50_is_not_a_win",
		"test_spa862_s1_edric_50_state_stays_active",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1106 NewGame regression: %d passed, %d failed" % [passed, failed])


# ── Shared helpers ─────────────────────────────────────────────────────────────

## Build a bare ScenarioManager for the given scenario.
## days_allowed defaults to the scenario's base allowance; ticks_per_day = 24.
static func _make_sm(scenario: int, days_allowed: int = 30) -> ScenarioManager:
	var sm := ScenarioManager.new()
	sm._active_scenario = scenario
	sm._days_allowed    = days_allowed
	sm.ticks_per_day    = 24
	return sm


## Build a minimal ReputationSystem pre-seeded with one or more snapshots.
static func _rep_with(snapshots: Array) -> ReputationSystem:
	var rep := ReputationSystem.new()
	for snap in snapshots:
		rep._cache[snap.npc_id] = snap
	return rep


## Build a ReputationSnapshot with the given score and safe defaults elsewhere.
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


## Assert neither WON nor FAILED was emitted and the given state var is ACTIVE.
## Returns true only when scenario_resolved was NOT called and state is ACTIVE.
static func _assert_active_after_eval(
		sm: ScenarioManager,
		rep: ReputationSystem,
		state_getter: Callable) -> bool:
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and state_getter.call() == ScenarioManager.ScenarioState.ACTIVE


# ── FRESH_START: Scenario 1 ────────────────────────────────────────────────────
# S1 starting rep: edric_fenn = 50 (S1_EDRIC_START_SCORE, scenarios.json startingReputations: {}).
# Win requires edric < 30. 50 is not < 30, so no instant win.
# No heat store attached → no heat-based fail. tick 0 → day 1, well within limit.

static func test_s1_fresh_master_no_instant_resolve() -> bool:
	# master: days_allowed = 30 (base)
	var sm  := _make_sm(1, 30)
	var rep := _rep_with([_snap("edric_fenn", 50)])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_1_state)


static func test_s1_fresh_apprentice_no_instant_resolve() -> bool:
	# apprentice: days_bonus = +5 → days_allowed = 35
	var sm  := _make_sm(1, 35)
	var rep := _rep_with([_snap("edric_fenn", 50)])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_1_state)


static func test_s1_fresh_spymaster_no_instant_resolve() -> bool:
	# spymaster: days_bonus = -5 → days_allowed = 25
	var sm  := _make_sm(1, 25)
	var rep := _rep_with([_snap("edric_fenn", 50)])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_1_state)


# ── FRESH_START: Scenario 2 ────────────────────────────────────────────────────
# S2 starting rep: illness_believer_count = 0.
# Win requires count >= 7. 0 is not >= 7. No Maren rejection seeded → no grace fail.

static func test_s2_fresh_master_no_instant_resolve() -> bool:
	var sm  := _make_sm(2, 24)
	var rep := ReputationSystem.new()
	# Believer count starts at 0 (not seeded)
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_2_state)


static func test_s2_fresh_apprentice_no_instant_resolve() -> bool:
	var sm  := _make_sm(2, 29)
	var rep := ReputationSystem.new()
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_2_state)


static func test_s2_fresh_spymaster_no_instant_resolve() -> bool:
	var sm  := _make_sm(2, 19)
	var rep := ReputationSystem.new()
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_2_state)


# ── FRESH_START: Scenario 3 ────────────────────────────────────────────────────
# S3 base starting reps: calder_fenn = 62, tomas_reeve = 48.
# Win requires calder >= 75 AND tomas <= 35 → not met.
# Instant fail requires calder < 35 → not met at 62.
# spymaster override: calder = 60, tomas = 52 → still safe.

static func test_s3_fresh_master_no_instant_resolve() -> bool:
	var sm  := _make_sm(3, 25)
	var rep := _rep_with([_snap("calder_fenn", 62), _snap("tomas_reeve", 48)])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_3_state)


static func test_s3_fresh_apprentice_no_instant_resolve() -> bool:
	var sm  := _make_sm(3, 30)
	var rep := _rep_with([_snap("calder_fenn", 62), _snap("tomas_reeve", 48)])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_3_state)


static func test_s3_fresh_spymaster_no_instant_resolve() -> bool:
	# spymaster startingReputationOverrides: calder = 60, tomas = 52
	var sm  := _make_sm(3, 20)
	var rep := _rep_with([_snap("calder_fenn", 60), _snap("tomas_reeve", 52)])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_3_state)


# ── FRESH_START: Scenario 4 ────────────────────────────────────────────────────
# S4 base starting reps: aldous_prior = 70, vera_midwife = 68, finn_monk = 68.
# Instant fail requires any < 40 → not met. Win only fires at deadline (day > 20).
# tick 0 → day 1, deadline not reached.
# apprentice override: 75/73/77; spymaster override: 62/60/63 — all safely above 40.

static func test_s4_fresh_master_no_instant_resolve() -> bool:
	var sm  := _make_sm(4, 20)
	var rep := _rep_with([
		_snap("aldous_prior", 70),
		_snap("vera_midwife", 68),
		_snap("finn_monk",    68),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_4_state)


static func test_s4_fresh_apprentice_no_instant_resolve() -> bool:
	# apprentice startingReputationOverrides: 75/73/77; days_allowed = 25
	var sm  := _make_sm(4, 25)
	var rep := _rep_with([
		_snap("aldous_prior", 75),
		_snap("vera_midwife", 73),
		_snap("finn_monk",    77),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_4_state)


static func test_s4_fresh_spymaster_no_instant_resolve() -> bool:
	# spymaster startingReputationOverrides: 62/60/63; days_allowed = 15
	var sm  := _make_sm(4, 15)
	var rep := _rep_with([
		_snap("aldous_prior", 62),
		_snap("vera_midwife", 60),
		_snap("finn_monk",    63),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_4_state)


# ── FRESH_START: Scenario 5 ────────────────────────────────────────────────────
# S5 base starting reps: edric_fenn = 58, aldric_vane = 45, tomas_reeve = 45.
# Win requires aldric >= 65 AND aldric > edric AND aldric > tomas AND edric < 45 AND tomas < 45 → not met.
# Instant fail requires aldric < 30 → not met at 45.
# spymaster override: edric = 62, aldric = 38, tomas = 48 — 38 is not < 30 → still safe.

static func test_s5_fresh_master_no_instant_resolve() -> bool:
	var sm  := _make_sm(5, 21)
	var rep := _rep_with([
		_snap("edric_fenn",  58),
		_snap("aldric_vane", 45),
		_snap("tomas_reeve", 45),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_5_state)


static func test_s5_fresh_apprentice_no_instant_resolve() -> bool:
	var sm  := _make_sm(5, 26)
	var rep := _rep_with([
		_snap("edric_fenn",  58),
		_snap("aldric_vane", 45),
		_snap("tomas_reeve", 45),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_5_state)


static func test_s5_fresh_spymaster_no_instant_resolve() -> bool:
	# spymaster startingReputationOverrides: edric=62, aldric=38, tomas=48; days_allowed=16
	var sm  := _make_sm(5, 16)
	var rep := _rep_with([
		_snap("edric_fenn",  62),
		_snap("aldric_vane", 38),
		_snap("tomas_reeve", 48),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_5_state)


# ── FRESH_START: Scenario 6 ────────────────────────────────────────────────────
# S6 base starting reps: aldric_vane = 55, marta_coin = 48.
# Win requires aldric <= 30 AND marta >= 62 → not met.
# Instant fail requires marta < 30 → not met at 48.  Heat = null → no heat fail.
# spymaster override: aldric = 63, marta = 44 → 44 is not < 30, 63 is not <= 30 → safe.

static func test_s6_fresh_master_no_instant_resolve() -> bool:
	var sm  := _make_sm(6, 20)
	var rep := _rep_with([
		_snap("aldric_vane", 55),
		_snap("marta_coin",  48),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_6_state)


static func test_s6_fresh_apprentice_no_instant_resolve() -> bool:
	var sm  := _make_sm(6, 25)
	var rep := _rep_with([
		_snap("aldric_vane", 55),
		_snap("marta_coin",  48),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_6_state)


static func test_s6_fresh_spymaster_no_instant_resolve() -> bool:
	# spymaster startingReputationOverrides: aldric=63, marta=44; days_allowed=15
	var sm  := _make_sm(6, 15)
	var rep := _rep_with([
		_snap("aldric_vane", 63),
		_snap("marta_coin",  44),
	])
	return _assert_active_after_eval(sm, rep, func(): return sm.scenario_6_state)


# ── STALE_STATE ────────────────────────────────────────────────────────────────
# Simulate a "leftover WON/FAILED flag from a previous session" then reset it to
# ACTIVE (as a correct New Game reset should do) and verify evaluate() still stays
# ACTIVE with fresh starting scores.
#
# The key invariant: after a proper reset to ACTIVE, the starting reputation
# values must never satisfy an instant-resolve condition.

## Stale WON state on S1, reset to ACTIVE, fresh edric = 50 → must not re-resolve as WON.
static func test_stale_s1_state_reset_to_active_no_instant_win() -> bool:
	var sm := _make_sm(1, 30)
	# Simulate stale state from a previous game
	sm.scenario_1_state = ScenarioManager.ScenarioState.WON
	# New Game reset
	sm.scenario_1_state = ScenarioManager.ScenarioState.ACTIVE
	var rep := _rep_with([_snap("edric_fenn", 50)])
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_1_state == ScenarioManager.ScenarioState.ACTIVE


## Stale FAILED state on S1, reset to ACTIVE, fresh edric = 50 → must not re-resolve as FAILED.
static func test_stale_s1_state_reset_to_active_no_instant_fail() -> bool:
	var sm := _make_sm(1, 30)
	sm.scenario_1_state = ScenarioManager.ScenarioState.FAILED
	sm.scenario_1_state = ScenarioManager.ScenarioState.ACTIVE
	var rep := _rep_with([_snap("edric_fenn", 50)])
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_1_state == ScenarioManager.ScenarioState.ACTIVE


## S3 stale WON reset: calder = 62, tomas = 48 at tick 0 → ACTIVE.
static func test_stale_s3_state_reset_to_active_no_instant_resolve() -> bool:
	var sm := _make_sm(3, 25)
	sm.scenario_3_state = ScenarioManager.ScenarioState.WON
	sm.scenario_3_state = ScenarioManager.ScenarioState.ACTIVE
	var rep := _rep_with([_snap("calder_fenn", 62), _snap("tomas_reeve", 48)])
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_3_state == ScenarioManager.ScenarioState.ACTIVE


## S5 stale WON reset: starting reps at tick 0 → ACTIVE.
static func test_stale_s5_state_reset_to_active_no_instant_resolve() -> bool:
	var sm := _make_sm(5, 21)
	sm.scenario_5_state = ScenarioManager.ScenarioState.WON
	sm.scenario_5_state = ScenarioManager.ScenarioState.ACTIVE
	var rep := _rep_with([
		_snap("edric_fenn",  58),
		_snap("aldric_vane", 45),
		_snap("tomas_reeve", 45),
	])
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_5_state == ScenarioManager.ScenarioState.ACTIVE


## S6 stale WON reset: starting reps at tick 0 → ACTIVE.
static func test_stale_s6_state_reset_to_active_no_instant_resolve() -> bool:
	var sm := _make_sm(6, 20)
	sm.scenario_6_state = ScenarioManager.ScenarioState.WON
	sm.scenario_6_state = ScenarioManager.ScenarioState.ACTIVE
	var rep := _rep_with([
		_snap("aldric_vane", 55),
		_snap("marta_coin",  48),
	])
	var resolved := false
	sm.scenario_resolved.connect(func(_sid, _state): resolved = true)
	sm.evaluate(rep, 0)
	return not resolved and sm.scenario_6_state == ScenarioManager.ScenarioState.ACTIVE


# ── SPA-862 exact reproduction ─────────────────────────────────────────────────
# Board reproduced: Scenario 1 / apprentice, fresh New Game → instant victory.
# State at the time: edric_fenn.score = 50 (starting value), win target = below 30.
# 50 is NOT below 30. evaluate() must NOT emit scenario_resolved(1, WON).

## scenario_resolved must NOT fire when edric = 50 (starting score, above 30 win target).
static func test_spa862_s1_edric_50_is_not_a_win() -> bool:
	var sm  := _make_sm(1, 35)  ## apprentice: 30 + 5 days_bonus = 35
	var rep := _rep_with([_snap("edric_fenn", 50)])
	var win_fired := false
	sm.scenario_resolved.connect(func(sid, state):
		if sid == 1 and state == ScenarioManager.ScenarioState.WON:
			win_fired = true)
	sm.evaluate(rep, 0)
	return not win_fired


## scenario_1_state must remain ACTIVE (not WON) when edric starts at 50.
## This directly asserts the state flag the HUD reads.  If this regresses, the
## main menu would display the scenario as already-won on fresh load.
static func test_spa862_s1_edric_50_state_stays_active() -> bool:
	var sm  := _make_sm(1, 35)  ## apprentice difficulty
	var rep := _rep_with([_snap("edric_fenn", 50)])
	sm.evaluate(rep, 0)
	return sm.scenario_1_state == ScenarioManager.ScenarioState.ACTIVE

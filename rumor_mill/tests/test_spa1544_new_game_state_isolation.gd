## test_spa1544_new_game_state_isolation.gd — Regression suite for SPA-1544.
##
## Locks down the three sub-bugs fixed in commit b6355d6:
##
##   1. DayNightCycle.reset_for_new_game() — stale day counter from main-menu timer.
##      DayNightCycle.tick_timer starts in _ready() and runs while the player browses
##      the main menu.  By click-time the day counter had advanced to day 6+, causing
##      the HUD to show Day 6 and every day-gated system to misfire on game start.
##      After reset: current_day=1, current_tick=0, _transition_paused=false,
##      _current_phase_name="".
##
##   2. SaveManager.clear_new_game_statics() — stale session-was-loaded flag.
##      If _session_was_loaded was left true from a previous save-load, TutorialController
##      would treat the fresh session as a restored save and skip intro tutorial steps.
##      After clear: session_was_loaded()==false, has_pending_load()==false.
##
##   3. MilestoneTracker S1 thresholds — fire at Edric's starting score (50).
##      The old score<=60 / <=55 / <=50 thresholds all evaluated true at tick 0
##      because Edric starts at exactly 50.  The fix gates the first toast on
##      score < S1_EDRIC_START_SCORE (strict less-than) and collapses the two
##      redundant mid-range toasts into a single score<=44 check.
##
## All tests run on bare in-memory instances — no live scene tree required.
## DayNightCycle tests inject a Timer and CanvasModulate so reset_for_new_game()
## can run its internal calls safely without @onready nodes.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1544NewGameStateIsolation
extends RefCounted

const DayNightCycleScript := preload("res://scripts/day_night_cycle.gd")


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Sub-bug 1: DayNightCycle stale day counter
		"test_reset_sets_day_to_one",
		"test_reset_sets_tick_to_zero",
		"test_reset_clears_transition_paused",
		"test_reset_clears_phase_name",
		# Sub-bug 2: SaveManager stale session flag
		"test_clear_statics_clears_session_was_loaded",
		"test_clear_statics_clears_pending_load",
		# Sub-bug 3: MilestoneTracker S1 thresholds at starting score
		"test_s1_no_milestone_at_start_score",
		"test_s1_first_milestone_fires_below_start_score",
		"test_s1_second_milestone_not_fired_at_45",
		"test_s1_second_milestone_fired_at_44",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1544 NewGame state isolation: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## DayNightCycle instance with injected Timer and CanvasModulate so
## reset_for_new_game() can run without the scene tree.
## _time_keys is pre-sorted so _apply_time_of_day(0, true) works correctly.
static func _make_dnc_for_reset() -> Node:
	var dnc := DayNightCycleScript.new()
	dnc.tick_timer      = Timer.new()
	dnc.canvas_modulate = CanvasModulate.new()
	dnc._time_keys      = dnc.TIME_COLORS.keys()
	dnc._time_keys.sort()
	return dnc


## Simulate stale main-menu state: timer ran for ~5 days while player browsed.
static func _prime_stale_state(dnc: Node) -> void:
	dnc.current_tick        = 120   # 5 full days × 24 ticks
	dnc.current_day         = 6
	dnc._transition_paused  = true
	dnc._current_phase_name = "Morning"


## MilestoneTracker wired for Scenario 1 with a single edric_fenn snapshot.
## _show_milestone is left invalid — we only inspect _fired after evaluate().
static func _make_mt_s1(edric_score: int) -> MilestoneTracker:
	var rep  := ReputationSystem.new()
	var snap := ReputationSystem.ReputationSnapshot.new()
	snap.npc_id     = "edric_fenn"
	snap.score      = edric_score
	snap.base_score = edric_score
	rep._cache["edric_fenn"] = snap

	var sm := ScenarioManager.new()
	sm._active_scenario = 1
	sm._days_allowed    = 30
	sm.ticks_per_day    = 24

	var mt := MilestoneTracker.new()
	mt.setup(1, rep, sm, null, Callable())
	return mt


# ── Sub-bug 1: DayNightCycle stale day counter ────────────────────────────────

## reset_for_new_game() must restore current_day to 1 regardless of stale state.
static func test_reset_sets_day_to_one() -> bool:
	var dnc := _make_dnc_for_reset()
	_prime_stale_state(dnc)
	dnc.reset_for_new_game()
	if dnc.current_day != 1:
		push_error("test_reset_sets_day_to_one: got %d, expected 1" % dnc.current_day)
		return false
	return true


## reset_for_new_game() must restore current_tick to 0.
static func test_reset_sets_tick_to_zero() -> bool:
	var dnc := _make_dnc_for_reset()
	_prime_stale_state(dnc)
	dnc.reset_for_new_game()
	if dnc.current_tick != 0:
		push_error("test_reset_sets_tick_to_zero: got %d, expected 0" % dnc.current_tick)
		return false
	return true


## reset_for_new_game() must clear _transition_paused so set_paused(false) can
## restart the timer once the mission briefing dismisses (SPA-1544 root cause).
static func test_reset_clears_transition_paused() -> bool:
	var dnc := _make_dnc_for_reset()
	_prime_stale_state(dnc)
	dnc.reset_for_new_game()
	if dnc._transition_paused:
		push_error("test_reset_clears_transition_paused: _transition_paused still true after reset")
		return false
	return true


## reset_for_new_game() must clear _current_phase_name so the phase overlay fires
## on the first real tick instead of being suppressed by the stale menu value.
static func test_reset_clears_phase_name() -> bool:
	var dnc := _make_dnc_for_reset()
	_prime_stale_state(dnc)
	dnc.reset_for_new_game()
	if dnc._current_phase_name != "":
		push_error("test_reset_clears_phase_name: got '%s', expected ''" % dnc._current_phase_name)
		return false
	return true


# ── Sub-bug 2: SaveManager stale session flag ─────────────────────────────────

## clear_new_game_statics() must reset session_was_loaded so TutorialController
## never treats a fresh New Game as a restored save session.
static func test_clear_statics_clears_session_was_loaded() -> bool:
	SaveManager._session_was_loaded = true
	SaveManager.clear_new_game_statics()
	if SaveManager.session_was_loaded():
		push_error("test_clear_statics_clears_session_was_loaded: flag still true after clear")
		return false
	return true


## clear_new_game_statics() must empty pending-load data so no stale save data
## is applied to the fresh scenario initialisation.
static func test_clear_statics_clears_pending_load() -> bool:
	SaveManager._pending_load_data = {"scenario_id": "scenario_1", "day": 6}
	SaveManager.clear_new_game_statics()
	if SaveManager.has_pending_load():
		push_error("test_clear_statics_clears_pending_load: pending data still present after clear")
		return false
	return true


# ── Sub-bug 3: MilestoneTracker S1 thresholds at starting score ───────────────
# S1_EDRIC_START_SCORE = 50.  Old thresholds: score<=60, <=55, <=50 all fired
# at tick 0.  Fixed thresholds: score < 50 (first), score <= 44 (second).

## At Edric's canonical starting score (50), evaluate() must fire NO milestones.
## score < 50 is false, score <= 44 is false — _fired dict stays empty.
static func test_s1_no_milestone_at_start_score() -> bool:
	var mt := _make_mt_s1(ScenarioConfig.S1_EDRIC_START_SCORE)  # 50
	mt.evaluate(0)
	if not mt._fired.is_empty():
		push_error("test_s1_no_milestone_at_start_score: fired %s at score 50" % str(mt._fired.keys()))
		return false
	return true


## At score 49 (one below starting), the first-progress toast (s1_rep_60) must fire.
## score < 50 → true.
static func test_s1_first_milestone_fires_below_start_score() -> bool:
	var mt := _make_mt_s1(49)
	mt.evaluate(0)
	if not mt._fired.has("s1_rep_60"):
		push_error("test_s1_first_milestone_fires_below_start_score: s1_rep_60 missing at score 49")
		return false
	return true


## At score 45, only s1_rep_60 fires; s1_rep_55 requires score <= 44.
static func test_s1_second_milestone_not_fired_at_45() -> bool:
	var mt := _make_mt_s1(45)
	mt.evaluate(0)
	if mt._fired.has("s1_rep_55"):
		push_error("test_s1_second_milestone_not_fired_at_45: s1_rep_55 fired at score 45 (threshold <=44)")
		return false
	return true


## At score 44, both s1_rep_60 and s1_rep_55 must fire (score < 50 AND score <= 44).
static func test_s1_second_milestone_fired_at_44() -> bool:
	var mt := _make_mt_s1(44)
	mt.evaluate(0)
	if not mt._fired.has("s1_rep_60"):
		push_error("test_s1_second_milestone_fired_at_44: s1_rep_60 missing at score 44")
		return false
	if not mt._fired.has("s1_rep_55"):
		push_error("test_s1_second_milestone_fired_at_44: s1_rep_55 missing at score 44")
		return false
	return true

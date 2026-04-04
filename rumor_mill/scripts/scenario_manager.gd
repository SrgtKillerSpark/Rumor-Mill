## scenario_manager.gd — Win/fail condition evaluator for Scenarios 1 and 3.
##
## Plain class (no Node); owned by World.
## Reads the cached ReputationSystem snapshots each tick and emits
## scenario_resolved when a win or fail condition is first met.
##
## Scenario 1 — The Alderman's Ruin:
##   WIN:  reputation(edric_fenn) < 30
##
## Scenario 3 — The Succession:
##   WIN:  reputation(calder_fenn) >= 80  AND  reputation(tomas_reeve) <= 30
##   FAIL: reputation(calder_fenn) < 40

class_name ScenarioManager

# ---------------------------------------------------------------------------
# Narrative text (loaded from scenarios.json via load_scenario_data).
# ---------------------------------------------------------------------------

var _scenario_title:   String = ""
var _starting_text:    String = ""
var _victory_text:     String = ""
var _fail_texts:       Dictionary = {}
var _days_allowed:     int = 30
var _active_scenario:  int = 0  # 1, 2, or 3 — set by load_scenario_data


## Load narrative fields from a scenario data dictionary (one entry from scenarios.json).
func load_scenario_data(data: Dictionary) -> void:
	_scenario_title = data.get("title", "")
	_starting_text  = data.get("startingText", "")
	_victory_text   = data.get("victoryText", "")
	_fail_texts     = data.get("failTexts", {})
	_days_allowed   = int(data.get("daysAllowed", 30))
	var sid: String = data.get("scenarioId", "")
	var parts := sid.split("_")
	_active_scenario = int(parts[-1]) if parts.size() >= 2 else 0


## Returns the scenario title string.
func get_title() -> String:
	return _scenario_title


## Returns the premise / starting text shown at scenario start.
func get_starting_text() -> String:
	return _starting_text


## Returns the victory text shown when the player wins.
func get_victory_text() -> String:
	return _victory_text


## Returns a fail text by reason key (e.g. "exposed", "timeout", "calder_implicated").
## Returns an empty string if the key is not found.
func get_fail_text(reason: String) -> String:
	return _fail_texts.get(reason, "")


## Returns the number of days the player has to complete this scenario.
func get_days_allowed() -> int:
	return _days_allowed


# NPC IDs used for win/fail checks.
const EDRIC_FENN_ID    := "edric_fenn"
const ALYS_HERBWIFE_ID := "alys_herbwife"
const MAREN_NUN_ID     := "maren_nun"
const CALDER_FENN_ID   := "calder_fenn"
const TOMAS_REEVE_ID   := "tomas_reeve"

# Scenario 1 threshold.
# SPA-98: raised from 25 — Edric's credulity=0.05 and loyalty=0.80 override make
# the original 26-point drop punishing for a tutorial scenario.
const S1_WIN_EDRIC_BELOW   := 30

# Scenario 2 thresholds.
# Win when 7+ NPCs are in BELIEVE/SPREAD/ACT state for illness rumors about Alys.
# SPA-98: raised from 5 — 5 believers was trivially reachable in 3-4 days with ILL-01
# (intensity=5). The real tension is avoiding Maren's contradiction, not the count.
const S2_WIN_ILLNESS_MIN   := 7
# Ticks per in-game day (matches DayNightCycle default).
const TICKS_PER_DAY        := 24

# Scenario 3 thresholds.
# SPA-98: eased from (Calder>=80, Tomas<=30) to (Calder>=75, Tomas<=35).
# PRAISE claims have low intensity (1-2), so reaching +22 on Calder in 25 days
# with 2 whispers/day was extremely difficult. Required gains now: +17 / -17.
const S3_WIN_CALDER_MIN    := 75
const S3_WIN_TOMAS_MAX     := 35
const S3_FAIL_CALDER_BELOW := 40

enum ScenarioState { ACTIVE, WON, FAILED }

## Emitted the first time a scenario resolves.
## scenario_id: 1, 2, or 3.  state: WON or FAILED.
signal scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState)

var scenario_1_state: ScenarioState = ScenarioState.ACTIVE
var scenario_2_state: ScenarioState = ScenarioState.ACTIVE
var scenario_3_state: ScenarioState = ScenarioState.ACTIVE

## Scenario 3 only: Calder's reputation score at the first evaluate() call.
## -1 means not yet recorded. Used by end_screen for the Calder Rep Delta stat.
var calder_score_start: int = -1
## Calder's score at the moment the scenario resolved (set in _check_scenario_3).
var calder_score_final: int = -1


## Evaluate win/fail conditions for the active scenario only.
## Call once per tick, after reputation_system.recalculate_all().
func evaluate(rep: ReputationSystem, current_tick: int) -> void:
	match _active_scenario:
		1: _check_scenario_1(rep, current_tick)
		2: _check_scenario_2(rep, current_tick)
		3: _check_scenario_3(rep, current_tick)


## Called when the player is caught eavesdropping. Fails Scenario 1 if still active.
func on_player_exposed() -> void:
	if _active_scenario != 1:
		return
	if scenario_1_state != ScenarioState.ACTIVE:
		return
	scenario_1_state = ScenarioState.FAILED
	scenario_resolved.emit(1, ScenarioState.FAILED)
	print("[ScenarioManager] Scenario 1 FAIL — player exposed during eavesdrop")


func _check_scenario_1(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_1_state != ScenarioState.ACTIVE:
		return
	var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
	if snap == null:
		return
	if snap.score < S1_WIN_EDRIC_BELOW:
		scenario_1_state = ScenarioState.WON
		scenario_resolved.emit(1, ScenarioState.WON)
		print("[ScenarioManager] Scenario 1 WIN — Edric Fenn reputation %d < %d" % [
			snap.score, S1_WIN_EDRIC_BELOW])
		return
	# Timeout fail: days elapsed exceeds the scenario timer.
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day > _days_allowed:
		scenario_1_state = ScenarioState.FAILED
		scenario_resolved.emit(1, ScenarioState.FAILED)
		print("[ScenarioManager] Scenario 1 FAIL — timeout, day %d > allowed %d" % [
			current_day, _days_allowed])


func _check_scenario_2(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_2_state != ScenarioState.ACTIVE:
		return
	var illness_count: int = rep.get_illness_believer_count(ALYS_HERBWIFE_ID)
	if illness_count >= S2_WIN_ILLNESS_MIN:
		scenario_2_state = ScenarioState.WON
		scenario_resolved.emit(2, ScenarioState.WON)
		print("[ScenarioManager] Scenario 2 WIN — %d NPCs believe illness about Alys Herbwife (>= %d)" % [
			illness_count, S2_WIN_ILLNESS_MIN])
		return
	# Contradicted fail: Sister Maren rejects illness rumors about Alys Herbwife.
	if rep.has_illness_rejecter(ALYS_HERBWIFE_ID, MAREN_NUN_ID):
		scenario_2_state = ScenarioState.FAILED
		scenario_resolved.emit(2, ScenarioState.FAILED)
		print("[ScenarioManager] Scenario 2 FAIL — Sister Maren rejected illness rumors about Alys Herbwife")
		return
	# Timeout fail: days elapsed exceeds the scenario timer.
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day > _days_allowed:
		scenario_2_state = ScenarioState.FAILED
		scenario_resolved.emit(2, ScenarioState.FAILED)
		print("[ScenarioManager] Scenario 2 FAIL — timeout, day %d > allowed %d" % [
			current_day, _days_allowed])


func _check_scenario_3(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_3_state != ScenarioState.ACTIVE:
		return
	var calder: ReputationSystem.ReputationSnapshot = rep.get_snapshot(CALDER_FENN_ID)
	var tomas:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
	if calder == null or tomas == null:
		return

	# Record Calder's starting score on the first evaluate() call.
	if calder_score_start == -1:
		calder_score_start = calder.score

	# Track Calder's latest score for end-screen delta display.
	calder_score_final = calder.score

	if calder.score >= S3_WIN_CALDER_MIN and tomas.score <= S3_WIN_TOMAS_MAX:
		scenario_3_state = ScenarioState.WON
		scenario_resolved.emit(3, ScenarioState.WON)
		print("[ScenarioManager] Scenario 3 WIN — Calder %d >= %d, Tomas %d <= %d" % [
			calder.score, S3_WIN_CALDER_MIN, tomas.score, S3_WIN_TOMAS_MAX])
		return

	if calder.score < S3_FAIL_CALDER_BELOW:
		scenario_3_state = ScenarioState.FAILED
		scenario_resolved.emit(3, ScenarioState.FAILED)
		print("[ScenarioManager] Scenario 3 FAIL — Calder %d < %d" % [
			calder.score, S3_FAIL_CALDER_BELOW])
		return

	# Timeout fail: days elapsed exceeds the scenario timer.
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day > _days_allowed:
		scenario_3_state = ScenarioState.FAILED
		scenario_resolved.emit(3, ScenarioState.FAILED)
		print("[ScenarioManager] Scenario 3 FAIL — timeout, day %d > allowed %d" % [
			current_day, _days_allowed])


# ---------------------------------------------------------------------------
# Progress queries (for HUD / Journal)
# ---------------------------------------------------------------------------

## Returns the current Scenario 2 progress dict.
func get_scenario_2_progress(rep: ReputationSystem) -> Dictionary:
	return {
		"illness_believer_count": rep.get_illness_believer_count(ALYS_HERBWIFE_ID),
		"win_threshold":          S2_WIN_ILLNESS_MIN,
		"state":                  scenario_2_state,
	}


## Returns the current Scenario 1 progress dict.
func get_scenario_1_progress(rep: ReputationSystem) -> Dictionary:
	var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
	return {
		"edric_score":   snap.score if snap != null else 50,
		"win_threshold": S1_WIN_EDRIC_BELOW,
		"state":         scenario_1_state,
	}


## Returns the current Scenario 3 progress dict.
func get_scenario_3_progress(rep: ReputationSystem) -> Dictionary:
	var calder: ReputationSystem.ReputationSnapshot = rep.get_snapshot(CALDER_FENN_ID)
	var tomas:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
	return {
		"calder_score":       calder.score if calder != null else 50,
		"tomas_score":        tomas.score  if tomas  != null else 50,
		"calder_win_target":  S3_WIN_CALDER_MIN,
		"tomas_win_target":   S3_WIN_TOMAS_MAX,
		"calder_fail_below":  S3_FAIL_CALDER_BELOW,
		"state":              scenario_3_state,
	}

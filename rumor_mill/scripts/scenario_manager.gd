## scenario_manager.gd — Win/fail condition evaluator for Scenarios 1 and 3.
##
## Plain class (no Node); owned by World.
## Reads the cached ReputationSystem snapshots each tick and emits
## scenario_resolved when a win or fail condition is first met.
##
## Scenario 1 — The Alderman's Ruin:
##   WIN:  reputation(edric_fenn) < 25
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


## Load narrative fields from a scenario data dictionary (one entry from scenarios.json).
func load_scenario_data(data: Dictionary) -> void:
	_scenario_title = data.get("title", "")
	_starting_text  = data.get("startingText", "")
	_victory_text   = data.get("victoryText", "")
	_fail_texts     = data.get("failTexts", {})
	_days_allowed   = int(data.get("daysAllowed", 30))


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
const EDRIC_FENN_ID  := "edric_fenn"
const CALDER_FENN_ID := "calder_fenn"
const TOMAS_REEVE_ID := "tomas_reeve"

# Scenario 1 threshold.
const S1_WIN_EDRIC_BELOW  := 25

# Scenario 3 thresholds.
const S3_WIN_CALDER_MIN   := 80
const S3_WIN_TOMAS_MAX    := 30
const S3_FAIL_CALDER_BELOW := 40

enum ScenarioState { ACTIVE, WON, FAILED }

## Emitted the first time a scenario resolves.
## scenario_id: 1 or 3.  state: WON or FAILED.
signal scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState)

var scenario_1_state: ScenarioState = ScenarioState.ACTIVE
var scenario_3_state: ScenarioState = ScenarioState.ACTIVE


## Evaluate all win/fail conditions from the current reputation cache.
## Call once per tick, after reputation_system.recalculate_all().
func evaluate(rep: ReputationSystem, _current_tick: int) -> void:
	_check_scenario_1(rep)
	_check_scenario_3(rep)


func _check_scenario_1(rep: ReputationSystem) -> void:
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


func _check_scenario_3(rep: ReputationSystem) -> void:
	if scenario_3_state != ScenarioState.ACTIVE:
		return
	var calder: ReputationSystem.ReputationSnapshot = rep.get_snapshot(CALDER_FENN_ID)
	var tomas:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
	if calder == null or tomas == null:
		return

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


# ---------------------------------------------------------------------------
# Progress queries (for HUD / Journal)
# ---------------------------------------------------------------------------

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

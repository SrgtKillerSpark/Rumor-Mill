## scenario_manager.gd — Win/fail condition evaluator for Scenarios 1–4.
##
## Plain class (no Node); owned by World.
## Reads the cached ReputationSystem snapshots each tick and emits
## scenario_resolved when a win or fail condition is first met.
##
## Scenario 1 — The Alderman's Ruin:
##   WIN:  reputation(edric_fenn) < 30
##   FAIL: any NPC heat >= 80 (exposed / SPA-502)
##         OR caught eavesdropping (instant exposed)
##         OR days elapsed >= days_allowed (timeout)
##
## Scenario 2 — The Plague Scare:
##   WIN:  7+ NPCs in BELIEVE/SPREAD/ACT for illness rumors about alys_herbwife
##   FAIL: maren_nun rejects illness rumors about alys_herbwife (contradicted)
##         OR days elapsed >= days_allowed (timeout)
##
## Scenario 3 — The Succession:
##   WIN:  reputation(calder_fenn) >= 75  AND  reputation(tomas_reeve) <= 35
##   FAIL: reputation(calder_fenn) < 35
##         OR days elapsed >= days_allowed (timeout)
##
## Scenario 4 — The Holy Inquisition:
##   WIN:  All 3 protected NPCs above reputation 45 when days elapsed >= days_allowed
##   FAIL: Any protected NPC drops below reputation 40 (instant)
##         OR days elapsed >= days_allowed with any NPC below 45

class_name ScenarioManager

# ---------------------------------------------------------------------------
# Narrative text (loaded from scenarios.json via load_scenario_data).
# ---------------------------------------------------------------------------

var _scenario_title:   String = ""
var _starting_text:    String = ""
var _victory_text:     String = ""
var _fail_texts:       Dictionary = {}
var _days_allowed:     int = 30
var _active_scenario:  int = 0  # 1, 2, 3, or 4 — set by load_scenario_data
var _objective_card:   Dictionary = {}


## Load narrative fields from a scenario data dictionary (one entry from scenarios.json).
func load_scenario_data(data: Dictionary) -> void:
	_scenario_title = data.get("title", "")
	_starting_text  = data.get("startingText", "")
	_victory_text   = data.get("victoryText", "")
	_fail_texts     = data.get("failTexts", {})
	_objective_card = data.get("objectiveCard", {})
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


## Returns the objective card dictionary with keys: mission, winCondition, timeLimit, danger, strategyHint.
func get_objective_card() -> Dictionary:
	return _objective_card


## Returns a compact win-condition target line for HUD display (second line under objective).
func get_win_condition_line() -> String:
	match _active_scenario:
		1: return "Target: Edric Fenn reputation below 30"
		2: return "Target: 7+ NPCs believing illness rumors"
		3: return "Target: Calder rep ≥ 75, Tomas rep ≤ 35"
		4: return "Protect: Aldous, Vera, Finn — keep all above 45"
	return ""


## Returns a short, actionable one-line objective for HUD display.
## More compact and player-facing than the narrative startingText.
func get_objective_one_liner() -> String:
	match _active_scenario:
		1: return "Ruin Lord Edric Fenn's reputation — bring it below 30 before the tax rolls are signed."
		2: return "Spread the illness rumor to 7+ townspeople. Avoid Sister Maren rejecting it."
		3: return "Raise Calder Fenn to 75+ reputation and drag Tomas Reeve to 35 or lower."
		4: return "Keep Aldous Prior, Vera Midwife, and Finn Monk above 45 reputation for 20 days."
	return _starting_text.substr(0, mini(_starting_text.find(".") + 1, 80))


## Override the days allowed (e.g. applied by difficulty modifiers after load).
func override_days_allowed(new_days: int) -> void:
	_days_allowed = new_days


## Set the intel store reference (for heat-based exposure checks in S1).
func set_intel_store(store: PlayerIntelStore) -> void:
	_intel_store = store


## Returns the current in-game day (1-based) derived from the tick counter.
## All scenario resolution checks use this formula, so HUDs should too.
func get_current_day(current_tick: int) -> int:
	return current_tick / TICKS_PER_DAY + 1


# NPC IDs used for win/fail checks.
const EDRIC_FENN_ID    := "edric_fenn"
const ALYS_HERBWIFE_ID := "alys_herbwife"
const MAREN_NUN_ID     := "maren_nun"
const CALDER_FENN_ID   := "calder_fenn"
const TOMAS_REEVE_ID   := "tomas_reeve"

# Scenario 1 thresholds.
# SPA-98: raised from 25 — Edric's credulity=0.05 and loyalty=0.80 override make
# the original 26-point drop punishing for a tutorial scenario.
const S1_WIN_EDRIC_BELOW   := 30
const S1_EDRIC_START_SCORE := 50  ## Edric's default base reputation at scenario start.
# SPA-502: cumulative exposure threshold — when any NPC's heat reaches this value,
# the Guard Captain connects the dots and the player is exposed.
const S1_EXPOSED_HEAT      := 80.0

# Scenario 2 thresholds.
# Win when 7+ NPCs are in BELIEVE/SPREAD/ACT state for illness rumors about Alys.
# SPA-98: raised from 5; SPA-530: raised from 6 — 6 believers was too easily reachable
# in the first 3–4 days given the high-credulity merchant chain. 7 requires deliberate
# routing through 2+ independent clusters and keeps tension alive into mid-game.
const S2_WIN_ILLNESS_MIN   := 7
# Ticks per in-game day (matches DayNightCycle default).
const TICKS_PER_DAY        := 24

# Scenario 3 thresholds.
# SPA-98: eased from (Calder>=80, Tomas<=30) to (Calder>=75, Tomas<=35).
# SPA-530: Calder starting rep raised to 65 (was 58), days_allowed raised to 27 (was 25).
# SPA-550: Calder fail floor lowered 40→35 — the rival's scandal attacks on Calder felt
# like random frustration near 40; wider buffer rewards strategy over luck.
# Tomas start lowered 52→48 in scenarios.json; rival daily phase pushed from day 16→18.
# Required gains now: +10 (Calder) / -13 (Tomas) with the rival seeding every day from day 18.
const S3_WIN_CALDER_MIN    := 75
const S3_WIN_TOMAS_MAX     := 35
const S3_FAIL_CALDER_BELOW := 35

# Scenario 4 thresholds & NPC ids.
# Protected NPCs must be >= S4_WIN_REP_MIN at deadline to win.
# SPA-550: separated fail from win threshold (was both 45). Fail at 40 = instant loss,
# but NPCs between 40-44 are in a "danger zone" — not yet fatal, but will lose at
# deadline unless recovered to 45+. This allows comeback plays instead of instant death
# and makes the defensive challenge about sustained play, not knife-edge precision.
# Starting reps raised in scenarios.json (Aldous 65→70, Vera 65→68, Finn 70→72).
# Inquisitor daily phase pushed from day 13→15; late intensity reduced 4→3.
const S4_PROTECTED_NPC_IDS: Array[String] = ["aldous_prior", "vera_midwife", "finn_monk"]
const S4_WIN_REP_MIN       := 45
const S4_FAIL_REP_BELOW    := 40

enum ScenarioState { ACTIVE, WON, FAILED }

## Emitted the first time a scenario resolves.
## scenario_id: 1, 2, 3, or 4.  state: WON or FAILED.
signal scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState)

## Emitted once when the scenario crosses a deadline threshold (0.75 or 0.90).
## threshold: 0.75 or 0.90.  days_remaining: int.
signal deadline_warning(threshold: float, days_remaining: int)

## Optional reference to the player intel store (for heat-based fail checks).
var _intel_store: PlayerIntelStore = null

var scenario_1_state: ScenarioState = ScenarioState.ACTIVE
var scenario_2_state: ScenarioState = ScenarioState.ACTIVE
var scenario_3_state: ScenarioState = ScenarioState.ACTIVE
var scenario_4_state: ScenarioState = ScenarioState.ACTIVE

## Tracks which deadline thresholds have already fired (0.75, 0.90).
var _deadline_warnings_fired: Dictionary = {}

## Number of times this scenario has been retried by the player.
## Set by main.gd at game-start from PlayerStats (SPA-335).
var retry_count: int = 0

## Scenario 3 only: Calder's reputation score at the first evaluate() call.
## -1 means not yet recorded. Used by end_screen for the Calder Rep Delta stat.
var calder_score_start: int = -1
## Calder's score at the moment the scenario resolved (set in _check_scenario_3).
var calder_score_final: int = -1


## Evaluate win/fail conditions for the active scenario only.
## Call once per tick, after reputation_system.recalculate_all().
func evaluate(rep: ReputationSystem, current_tick: int) -> void:
	_check_deadline_warnings(current_tick)
	match _active_scenario:
		1: _check_scenario_1(rep, current_tick)
		2: _check_scenario_2(rep, current_tick)
		3: _check_scenario_3(rep, current_tick)
		4: _check_scenario_4(rep, current_tick)


## Returns the fraction of time elapsed (0.0–1.0) for the current scenario.
func get_time_fraction(current_tick: int) -> float:
	if _days_allowed <= 1:
		return 1.0
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	return clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)


## Returns true when the scenario is in the final 25% of its allowed time.
func is_final_quarter(current_tick: int) -> bool:
	return get_time_fraction(current_tick) >= 0.75


## Check and emit deadline warning signals at 75% and 90% thresholds.
func _check_deadline_warnings(current_tick: int) -> void:
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	var fraction := get_time_fraction(current_tick)
	var days_remaining: int = maxi(_days_allowed - current_day, 0)
	for threshold_pct: int in [75, 90]:
		var threshold := threshold_pct / 100.0
		if fraction >= threshold and not _deadline_warnings_fired.has(threshold_pct):
			_deadline_warnings_fired[threshold_pct] = true
			deadline_warning.emit(threshold, days_remaining)


## Called when the player is caught eavesdropping. Fails Scenario 1 if still active.
func on_player_exposed() -> void:
	if _active_scenario != 1:
		return
	if scenario_1_state != ScenarioState.ACTIVE:
		return
	scenario_1_state = ScenarioState.FAILED
	scenario_resolved.emit(1, ScenarioState.FAILED)


func _check_scenario_1(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_1_state != ScenarioState.ACTIVE:
		return
	var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
	if snap == null:
		return
	if snap.score < S1_WIN_EDRIC_BELOW:
		scenario_1_state = ScenarioState.WON
		scenario_resolved.emit(1, ScenarioState.WON)
		return
	# Exposed fail: any NPC's suspicion of the player exceeds threshold (SPA-502).
	if _intel_store != null:
		for npc_id in _intel_store.heat:
			if _intel_store.heat[npc_id] >= S1_EXPOSED_HEAT:
				scenario_1_state = ScenarioState.FAILED
				scenario_resolved.emit(1, ScenarioState.FAILED)
				return
	# Timeout fail: day limit reached (>= aligns with get_time_fraction hitting 1.0).
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day >= _days_allowed:
		scenario_1_state = ScenarioState.FAILED
		scenario_resolved.emit(1, ScenarioState.FAILED)


func _check_scenario_2(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_2_state != ScenarioState.ACTIVE:
		return
	var illness_count: int = rep.get_illness_believer_count(ALYS_HERBWIFE_ID)
	if illness_count >= S2_WIN_ILLNESS_MIN:
		scenario_2_state = ScenarioState.WON
		scenario_resolved.emit(2, ScenarioState.WON)
		return
	# Contradicted fail: Sister Maren rejects illness rumors about Alys Herbwife.
	if rep.has_illness_rejecter(ALYS_HERBWIFE_ID, MAREN_NUN_ID):
		scenario_2_state = ScenarioState.FAILED
		scenario_resolved.emit(2, ScenarioState.FAILED)
		return
	# Timeout fail: day limit reached (>= aligns with get_time_fraction hitting 1.0).
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day >= _days_allowed:
		scenario_2_state = ScenarioState.FAILED
		scenario_resolved.emit(2, ScenarioState.FAILED)


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
		return

	if calder.score < S3_FAIL_CALDER_BELOW:
		scenario_3_state = ScenarioState.FAILED
		scenario_resolved.emit(3, ScenarioState.FAILED)
		return

	# Timeout fail: day limit reached (>= aligns with get_time_fraction hitting 1.0).
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day >= _days_allowed:
		scenario_3_state = ScenarioState.FAILED
		scenario_resolved.emit(3, ScenarioState.FAILED)


# ---------------------------------------------------------------------------
# Progress queries (for HUD / Journal)
# ---------------------------------------------------------------------------

## Returns the current Scenario 2 progress dict.
func get_scenario_2_progress(rep: ReputationSystem) -> Dictionary:
	return {
		"illness_believer_count": rep.get_illness_believer_count(ALYS_HERBWIFE_ID),
		"illness_believer_ids":   rep.get_illness_believer_ids(ALYS_HERBWIFE_ID),
		"illness_rejecter_ids":   rep.get_illness_rejecter_ids(ALYS_HERBWIFE_ID),
		"win_threshold":          S2_WIN_ILLNESS_MIN,
		"state":                  scenario_2_state,
	}


## Returns the current Scenario 1 progress dict.
func get_scenario_1_progress(rep: ReputationSystem) -> Dictionary:
	var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
	return {
		"edric_score":   snap.score if snap != null else S1_EDRIC_START_SCORE,
		"start_score":   S1_EDRIC_START_SCORE,
		"win_threshold": S1_WIN_EDRIC_BELOW,
		"state":         scenario_1_state,
	}


func _check_scenario_4(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_4_state != ScenarioState.ACTIVE:
		return
	# Fail: any protected NPC drops below 40 (instant fail).
	for npc_id in S4_PROTECTED_NPC_IDS:
		var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
		if snap == null:
			continue
		if snap.score < S4_FAIL_REP_BELOW:
			scenario_4_state = ScenarioState.FAILED
			scenario_resolved.emit(4, ScenarioState.FAILED)
			return
	# Deadline reached: resolve win or fail (>= aligns with get_time_fraction hitting 1.0).
	var current_day: int = current_tick / TICKS_PER_DAY + 1
	if current_day >= _days_allowed:
		var all_above: bool = true
		for npc_id in S4_PROTECTED_NPC_IDS:
			var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
			if snap == null or snap.score < S4_WIN_REP_MIN:
				all_above = false
				break
		if all_above:
			scenario_4_state = ScenarioState.WON
			scenario_resolved.emit(4, ScenarioState.WON)
		else:
			scenario_4_state = ScenarioState.FAILED
			scenario_resolved.emit(4, ScenarioState.FAILED)


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


## Returns the current Scenario 4 progress dict.
func get_scenario_4_progress(rep: ReputationSystem) -> Dictionary:
	var scores: Dictionary = {}
	var min_score: int = 100
	for npc_id in S4_PROTECTED_NPC_IDS:
		var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
		var score: int = snap.score if snap != null else 50
		scores[npc_id] = score
		if score < min_score:
			min_score = score
	return {
		"protected_scores":  scores,
		"win_threshold":     S4_WIN_REP_MIN,
		"fail_threshold":    S4_FAIL_REP_BELOW,
		"min_score":         min_score,
		"state":             scenario_4_state,
	}

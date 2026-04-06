## scenario_manager.gd — Win/fail condition evaluator for Scenarios 1–6.
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
##   WIN:  All 3 protected NPCs above reputation 48 when days elapsed >= days_allowed
##   FAIL: Any protected NPC drops below reputation 42 (instant)
##         OR days elapsed >= days_allowed with any NPC below 48
##
## Scenario 5 — The Election (SPA-605):
##   WIN:  reputation(aldric_vane) >= 65 AND highest among 3 candidates
##         AND reputation(edric_fenn) < 45 AND reputation(tomas_reeve) < 45
##   FAIL: reputation(aldric_vane) < 30 (instant)
##         OR days elapsed >= days_allowed (timeout)
##   EVENT: Day 15 — Prior Aldous endorses highest-rep candidate (+8 bonus)
##
## Scenario 6 — The Merchant's Debt (SPA-605):
##   WIN:  reputation(aldric_vane) <= 30 AND reputation(marta_coin) >= 62
##   FAIL: reputation(marta_coin) < 30 (instant)
##         OR any NPC heat >= 55 (lower threshold — guards on payroll)
##         OR days elapsed >= days_allowed (timeout)

class_name ScenarioManager

# ---------------------------------------------------------------------------
# Narrative text (loaded from scenarios.json via load_scenario_data).
# ---------------------------------------------------------------------------

var _scenario_title:   String = ""
var _intro_text:       String = ""
var _starting_text:    String = ""
var _victory_text:     String = ""
var _fail_texts:       Dictionary = {}
var _days_allowed:     int = 30
var _active_scenario:       int        = 0  # 1–6 — set by load_scenario_data
var _objective_card:        Dictionary = {}
var _milestone_toasts:      Array      = []
var _strategic_brief:       Dictionary = {}
var _suggestion_overrides:  Dictionary = {}  # SPA-743: per-scenario hint tuning


## Load narrative fields from a scenario data dictionary (one entry from scenarios.json).
func load_scenario_data(data: Dictionary) -> void:
	_scenario_title   = data.get("title", "")
	_intro_text       = data.get("introText", "")
	_starting_text    = data.get("startingText", "")
	_victory_text     = data.get("victoryText", "")
	_fail_texts       = data.get("failTexts", {})
	_objective_card   = data.get("objectiveCard", {})
	_days_allowed     = int(data.get("daysAllowed", 30))
	_milestone_toasts      = data.get("milestoneToasts",     [])
	_strategic_brief       = data.get("strategicBrief",      {})
	_suggestion_overrides  = data.get("suggestion_overrides", {})
	var sid: String   = data.get("scenarioId", "")
	var parts := sid.split("_")
	_active_scenario = int(parts[-1]) if parts.size() >= 2 else 0


## Returns the scenario title string.
func get_title() -> String:
	return _scenario_title


## Returns the narrative intro text (2-3 sentence hook from introText in scenarios.json).
func get_intro_text() -> String:
	return _intro_text


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


## Returns per-scenario tuning overrides for the Tier 3 suggestion engine.
## Keys: "heat_spike_threshold" (float), "category_priorities" (Array[String]).
func get_suggestion_overrides() -> Dictionary:
	return _suggestion_overrides


## Returns the NPC heat level that triggers an exposure fail for the active scenario.
## Returns -1.0 for scenarios where heat does not cause a direct failure (S2, S3, S4, S5).
func get_heat_ceiling() -> float:
	match _active_scenario:
		1: return S1_EXPOSED_HEAT
		6: return S6_EXPOSED_HEAT
		_: return -1.0


## Returns the objective card dictionary with keys: mission, winCondition, timeLimit, danger, strategyHint.
func get_objective_card() -> Dictionary:
	return _objective_card


## Returns the milestone toast config array loaded from scenarios.json.
## Each entry is a Dictionary with keys "threshold" (float 0–1) and "message" (String).
func get_milestone_toasts() -> Array:
	return _milestone_toasts


## Returns the strategic brief dictionary for the active scenario.
## Keys: targetNpcId, repStart, goalLabel, primaryConstraint, strategicHint.
## Used by StrategicOverview to display the pre-game intelligence summary.
func get_strategic_brief() -> Dictionary:
	return _strategic_brief


## Returns normalized 0.0–1.0 progress toward the active scenario's win condition.
## Used by MilestoneTracker to fire progress toasts at configurable thresholds.
func get_win_progress(rep: ReputationSystem, current_tick: int) -> float:
	match _active_scenario:
		1:
			var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
			if snap == null:
				return 0.0
			# Edric starts at 50, must drop below 30.  Progress = drop / range.
			var range_pts: float = float(S1_EDRIC_START_SCORE - S1_WIN_EDRIC_BELOW)
			return clampf(float(S1_EDRIC_START_SCORE - snap.score) / range_pts, 0.0, 1.0)
		2:
			var count: float = float(rep.get_illness_believer_count(ALYS_HERBWIFE_ID))
			return clampf(count / float(s2_win_illness_min), 0.0, 1.0)
		3:
			var calder: ReputationSystem.ReputationSnapshot = rep.get_snapshot(CALDER_FENN_ID)
			var tomas:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
			if calder == null or tomas == null:
				return 0.0
			# Calder needs to reach 75 (assume start ≈ 50); Tomas needs to drop to 35 (assume start ≈ 50).
			# calder_score_start is -1 until the first evaluate() call; return 0 until it is initialised.
			if calder_score_start == -1:
				return 0.0
			var calder_start: float = float(calder_score_start)
			var prog_calder: float = clampf(
				(calder.score - calder_start) / (S3_WIN_CALDER_MIN - calder_start), 0.0, 1.0)
			var prog_tomas: float = clampf(
				(50.0 - tomas.score) / (50.0 - S3_WIN_TOMAS_MAX), 0.0, 1.0)
			return minf(prog_calder, prog_tomas)
		4:
			# Defensive scenario: progress is surviving through time while keeping charges safe.
			return get_time_fraction(current_tick)
		5:
			# Three-way election: Aldric must reach 65+, rivals must drop below 45.
			var aldric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(ALDRIC_VANE_ID)
			if aldric == null:
				return 0.0
			var edric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
			var tomas: ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
			if edric == null or tomas == null:
				return 0.0
			# Aldric starts ~45, must reach 65.  Rivals start ~58/45, must drop below 45.
			var prog_aldric: float = clampf(
				(aldric.score - 45.0) / (S5_WIN_ALDRIC_MIN - 45.0), 0.0, 1.0)
			var prog_edric: float = clampf(
				(58.0 - edric.score) / (58.0 - S5_WIN_RIVALS_MAX), 0.0, 1.0)
			var prog_tomas: float = clampf(
				(45.0 - tomas.score) / maxf(45.0 - S5_WIN_RIVALS_MAX, 1.0), 0.0, 1.0)
			return minf(prog_aldric, minf(prog_edric, prog_tomas))
		6:
			# Stealth exposure: Aldric must drop to 30, Marta must stay at 60+.
			var s6_aldric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(ALDRIC_VANE_ID)
			var s6_marta:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(MARTA_COIN_ID)
			if s6_aldric == null or s6_marta == null:
				return 0.0
			# Aldric starts at 55, must drop to 30.  Marta starts at 48, must reach 62.
			var prog_aldric_down: float = clampf(
				(55.0 - s6_aldric.score) / (55.0 - S6_WIN_ALDRIC_MAX), 0.0, 1.0)
			var prog_marta_up: float = clampf(
				(s6_marta.score - 48.0) / maxf(S6_WIN_MARTA_MIN - 48.0, 1.0), 0.0, 1.0)
			return minf(prog_aldric_down, prog_marta_up)
	return 0.0


## Returns a compact win-condition target line for HUD display (second line under objective).
func get_win_condition_line() -> String:
	match _active_scenario:
		1: return "Target: Edric Fenn reputation below 30"
		2: return "Target: 7+ NPCs believing illness rumors"
		3: return "Target: Calder rep ≥ 75, Tomas rep ≤ 35"
		4: return "Protect: Aldous, Vera, Finn — keep all above 48"
		5: return "Elect Aldric Vane: rep ≥ 65 & highest, rivals < 45"
		6: return "Expose Aldric (rep ≤ 30), protect Marta (rep ≥ 62)"
	return ""


## Returns a short, actionable one-line objective for HUD display.
## More compact and player-facing than the narrative startingText.
func get_objective_one_liner() -> String:
	match _active_scenario:
		1: return "Ruin Edric Fenn — make the town turn on him"
		2: return "Spread the plague lie — 7 believers needed"
		3: return "Crown Calder, ruin Tomas — before the rival beats you"
		4: return "Defend three innocents from the Inquisitor"
		5: return "Get Aldric Vane elected — boost him to 65+ and undermine both rivals below 45."
		6: return "Expose Aldric Vane's embezzlement (rep ≤ 30) while protecting Marta Coin (rep ≥ 62)."
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
	return current_tick / ticks_per_day + 1


# NPC IDs used for win/fail checks.
const EDRIC_FENN_ID    := "edric_fenn"
const ALYS_HERBWIFE_ID := "alys_herbwife"
const MAREN_NUN_ID     := "maren_nun"
const CALDER_FENN_ID   := "calder_fenn"
const TOMAS_REEVE_ID   := "tomas_reeve"
const ALDRIC_VANE_ID   := "aldric_vane"
const MARTA_COIN_ID    := "marta_coin"
const ALDOUS_PRIOR_ID  := "aldous_prior"

# Scenario 1 thresholds.
# SPA-98: raised from 25 — Edric's credulity=0.05 and loyalty=0.80 override make
# the original 26-point drop punishing for a tutorial scenario.
var S1_WIN_EDRIC_BELOW   := 30
var S1_EDRIC_START_SCORE := 50  ## Edric's default base reputation at scenario start.
# SPA-502: cumulative exposure threshold — when any NPC's heat reaches this value,
# the Guard Captain connects the dots and the player is exposed.
var S1_EXPOSED_HEAT      := 80.0

# Scenario 2 thresholds.
# Win when 7+ NPCs are in BELIEVE/SPREAD/ACT state for illness rumors about Alys.
# SPA-98: raised from 5; SPA-530: raised from 6 — 6 believers was too easily reachable
# in the first 3–4 days given the high-credulity merchant chain. 7 requires deliberate
# routing through 2+ independent clusters and keeps tension alive into mid-game.
const S2_WIN_ILLNESS_MIN_DEFAULT := 7
var s2_win_illness_min: int = S2_WIN_ILLNESS_MIN_DEFAULT
# SPA-592: days of grace after Maren first rejects before triggering the instant fail.
# Prevents silent propagation chains from ending the scenario without player agency.
const S2_MAREN_GRACE_DAYS  := 2
# Ticks per in-game day (matches DayNightCycle default; overridden by world.gd on scenario load).
var ticks_per_day: int = 24

# Scenario 3 thresholds.
# SPA-98: eased from (Calder>=80, Tomas<=30) to (Calder>=75, Tomas<=35).
# SPA-530: Calder starting rep raised to 65 (was 58), days_allowed raised to 27 (was 25).
# SPA-550: Calder fail floor lowered 40→35 — the rival's scandal attacks on Calder felt
# like random frustration near 40; wider buffer rewards strategy over luck.
# Tomas start lowered 52→48 in scenarios.json; rival daily phase pushed from day 16→18.
# Required gains now: +10 (Calder) / -13 (Tomas) with the rival seeding every day from day 18.
var S3_WIN_CALDER_MIN    := 75
var S3_WIN_TOMAS_MAX     := 35
var S3_FAIL_CALDER_BELOW := 35

# Scenario 4 thresholds & NPC ids.
# Protected NPCs must be >= S4_WIN_REP_MIN at deadline to win.
# SPA-550: separated fail from win threshold (was both 45). Fail at 40 = instant loss,
# but NPCs between 40-44 are in a "danger zone" — not yet fatal, but will lose at
# deadline unless recovered to 45+. This allows comeback plays instead of instant death
# and makes the defensive challenge about sustained play, not knife-edge precision.
# Starting reps raised in scenarios.json (Aldous 65→70, Vera 65→68, Finn 70→72).
# Inquisitor daily phase pushed from day 13→15; late intensity reduced 4→3.
# SPA-747: win 45→48, fail 40→42 — new HUD systems give near-perfect info, shrinking
# the danger zone to restore defensive pressure.
const S4_PROTECTED_NPC_IDS: Array[String] = ["aldous_prior", "vera_midwife", "finn_monk"]
var S4_WIN_REP_MIN       := 48
var S4_FAIL_REP_BELOW    := 42

# Scenario 5 thresholds (The Election — SPA-605).
# Three-way race: Aldric must reach 65+ and be highest; both rivals must be below 45.
# Instant fail if Aldric drops below 30. Endorsement day loaded from scenarios.json (+8 to leader).
# Vars (not const) so difficulty modifiers from scenarios.json can override them.
const S5_CANDIDATE_IDS: Array[String] = ["edric_fenn", "aldric_vane", "tomas_reeve"]
var S5_WIN_ALDRIC_MIN:    int = 65
var S5_WIN_RIVALS_MAX:    int = 45
var S5_FAIL_ALDRIC_BELOW: int = 30
var S5_ENDORSEMENT_DAY:       int = 13
var S5_ENDORSEMENT_BONUS: int = 8

# Scenario 6 thresholds (The Merchant's Debt — SPA-605).
# Expose Aldric (rep <= 30) while protecting Marta (rep >= 62).
# Lower heat ceiling (55) — guards are on Aldric's payroll.
# Instant fail if Marta drops below 30.
# Vars (not const) so difficulty modifiers from scenarios.json can override them.
# SPA-747: marta win 60→62, heat ceiling 60→55 — visible heat budget must be tighter.
var S6_WIN_ALDRIC_MAX:   int   = 30
var S6_WIN_MARTA_MIN:    int   = 62
var S6_FAIL_MARTA_BELOW: int   = 30
var S6_EXPOSED_HEAT:     float = 55.0

enum ScenarioState { ACTIVE, WON, FAILED }

## Emitted the first time a scenario resolves.
## scenario_id: 1–6.  state: WON or FAILED.
signal scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState)

## Emitted once when the scenario crosses a deadline threshold (0.75 or 0.90).
## threshold: 0.75 or 0.90.  days_remaining: int.
signal deadline_warning(threshold: float, days_remaining: int)

## SPA-592: Emitted the first time Maren rejects the illness rumor, starting the grace window.
## days_remaining: how many days the player has to reach 7 believers before the fail fires.
signal s2_maren_grace_started(days_remaining: int)

## Scenario 5 only: emitted when Prior Aldous endorses a candidate on day 15.
## candidate_id: the NPC with the highest reputation. bonus: the rep boost applied.
signal endorsement_triggered(candidate_id: String, bonus: int)

## Optional reference to the player intel store (for heat-based fail checks).
var _intel_store: PlayerIntelStore = null

var scenario_1_state: ScenarioState = ScenarioState.ACTIVE
var scenario_2_state: ScenarioState = ScenarioState.ACTIVE
var scenario_3_state: ScenarioState = ScenarioState.ACTIVE
var scenario_4_state: ScenarioState = ScenarioState.ACTIVE
var scenario_5_state: ScenarioState = ScenarioState.ACTIVE
var scenario_6_state: ScenarioState = ScenarioState.ACTIVE

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

## Scenario 5 only: whether the endorsement has already fired.
var _s5_endorsement_fired: bool = false
## Scenario 5 only: which candidate received the endorsement (empty = not yet).
var s5_endorsed_candidate: String = ""

## SPA-592: tick when Maren first entered REJECT state (-1 = not yet).
## Used to enforce S2_MAREN_GRACE_DAYS before the contradicted fail fires.
var _s2_maren_first_reject_tick: int = -1
## SPA-592: display name of the NPC who first carried the illness rumor to Maren.
## Set by World._on_npc_rumor_transmitted; read by end_screen for chain attribution.
var s2_maren_carrier_name: String = ""


## Evaluate win/fail conditions for the active scenario only.
## Call once per tick, after reputation_system.recalculate_all().
func evaluate(rep: ReputationSystem, current_tick: int) -> void:
	_check_deadline_warnings(current_tick)
	match _active_scenario:
		1: _check_scenario_1(rep, current_tick)
		2: _check_scenario_2(rep, current_tick)
		3: _check_scenario_3(rep, current_tick)
		4: _check_scenario_4(rep, current_tick)
		5: _check_scenario_5(rep, current_tick)
		6: _check_scenario_6(rep, current_tick)


## Returns the fraction of time elapsed (0.0–1.0) for the current scenario.
func get_time_fraction(current_tick: int) -> float:
	if _days_allowed <= 1:
		return 1.0
	var current_day: int = current_tick / ticks_per_day + 1
	return clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)


## Returns true when the scenario is in the final 25% of its allowed time.
func is_final_quarter(current_tick: int) -> bool:
	return get_time_fraction(current_tick) >= 0.75


## Check and emit deadline warning signals at 75% and 90% thresholds.
func _check_deadline_warnings(current_tick: int) -> void:
	var current_day: int = current_tick / ticks_per_day + 1
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
	# Timeout fail: day limit exceeded (> gives the player the full last day; get_time_fraction is clamped at 1.0).
	var current_day: int = current_tick / ticks_per_day + 1
	if current_day > _days_allowed:
		scenario_1_state = ScenarioState.FAILED
		scenario_resolved.emit(1, ScenarioState.FAILED)


func _check_scenario_2(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_2_state != ScenarioState.ACTIVE:
		return
	var illness_count: int = rep.get_illness_believer_count(ALYS_HERBWIFE_ID)
	if illness_count >= s2_win_illness_min:
		scenario_2_state = ScenarioState.WON
		scenario_resolved.emit(2, ScenarioState.WON)
		return
	# Contradicted fail: Sister Maren rejects illness rumors about Alys Herbwife.
	# SPA-592: grace window — record first rejection tick and only fail after
	# S2_MAREN_GRACE_DAYS, giving the player a chance to hit 7 believers or
	# counter-seed doubt before the silent-chain penalty closes the scenario.
	if rep.has_illness_rejecter(ALYS_HERBWIFE_ID, MAREN_NUN_ID):
		if _s2_maren_first_reject_tick == -1:
			_s2_maren_first_reject_tick = current_tick
			s2_maren_grace_started.emit(S2_MAREN_GRACE_DAYS)
		elif current_tick >= _s2_maren_first_reject_tick + ticks_per_day * S2_MAREN_GRACE_DAYS:
			scenario_2_state = ScenarioState.FAILED
			scenario_resolved.emit(2, ScenarioState.FAILED)
			return
	# Timeout fail: day limit exceeded (> gives the player the full last day; get_time_fraction is clamped at 1.0).
	var current_day: int = current_tick / ticks_per_day + 1
	if current_day > _days_allowed:
		scenario_2_state = ScenarioState.FAILED
		scenario_resolved.emit(2, ScenarioState.FAILED)


func _check_scenario_3(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_3_state != ScenarioState.ACTIVE:
		return

	# Timeout must be checked before the null guard so a missing NPC cannot
	# prevent the scenario from ever resolving.
	var current_day: int = current_tick / ticks_per_day + 1
	if current_day > _days_allowed:
		scenario_3_state = ScenarioState.FAILED
		scenario_resolved.emit(3, ScenarioState.FAILED)
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


# ---------------------------------------------------------------------------
# Progress queries (for HUD / Journal)
# ---------------------------------------------------------------------------

## Returns the current Scenario 2 progress dict.
func get_scenario_2_progress(rep: ReputationSystem) -> Dictionary:
	return {
		"illness_believer_count": rep.get_illness_believer_count(ALYS_HERBWIFE_ID),
		"illness_believer_ids":   rep.get_illness_believer_ids(ALYS_HERBWIFE_ID),
		"illness_rejecter_ids":   rep.get_illness_rejecter_ids(ALYS_HERBWIFE_ID),
		"win_threshold":          s2_win_illness_min,
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
	# Fail: any protected NPC drops below 42 (instant fail).
	for npc_id in S4_PROTECTED_NPC_IDS:
		var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
		if snap == null:
			continue
		if snap.score < S4_FAIL_REP_BELOW:
			scenario_4_state = ScenarioState.FAILED
			scenario_resolved.emit(4, ScenarioState.FAILED)
			return
	# Deadline reached: resolve win or fail (> gives the player the full last day; get_time_fraction is clamped at 1.0).
	var current_day: int = current_tick / ticks_per_day + 1
	if current_day > _days_allowed:
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


# ---------------------------------------------------------------------------
# Scenario 5 — The Election (SPA-605)
# ---------------------------------------------------------------------------

func _check_scenario_5(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_5_state != ScenarioState.ACTIVE:
		return

	var current_day: int = current_tick / ticks_per_day + 1

	# Timeout must be checked before the null guard so a missing NPC cannot
	# prevent the scenario from ever resolving.
	if current_day > _days_allowed:
		scenario_5_state = ScenarioState.FAILED
		scenario_resolved.emit(5, ScenarioState.FAILED)
		return

	var aldric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(ALDRIC_VANE_ID)
	var edric:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
	var tomas:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
	if aldric == null or edric == null or tomas == null:
		return

	# Endorsement: Prior Aldous endorses the candidate with the highest rep.
	if not _s5_endorsement_fired and current_day >= S5_ENDORSEMENT_DAY:
		_s5_endorsement_fired = true
		var best_id: String = ALDRIC_VANE_ID
		var best_score: int = aldric.score
		if edric.score > best_score:
			best_id = EDRIC_FENN_ID
			best_score = edric.score
		if tomas.score > best_score:
			best_id = TOMAS_REEVE_ID
		s5_endorsed_candidate = best_id
		rep.apply_score_delta(best_id, S5_ENDORSEMENT_BONUS)
		endorsement_triggered.emit(best_id, S5_ENDORSEMENT_BONUS)
		# Re-read snapshots after endorsement delta.
		aldric = rep.get_snapshot(ALDRIC_VANE_ID)
		edric  = rep.get_snapshot(EDRIC_FENN_ID)
		tomas  = rep.get_snapshot(TOMAS_REEVE_ID)
		if aldric == null or edric == null or tomas == null:
			return

	# WIN: Aldric >= 65, highest of all three, both rivals strictly below 45.
	if (aldric.score >= S5_WIN_ALDRIC_MIN
			and aldric.score > edric.score
			and aldric.score > tomas.score
			and edric.score < S5_WIN_RIVALS_MAX
			and tomas.score < S5_WIN_RIVALS_MAX):
		scenario_5_state = ScenarioState.WON
		scenario_resolved.emit(5, ScenarioState.WON)
		return

	# FAIL: Aldric drops below 30 (instant fail — campaign collapses).
	if aldric.score < S5_FAIL_ALDRIC_BELOW:
		scenario_5_state = ScenarioState.FAILED
		scenario_resolved.emit(5, ScenarioState.FAILED)


## Returns the current Scenario 5 progress dict.
func get_scenario_5_progress(rep: ReputationSystem) -> Dictionary:
	var aldric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(ALDRIC_VANE_ID)
	var edric:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(EDRIC_FENN_ID)
	var tomas:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(TOMAS_REEVE_ID)
	return {
		"aldric_score":       aldric.score if aldric != null else 48,
		"edric_score":        edric.score  if edric  != null else 58,
		"tomas_score":        tomas.score  if tomas  != null else 45,
		"win_aldric_min":     S5_WIN_ALDRIC_MIN,
		"win_rivals_max":     S5_WIN_RIVALS_MAX,
		"fail_aldric_below":  S5_FAIL_ALDRIC_BELOW,
		"endorsement_fired":  _s5_endorsement_fired,
		"endorsed_candidate": s5_endorsed_candidate,
		"state":              scenario_5_state,
	}


# ---------------------------------------------------------------------------
# Scenario 6 — The Merchant's Debt (SPA-605)
# ---------------------------------------------------------------------------

func _check_scenario_6(rep: ReputationSystem, current_tick: int) -> void:
	if scenario_6_state != ScenarioState.ACTIVE:
		return

	# Timeout must be checked before the null guard so a missing NPC cannot
	# prevent the scenario from ever resolving.
	var current_day: int = current_tick / ticks_per_day + 1
	if current_day > _days_allowed:
		scenario_6_state = ScenarioState.FAILED
		scenario_resolved.emit(6, ScenarioState.FAILED)
		return

	# FAIL (exposure): heat ceiling in S6 (guards on Aldric's payroll).
	if _intel_store != null:
		for npc_id in _intel_store.heat:
			if _intel_store.heat[npc_id] >= S6_EXPOSED_HEAT:
				scenario_6_state = ScenarioState.FAILED
				scenario_resolved.emit(6, ScenarioState.FAILED)
				return

	var aldric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(ALDRIC_VANE_ID)
	var marta:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(MARTA_COIN_ID)
	if aldric == null or marta == null:
		return

	# WIN: Aldric <= 30 AND Marta >= 60.
	if aldric.score <= S6_WIN_ALDRIC_MAX and marta.score >= S6_WIN_MARTA_MIN:
		scenario_6_state = ScenarioState.WON
		scenario_resolved.emit(6, ScenarioState.WON)
		return

	# FAIL: Marta drops below 30 (instant fail — she's been silenced).
	if marta.score < S6_FAIL_MARTA_BELOW:
		scenario_6_state = ScenarioState.FAILED
		scenario_resolved.emit(6, ScenarioState.FAILED)


## Returns the current Scenario 6 progress dict.
func get_scenario_6_progress(rep: ReputationSystem) -> Dictionary:
	var aldric: ReputationSystem.ReputationSnapshot = rep.get_snapshot(ALDRIC_VANE_ID)
	var marta:  ReputationSystem.ReputationSnapshot = rep.get_snapshot(MARTA_COIN_ID)
	var current_heat: float = 0.0
	if _intel_store != null:
		for npc_id in _intel_store.heat:
			if _intel_store.heat[npc_id] > current_heat:
				current_heat = _intel_store.heat[npc_id]
	return {
		"aldric_score":     aldric.score if aldric != null else 55,
		"marta_score":      marta.score  if marta  != null else 52,
		"win_aldric_max":   S6_WIN_ALDRIC_MAX,
		"win_marta_min":    S6_WIN_MARTA_MIN,
		"fail_marta_below": S6_FAIL_MARTA_BELOW,
		"heat_ceiling":     S6_EXPOSED_HEAT,
		"max_heat":         current_heat,
		"state":            scenario_6_state,
	}

## milestone_tracker.gd — Narrative milestone notification system (SPA-479).
##
## Plain class (no Node).  Evaluates scenario progress each tick and fires
## one-shot narrative milestones that make the player feel their actions matter.
## Each milestone fires exactly once per game via _fired dictionary.
##
## Milestones are scenario-specific and tied to concrete progress thresholds.
## They surface via the show_milestone callback provided at setup time.

class_name MilestoneTracker


## Callback signature: func(text: String, color: Color) -> void
var _show_milestone: Callable = Callable()

## Tracks which milestone IDs have already fired this session.
var _fired: Dictionary = {}

## Cached refs set via setup().
var _scenario_id: int = 0
var _rep_system: ReputationSystem = null
var _scenario_mgr: ScenarioManager = null
var _intel_store: PlayerIntelStore = null


func setup(
		scenario_id: int,
		rep_system: ReputationSystem,
		scenario_mgr: ScenarioManager,
		intel_store: PlayerIntelStore,
		show_milestone_fn: Callable
) -> void:
	_scenario_id    = scenario_id
	_rep_system     = rep_system
	_scenario_mgr   = scenario_mgr
	_intel_store    = intel_store
	_show_milestone = show_milestone_fn


## Call once per tick (after reputation recalculation).
func evaluate(current_tick: int) -> void:
	if _rep_system == null or _scenario_mgr == null:
		return
	match _scenario_id:
		1: _eval_s1(current_tick)
		2: _eval_s2(current_tick)
		3: _eval_s3(current_tick)
		4: _eval_s4(current_tick)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _fire(id: String, text: String, color: Color) -> void:
	if _fired.has(id):
		return
	_fired[id] = true
	if _show_milestone.is_valid():
		_show_milestone.call(text, color)


const C_PROGRESS := Color(0.50, 1.00, 0.55, 1.0)   # green — good progress
const C_WARNING  := Color(1.00, 0.75, 0.25, 1.0)    # amber — caution
const C_DANGER   := Color(0.95, 0.30, 0.15, 1.0)    # red — threat
const C_NEUTRAL  := Color(0.85, 0.78, 0.55, 1.0)    # parchment — informational


# ── Scenario 1: The Alderman's Ruin ───���─────────────────────────────────────

func _eval_s1(_current_tick: int) -> void:
	var snap: ReputationSystem.ReputationSnapshot = _rep_system.get_snapshot("edric_fenn")
	if snap == null:
		return
	var score: int = snap.score

	# Reputation crossing key thresholds (descending).
	if score <= 60:
		_fire("s1_rep_60", "Whispers take hold — Edric's standing is shaken", C_PROGRESS)
	if score <= 50:
		_fire("s1_rep_50", "The town doubts Lord Fenn", C_PROGRESS)
	if score <= 40:
		_fire("s1_rep_40", "Edric is losing allies — keep pushing", C_PROGRESS)
	if score <= 35:
		_fire("s1_rep_35", "Almost there — Edric teeters on the edge", C_WARNING)

	# Believer count milestones.
	var believers: int = _rep_system.get_global_believer_count()
	if believers >= 3:
		_fire("s1_believers_3", "3 townspeople believe your rumors", C_NEUTRAL)
	if believers >= 6:
		_fire("s1_believers_6", "The rumor mill is turning — 6 believers", C_PROGRESS)


# ── Scenario 2: The Plague Scare ──────────��─────────────────────────────────

func _eval_s2(_current_tick: int) -> void:
	var count: int = _rep_system.get_illness_believer_count("alys_herbwife")

	if count >= 2:
		_fire("s2_believers_2", "2 believe Alys is ill — the fear spreads", C_PROGRESS)
	if count >= 4:
		_fire("s2_believers_4", "4 believers — halfway to critical mass", C_PROGRESS)
	if count >= 5:
		_fire("s2_believers_5", "One more believer and panic takes hold!", C_WARNING)

	# Maren threat: check if she has any illness rumors in evaluating state.
	# We approximate by checking her heat — high heat means she's processing rumors.
	if _intel_store != null and _intel_store.heat_enabled:
		var maren_heat: float = _intel_store.get_heat("maren_nun")
		if maren_heat >= 40.0:
			_fire("s2_maren_suspicious", "⚠ Sister Maren grows suspicious...", C_DANGER)


# ── Scenario 3: The Succession ────────────��─────────────────────────────────

func _eval_s3(_current_tick: int) -> void:
	var calder: ReputationSystem.ReputationSnapshot = _rep_system.get_snapshot("calder_fenn")
	var tomas:  ReputationSystem.ReputationSnapshot = _rep_system.get_snapshot("tomas_reeve")
	if calder == null or tomas == null:
		return

	# Calder rising.
	if calder.score >= 60:
		_fire("s3_calder_60", "Calder gains the merchants' ear", C_PROGRESS)
	if calder.score >= 70:
		_fire("s3_calder_70", "Calder Fenn is nearly a favourite — push to 75", C_WARNING)

	# Tomas falling.
	if tomas.score <= 45:
		_fire("s3_tomas_45", "Tomas Reeve's support is crumbling", C_PROGRESS)
	if tomas.score <= 38:
		_fire("s3_tomas_38", "The Reeve is nearly finished — drag him below 35", C_WARNING)

	# Calder danger.
	if calder.score <= 45:
		_fire("s3_calder_danger", "⚠ Calder's reputation is in danger — counter the rival!", C_DANGER)


# ── Scenario 4: The Holy Inquisition ────────────────────────────────────────

func _eval_s4(current_tick: int) -> void:
	var min_score: int = 100
	var weakest_name: String = ""
	for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
		var snap: ReputationSystem.ReputationSnapshot = _rep_system.get_snapshot(npc_id)
		if snap == null:
			continue
		if snap.score < min_score:
			min_score = snap.score
			weakest_name = npc_id.replace("_", " ").capitalize()

	# Safety milestones.
	var day: int = _scenario_mgr.get_current_day(current_tick)
	if day >= 5 and min_score >= 50:
		_fire("s4_day5_safe", "Day 5 — all charges safe. Hold the line.", C_PROGRESS)
	if day >= 10 and min_score >= 50:
		_fire("s4_day10_safe", "Halfway through — the Inquisitor hasn't broken through", C_PROGRESS)
	if day >= 15 and min_score >= 50:
		_fire("s4_day15_safe", "Day 15 — 5 more days. Stay vigilant!", C_WARNING)

	# Danger milestones.
	if min_score <= 52 and min_score > ScenarioManager.S4_FAIL_REP_BELOW:
		_fire("s4_close_call", "⚠ %s is dangerously close to the threshold!" % weakest_name, C_DANGER)
	if min_score <= 48 and min_score > ScenarioManager.S4_FAIL_REP_BELOW:
		_fire("s4_critical", "⚠ CRITICAL — %s is about to fall!" % weakest_name, C_DANGER)

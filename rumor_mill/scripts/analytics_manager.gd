## analytics_manager.gd — SPA-994: Analytics logger signal wiring.
##
## Owns the AnalyticsLogger instance and wires all analytics signals.
## Extracted from main.gd to keep the entry-point lean.
##
## Usage (from main.gd):
##   _analytics_manager = AnalyticsManager.new()
##   _analytics_manager.setup(scenario_id, world, day_night, rumor_panel, recon_ctrl)

extends RefCounted
class_name AnalyticsManager

var _analytics_logger:      AnalyticsLogger = null
var _analytics_scenario_id: String          = ""
var _analytics_rep_snapshot: Dictionary     = {}  # npc_id → int score, for delta tracking

var _world:     Node2D = null
var _day_night: Node   = null


## Wire all analytics signals and start the session log.
func setup(
		scenario_id: String,
		world: Node2D,
		day_night: Node,
		rumor_panel: CanvasLayer,
		recon_ctrl: Node
) -> void:
	_world     = world
	_day_night = day_night

	_analytics_logger = AnalyticsLogger.new()
	_analytics_logger.start_session(scenario_id, GameState.selected_difficulty)
	_analytics_scenario_id = scenario_id

	# Log each rumor seeded (full context for propagation frequency analysis).
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_analytics_rumor_seeded)

	# Log NPC rumor-slot state transitions (BELIEVE / SPREAD / ACT / REJECT).
	if "npcs" in world:
		for npc in world.npcs:
			if npc.has_signal("rumor_state_changed"):
				npc.rumor_state_changed.connect(_on_analytics_npc_state_changed)

	# Log evidence collection interactions (observe / eavesdrop).
	if recon_ctrl != null and recon_ctrl.has_signal("action_performed"):
		recon_ctrl.action_performed.connect(_on_analytics_evidence_interaction)

	# Log per-day reputation deltas for balance tuning.
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_analytics_new_day)

	# Log scenario outcome and session summary.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_analytics_scenario_resolved)


func _on_analytics_rumor_seeded(
		_rumor_id: String,
		subject_name: String,
		claim_id: String,
		seed_target_name: String
) -> void:
	if _analytics_logger == null:
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_rumor_seeded(subject_name, claim_id, seed_target_name, day, _analytics_scenario_id)


func _on_analytics_npc_state_changed(npc_name: String, new_state: String, rumor_id: String) -> void:
	if _analytics_logger == null:
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_npc_state_changed(npc_name, rumor_id, new_state, day, _analytics_scenario_id)


func _on_analytics_evidence_interaction(message: String, success: bool) -> void:
	if _analytics_logger == null:
		return
	var action_type: String
	if "Observe" in message:
		action_type = "observe"
	elif "Eavesdrop" in message:
		action_type = "eavesdrop"
	else:
		return  # Only log observe and eavesdrop evidence interactions.
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_evidence_interaction(action_type, success, day, _analytics_scenario_id)


func _on_analytics_new_day(day: int) -> void:
	if _analytics_logger == null or _world == null:
		return
	var rep: ReputationSystem = _world.reputation_system if "reputation_system" in _world else null
	if rep == null:
		return
	var snapshots: Dictionary = rep.get_all_snapshots()
	for npc_id in snapshots:
		var snap: ReputationSystem.ReputationSnapshot = snapshots[npc_id]
		var prev_score: int = _analytics_rep_snapshot.get(npc_id, snap.score)
		if abs(snap.score - prev_score) >= 3:
			_analytics_logger.log_reputation_delta(npc_id, prev_score, snap.score, day, _analytics_scenario_id)
		_analytics_rep_snapshot[npc_id] = snap.score


func _on_analytics_scenario_resolved(
		scenario_id: int,
		state: ScenarioManager.ScenarioState
) -> void:
	if _analytics_logger == null:
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_event("scenario_ended", {
		"scenario_id":   "scenario_%d" % scenario_id,
		"difficulty":    GameState.selected_difficulty,
		"outcome":       "WON" if state == ScenarioManager.ScenarioState.WON else "FAILED",
		"day_reached":   day,
		"duration_sec":  _analytics_logger.get_session_duration_seconds(),
	})

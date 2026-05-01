## analytics_manager.gd — SPA-994/SPA-1054: Analytics logger signal wiring
## with debug logging and bounded pre-setup event queue.
##
## Owns the AnalyticsLogger instance and wires all analytics signals.
## Extracted from main.gd to keep the entry-point lean.
##
## New in SPA-1054:
##   • push_warning() emitted for every silently-dropped event or skipped wiring
##   • Bounded pre-setup queue (max QUEUE_CAP entries) buffers events that arrive
##     before setup() is called and replays them once the logger is ready.
##
## New in SPA-1454:
##   • scenario_fail_trigger wired from ScenarioManager — emits once per FAILED
##     resolution with fail_cause and trigger_npc_id for direct balance analysis.
##
## Usage (from main.gd):
##   _analytics_manager = AnalyticsManager.new()
##   _analytics_manager.setup(scenario_id, world, day_night, rumor_panel, recon_ctrl)

extends RefCounted
class_name AnalyticsManager

## Maximum number of events held in the pre-setup buffer.
## Once full, the oldest entry is evicted to make room.
const QUEUE_CAP := 64

var _analytics_logger:       AnalyticsLogger = null
var _analytics_scenario_id:  String          = ""
var _analytics_rep_snapshot: Dictionary      = {}  # npc_id → int score, for delta tracking

var _world:     Node2D = null
var _day_night: Node   = null

## Pre-setup event queue. Each entry: { "method": String, "args": Array }.
var _event_queue: Array = []


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

	# Replay any events that fired before the logger was ready.
	_flush_queue()

	# Log each rumor seeded (full context for propagation frequency analysis).
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_analytics_rumor_seeded)
	else:
		push_warning("AnalyticsManager: rumor_panel is null — rumor_seeded events will not be logged")

	# Log NPC rumor-slot state transitions (BELIEVE / SPREAD / ACT / REJECT).
	if "npcs" in world:
		for npc in world.npcs:
			if npc.has_signal("rumor_state_changed"):
				npc.rumor_state_changed.connect(_on_analytics_npc_state_changed)
	else:
		push_warning("AnalyticsManager: world has no 'npcs' property — npc_state_changed events will not be logged")

	# Log evidence collection interactions (observe / eavesdrop).
	if recon_ctrl != null:
		if recon_ctrl.has_signal("action_performed"):
			recon_ctrl.action_performed.connect(_on_analytics_evidence_interaction)
		else:
			push_warning("AnalyticsManager: recon_ctrl has no action_performed signal — evidence_interaction events will not be logged")
	else:
		push_warning("AnalyticsManager: recon_ctrl is null — evidence_interaction events will not be logged")

	# Log per-day reputation deltas for balance tuning.
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_analytics_new_day)
	else:
		push_warning("AnalyticsManager: day_night is null or missing day_changed — reputation_delta events will not be logged")

	# Log scenario outcome and session summary.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_analytics_scenario_resolved)
		# SPA-1454: Log explicit fail cause just before scenario_resolved fires.
		sm.scenario_fail_trigger.connect(_on_analytics_scenario_fail_trigger)
	else:
		push_warning("AnalyticsManager: world.scenario_manager is null — scenario_resolved events will not be logged")

	# SPA-1241: Log user settings changes via SettingsManager autoload signal.
	if SettingsManager.has_signal("setting_changed"):
		SettingsManager.setting_changed.connect(_on_analytics_settings_changed)
	else:
		push_warning("AnalyticsManager: SettingsManager missing setting_changed signal — settings_changed events will not be logged")


func _on_analytics_rumor_seeded(
		_rumor_id: String,
		subject_name: String,
		claim_id: String,
		seed_target_name: String
) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_rumor_seeded", [_rumor_id, subject_name, claim_id, seed_target_name])
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_rumor_seeded(subject_name, claim_id, seed_target_name, day, _analytics_scenario_id)


func _on_analytics_npc_state_changed(npc_name: String, new_state: String, rumor_id: String) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_npc_state_changed", [npc_name, new_state, rumor_id])
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_npc_state_changed(npc_name, rumor_id, new_state, day, _analytics_scenario_id)


func _on_analytics_evidence_interaction(message: String, success: bool) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_evidence_interaction", [message, success])
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
	if _analytics_logger == null:
		_enqueue("_on_analytics_new_day", [day])
		return
	if _world == null:
		push_warning("AnalyticsManager: _world is null in _on_analytics_new_day — reputation events for day %d dropped" % day)
		return
	var rep: ReputationSystem = _world.reputation_system if "reputation_system" in _world else null
	if rep == null:
		push_warning("AnalyticsManager: _world.reputation_system is null — reputation events for day %d dropped" % day)
		return
	var snapshots: Dictionary = rep.get_all_snapshots()
	for npc_id in snapshots:
		var snap: ReputationSystem.ReputationSnapshot = snapshots[npc_id]
		var prev_score: int = _analytics_rep_snapshot.get(npc_id, snap.score)
		if abs(snap.score - prev_score) >= 3:
			_analytics_logger.log_reputation_delta(npc_id, prev_score, snap.score, day, _analytics_scenario_id)
		_analytics_rep_snapshot[npc_id] = snap.score
	# SPA-1417: Emit lossless point-in-time snapshots for win-condition NPCs so
	# day-checkpoint balancing (e.g. Calder rep at day 15 for proposal 3-A) can
	# be reconstructed exactly without relying on the threshold-filtered delta events.
	var sm: ScenarioManager = _world.scenario_manager if "scenario_manager" in _world else null
	if sm != null:
		for npc_id in sm.get_win_condition_npc_ids():
			var snap: ReputationSystem.ReputationSnapshot = snapshots.get(npc_id)
			if snap != null:
				_analytics_logger.log_reputation_snapshot(npc_id, snap.score, day, _analytics_scenario_id)
	else:
		push_warning("AnalyticsManager: _world.scenario_manager is null — reputation_snapshot for day %d skipped" % day)


## SPA-1241: Wire TutorialController step_completed signal.
## Called after the TutorialController is created (deferred from setup() because
## the controller is instantiated later in the game-start flow).
func wire_tutorial_controller(tutorial_ctrl: Node) -> void:
	if tutorial_ctrl != null and tutorial_ctrl.has_signal("step_completed"):
		tutorial_ctrl.step_completed.connect(_on_analytics_tutorial_step_completed)
	else:
		push_warning("AnalyticsManager: tutorial_ctrl is null or missing step_completed — tutorial_step_completed events will not be logged")


func _on_analytics_tutorial_step_completed(step_id: String, scenario_id: String) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_tutorial_step_completed", [step_id, scenario_id])
		return
	_analytics_logger.log_tutorial_step_completed(step_id, scenario_id)


func _on_analytics_settings_changed(setting_key: String, old_value: String, new_value: String) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_settings_changed", [setting_key, old_value, new_value])
		return
	_analytics_logger.log_settings_changed(setting_key, old_value, new_value)


## SPA-1454: Log explicit fail cause. Fired by ScenarioManager just before
## scenario_resolved when outcome=FAILED, so the event always precedes scenario_ended.
func _on_analytics_scenario_fail_trigger(
		scenario_id: int,
		fail_cause: String,
		trigger_npc_id: String,
		trigger_rumor_id: String
) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_scenario_fail_trigger", [scenario_id, fail_cause, trigger_npc_id, trigger_rumor_id])
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_scenario_fail_trigger(
		"scenario_%d" % scenario_id, day, fail_cause, trigger_npc_id, trigger_rumor_id)


func _on_analytics_scenario_resolved(
		scenario_id: int,
		state: ScenarioManager.ScenarioState
) -> void:
	if _analytics_logger == null:
		_enqueue("_on_analytics_scenario_resolved", [scenario_id, state])
		return
	var day: int = _day_night.current_day if _day_night != null and "current_day" in _day_night else 0
	_analytics_logger.log_event("scenario_ended", {
		"scenario_id":   "scenario_%d" % scenario_id,
		"difficulty":    GameState.selected_difficulty,
		"outcome":       "WON" if state == ScenarioManager.ScenarioState.WON else "FAILED",
		"day_reached":   day,
		"duration_sec":  _analytics_logger.get_session_duration_seconds(),
	})


# ── Internal ─────────────────────────────────────────────────────────────────

## Buffer an event for replay once setup() is called.
## Evicts the oldest entry if the queue is already at QUEUE_CAP.
func _enqueue(method: String, args: Array) -> void:
	if _event_queue.size() >= QUEUE_CAP:
		push_warning("AnalyticsManager: pre-setup queue full (%d), dropping oldest event to make room" % QUEUE_CAP)
		_event_queue.pop_front()
	_event_queue.append({ "method": method, "args": args })


## Replay all buffered events now that _analytics_logger is available.
func _flush_queue() -> void:
	if _event_queue.is_empty():
		return
	for entry in _event_queue:
		callv(entry["method"], entry["args"])
	_event_queue.clear()

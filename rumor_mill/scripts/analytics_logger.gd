## analytics_logger.gd — SPA-244: Local player behaviour event log.
##
## Append-only NDJSON log at user://analytics.json.
## One JSON object per line; easy to aggregate with jq, Python, or spreadsheets.
##
## Wire from main.gd:
##   _analytics_logger = AnalyticsLogger.new()
##   _analytics_logger.start_session(scenario_id, difficulty)
##
## Call log_event("type", { key: value, ... }) for any notable player action.
## All writes are silent no-ops when SettingsManager.analytics_enabled is false.

extends RefCounted
class_name AnalyticsLogger

const SAVE_PATH := "user://analytics.json"

## Unix timestamp at session start — used to compute duration_sec at session end.
var _session_start_time: int = 0


## Record the start of a play session and emit a scenario_selected event.
func start_session(scenario_id: String, difficulty: String) -> void:
	_session_start_time = int(Time.get_unix_time_from_system())
	log_event("scenario_selected", {
		"scenario_id": scenario_id,
		"difficulty":  difficulty,
	})


## Append an event with an ISO-8601 timestamp plus any extra fields from data.
func log_event(event_type: String, data: Dictionary) -> void:
	if not SettingsManager.analytics_enabled:
		return
	var entry: Dictionary = {}
	for key in data:
		entry[key] = data[key]
	# Reserved fields overwrite any caller-supplied values.
	entry["ts"]   = Time.get_datetime_string_from_system(true)
	entry["type"] = event_type
	_append_line(JSON.stringify(entry))


## Seconds elapsed since start_session() was called. Returns 0 if not started.
func get_session_duration_seconds() -> int:
	if _session_start_time == 0:
		return 0
	return int(Time.get_unix_time_from_system()) - _session_start_time


## Log a rumor being seeded into the social graph.
## Captures subject, claim type, seed target, and day for propagation analysis.
func log_rumor_seeded(subject_name: String, claim_id: String, seed_target: String, day: int, scenario_id: String) -> void:
	log_event("rumor_seeded", {
		"subject_name":  subject_name,
		"claim_id":      claim_id,
		"seed_target":   seed_target,
		"day":           day,
		"scenario_id":   scenario_id,
	})


## Log an NPC rumor-slot state transition (BELIEVE, SPREAD, ACT, REJECT, etc.).
## Used to track how quickly rumors propagate and which NPCs resist them.
func log_npc_state_changed(npc_name: String, rumor_id: String, new_state: String, day: int, scenario_id: String) -> void:
	log_event("npc_state_changed", {
		"npc_name":    npc_name,
		"rumor_id":    rumor_id,
		"new_state":   new_state,
		"day":         day,
		"scenario_id": scenario_id,
	})


## Log a meaningful reputation score change for an NPC between days.
## Only called when abs(delta) >= 3 to avoid noise from micro-fluctuations.
func log_reputation_delta(npc_id: String, from_score: int, to_score: int, day: int, scenario_id: String) -> void:
	log_event("reputation_delta", {
		"npc_id":      npc_id,
		"from_score":  from_score,
		"to_score":    to_score,
		"delta":       to_score - from_score,
		"day":         day,
		"scenario_id": scenario_id,
	})


## Log a player evidence-collection action (observe or eavesdrop).
## Used to correlate recon activity with rumor propagation speed.
func log_evidence_interaction(action_type: String, success: bool, day: int, scenario_id: String) -> void:
	log_event("evidence_interaction", {
		"action_type": action_type,
		"success":     success,
		"day":         day,
		"scenario_id": scenario_id,
	})


## Log a tutorial step completion (SPA-1241).
## Tracks per-step abandonment: which steps players reach before quitting.
func log_tutorial_step_completed(step_id: String, scenario_id: String) -> void:
	log_event("tutorial_step_completed", {
		"step_id":     step_id,
		"scenario_id": scenario_id,
	})


## Log a user settings change (SPA-1241).
## Tracks which settings players touch and how they change them.
func log_settings_changed(setting_key: String, old_value: String, new_value: String) -> void:
	log_event("settings_changed", {
		"setting_key": setting_key,
		"old_value":   old_value,
		"new_value":   new_value,
	})


# ── Internal ─────────────────────────────────────────────────────────────────

func _append_line(line: String) -> void:
	# Open READ_WRITE to append to an existing file; fall back to WRITE (create).
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AnalyticsLogger: cannot open %s (err %d)" % [
				SAVE_PATH, FileAccess.get_open_error()])
		return
	file.seek_end()
	file.store_line(line)
	file.close()

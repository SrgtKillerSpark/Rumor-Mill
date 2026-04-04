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
	var entry: Dictionary = {
		"ts":   Time.get_datetime_string_from_system(true),
		"type": event_type,
	}
	for key in data:
		entry[key] = data[key]
	_append_line(JSON.stringify(entry))


## Seconds elapsed since start_session() was called. Returns 0 if not started.
func get_session_duration_seconds() -> int:
	if _session_start_time == 0:
		return 0
	return int(Time.get_unix_time_from_system()) - _session_start_time


# ── Internal ─────────────────────────────────────────────────────────────────

func _append_line(line: String) -> void:
	# Open READ_WRITE to append to an existing file; fall back to WRITE (create).
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("AnalyticsLogger: cannot open %s (err %d)" % [
				SAVE_PATH, FileAccess.get_open_error()])
		return
	file.seek_end()
	file.store_line(line)
	file.close()

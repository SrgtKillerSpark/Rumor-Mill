## progress_data.gd — Static helper for persisting scenario completion (SPA-137).
##
## Saves completed scenario IDs to user://progress.json so the main menu can
## determine which scenarios are locked across sessions.
##
## Usage:
##   ProgressData.mark_completed("scenario_1")
##   ProgressData.get_completed()  # -> ["scenario_1"]
##   ProgressData.is_completed("scenario_1")  # -> true

class_name ProgressData

const SAVE_PATH := "user://progress.json"


## Returns the array of completed scenario ID strings.
static func get_completed() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("ProgressData: failed to open '%s' for reading" % SAVE_PATH)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed.get("completed", [])
	return []


## Returns true if the given scenario_id has been completed.
static func is_completed(scenario_id: String) -> bool:
	return scenario_id in get_completed()


## Marks scenario_id as completed and persists to disk.
## Safe to call multiple times — duplicates are ignored.
static func mark_completed(scenario_id: String) -> void:
	var completed := get_completed()
	if scenario_id not in completed:
		completed.append(scenario_id)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("ProgressData: failed to open '%s' for writing" % SAVE_PATH)
		return
	f.store_string(JSON.stringify({"completed": completed}))
	f.close()

extends Node

## player_stats.gd — SPA-273: Persistent player statistics across play sessions.
## SPA-335: Added session-length flush, tutorial completion tracking, retry counter.
##
## Autoload singleton (PlayerStats). Tracks lifetime stats and per-scenario,
## per-difficulty bests. Persists to user://player_stats.json.
##
## Usage:
##   PlayerStats.start_session()                   # call when a new game begins
##   PlayerStats.flush_session_time()              # call on pause / app quit
##   PlayerStats.record_game(scenario_id, ...)     # call at game end
##   PlayerStats.record_tutorial_steps(sid, diff, seen, total) # call at game end
##   PlayerStats.record_retry(sid, diff)           # call when same scenario restarts
##   PlayerStats.get_scenario_stats(sid, diff)     # for stats screen
##   PlayerStats.get_totals()                      # global lifetime totals

const SAVE_PATH := "user://player_stats.json"
const VERSION   := 1

const DIFFICULTIES := ["apprentice", "master", "spymaster"]
const SCENARIO_IDS := ["scenario_1", "scenario_2", "scenario_3", "scenario_4"]

# ── In-session tracking ───────────────────────────────────────────────────────
var _session_start_time: int = 0

# ── Loaded data ───────────────────────────────────────────────────────────────
var _data: Dictionary = {}


func _ready() -> void:
	_data = _load()


## Mark the start of a new play session (call from main.gd when game begins).
func start_session() -> void:
	_session_start_time = int(Time.get_unix_time_from_system())


## Seconds elapsed since start_session(). Returns 0 if not started.
func get_session_duration_sec() -> int:
	if _session_start_time == 0:
		return 0
	return int(Time.get_unix_time_from_system()) - _session_start_time


## Persist current partial session time without ending the session.
## Call on pause or app quit so play time is not lost if the player exits mid-game.
## Resets the internal start time so the next flush / record_game only counts
## the time elapsed since this call.
func flush_session_time() -> void:
	if _session_start_time == 0:
		return
	var elapsed := int(Time.get_unix_time_from_system()) - _session_start_time
	_data["total_play_time_sec"] = _data.get("total_play_time_sec", 0) + elapsed
	_session_start_time = int(Time.get_unix_time_from_system())
	_save()


## Record the results of a completed game. Saves immediately.
##
## scenario_id   — e.g. "scenario_1"
## difficulty    — "apprentice", "master", or "spymaster"
## won           — true = victory, false = defeat
## days_taken    — day counter at resolution
## rumors_spread — propagation_engine.lineage.size()
## npcs_reached  — count of NPCs with non-empty rumor_slots
## peak_belief   — reputation score of the scenario target NPC (0-100)
## bribes_paid   — number of bribe actions used this session
func record_game(
	scenario_id:   String,
	difficulty:    String,
	won:           bool,
	days_taken:    int,
	rumors_spread: int,
	npcs_reached:  int,
	peak_belief:   int,
	bribes_paid:   int,
) -> void:
	var play_time := get_session_duration_sec()
	# Reset the session clock so a subsequent flush_session_time() doesn't double-count.
	_session_start_time = int(Time.get_unix_time_from_system())

	# ── Global totals ─────────────────────────────────────────────────────────
	_data["total_play_time_sec"]  = _data.get("total_play_time_sec",  0) + play_time
	_data["total_rumors_spread"]  = _data.get("total_rumors_spread",  0) + rumors_spread
	_data["total_npcs_convinced"] = _data.get("total_npcs_convinced", 0) + npcs_reached
	_data["total_bribes_paid"]    = _data.get("total_bribes_paid",    0) + bribes_paid

	# ── Per-scenario / per-difficulty ─────────────────────────────────────────
	if not _data.has("scenarios"):
		_data["scenarios"] = {}
	if not _data["scenarios"].has(scenario_id):
		_data["scenarios"][scenario_id] = {}
	if not _data["scenarios"][scenario_id].has(difficulty):
		_data["scenarios"][scenario_id][difficulty] = _blank_record()

	var rec: Dictionary = _data["scenarios"][scenario_id][difficulty]
	rec["games_played"] = rec.get("games_played", 0) + 1
	if won:
		rec["wins"] = rec.get("wins", 0) + 1
		var prev_fastest: int = rec.get("fastest_win_days", -1)
		if prev_fastest < 0 or days_taken < prev_fastest:
			rec["fastest_win_days"] = days_taken
	else:
		rec["losses"] = rec.get("losses", 0) + 1

	var score := _compute_score(rumors_spread, npcs_reached, peak_belief)
	if score > rec.get("best_score", 0):
		rec["best_score"] = score

	_save()


## Returns the stats record for a scenario + difficulty.
## Keys: games_played, wins, losses, best_score, fastest_win_days (-1 = never won).
func get_scenario_stats(scenario_id: String, difficulty: String) -> Dictionary:
	return _data.get("scenarios", {}).get(scenario_id, {}).get(difficulty, _blank_record())


## Record tutorial step completion for a finished game. Saves immediately.
## seen  — number of distinct tutorial tooltip IDs marked seen this session.
## total — total number of available tutorial steps (TutorialSystem.TOOLTIP_DATA.size()).
func record_tutorial_steps(
	scenario_id: String,
	difficulty:  String,
	seen:        int,
	total:       int,
) -> void:
	if not _data.has("scenarios"):
		_data["scenarios"] = {}
	if not _data["scenarios"].has(scenario_id):
		_data["scenarios"][scenario_id] = {}
	if not _data["scenarios"][scenario_id].has(difficulty):
		_data["scenarios"][scenario_id][difficulty] = _blank_record()
	var rec: Dictionary = _data["scenarios"][scenario_id][difficulty]
	rec["tutorial_steps_seen"]  = rec.get("tutorial_steps_seen",  0) + seen
	rec["tutorial_steps_total"] = rec.get("tutorial_steps_total", 0) + total
	_data["total_tutorial_steps_seen"]  = _data.get("total_tutorial_steps_seen",  0) + seen
	_data["total_tutorial_steps_total"] = _data.get("total_tutorial_steps_total", 0) + total
	_save()


## Increment the retry counter for a scenario + difficulty. Saves immediately.
## Call from main.gd when a player restarts the same scenario.
func record_retry(scenario_id: String, difficulty: String) -> void:
	if not _data.has("scenarios"):
		_data["scenarios"] = {}
	if not _data["scenarios"].has(scenario_id):
		_data["scenarios"][scenario_id] = {}
	if not _data["scenarios"][scenario_id].has(difficulty):
		_data["scenarios"][scenario_id][difficulty] = _blank_record()
	var rec: Dictionary = _data["scenarios"][scenario_id][difficulty]
	rec["retries"] = rec.get("retries", 0) + 1
	_data["total_retries"] = _data.get("total_retries", 0) + 1
	_save()


## Returns the lifetime global totals dictionary.
## Keys: total_play_time_sec, total_rumors_spread, total_npcs_convinced,
##       total_bribes_paid, total_retries, total_tutorial_steps_seen,
##       total_tutorial_steps_total.
func get_totals() -> Dictionary:
	return {
		"total_play_time_sec":         _data.get("total_play_time_sec",         0),
		"total_rumors_spread":         _data.get("total_rumors_spread",         0),
		"total_npcs_convinced":        _data.get("total_npcs_convinced",        0),
		"total_bribes_paid":           _data.get("total_bribes_paid",           0),
		"total_retries":               _data.get("total_retries",               0),
		"total_tutorial_steps_seen":   _data.get("total_tutorial_steps_seen",   0),
		"total_tutorial_steps_total":  _data.get("total_tutorial_steps_total",  0),
	}


## Returns true if any games have been recorded.
func has_any_data() -> bool:
	for sid in SCENARIO_IDS:
		for diff in DIFFICULTIES:
			if get_scenario_stats(sid, diff).get("games_played", 0) > 0:
				return true
	return false


## Record a post-scenario feedback response (SPA-336). Saves immediately.
##
## scenario_id   — e.g. "scenario_1"
## difficulty    — "apprentice", "master", or "spymaster"
## preset_index  — 0-3 matching FeedbackPrompt.PRESETS order, or -1 if none selected
## freetext      — optional open text (clamped to 200 chars on save)
func record_feedback(
	scenario_id:  String,
	difficulty:   String,
	preset_index: int,
	freetext:     String,
) -> void:
	if not _data.has("feedback"):
		_data["feedback"] = []
	_data["feedback"].append({
		"scenario_id":  scenario_id,
		"difficulty":   difficulty,
		"preset_index": preset_index,
		"freetext":     freetext.left(200),
		"timestamp":    int(Time.get_unix_time_from_system()),
	})
	_save()


## Wipes all recorded stats and saves (used by stats screen reset button).
func reset_all() -> void:
	_data = {}
	_save()


# ── Internal helpers ──────────────────────────────────────────────────────────

## Composite performance score for a single game.
## Weighted so rumors and NPCs matter, but peak belief is significant.
static func _compute_score(rumors_spread: int, npcs_reached: int, peak_belief: int) -> int:
	return rumors_spread * 5 + npcs_reached * 10 + peak_belief


static func _blank_record() -> Dictionary:
	return {
		"games_played":           0,
		"wins":                   0,
		"losses":                 0,
		"best_score":             0,
		"fastest_win_days":       -1,
		"retries":                0,
		"tutorial_steps_seen":    0,
		"tutorial_steps_total":   0,
	}


func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("PlayerStats: cannot open '%s' for reading" % SAVE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	push_warning("PlayerStats: malformed data in '%s', starting fresh" % SAVE_PATH)
	return {}


func _save() -> void:
	_data["version"] = VERSION
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("PlayerStats: cannot open '%s' for writing" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()

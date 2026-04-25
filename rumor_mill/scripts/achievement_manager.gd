extends Node

## achievement_manager.gd — Autoload singleton for Steam achievement tracking.
##
## Defines all achievement IDs and metadata.  On unlock, records the achievement
## locally (user://achievements.json) and emits achievement_unlocked.
## Actual Steam SDK calls are stubbed out; the TODO comment marks each one.
##
## Usage:
##   AchievementManager.unlock("scenario_1_complete")
##   AchievementManager.is_unlocked("ghost")
##   AchievementManager.get_all()  → Array of dicts with id/name/description/unlocked

# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Achievement definitions
# ---------------------------------------------------------------------------

## Static table: achievement_id → { name, description, steam_api_name }
const ACHIEVEMENTS: Dictionary = {
	"scenario_1_complete": {
		"name":           "The Alderman Falls",
		"description":    "Complete Scenario 1: The Alderman's Ruin.",
		"steam_api_name": "ACH_SCENARIO_1_COMPLETE",
	},
	"scenario_2_complete": {
		"name":           "The Town Fears",
		"description":    "Complete Scenario 2: The Plague Scare.",
		"steam_api_name": "ACH_SCENARIO_2_COMPLETE",
	},
	"scenario_3_complete": {
		"name":           "The New Order",
		"description":    "Complete Scenario 3: The Succession.",
		"steam_api_name": "ACH_SCENARIO_3_COMPLETE",
	},
	"scenario_4_complete": {
		"name":           "Faith Preserved",
		"description":    "Complete Scenario 4: The Holy Inquisition.",
		"steam_api_name": "ACH_SCENARIO_4_COMPLETE",
	},
	"scenario_5_complete": {
		"name":           "The People's Choice",
		"description":    "Complete Scenario 5: The Election.",
		"steam_api_name": "ACH_SCENARIO_5_COMPLETE",
	},
	"scenario_6_complete": {
		"name":           "Debts Collected",
		"description":    "Complete Scenario 6: The Merchant's Debt.",
		"steam_api_name": "ACH_SCENARIO_6_COMPLETE",
	},
	"master_victory": {
		"name":           "Seasoned Schemer",
		"description":    "Win any scenario on Master difficulty.",
		"steam_api_name": "ACH_MASTER_VICTORY",
	},
	"spymaster_victory": {
		"name":           "Shadow Weaver",
		"description":    "Win any scenario on Spymaster difficulty.",
		"steam_api_name": "ACH_SPYMASTER_VICTORY",
	},
	"whisper_network": {
		"name":           "The Web Is Cast",
		"description":    "Spread a rumor to 20 or more unique NPCs in a single game.",
		"steam_api_name": "ACH_WHISPER_NETWORK",
	},
	"ghost": {
		"name":           "Like a Ghost",
		"description":    "Win a scenario without ever being detected.",
		"steam_api_name": "ACH_GHOST",
	},
	"jack_of_all_trades": {
		"name":           "Every Tool",
		"description":    "Use all four action types (Observe, Eavesdrop, Craft Rumor, Bribe) in one playthrough.",
		"steam_api_name": "ACH_JACK_OF_ALL_TRADES",
	},
	"speedrunner": {
		"name":           "Rumor's Wind",
		"description":    "Win any scenario in under 10 days.",
		"steam_api_name": "ACH_SPEEDRUNNER",
	},
	"mastermind": {
		"name":           "Grand Manipulator",
		"description":    "Complete all six scenarios.",
		"steam_api_name": "ACH_MASTERMIND",
	},
	"a_rumor_begins": {
		"name":           "It Starts With a Whisper",
		"description":    "Seed your very first rumor.",
		"steam_api_name": "ACH_A_RUMOR_BEGINS",
	},
}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

const SAVE_PATH := "user://achievements.json"

## Set of unlocked achievement ids (id → true).
var _unlocked: Dictionary = {}

## True when GodotSteam initialised successfully this session.
var _steam_active: bool = false

## Late-bound reference to the Steam singleton (avoids parse-time errors when
## the GodotSteam GDExtension is not installed).
var _steam: Object = null


func _ready() -> void:
	_load()
	_init_steam()


func _process(_delta: float) -> void:
	if _steam_active:
		_steam.run_callbacks()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Unlock an achievement.  Safe to call multiple times; ignores already-unlocked ids.
func unlock(achievement_id: String) -> void:
	if _unlocked.has(achievement_id):
		return
	if not ACHIEVEMENTS.has(achievement_id):
		push_warning("[AchievementManager] Unknown achievement id: '%s'" % achievement_id)
		return

	_unlocked[achievement_id] = true
	_save()

	var display_name: String = ACHIEVEMENTS[achievement_id].get("name", achievement_id)

	if _steam_active:
		_steam.setAchievement(ACHIEVEMENTS[achievement_id]["steam_api_name"])
		_steam.storeStats()


## Returns true if the given achievement has been unlocked.
func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


## Returns an Array of all achievement definitions, each augmented with
## an "id" key and an "unlocked" bool.
func get_all() -> Array:
	var result: Array = []
	for ach_id in ACHIEVEMENTS:
		var entry: Dictionary = ACHIEVEMENTS[ach_id].duplicate()
		entry["id"]       = ach_id
		entry["unlocked"] = _unlocked.has(ach_id)
		result.append(entry)
	return result


# ---------------------------------------------------------------------------
# Steam helpers
# ---------------------------------------------------------------------------

## Attempt to initialise GodotSteam.  Sets _steam_active on success.
## Silently skips if the extension is not present (standalone / dev mode).
func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	var result: Dictionary = _steam.steamInitEx()
	if result.get("status", -1) == 0:  # STEAM_API_INIT_RESULT_OK
		_steam_active = true
	else:
		push_warning("[AchievementManager] Steam init failed: %s" % str(result.get("verbal", "unknown")))


# ---------------------------------------------------------------------------
# Persistence helpers
# ---------------------------------------------------------------------------

func _save() -> void:
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[AchievementManager] Could not open '%s' for writing (err %d)" % [
			tmp_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(_unlocked))
	file.close()
	# Atomically replace the achievements file so a crash mid-write cannot corrupt it.
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("[AchievementManager] Could not open user:// for atomic rename (err %d)" % DirAccess.get_open_error())
		return
	var rename_err := dir.rename(tmp_path, SAVE_PATH)
	if rename_err != OK:
		push_warning("[AchievementManager] Failed to rename '%s' to '%s' (err %d)" % [
			tmp_path, SAVE_PATH, rename_err])


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[AchievementManager] Could not open '%s' for reading (err %d)" % [
			SAVE_PATH, FileAccess.get_open_error()])
		return
	var text    := file.get_as_text()
	var parsed  = JSON.parse_string(text)
	if parsed is Dictionary:
		_unlocked = parsed
	else:
		push_warning("[AchievementManager] Save file parse error — resetting unlock state")
		_unlocked = {}

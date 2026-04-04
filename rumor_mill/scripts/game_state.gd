extends Node

## game_state.gd — Global singleton (autoload) for cross-scene state.
##
## Stores the scenario selected in the main menu so World can read it
## after the scene transition. Persists across scene changes.

## The scenario id chosen by the player. Matches "scenarioId" keys in
## scenarios.json: "scenario_1", "scenario_2", "scenario_3".
var selected_scenario_id: String = "scenario_1"

## The difficulty preset chosen by the player: "apprentice", "master", or "spymaster".
var selected_difficulty: String = "master"

## Returns the modifier dictionary for the given difficulty preset.
## Keys:
##   whisper_bonus          — added to PlayerIntelStore.MAX_DAILY_WHISPERS
##   action_bonus           — added to PlayerIntelStore.MAX_DAILY_ACTIONS
##   heat_decay             — heat decay per day (replaces the default 6.0)
##   days_bonus             — added to scenario daysAllowed
##   rival_cooldown_offset  — added to RivalAgent cooldown each cycle (positive = slower)
static func get_difficulty_modifiers(preset: String) -> Dictionary:
	match preset:
		"apprentice":
			return {
				"whisper_bonus":             1,
				"action_bonus":              1,
				"heat_decay":                8.0,
				"days_bonus":                5,
				"rival_cooldown_offset":     1,
				"inquisitor_cooldown_offset": 1,
			}
		"spymaster":
			return {
				"whisper_bonus":             -1,
				"action_bonus":              -1,
				"heat_decay":                3.0,
				"days_bonus":                -5,
				"rival_cooldown_offset":     -1,
				"inquisitor_cooldown_offset": -1,
			}
		_:  # "master" — normal defaults
			return {
				"whisper_bonus":             0,
				"action_bonus":              0,
				"heat_decay":                6.0,
				"days_bonus":                0,
				"rival_cooldown_offset":     0,
				"inquisitor_cooldown_offset": 0,
			}

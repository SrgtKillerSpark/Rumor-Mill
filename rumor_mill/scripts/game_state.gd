extends Node

## game_state.gd — Global singleton (autoload) for cross-scene state.
##
## Stores the scenario selected in the main menu so World can read it
## after the scene transition. Persists across scene changes.

## The scenario id chosen by the player. Matches "scenarioId" keys in
## scenarios.json: "scenario_1", "scenario_2", "scenario_3".
var selected_scenario_id: String = "scenario_1"

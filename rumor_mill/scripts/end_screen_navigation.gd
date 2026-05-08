class_name EndScreenNavigation
extends RefCounted

## end_screen_navigation.gd — Scenario sequencing and button-handler coroutines
## for EndScreen.
##
## Extracted from end_screen.gd (SPA-1016). Owns scenario ordering, the
## next-scenario tease loader, and the three main button actions
## (Play Again / Next Scenario / Main Menu).
##
## Call setup(tree) once. Set the active scenario id via set_scenario_id()
## before the button actions are triggered.

var _tree:                SceneTree = null
var _current_scenario_id: String   = ""


func setup(tree: SceneTree) -> void:
	_tree = tree


func set_scenario_id(id: String) -> void:
	_current_scenario_id = id


## Returns the next scenario's string id, or "" if there is none.
static func next_scenario_id(current: String) -> String:
	match current:
		"scenario_1": return "scenario_2"
		"scenario_2": return "scenario_3"
		"scenario_3": return "scenario_4"
		"scenario_4": return "scenario_5"
		"scenario_5": return "scenario_6"
	return ""


## Load title + teaseHook for the given scenario id from scenarios.json.
static func load_next_scenario_tease(scenario_id: String) -> String:
	const SCENARIOS_PATH := "res://data/scenarios.json"
	if not FileAccess.file_exists(SCENARIOS_PATH):
		return ""
	var file := FileAccess.open(SCENARIOS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return ""
	for entry: Variant in parsed as Array:
		if not (entry is Dictionary):
			continue
		if (entry as Dictionary).get("scenarioId", "") != scenario_id:
			continue
		var title: String = str((entry as Dictionary).get("title", ""))
		var hook: String  = str((entry as Dictionary).get("teaseHook",
				(entry as Dictionary).get("hookText", "")))
		if title.is_empty():
			return ""
		if hook.is_empty():
			return "Next: " + title
		return "Next: " + title + " \u2014 " + hook
	return ""


func on_play_again() -> void:
	var pause_menu_script = preload("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = _current_scenario_id
	await TransitionManager.fade_out(0.35)
	_tree.reload_current_scene()


func on_next_scenario() -> void:
	var next_id := next_scenario_id(_current_scenario_id)
	if next_id.is_empty():
		return
	var pause_menu_script = preload("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = next_id
	await TransitionManager.fade_out(0.35)
	_tree.reload_current_scene()


func on_main_menu() -> void:
	var pause_menu_script = preload("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = ""
	await TransitionManager.fade_out(0.35)
	_tree.reload_current_scene()

extends CanvasLayer

## objective_hud.gd — Persistent HUD showing scenario objective and day counter.
##
## Shows at the top-left of the screen:
##   • Scenario title
##   • One-line objective (first sentence of startingText)
##   • "Day X / Y" counter, updated each in-game day
##
## Call setup(scenario_manager, day_night) after the game starts.

@onready var title_label:     Label = $Panel/VBox/TitleLabel
@onready var objective_label: Label = $Panel/VBox/ObjectiveLabel
@onready var day_label:       Label = $Panel/VBox/DayLabel

var _scenario_manager: ScenarioManager = null
var _day_night:        Node            = null
var _days_allowed:     int             = 30


func _ready() -> void:
	layer = 4


func setup(scenario_manager: ScenarioManager, day_night: Node) -> void:
	_scenario_manager = scenario_manager
	_day_night        = day_night
	_days_allowed     = scenario_manager.get_days_allowed()
	_refresh()
	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)


func _on_day_changed(_day: int) -> void:
	_refresh()


func _refresh() -> void:
	if _scenario_manager == null:
		return

	title_label.text = _scenario_manager.get_title()

	var starting_text: String = _scenario_manager.get_starting_text()
	var dot_pos: int = starting_text.find(".")
	var objective: String = starting_text if dot_pos == -1 else starting_text.substr(0, dot_pos + 1)
	objective_label.text = objective

	if _day_night != null:
		var current_day: int = _day_night.current_day
		day_label.text = "Day %d / %d" % [current_day, _days_allowed]
	else:
		day_label.text = "Day — / %d" % _days_allowed

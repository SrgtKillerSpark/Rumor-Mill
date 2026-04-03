extends CanvasLayer

## objective_hud.gd — Persistent HUD showing scenario objective and day counter.
##
## Shows at the top-left of the screen:
##   • Scenario title (gold)
##   • One-line objective (first sentence of startingText)
##   • "Day X / Y" counter + current time-of-day label, updated each tick
##   • Amber day progress bar that fills as days pass

@onready var title_label:     Label     = $Panel/VBox/TitleLabel
@onready var objective_label: Label     = $Panel/VBox/ObjectiveLabel
@onready var day_label:       Label     = $Panel/VBox/DayRow/DayLabel
@onready var time_label:      Label     = $Panel/VBox/DayRow/TimeOfDayLabel
@onready var progress_bar:    ColorRect = $Panel/VBox/DayProgressBG/DayProgressBar
@onready var progress_bg:     ColorRect = $Panel/VBox/DayProgressBG

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
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_tick)


func _on_day_changed(_day: int) -> void:
	_refresh()


func _on_tick(_tick: int) -> void:
	_refresh_time()


func _refresh() -> void:
	if _scenario_manager == null:
		return

	title_label.text = _scenario_manager.get_title()

	var starting_text: String = _scenario_manager.get_starting_text()
	var dot_pos: int = starting_text.find(".")
	var objective: String = starting_text if dot_pos == -1 else starting_text.substr(0, dot_pos + 1)
	objective_label.text = objective

	_refresh_time()


func _refresh_time() -> void:
	if _day_night == null:
		return

	var current_day: int = _day_night.current_day
	day_label.text = "Day %d / %d" % [current_day, _days_allowed]

	# Update time-of-day label.
	if "current_tick" in _day_night and "ticks_per_day" in _day_night:
		var tick: int      = _day_night.current_tick
		var tpd:  int      = _day_night.ticks_per_day
		var hour: float    = float(tick) / float(tpd) * 24.0
		var h:    int      = int(hour) % 24
		var m:    int      = int((hour - int(hour)) * 60.0)
		var ampm: String   = "AM" if h < 12 else "PM"
		var h12:  int      = h % 12
		if h12 == 0:
			h12 = 12
		time_label.text = "%d:%02d %s" % [h12, m, ampm]

	# Update progress bar width as a fraction of days_allowed.
	if progress_bar != null and progress_bg != null:
		var fraction: float = clampf(float(current_day - 1) / float(max(_days_allowed - 1, 1)), 0.0, 1.0)
		# Animate the bar width by adjusting anchor_right.
		progress_bar.anchor_right = fraction
		# Colour shifts from amber → orange-red in the last 25% of days.
		if fraction >= 0.75:
			var t: float = (fraction - 0.75) / 0.25
			progress_bar.color = Color(0.85 + 0.1 * t, 0.55 - 0.35 * t, 0.10 - 0.10 * t, 1.0)
		else:
			progress_bar.color = Color(0.85, 0.55, 0.10, 1.0)

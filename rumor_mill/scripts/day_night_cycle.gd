extends Node

## day_night_cycle.gd — drives the game tick loop and a visual day/night modulate.
##
## Time model:
##   • One in-game "day" = TICKS_PER_DAY ticks.
##   • Real time per tick is controlled by TICK_DURATION_SECONDS.
##   • The CanvasModulate colour shifts from bright noon to dark midnight and back.

signal game_tick(tick: int)
signal day_changed(day: int)

@export var tick_duration_seconds: float = 1.0   ## Real seconds between ticks
@export var ticks_per_day: int = 24              ## Ticks that make one full day

## Visual colours for key time-of-day points (hour 0-23 mapped to tick 0-23)
const TIME_COLORS: Dictionary = {
	0:  Color(0.10, 0.12, 0.25),   # midnight — deep blue-black
	4:  Color(0.08, 0.10, 0.20),   # pre-dawn
	6:  Color(0.60, 0.45, 0.30),   # sunrise — warm amber
	10: Color(1.00, 1.00, 0.95),   # late morning — bright white
	12: Color(1.00, 1.00, 1.00),   # noon
	16: Color(1.00, 0.95, 0.80),   # afternoon — golden
	18: Color(0.80, 0.55, 0.30),   # sunset — orange
	20: Color(0.35, 0.30, 0.55),   # dusk — purple
	22: Color(0.15, 0.15, 0.30),   # evening
	23: Color(0.10, 0.12, 0.25),   # late night
}

var current_tick: int = 0
var current_day: int = 1

# ── Day transition flash overlay ──────────────────────────────────────────────
var _day_flash_rect:  ColorRect = null
var _day_flash_tween: Tween     = null

@onready var tick_timer:      Timer          = $TickTimer
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
# time_label removed — time is displayed via ObjectiveHUD
var time_label: Label = null


func _ready() -> void:
	tick_timer.wait_time = tick_duration_seconds
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	tick_timer.start()
	_apply_time_of_day(0)
	_update_time_label()
	_build_day_flash_overlay()


func _build_day_flash_overlay() -> void:
	# A full-screen ColorRect on a CanvasLayer that briefly flashes when the day turns.
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_day_flash_rect = ColorRect.new()
	_day_flash_rect.color = Color(0.95, 0.90, 0.60, 0.0)  # warm parchment, fully transparent
	_day_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_day_flash_rect)


func _on_tick_timer_timeout() -> void:
	current_tick += 1
	var hour_of_day: int = current_tick % ticks_per_day
	if hour_of_day == 0:
		current_day += 1
		emit_signal("day_changed", current_day)
		_play_day_transition_flash()
	emit_signal("game_tick", current_tick)
	_apply_time_of_day(hour_of_day)
	_update_time_label()


func _play_day_transition_flash() -> void:
	if _day_flash_rect == null:
		return
	if _day_flash_tween != null and _day_flash_tween.is_valid():
		_day_flash_tween.kill()
	_day_flash_tween = create_tween()
	# Fade in to a soft warm glow, then fade back out.
	_day_flash_tween.tween_property(_day_flash_rect, "color:a", 0.30, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_day_flash_tween.tween_property(_day_flash_rect, "color:a", 0.0,  0.55) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _apply_time_of_day(hour: int) -> void:
	# Interpolate between the two nearest keyframe colours.
	var keys: Array = TIME_COLORS.keys()
	keys.sort()

	var prev_hour: int = keys[0]
	var next_hour: int = keys[keys.size() - 1]

	for k in keys:
		if k <= hour:
			prev_hour = k
		if k >= hour and k < next_hour:
			next_hour = k
			break

	if prev_hour == next_hour:
		canvas_modulate.color = TIME_COLORS[prev_hour]
		return

	var t := float(hour - prev_hour) / float(next_hour - prev_hour)
	canvas_modulate.color = TIME_COLORS[prev_hour].lerp(TIME_COLORS[next_hour], t)


func _update_time_label() -> void:
	if time_label == null:
		return
	var hour_of_day: int = current_tick % ticks_per_day
	var period := "AM" if hour_of_day < 12 else "PM"
	var display_hour: int = hour_of_day % 12
	if display_hour == 0:
		display_hour = 12
	time_label.text = "Day %d  |  %02d:00 %s  (Tick %d)" % [current_day, display_hour, period, current_tick]


## Pause / resume the tick loop (e.g. when the game is paused).
func set_paused(paused: bool) -> void:
	if paused:
		tick_timer.stop()
	else:
		tick_timer.start()

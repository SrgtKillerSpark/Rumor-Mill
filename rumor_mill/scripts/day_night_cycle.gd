extends Node

## day_night_cycle.gd — drives the game tick loop and a visual day/night modulate.
##
## Time model:
##   • One in-game "day" = TICKS_PER_DAY ticks.
##   • Real time per tick is controlled by TICK_DURATION_SECONDS.
##   • The CanvasModulate colour shifts from bright noon to dark midnight and back.

signal game_tick(tick: int)
signal day_changed(day: int)
## Emitted at the start of the day transition flash so HUDs can react.
signal day_transition_started(day: int)

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

# Precomputed sorted list of TIME_COLORS keys — avoids re-sorting every tick.
var _time_keys: Array = []

# ── Day transition flash overlay ──────────────────────────────────────────────
var _day_flash_rect:    ColorRect = null
var _day_flash_tween:   Tween     = null
var _day_banner_label:  Label     = null
var _day_banner_tween:  Tween     = null
var _day_obj_label:     Label     = null
var _day_obj_tween:     Tween     = null
## Set by World after ScenarioManager is ready. Called with no args; returns String.
var objective_text_provider: Callable

# ── Directional shadow gradient (SPA-586) ─────────────────────────────────────
# A subtle full-screen gradient that shifts direction as the sun moves:
# dawn → warm light from the left; dusk → warm light from the right.
# Layer 1 keeps it above terrain but below HUD.
var _shadow_layer: CanvasLayer    = null
var _shadow_rect:  ColorRect      = null
var _shadow_mat:   ShaderMaterial = null

@onready var tick_timer:      Timer          = $TickTimer
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
# time_label removed — time is displayed via ObjectiveHUD
var time_label: Label = null


func _ready() -> void:
	_time_keys = TIME_COLORS.keys()
	_time_keys.sort()
	tick_duration_seconds = SettingsManager.game_speed
	tick_timer.wait_time = tick_duration_seconds
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	tick_timer.start()
	_apply_time_of_day(0)
	_update_time_label()
	_build_day_flash_overlay()
	_build_shadow_overlay()
	emit_signal("game_tick", 0)


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

	# Day number banner that fades in over the flash.
	_day_banner_label = Label.new()
	_day_banner_label.set_anchors_preset(Control.PRESET_CENTER)
	_day_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_banner_label.anchor_left   = 0.5
	_day_banner_label.anchor_right  = 0.5
	_day_banner_label.anchor_top    = 0.5
	_day_banner_label.anchor_bottom = 0.5
	_day_banner_label.offset_left   = -200.0
	_day_banner_label.offset_right  =  200.0
	_day_banner_label.offset_top    = -30.0
	_day_banner_label.offset_bottom =  30.0
	_day_banner_label.add_theme_font_size_override("font_size", 28)
	# Dark ink on the warm flash — reads as medieval manuscript.
	_day_banner_label.add_theme_color_override("font_color", Color(0.22, 0.12, 0.04, 1.0))
	_day_banner_label.add_theme_constant_override("outline_size", 2)
	_day_banner_label.add_theme_color_override("font_outline_color", Color(0.95, 0.85, 0.55, 0.5))
	_day_banner_label.modulate.a = 0.0
	_day_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_day_banner_label)

	# Scenario objective reminder — fades in below the day number.
	_day_obj_label = Label.new()
	_day_obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_obj_label.anchor_left   = 0.5
	_day_obj_label.anchor_right  = 0.5
	_day_obj_label.anchor_top    = 0.5
	_day_obj_label.anchor_bottom = 0.5
	_day_obj_label.offset_left   = -230.0
	_day_obj_label.offset_right  =  230.0
	_day_obj_label.offset_top    =  14.0
	_day_obj_label.offset_bottom =  40.0
	_day_obj_label.add_theme_font_size_override("font_size", 13)
	_day_obj_label.add_theme_color_override("font_color", Color(0.30, 0.18, 0.06, 1.0))
	_day_obj_label.add_theme_constant_override("outline_size", 1)
	_day_obj_label.add_theme_color_override("font_outline_color", Color(0.95, 0.85, 0.55, 0.4))
	_day_obj_label.modulate.a = 0.0
	_day_obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_day_obj_label)


func _on_tick_timer_timeout() -> void:
	current_tick += 1
	var hour_of_day: int = current_tick % ticks_per_day
	if hour_of_day == 0:
		current_day += 1
		emit_signal("day_transition_started", current_day)
		emit_signal("day_changed", current_day)
		_play_day_transition_flash()
	emit_signal("game_tick", current_tick)
	_apply_time_of_day(hour_of_day)
	_update_shadow_direction(hour_of_day)
	_update_time_label()


func _play_day_transition_flash() -> void:
	if _day_flash_rect == null:
		return

	if _day_flash_tween != null and _day_flash_tween.is_valid():
		_day_flash_tween.kill()
	if _day_banner_tween != null and _day_banner_tween.is_valid():
		_day_banner_tween.kill()

	# Warm parchment flash — fade in then out.
	_day_flash_tween = create_tween()
	_day_flash_tween.tween_property(_day_flash_rect, "color:a", 0.30, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_day_flash_tween.tween_property(_day_flash_rect, "color:a", 0.0,  0.55) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	# Day number banner — fades in over the flash, then fades out.
	if _day_banner_label != null:
		_day_banner_label.text = "Day %d" % current_day
		_day_banner_label.modulate.a = 0.0
		_day_banner_tween = create_tween()
		_day_banner_tween.tween_property(_day_banner_label, "modulate:a", 1.0, 0.30) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_day_banner_tween.tween_interval(0.20)
		_day_banner_tween.tween_property(_day_banner_label, "modulate:a", 0.0, 0.55) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	# Scenario objective reminder — same timing as the day banner.
	if _day_obj_label != null:
		var obj_text := ""
		if objective_text_provider.is_valid():
			obj_text = objective_text_provider.call()
		if not obj_text.is_empty():
			if _day_obj_tween != null and _day_obj_tween.is_valid():
				_day_obj_tween.kill()
			_day_obj_label.text = obj_text
			_day_obj_label.modulate.a = 0.0
			_day_obj_tween = create_tween()
			_day_obj_tween.tween_property(_day_obj_label, "modulate:a", 1.0, 0.30) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			_day_obj_tween.tween_interval(0.20)
			_day_obj_tween.tween_property(_day_obj_label, "modulate:a", 0.0, 0.55) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _apply_time_of_day(hour: int) -> void:
	# Interpolate between the two nearest keyframe colours.
	# When hour exceeds the last key (ticks_per_day > max key), wrap toward
	# the first key of the next cycle to avoid a hard colour snap at midnight.
	var last_key: int = _time_keys[_time_keys.size() - 1]
	var prev_hour: int = _time_keys[0]
	var next_hour: int = last_key

	for k in _time_keys:
		if k <= hour:
			prev_hour = k
		if k >= hour and k < next_hour:
			next_hour = k
			break

	if prev_hour == next_hour:
		# Past the last key: interpolate toward the first key of the next cycle.
		if hour > last_key:
			var wrap_span: int = ticks_per_day - last_key
			if wrap_span > 0:
				var t := float(hour - last_key) / float(wrap_span)
				canvas_modulate.color = TIME_COLORS[last_key].lerp(TIME_COLORS[_time_keys[0]], t)
				return
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


## SPA-757: Skip remaining ticks in the current day and advance to the next dawn.
## Emits day_changed / day_transition_started as if the day had ended normally,
## then fires game_tick for each skipped tick so listeners stay in sync.
signal day_skipped(new_day: int)

func skip_to_next_day() -> void:
	var hour_of_day: int = current_tick % ticks_per_day
	if hour_of_day == 0:
		return  # already at dawn — nothing to skip
	var ticks_remaining: int = ticks_per_day - hour_of_day
	current_tick += ticks_remaining
	current_day += 1
	emit_signal("day_transition_started", current_day)
	emit_signal("day_changed", current_day)
	_play_day_transition_flash()
	emit_signal("game_tick", current_tick)
	_apply_time_of_day(0)
	_update_shadow_direction(0)
	_update_time_label()
	day_skipped.emit(current_day)


# ── Directional shadow overlay (SPA-586) ──────────────────────────────────────

func _build_shadow_overlay() -> void:
	_shadow_layer = CanvasLayer.new()
	_shadow_layer.layer = 1   # above terrain/atmo, below HUD
	add_child(_shadow_layer)

	_shadow_rect = ColorRect.new()
	_shadow_rect.name = "ShadowOverlay"
	_shadow_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

// origin: where the "sun" is (0=left edge, 1=right edge, 0.5=overhead noon).
uniform float u_sun_x      : hint_range(0.0, 1.0) = 0.5;
// strength: overall alpha of the effect (0 at noon/night, max at dawn/dusk).
uniform float u_strength   : hint_range(0.0, 1.0) = 0.0;
// warm: 1.0 for sunrise/sunset warm tint, 0.0 for flat shadow.
uniform float u_warm       : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float dist = abs(UV.x - u_sun_x);
	// A soft ramp: bright on the sun side, dark shadow on the far side.
	float shadow = smoothstep(0.0, 1.0, dist);
	// Warm amber for sunrise/sunset, cool grey for general shadow.
	vec3 warm_col  = vec3(0.90, 0.55, 0.15);
	vec3 cool_col  = vec3(0.05, 0.08, 0.20);
	vec3 col = mix(cool_col, warm_col, u_warm);
	COLOR = vec4(col, shadow * u_strength);
}
"""
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = shader
	_shadow_mat.set_shader_parameter("u_sun_x",   0.5)
	_shadow_mat.set_shader_parameter("u_strength", 0.0)
	_shadow_mat.set_shader_parameter("u_warm",     0.0)
	_shadow_rect.material = _shadow_mat
	_shadow_layer.add_child(_shadow_rect)


func _update_shadow_direction(hour: int) -> void:
	if _shadow_mat == null:
		return

	# Sun moves from left (dawn/east) at hour 6 to right (dusk/west) at hour 18.
	# Overnight it is below the horizon — no directional effect.
	var sun_x:    float = 0.5
	var strength: float = 0.0
	var warm:     float = 0.0

	if hour >= 6 and hour <= 18:
		# Normalise 6→18 to 0→1 so sun_x goes 0.05 (left) → 0.95 (right)
		var t: float = float(hour - 6) / 12.0
		sun_x = lerp(0.05, 0.95, t)

		# Golden hour strength peaks at dawn and dusk
		# Use a sine curve peaking at dawn (t=0) and dusk (t=1), valley at noon (t=0.5)
		var noon_dip: float = abs(t - 0.5) * 2.0   # 0 at noon, 1 at dawn/dusk
		strength = noon_dip * 0.18   # max 18% alpha — subtle
		warm = smoothstep(0.4, 1.0, noon_dip)

	_shadow_mat.set_shader_parameter("u_sun_x",    sun_x)
	_shadow_mat.set_shader_parameter("u_strength", strength)
	_shadow_mat.set_shader_parameter("u_warm",     warm)

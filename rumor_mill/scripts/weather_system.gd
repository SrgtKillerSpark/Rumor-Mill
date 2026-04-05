extends Node

## weather_system.gd — occasional rain overlay with a sound hook (SPA-586).
##
## Visual: a full-screen shader overlay on CanvasLayer 3 draws animated
## rain streaks.  Weather is purely decorative — it does not affect gameplay.
##
## Audio hook: emits weather_changed("rain") / weather_changed("clear") so the
## AudioManager (or any other listener) can fade in rain SFX when ready.
##
## Integration:
##   var _weather := WeatherSystem.new()
##   add_child(_weather)
##   _weather.weather_changed.connect(_on_weather_changed)
##   # then each tick:
##   _weather.on_game_tick(tick, ticks_per_day)
##
## Rain is triggered randomly: roughly once per day on average, lasting 2–5 hours.
## It never starts at midnight (hour 0) so the day-transition flash is unobscured.

signal weather_changed(type: String)   ## "rain" or "clear"

# ── Tuning constants ──────────────────────────────────────────────────────────

## Probability per tick that rain begins (when it is currently clear).
## At 24 ticks/day this gives ~1 rain event every 2–3 days on average.
const RAIN_START_CHANCE  := 0.04

## Probability per tick that rain ends (when it is currently raining).
## At 24 ticks/day this makes rain last ~3–5 ticks (hours) on average.
const RAIN_STOP_CHANCE   := 0.22

## Rain never starts during midnight (hour 0) — keeps day flash unobscured.
const RAIN_FORBIDDEN_HOUR := 0

## Max alpha for the rain overlay (0.0 – 1.0).
const RAIN_MAX_ALPHA := 0.55

# ── State ─────────────────────────────────────────────────────────────────────

var _layer:       CanvasLayer    = null
var _rect:        ColorRect      = null
var _mat:         ShaderMaterial = null
var _fade_tween:  Tween          = null

var is_raining:   bool  = false
var _rain_time:   float = 0.0   # accumulated seconds (drives shader animation)


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_build_rain_overlay()


func _process(delta: float) -> void:
	if is_raining and _mat != null:
		_rain_time += delta
		_mat.set_shader_parameter("u_time", _rain_time)


# ── Overlay builder ───────────────────────────────────────────────────────────

func _build_rain_overlay() -> void:
	_rect = ColorRect.new()
	_rect.name = "RainOverlay"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0  # starts fully invisible

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float u_time : hint_range(0.0, 9999.0) = 0.0;
uniform vec4  u_streak_color : source_color = vec4(0.55, 0.65, 0.80, 1.0);

// Pseudo-random helper
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Tile the screen into a grid of cells; each cell holds one streak.
	vec2 grid = vec2(40.0, 15.0);   // columns x rows
	vec2 cell = floor(UV * grid);
	vec2 local = fract(UV * grid);

	// Per-cell random offsets
	float r_x     = rand(cell);
	float r_speed = 0.6 + rand(cell + vec2(1.0, 0.0)) * 1.6;
	float r_len   = 0.05 + rand(cell + vec2(2.0, 0.0)) * 0.20;
	float r_alpha = 0.5  + rand(cell + vec2(3.0, 0.0)) * 0.5;

	// Streak x position (slight diagonal)
	float sx = r_x + local.y * 0.10;

	// Streak falls over time, wrapping within the cell
	float sy = fract(local.y - u_time * r_speed * 0.6);

	// Draw a thin vertical streak
	float x_dist  = abs(local.x - r_x);
	float on_streak = step(x_dist, 0.025);
	float on_len    = step(sy, r_len);

	float alpha = on_streak * on_len * r_alpha;
	COLOR = vec4(u_streak_color.rgb, alpha * u_streak_color.a);
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("u_time", 0.0)
	_rect.material = _mat
	_layer.add_child(_rect)


# ── Public API ────────────────────────────────────────────────────────────────

## Called by world.gd each game tick.
func on_game_tick(tick: int, ticks_per_day: int) -> void:
	var hour: int = tick % ticks_per_day
	if is_raining:
		if randf() < RAIN_STOP_CHANCE:
			_stop_rain()
	else:
		if hour != RAIN_FORBIDDEN_HOUR and randf() < RAIN_START_CHANCE:
			_start_rain()


func _start_rain() -> void:
	if is_raining:
		return
	is_raining = true
	_rain_time  = 0.0
	_set_overlay_alpha(RAIN_MAX_ALPHA, 2.5)
	emit_signal("weather_changed", "rain")


func _stop_rain() -> void:
	if not is_raining:
		return
	is_raining = false
	_set_overlay_alpha(0.0, 3.0)
	emit_signal("weather_changed", "clear")


func _set_overlay_alpha(target: float, duration: float) -> void:
	if _rect == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_rect, "modulate:a", target, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

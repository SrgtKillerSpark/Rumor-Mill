extends Node

## ambient_particles.gd — time-of-day atmospheric particle effects (SPA-586).
##
## Manages three screen-space CPUParticles2D emitters on a dedicated CanvasLayer:
##   • dust_motes  — warm golden specks drifting upward during daylight (08–18)
##   • fireflies   — blinking yellow-green orbs at dusk (19–21)
##   • night_sparks — cold blue-white sparkles at night (20–06)
##
## Connect to DayNightCycle by calling on_game_tick(tick, ticks_per_day) each tick.
## Performance: all three emitters are CPUParticles2D with low particle counts;
## emitters that are off-hour have emitting = false so they cost near-zero CPU.

# Hour windows (24-hour clock, matching ticks_per_day == 24 default)
const DUST_START    := 8
const DUST_END      := 18
const FIREFLY_START := 19
const FIREFLY_END   := 21
const NIGHT_START   := 20   # overlaps firefly end; night runs until DUST_START

var _layer:         CanvasLayer      = null
var _dust:          CPUParticles2D   = null
var _firefly:       CPUParticles2D   = null
var _night:         CPUParticles2D   = null

var _ticks_per_day: int = 24


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2   # above terrain (0), below HUD (10+)
	add_child(_layer)
	_build_dust_motes()
	_build_fireflies()
	_build_night_sparks()
	_apply_hour(0)


# ── Emitter builders ──────────────────────────────────────────────────────────

func _build_dust_motes() -> void:
	_dust = CPUParticles2D.new()
	_dust.name = "DustMotes"
	_dust.amount        = 35
	_dust.lifetime      = 9.0
	_dust.one_shot      = false
	_dust.explosiveness = 0.0
	_dust.randomness    = 1.0

	# Spread evenly across a large screen-covering rectangle
	_dust.emission_shape         = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents  = Vector2(700, 400)
	_dust.position               = Vector2(576, 324)  # nominal screen centre (1152×648)

	_dust.direction              = Vector2(0.15, -1.0)
	_dust.spread                 = 25.0
	_dust.gravity                = Vector2(0.0, -5.0)
	_dust.initial_velocity_min   = 8.0
	_dust.initial_velocity_max   = 18.0
	_dust.scale_amount_min       = 1.0
	_dust.scale_amount_max       = 3.0

	# Warm golden; alpha ramp fades in then out over the particle lifetime
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.00, 0.90, 0.55, 0.0))
	ramp.add_point(0.20, Color(1.00, 0.90, 0.55, 0.55))
	ramp.add_point(0.80, Color(1.00, 0.90, 0.55, 0.45))
	ramp.set_color(1, Color(1.00, 0.90, 0.55, 0.0))
	_dust.color_ramp = ramp

	_layer.add_child(_dust)


func _build_fireflies() -> void:
	_firefly = CPUParticles2D.new()
	_firefly.name = "Fireflies"
	_firefly.amount        = 18
	_firefly.lifetime      = 5.0
	_firefly.one_shot      = false
	_firefly.explosiveness = 0.0
	_firefly.randomness    = 1.0

	_firefly.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_firefly.emission_rect_extents = Vector2(650, 360)
	_firefly.position              = Vector2(576, 324)

	_firefly.direction             = Vector2(0.0, -1.0)
	_firefly.spread                = 80.0   # wide spread so they wander
	_firefly.gravity               = Vector2(0.0, 0.0)
	_firefly.initial_velocity_min  = 5.0
	_firefly.initial_velocity_max  = 20.0
	_firefly.scale_amount_min      = 2.5
	_firefly.scale_amount_max      = 5.0

	# Yellow-green blink effect via scale curve gives a "blinking" visual
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.15, 1.0))
	scale_curve.add_point(Vector2(0.45, 0.2))
	scale_curve.add_point(Vector2(0.60, 1.0))
	scale_curve.add_point(Vector2(0.80, 0.1))
	scale_curve.add_point(Vector2(1.0,  0.0))
	_firefly.scale_curve = scale_curve

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.70, 1.00, 0.30, 0.0))
	ramp.add_point(0.15, Color(0.80, 1.00, 0.40, 0.90))
	ramp.add_point(0.50, Color(0.90, 1.00, 0.50, 0.70))
	ramp.add_point(0.85, Color(0.80, 1.00, 0.40, 0.80))
	ramp.set_color(1, Color(0.70, 1.00, 0.30, 0.0))
	_firefly.color_ramp = ramp

	_layer.add_child(_firefly)


func _build_night_sparks() -> void:
	_night = CPUParticles2D.new()
	_night.name = "NightSparks"
	_night.amount        = 25
	_night.lifetime      = 12.0
	_night.one_shot      = false
	_night.explosiveness = 0.0
	_night.randomness    = 1.0

	_night.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_night.emission_rect_extents = Vector2(700, 400)
	_night.position              = Vector2(576, 324)

	# Barely drifting — mimics lantern ember glow / far stars
	_night.direction             = Vector2(0.0, -1.0)
	_night.spread                = 45.0
	_night.gravity               = Vector2(0.0, 0.0)
	_night.initial_velocity_min  = 2.0
	_night.initial_velocity_max  = 8.0
	_night.scale_amount_min      = 1.0
	_night.scale_amount_max      = 3.0

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.00, 0.80, 0.40, 0.0))
	ramp.add_point(0.25, Color(1.00, 0.85, 0.50, 0.70))
	ramp.add_point(0.75, Color(0.90, 0.75, 0.35, 0.55))
	ramp.set_color(1, Color(0.80, 0.65, 0.30, 0.0))
	_night.color_ramp = ramp

	_layer.add_child(_night)


# ── Public API ────────────────────────────────────────────────────────────────

## Called by world.gd each game tick to update which emitters are active.
func on_game_tick(tick: int, ticks_per_day: int) -> void:
	_ticks_per_day = ticks_per_day
	var hour: int = tick % ticks_per_day
	_apply_hour(hour)


func _apply_hour(hour: int) -> void:
	var want_dust:    bool = (hour >= DUST_START and hour < DUST_END)
	var want_firefly: bool = (hour >= FIREFLY_START and hour < FIREFLY_END)
	var want_night:   bool = (hour >= NIGHT_START or hour < DUST_START)

	if _dust    != null: _dust.emitting    = want_dust
	if _firefly != null: _firefly.emitting = want_firefly
	if _night   != null: _night.emitting   = want_night

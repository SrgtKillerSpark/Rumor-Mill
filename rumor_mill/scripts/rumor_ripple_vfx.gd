extends Node2D

## rumor_ripple_vfx.gd — SPA-805: Expanding ring VFX played at the seed target NPC.
##
## Spawned by main.gd when the player successfully seeds a rumor.
## Draws 3 concentric rings that expand outward and fade over DURATION seconds.
## Self-frees on completion — no cleanup required by caller.
##
## Usage:
##   var fx := preload("res://scripts/rumor_ripple_vfx.gd").new()
##   fx.accent_color = scenario_accent_color   # optional, defaults to warm gold
##   world.add_child(fx)
##   fx.global_position = seed_target_npc.global_position

const RING_COUNT  := 3
const DURATION    := 1.5     ## total animation time in seconds
const MAX_RADIUS  := 72.0    ## outermost ring radius at peak expansion
const LINE_WIDTH  := 2.5     ## ring stroke width

## Ring stagger: each ring starts offset seconds after the previous.
const RING_STAGGER := 0.18

## Accent colour — set by caller before add_child; defaults to warm gold.
var accent_color: Color = Color(0.92, 0.72, 0.18, 0.85)

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _elapsed / DURATION  # overall progress 0 → 1
	for i in RING_COUNT:
		# Stagger each ring so they spread out sequentially.
		var ring_start := float(i) * RING_STAGGER
		if t < ring_start:
			continue
		# Normalised progress for this ring (0 → 1 over its active window).
		var ring_t := clampf((t - ring_start) / (1.0 - ring_start), 0.0, 1.0)
		var radius  := ring_t * MAX_RADIUS
		# Alpha: full at start, fades to 0 as the ring expands.
		var alpha   := (1.0 - ring_t) * accent_color.a
		if alpha <= 0.0:
			continue
		var col := Color(accent_color.r, accent_color.g, accent_color.b, alpha)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, col, LINE_WIDTH, true)

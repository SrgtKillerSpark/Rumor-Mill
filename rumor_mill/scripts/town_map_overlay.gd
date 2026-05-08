extends Node2D

## town_map_overlay.gd — SPA-910: Gathering spot highlights and NPC destination dots.
##
## Draws two layers of dynamic visual feedback on top of the world map:
##
##   1. GATHERING SPOT HIGHLIGHTS — pulsing amber rings at active gathering points
##      (well, market, tavern, etc.) sized in proportion to how many NPCs are
##      currently clustered nearby.  Updates every REFRESH_INTERVAL seconds.
##
##   2. NPC DESTINATION DOTS — small faction-coloured diamonds drawn at each NPC's
##      current schedule waypoint, so the player can see where crowds are moving.
##
## Setup: call setup(npc_list, gathering_points) after world initialises NPCs.
## Add as a direct child of NPCContainer so coordinate space matches npc.gd.

const TILE_W := 64
const TILE_H := 32

## How often (seconds) to recalculate NPC-per-gathering-point counts.
const REFRESH_INTERVAL := 2.5

## Maximum NPC count considered for ring radius scaling.
const MAX_COUNT_FOR_SCALE := 8

## Faction colours for destination diamonds (semi-transparent).
const FACTION_COLORS: Dictionary = {
	"merchant": Color(0.15, 0.38, 0.82, 0.55),
	"noble":    Color(0.72, 0.10, 0.14, 0.55),
	"clergy":   Color(0.82, 0.72, 0.08, 0.55),
}

var _npcs: Array = []
var _gathering_points: Dictionary = {}

## location_key → count of NPCs within GATHER_RADIUS cells.
var _npc_counts: Dictionary = {}

## How close (grid cells) an NPC must be to "register" at a gathering point.
const GATHER_RADIUS := 3

var _pulse: float = 0.0
var _refresh_timer: float = 0.0


func setup(npc_list: Array, gathering_points: Dictionary) -> void:
	_npcs            = npc_list
	_gathering_points = gathering_points
	_recalculate_counts()


func _process(delta: float) -> void:
	_pulse        += delta * 2.2
	if _pulse > TAU:
		_pulse -= TAU
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_recalculate_counts()
	queue_redraw()


func _draw() -> void:
	_draw_gathering_spots()
	_draw_npc_destinations()


# ── Gathering spot highlights ─────────────────────────────────────────────────

func _recalculate_counts() -> void:
	_npc_counts.clear()
	for loc_key in _gathering_points:
		var center: Vector2i = _gathering_points[loc_key]
		var count := 0
		for npc in _npcs:
			if (npc.current_cell - center).length() <= GATHER_RADIUS:
				count += 1
		if count > 0:
			_npc_counts[loc_key] = count


func _draw_gathering_spots() -> void:
	var pulse_scale := 1.0 + sin(_pulse) * 0.14
	for loc_key in _npc_counts:
		var count: int      = _npc_counts[loc_key]
		var center: Vector2i = _gathering_points[loc_key]
		var pos: Vector2    = _iso(center.x, center.y)

		var t := minf(float(count) / MAX_COUNT_FOR_SCALE, 1.0)
		var base_r := lerpf(7.0, 24.0, t) * pulse_scale

		# Outer glow ring.
		var glow_alpha := lerpf(0.12, 0.22, t) + sin(_pulse) * 0.04
		draw_arc(pos, base_r + 5.0, 0.0, TAU, 20,
			Color(1.0, 0.84, 0.30, glow_alpha), 2.5)
		# Inner translucent fill.
		draw_circle(pos, base_r, Color(1.0, 0.84, 0.30, lerpf(0.06, 0.14, t)))


# ── NPC destination dots ──────────────────────────────────────────────────────

func _draw_npc_destinations() -> void:
	for npc in _npcs:
		if npc.schedule_waypoints.is_empty():
			continue
		var wi: int = clampi(npc._waypoint_index, 0, npc.schedule_waypoints.size() - 1)
		var target: Vector2i = npc.schedule_waypoints[wi]
		if target == npc.current_cell:
			continue  # already at destination

		var dest_pos: Vector2 = _iso(target.x, target.y)
		var faction: String   = npc.npc_data.get("faction", "merchant")
		var col: Color        = FACTION_COLORS.get(faction, Color(0.5, 0.5, 0.5, 0.5))

		# Small isometric diamond marker (5 px half-size).
		var d := 5.0
		var diamond := PackedVector2Array([
			dest_pos + Vector2(0.0, -d),
			dest_pos + Vector2(d,   0.0),
			dest_pos + Vector2(0.0,  d),
			dest_pos + Vector2(-d,  0.0),
		])
		draw_colored_polygon(diamond, col)


# ── Utility ───────────────────────────────────────────────────────────────────

## Convert grid cell to world space (matches npc.gd _cell_to_world).
func _iso(x: int, y: int) -> Vector2:
	return Vector2(
		(x - y) * (TILE_W / 2.0),
		(x + y) * (TILE_H / 2.0)
	)

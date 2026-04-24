extends Node2D

## district_overlay.gd — SPA-910: Visual district zones for town map variety.
##
## Draws semi-transparent isometric polygon overlays for five distinct town
## districts (Noble Quarter, Church District, Market Square, Civic Heart,
## Eastern Quarter).  Each district is defined by grid-coordinate bounds; the
## conversion to screen space uses the same formula as npc.gd _cell_to_world().
##
## Usage: add as a child of the World node (sibling to TerrainLayer).
## The node uses z_index = -1 so it renders behind buildings and NPCs.
##
## SPA-925: fill and border colours are now sourced from
## ScenarioEnvironmentPalette.DISTRICT_PALETTES so all palette edits live in one place.

const TILE_W := 64
const TILE_H := 32

## District definitions.  x1/y1 = grid top-left (inclusive), x2/y2 = bottom-right.
## label = display name shown at district centroid and used as key in
##         ScenarioEnvironmentPalette.DISTRICT_PALETTES for colour lookup.
const DISTRICTS: Array[Dictionary] = [
	{
		"label":  "Noble Quarter",
		"x1": 1,  "y1": 1,
		"x2": 13, "y2": 20,
	},
	{
		"label":  "Church District",
		"x1": 25, "y1": 1,
		"x2": 42, "y2": 14,
	},
	{
		"label":  "Market Square",
		"x1": 1,  "y1": 22,
		"x2": 22, "y2": 42,
	},
	{
		"label":  "Civic Heart",
		"x1": 14, "y1": 5,
		"x2": 32, "y2": 28,
	},
	{
		"label":  "Eastern Quarter",
		"x1": 30, "y1": 14,
		"x2": 47, "y2": 47,
	},
]

var _font: Font = null


func _ready() -> void:
	z_index = -1          # render behind buildings, props, and NPCs
	_font = ThemeDB.fallback_font


func _draw() -> void:
	for district in DISTRICTS:
		_draw_district(district)


## Convert a grid cell to world (screen) space.
## Matches npc.gd _cell_to_world() exactly.
func _iso(x: int, y: int) -> Vector2:
	return Vector2(
		(x - y) * (TILE_W / 2.0),
		(x + y) * (TILE_H / 2.0)
	)


## Draw one district: filled isometric diamond, border, and centroid label.
## Colours are resolved at draw time from ScenarioEnvironmentPalette (SPA-925).
func _draw_district(d: Dictionary) -> void:
	var x1: int = d["x1"]
	var y1: int = d["y1"]
	var x2: int = d["x2"]
	var y2: int = d["y2"]

	var fill:   Color = ScenarioEnvironmentPalette.district_fill(d["label"])
	var border: Color = ScenarioEnvironmentPalette.district_border(d["label"])

	# Four corners of the rectangular district mapped to isometric space.
	#   NW (top)    = grid(x1, y1)
	#   NE (right)  = grid(x2, y1)
	#   SE (bottom) = grid(x2, y2)
	#   SW (left)   = grid(x1, y2)
	var pts := PackedVector2Array([
		_iso(x1, y1),
		_iso(x2, y1),
		_iso(x2, y2),
		_iso(x1, y2),
	])

	draw_colored_polygon(pts, fill)
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		border,
		1.5
	)

	# Label at approximate centroid.
	var cx: int = (x1 + x2) / 2
	var cy: int = (y1 + y2) / 2
	var label_pos: Vector2 = _iso(cx, cy)
	if _font != null:
		var label_color := Color(border.r, border.g, border.b, 0.70)
		draw_string(
			_font,
			label_pos + Vector2(-50.0, -4.0),
			d["label"],
			HORIZONTAL_ALIGNMENT_CENTER,
			100.0,
			9,
			label_color
		)

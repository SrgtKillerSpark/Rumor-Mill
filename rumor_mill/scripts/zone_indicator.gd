extends CanvasLayer

## zone_indicator.gd — HUD element showing which town area the camera is viewing.
##
## Compares the camera's world-space centre against known gathering-point cells
## and displays the nearest named location in a small bottom-left label.
## Call setup(world, camera) from main.gd after the scene tree is ready.

const C_BG    := Color(0.08, 0.05, 0.03, 0.82)
const C_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TEXT   := Color(0.92, 0.82, 0.60, 1.0)
const C_SUBTEXT := Color(0.65, 0.58, 0.45, 1.0)

# Human-readable names for location codes.
const LOCATION_NAMES := {
	"manor":          "The Manor",
	"tavern":         "The Tavern",
	"chapel":         "The Chapel",
	"market":         "Market Square",
	"well":           "Town Well",
	"blacksmith":     "Blacksmith",
	"mill":           "The Mill",
	"trader_stall":   "Trader Stalls",
	"storage":        "Warehouse District",
	"tanner":         "Tanner's Yard",
	"town_hall":      "Town Hall",
	"alderman_house": "Alderman's House",
	"courthouse":     "Courthouse",
	"guardhouse":     "Guardpost",
	"graveyard":      "Graveyard",
}

# Only show named zones — skip patrol and generic schedule locations.
const SKIP_LOCATIONS := ["patrol", "home", "work"]

var _world_ref: Node2D = null
var _camera_ref: Camera2D = null
var _label: Label = null
var _panel: PanelContainer = null
var _current_zone: String = ""
var _fade_tween: Tween = null

# Tile size for converting grid cells → world coordinates (isometric).
const TILE_W := 64
const TILE_H := 32


func _ready() -> void:
	layer = 6
	_build_ui()


func setup(world_node: Node2D, cam: Camera2D) -> void:
	_world_ref  = world_node
	_camera_ref = cam


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ZonePanel"

	# Anchor bottom-left.
	_panel.set_anchor_and_offset(SIDE_LEFT,   0.0,  12.0)
	_panel.set_anchor_and_offset(SIDE_RIGHT,  0.0, 200.0)
	_panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -12.0)
	_panel.set_anchor_and_offset(SIDE_TOP,    1.0, -40.0)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.text = ""
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", C_TEXT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel.add_child(_label)

	add_child(_panel)
	_panel.modulate.a = 0.0


func _process(_delta: float) -> void:
	if _camera_ref == null or _world_ref == null:
		return

	var cam_pos: Vector2 = _camera_ref.global_position
	var nearest_zone := _find_nearest_zone(cam_pos)

	if nearest_zone != _current_zone:
		_current_zone = nearest_zone
		if nearest_zone.is_empty():
			_fade_out()
		else:
			_label.text = nearest_zone
			_fade_in()


func _find_nearest_zone(cam_world_pos: Vector2) -> String:
	# Convert camera world position to approximate grid cell.
	# Isometric: x = (col + row) * TILE_W/2, y = (row - col) * TILE_H/2 + offset
	# Reverse: col ≈ (x/TILE_W - y/TILE_H), row ≈ (x/TILE_W + y/TILE_H)
	# We don't need exact — just compare distances in world space.

	if not "_gathering_points" in _world_ref:
		return ""

	var gp: Dictionary = _world_ref._gathering_points
	var best_dist: float = 999999.0
	var best_loc: String = ""

	for loc_key in gp:
		if loc_key in SKIP_LOCATIONS:
			continue
		var cell: Vector2i = gp[loc_key]
		var world_pos := _cell_to_world(cell)
		var dist: float = cam_world_pos.distance_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best_loc  = loc_key

	# Only show zone name if camera is within ~6 tiles of the location.
	if best_dist > 6.0 * TILE_W:
		return ""

	return LOCATION_NAMES.get(best_loc, best_loc.capitalize())


func _cell_to_world(cell: Vector2i) -> Vector2:
	# Isometric conversion matching world.gd's tile placement.
	var wx: float = (cell.x + cell.y) * (TILE_W * 0.5)
	var wy: float = (cell.y - cell.x) * (TILE_H * 0.5)
	return Vector2(wx, wy)


func _fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _fade_out() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(_panel, "modulate:a", 0.0, 0.2)

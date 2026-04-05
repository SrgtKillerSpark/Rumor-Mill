extends CanvasLayer

## building_tooltip.gd — Hover tooltip panel for buildings.
##
## Displays a parchment-style panel near the cursor showing:
##   • Building name
##   • Atmospheric location description (from data/flavor_text.json)
##
## Add as a child of Main and call setup(world) to enable hover detection.

const C_BG     := Color(0.10, 0.07, 0.05, 0.93)
const C_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE  := Color(0.92, 0.78, 0.12, 1.0)
const C_LABEL  := Color(0.82, 0.75, 0.60, 1.0)

const OFFSET       := Vector2(18, -95)
const PANEL_W      := 240
const FADE_IN_SEC  := 0.12
const FADE_OUT_SEC := 0.10

## Hit radius in grid tiles — matches recon_controller's BUILDING_HIT_TILES.
const BUILDING_HIT_TILES := 2

const C_HINT    := Color(0.90, 0.75, 0.40, 0.85)

var _panel:       PanelContainer = null
var _name_lbl:    Label          = null
var _desc_lbl:    Label          = null
var _hint_lbl:    Label          = null

var _world_ref:   Node2D   = null
var _flavor_text: Dictionary = {}
var _current_loc: String   = ""
var _fade_tween:  Tween    = null


func _ready() -> void:
	layer = 9   # same level as npc_tooltip
	_load_flavor_text()
	_build_panel()


func setup(world: Node2D) -> void:
	_world_ref = world


func _load_flavor_text() -> void:
	var file := FileAccess.open("res://data/flavor_text.json", FileAccess.READ)
	if file == null:
		push_warning("BuildingTooltip: flavor_text.json not found — descriptions disabled")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_flavor_text = parsed


# ── Per-frame hover detection + cursor position ───────────────────────────────

func _process(_delta: float) -> void:
	if _panel.visible:
		_keep_near_cursor()

	if _world_ref == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return

	var screen_pos: Vector2 = viewport.get_mouse_position()
	var world_pos:  Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_pos
	var loc := _hit_test_location(world_pos)

	if loc == _current_loc:
		return

	_current_loc = loc
	if loc != "":
		_populate(loc)
		_fade_to(1.0)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		_fade_to(0.0)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _hit_test_location(world_pos: Vector2) -> String:
	if not ("_building_entries" in _world_ref):
		return ""
	var clicked_cell := _world_to_cell(world_pos)
	for loc_name in _world_ref._building_entries:
		var entry: Vector2i = _world_ref._building_entries[loc_name]
		var dist: float = (clicked_cell - entry).length()
		if dist <= BUILDING_HIT_TILES:
			return loc_name
	return ""


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var cx := world_pos.x / 64.0 + world_pos.y / 32.0
	var cy := world_pos.y / 32.0 - world_pos.x / 64.0
	return Vector2i(int(round(cx)), int(round(cy)))


# ── Panel position ────────────────────────────────────────────────────────────

func _keep_near_cursor() -> void:
	if not _panel.visible:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var panel_h: float = _panel.size.y if _panel.size.y > 0 else 80.0
	var target_x: float = mouse_pos.x + OFFSET.x
	var target_y: float = mouse_pos.y + OFFSET.y
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	target_x = clampf(target_x, 4.0, vp_size.x - PANEL_W - 4.0)
	target_y = clampf(target_y, 4.0, vp_size.y - panel_h - 4.0)
	_panel.set_position(Vector2(target_x, target_y))


# ── Fade helpers ──────────────────────────────────────────────────────────────

func _fade_to(target_alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if target_alpha > 0.0:
		_panel.visible = true
		_keep_near_cursor()
	_fade_tween = create_tween()
	var duration := FADE_IN_SEC if target_alpha > 0.0 else FADE_OUT_SEC
	_fade_tween.tween_property(_panel, "modulate:a", target_alpha, duration)
	if target_alpha == 0.0:
		_fade_tween.tween_callback(func() -> void: _panel.visible = false)


# ── Build panel ───────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 14)
	_name_lbl.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_name_lbl)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", 12)
	_desc_lbl.add_theme_color_override("font_color", C_LABEL)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(PANEL_W - 20, 0)
	vbox.add_child(_desc_lbl)

	_hint_lbl = Label.new()
	_hint_lbl.text = "Right-click to Observe"
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", C_HINT)
	_hint_lbl.add_theme_constant_override("outline_size", 1)
	_hint_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	vbox.add_child(_hint_lbl)

	_panel.modulate.a = 0.0
	_panel.visible = false
	add_child(_panel)


# ── Populate from location name ───────────────────────────────────────────────

func _populate(loc_name: String) -> void:
	_name_lbl.text = loc_name.replace("_", " ").capitalize()
	var descs: Dictionary = _flavor_text.get("location_descriptions", {})
	_desc_lbl.text = descs.get(loc_name, "A location in this town.")
	_desc_lbl.visible = true

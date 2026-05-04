extends CanvasLayer

## tooltip_manager.gd — Global singleton for parchment-styled HUD tooltips (SPA-769).
##
## Add to project.godot as an autoload named "TooltipManager".
## Tooltip content is data-driven from data/tooltips.json.
##
## API:
##   TooltipManager.show_at(key: String)  — show tooltip for the given key
##   TooltipManager.hide_tooltip()         — fade the tooltip out

# ── Palette (parchment / medieval aesthetic) ──────────────────────────────────
const C_BG     := Color(0.10, 0.07, 0.05, 0.93)
const C_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE  := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY   := Color(0.82, 0.75, 0.60, 1.0)

const FADE_IN_SEC  := 0.12
const FADE_OUT_SEC := 0.10
const PANEL_W      := 280
const OFFSET       := Vector2(20, -90)  # cursor offset; panel floats above-right

var _panel:        PanelContainer = null
var _title_lbl:    Label          = null
var _body_lbl:     Label          = null
var _visible_flag: bool           = false
var _fade_tween:   Tween          = null
var _data:         Dictionary     = {}


func _ready() -> void:
	# SPA-1179 #32: layer 100 — above every other UI layer, including hud_tooltip(99).
	# Tooltip layer precedence: hud_tooltip(99) < tooltip_manager(100).
	# hud_tooltip handles auto-detected hover tooltips; this singleton handles
	# explicit data-driven tooltips via show_at(key).
	layer = 100
	_load_data()
	_build_panel()


func _load_data() -> void:
	var file := FileAccess.open("res://data/tooltips.json", FileAccess.READ)
	if file == null:
		push_warning("TooltipManager: data/tooltips.json not found — tooltips disabled")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("TooltipManager: tooltips.json parse failed")


## Show the tooltip for the given key.  Does nothing if the key is unknown.
func show_at(key: String) -> void:
	var entry: Dictionary = _data.get(key, {})
	if entry.is_empty():
		return
	_title_lbl.text = entry.get("title", "")
	_body_lbl.text  = entry.get("body",  "")
	_visible_flag = true
	_fade_to(1.0)


## Hide the currently visible tooltip.
func hide_tooltip() -> void:
	_visible_flag = false
	_fade_to(0.0)


# ── Per-frame: keep panel near cursor ─────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _visible_flag or _panel == null:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var tx: float = mouse_pos.x + OFFSET.x
	var ty: float = mouse_pos.y + OFFSET.y
	var panel_h: float = _panel.size.y if _panel.size.y > 0.0 else 80.0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	tx = clampf(tx, 8.0, vp.x - PANEL_W - 8.0)
	ty = clampf(ty, 8.0, vp.y - panel_h - 8.0)
	_panel.set_position(Vector2(tx, ty))


# ── Internal ──────────────────────────────────────────────────────────────────

func _fade_to(alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if alpha > 0.0:
		_panel.visible = true
	_fade_tween = create_tween()
	var dur := FADE_IN_SEC if alpha > 0.0 else FADE_OUT_SEC
	_fade_tween.tween_property(_panel, "modulate:a", alpha, dur)
	if alpha == 0.0:
		_fade_tween.tween_callback(func() -> void: _panel.visible = false)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat game input

	var style := StyleBoxFlat.new()
	style.bg_color    = C_BG
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
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 14)
	_title_lbl.add_theme_color_override("font_color", C_TITLE)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_lbl)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_body_lbl = Label.new()
	_body_lbl.add_theme_font_size_override("font_size", 12)
	_body_lbl.add_theme_color_override("font_color", C_BODY)
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.custom_minimum_size = Vector2(PANEL_W - 20, 0)
	_body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_body_lbl)

	_panel.modulate.a = 0.0
	_panel.visible = false
	add_child(_panel)

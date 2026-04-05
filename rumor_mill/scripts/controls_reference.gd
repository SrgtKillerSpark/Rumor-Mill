extends CanvasLayer

## controls_reference.gd — Toggleable controls reference overlay.
##
## Displays a compact reference of all keybindings in the bottom-left corner.
## Toggle with F1 or the "?" button.  Semi-transparent so gameplay stays visible.

const C_BG       := Color(0.08, 0.05, 0.03, 0.88)
const C_BORDER   := Color(0.55, 0.38, 0.18, 1.0)
const C_HEADING  := Color(0.92, 0.78, 0.12, 1.0)
const C_KEY_NAME := Color(0.95, 0.85, 0.55, 1.0)
const C_KEY_DESC := Color(0.80, 0.72, 0.56, 1.0)

const BINDINGS := [
	["WASD / Arrows", "Pan camera"],
	["Mouse Wheel", "Zoom in / out"],
	["Middle Drag", "Free pan"],
	["Right-click building", "Observe location"],
	["Right-click NPC pair", "Eavesdrop on conversation"],
	["R", "Open Rumor Panel"],
	["J", "Open Journal"],
	["G", "Open Social Graph"],
	["Space", "Pause / Resume"],
	["1", "Normal speed"],
	["3", "Fast speed (3x)"],
	["H", "Replay last hint"],
	["F1", "Toggle this reference"],
	["Esc", "Close open panel"],
]

var _panel: PanelContainer = null
var _fade_tween: Tween = null
var _is_visible: bool = false


func _ready() -> void:
	layer = 18
	_build_panel()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	_is_visible = not _is_visible
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _is_visible:
		_panel.visible = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(_panel, "modulate:a", 1.0, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_panel, "modulate:a", 0.0, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fade_tween.tween_callback(func() -> void: _panel.visible = false)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12.0
	_panel.offset_top = -320.0
	_panel.offset_right = 280.0
	_panel.offset_bottom = -12.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	# Header
	var title := Label.new()
	title.text = "Controls Reference"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", C_HEADING)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	vbox.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Keybinding rows
	for binding in BINDINGS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var key_lbl := Label.new()
		key_lbl.text = binding[0]
		key_lbl.custom_minimum_size = Vector2(130, 0)
		key_lbl.add_theme_font_size_override("font_size", 13)
		key_lbl.add_theme_color_override("font_color", C_KEY_NAME)
		key_lbl.add_theme_constant_override("outline_size", 1)
		key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		row.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = binding[1]
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", C_KEY_DESC)
		row.add_child(desc_lbl)

		vbox.add_child(row)

	# Footer hint
	var footer := Label.new()
	footer.text = "Press F1 to close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.60, 0.55, 0.40, 0.8))
	vbox.add_child(footer)

	_panel.modulate.a = 0.0
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

extends CanvasLayer

## context_controls_panel.gd — Context-aware controls bar (bottom-left).
##
## Replaces the static ControlsPanel label from Main.tscn with a dynamic
## bar that shows only the relevant controls for the current game mode.
## Also includes a "?" help button that opens the full controls reference.

const C_BG      := Color(0.08, 0.05, 0.03, 0.82)
const C_BORDER  := Color(0.55, 0.38, 0.18, 0.5)
const C_TEXT    := Color(0.65, 0.58, 0.45, 0.90)
const C_KEY     := Color(0.92, 0.78, 0.12, 0.95)
const C_MUTED   := Color(0.50, 0.45, 0.38, 0.70)
const C_ACTIVE  := Color(0.40, 1.0, 0.50, 0.95)  # green highlight for available actions

## Mode enum for controlling which bindings are shown.
enum Mode {
	EXPLORE,       ## Default — camera, recon, open panels
	RUMOR_PANEL,   ## Rumor crafting panel is open
	JOURNAL,       ## Journal is open
	SOCIAL_GRAPH,  ## Social graph overlay is open
	PAUSED,        ## Game is paused
}

## Controls definitions per mode: [[key, description, highlight?], ...]
const MODE_BINDINGS := {
	Mode.EXPLORE: [
		["WASD", "Pan", false],
		["Scroll", "Zoom", false],
		["R-Click", "Recon", true],
		["R", "Rumor", true],
		["J", "Journal", false],
		["G/M", "Map", false],
		["Tab", "Select NPC", false],
		["Space", "Pause", false],
		["?", "Help", false],
	],
	Mode.RUMOR_PANEL: [
		["Click", "Select", true],
		["Esc", "Close", true],
		["Tab", "Next step", false],
	],
	Mode.JOURNAL: [
		["1-4", "Switch tab", false],
		["Esc", "Close", true],
		["Click", "Filter/expand", false],
	],
	Mode.SOCIAL_GRAPH: [
		["Drag", "Pan graph", false],
		["Scroll", "Zoom", false],
		["Click", "Select NPC", true],
		["Esc", "Close", true],
	],
	Mode.PAUSED: [
		["Space", "Resume", true],
		["Esc", "Menu", false],
	],
}

var _panel: Panel = null
var _hbox: HBoxContainer = null
var _help_btn: Button = null
var _current_mode: int = Mode.EXPLORE
var _controls_ref: CanvasLayer = null  # reference to controls_reference.gd overlay

# Track interactable state for visual indicators.
var _has_actions: bool = true
var _has_whispers: bool = true
var _action_indicators: Dictionary = {}  # key_text → Label node


func _ready() -> void:
	layer = 1  # Just above default HUD layer
	_build_panel()


func setup(controls_ref: CanvasLayer) -> void:
	_controls_ref = controls_ref


## Update the displayed mode. Call from main.gd when panels open/close.
func set_mode(mode: int) -> void:
	if mode == _current_mode:
		return
	_current_mode = mode
	_rebuild_bindings()


## Update resource availability indicators (called from recon_hud refresh).
func update_availability(actions_remaining: int, whispers_remaining: int) -> void:
	var had_actions := _has_actions
	var had_whispers := _has_whispers
	_has_actions = actions_remaining > 0
	_has_whispers = whispers_remaining > 0
	if had_actions != _has_actions or had_whispers != _has_whispers:
		_rebuild_bindings()


func _build_panel() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 6.0
	_panel.offset_top = -36.0
	_panel.offset_right = minf(780.0, get_viewport_rect().size.x - 6.0)
	_panel.offset_bottom = -6.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.set_border_width_all(1)
	style.border_color = C_BORDER
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.tooltip_text = "Context Controls\nShows relevant controls for your current activity.\nPress ? or F1 for full reference."
	add_child(_panel)

	_hbox = HBoxContainer.new()
	_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hbox.offset_left = 8.0
	_hbox.offset_right = -8.0
	_hbox.add_theme_constant_override("separation", 4)
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_hbox)

	_rebuild_bindings()


func _rebuild_bindings() -> void:
	if _hbox == null:
		return
	for child in _hbox.get_children():
		child.queue_free()
	_action_indicators.clear()

	var bindings: Array = MODE_BINDINGS.get(_current_mode, MODE_BINDINGS[Mode.EXPLORE])

	for binding in bindings:
		var key_text: String = binding[0]
		var desc_text: String = binding[1]
		var highlight: bool = binding[2]

		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)

		# Key badge.
		var key_lbl := Label.new()
		key_lbl.text = key_text
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_constant_override("outline_size", 1)
		key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))

		# Determine color: highlighted actions get brighter treatment.
		var key_color := C_KEY
		var desc_color := C_TEXT
		if highlight:
			# Check if the highlighted action is currently available.
			var available := true
			if key_text == "R-Click" and not _has_actions:
				available = false
			elif key_text == "R" and not _has_whispers:
				available = false
			if available:
				key_color = C_ACTIVE
				desc_color = Color(0.80, 0.95, 0.80, 0.95)
			else:
				key_color = C_MUTED
				desc_color = C_MUTED
		key_lbl.add_theme_color_override("font_color", key_color)
		pair.add_child(key_lbl)

		# Description.
		var desc_lbl := Label.new()
		desc_lbl.text = desc_text
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", desc_color)
		pair.add_child(desc_lbl)

		_hbox.add_child(pair)

		# Separator between pairs.
		var sep := Label.new()
		sep.text = " | "
		sep.add_theme_font_size_override("font_size", 11)
		sep.add_theme_color_override("font_color", Color(0.40, 0.35, 0.28, 0.5))
		_hbox.add_child(sep)

	# Remove trailing separator.
	if _hbox.get_child_count() > 0:
		var last := _hbox.get_child(_hbox.get_child_count() - 1)
		if last is Label and last.text == " | ":
			last.queue_free()

	# Add help button at the end.
	_build_help_button()


func _build_help_button() -> void:
	_help_btn = Button.new()
	_help_btn.text = " ? "
	_help_btn.custom_minimum_size = Vector2(26, 22)
	_help_btn.add_theme_font_size_override("font_size", 13)
	_help_btn.add_theme_color_override("font_color", C_KEY)
	_help_btn.tooltip_text = "Help (F1)\nOpen the full controls reference overlay."

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.14, 0.08, 0.85)
	style.set_border_width_all(1)
	style.border_color = C_BORDER
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	_help_btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.35, 0.24, 0.10, 0.95)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(0.75, 0.55, 0.20, 1.0)
	hover_style.set_corner_radius_all(3)
	hover_style.set_content_margin_all(2)
	_help_btn.add_theme_stylebox_override("hover", hover_style)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.35, 0.24, 0.10, 0.95)
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_corner_radius_all(3)
	focus_style.set_content_margin_all(2)
	_help_btn.add_theme_stylebox_override("focus", focus_style)

	_help_btn.pressed.connect(_on_help_pressed)
	_hbox.add_child(_help_btn)


func _on_help_pressed() -> void:
	AudioManager.play_ui("click")
	if _controls_ref != null and _controls_ref.has_method("toggle"):
		_controls_ref.toggle()

extends CanvasLayer

## thought_bubble_legend.gd — SPA-806: Collapsible legend for NPC thought bubble symbols.
##
## Small overlay anchored to the bottom-right corner showing the 5 most common
## rumor state symbols. Auto-collapses after Day 5. First-time players see it
## expanded; returning players see it collapsed. Expandable via hover or L hotkey.

# ── Palette ──────────────────────────────────────────────────────────────────

const C_BG       := Color(0.08, 0.06, 0.04, 0.88)
const C_BORDER   := Color(0.55, 0.38, 0.18, 0.7)
const C_HEADING  := Color(0.92, 0.78, 0.12, 1.0)
const C_SYMBOL   := Color(0.95, 0.88, 0.65, 1.0)
const C_DESC     := Color(0.70, 0.65, 0.55, 1.0)
const C_TAB_BG   := Color(0.10, 0.07, 0.05, 0.90)
const C_TAB_TEXT := Color(0.75, 0.65, 0.50, 1.0)

const LEGEND_ENTRIES: Array = [
	{"symbol": "?",  "color": Color(1.00, 1.00, 0.50, 1.0), "desc": "Evaluating"},
	{"symbol": "!",  "color": Color(0.40, 1.00, 0.50, 1.0), "desc": "Believes"},
	{"symbol": "...", "color": Color(1.00, 0.75, 0.30, 1.0), "desc": "Spreading"},
	{"symbol": "x",  "color": Color(0.70, 0.70, 0.90, 1.0), "desc": "Rejected"},
	{"symbol": "!!", "color": Color(1.00, 0.40, 0.90, 1.0), "desc": "Acting"},
]

const COLLAPSE_AFTER_DAY := 5
const MARGIN := 16

# ── Node refs ────────────────────────────────────────────────────────────────

var _panel: PanelContainer = null
var _content_vbox: VBoxContainer = null
var _tab_btn: Button = null
var _expanded: bool = true
var _day_night: Node = null


func _ready() -> void:
	layer = 12
	_build_ui()


func setup(day_night: Node, is_returning_player: bool) -> void:
	_day_night = day_night
	_expanded = not is_returning_player
	_apply_expanded_state()

	if _day_night != null and _day_night.has_signal("day_changed"):
		_day_night.day_changed.connect(_on_day_changed)
		if _day_night.current_day > COLLAPSE_AFTER_DAY:
			_expanded = false
			_apply_expanded_state()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			_toggle()


func _build_ui() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)
	container.anchor_right  = 1.0
	container.anchor_bottom = 1.0
	container.offset_left   = -180
	container.offset_top    = -280
	container.offset_right  = -MARGIN
	container.offset_bottom = -90  # above the help-reminder panel
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	anchor.add_child(container)

	# Collapse/expand tab button.
	_tab_btn = Button.new()
	_tab_btn.text = "Symbols ▼"
	_tab_btn.flat = true
	_tab_btn.add_theme_font_size_override("font_size", 11)
	_tab_btn.add_theme_color_override("font_color", C_TAB_TEXT)
	_tab_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_tab_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_tab_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_tab_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tab_btn.pressed.connect(_toggle)
	_tab_btn.mouse_entered.connect(func() -> void:
		if not _expanded:
			_set_expanded(true)
	)
	container.add_child(_tab_btn)

	# Main legend panel.
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_exited.connect(func() -> void:
		if _day_night != null and _day_night.current_day > COLLAPSE_AFTER_DAY:
			_set_expanded(false)
	)
	container.add_child(_panel)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(_content_vbox)

	# Heading
	var heading := Label.new()
	heading.text = "Thought Bubbles"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(heading)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(sep)

	# Legend entries
	for entry: Dictionary in LEGEND_ENTRIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var sym_lbl := Label.new()
		sym_lbl.text = entry["symbol"]
		sym_lbl.custom_minimum_size = Vector2(24, 0)
		sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_lbl.add_theme_font_size_override("font_size", 13)
		sym_lbl.add_theme_color_override("font_color", entry["color"])
		sym_lbl.add_theme_constant_override("outline_size", 2)
		sym_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		row.add_child(sym_lbl)

		var eq_lbl := Label.new()
		eq_lbl.text = "="
		eq_lbl.add_theme_font_size_override("font_size", 11)
		eq_lbl.add_theme_color_override("font_color", C_DESC)
		row.add_child(eq_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", C_DESC)
		row.add_child(desc_lbl)

		_content_vbox.add_child(row)

	# Hotkey hint
	var hint := Label.new()
	hint.text = "Press L to toggle"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_content_vbox.add_child(hint)


func _toggle() -> void:
	_set_expanded(not _expanded)


func _set_expanded(value: bool) -> void:
	_expanded = value
	_apply_expanded_state()


func _apply_expanded_state() -> void:
	if _panel == null:
		return
	_panel.visible = _expanded
	_tab_btn.text = "Symbols ▼" if _expanded else "Symbols ▲"


func _on_day_changed(day: int) -> void:
	if day > COLLAPSE_AFTER_DAY and _expanded:
		_set_expanded(false)

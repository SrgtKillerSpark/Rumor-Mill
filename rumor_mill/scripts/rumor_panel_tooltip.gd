extends CanvasLayer

## rumor_panel_tooltip.gd — SPA-629 First-time Rumor Panel tooltip overlay.
##
## Sequential 3-step walkthrough displayed over the Rumor Panel the first time
## it opens in Scenario 1.  Each step highlights a key area of the crafting
## workflow.  Click "Next" to advance; "Got it!" on the final step dismisses
## permanently (persisted via SettingsManager.dismissed_tooltips).
##
## Usage from main.gd:
##   var tooltip := preload("res://scripts/rumor_panel_tooltip.gd").new()
##   tooltip.name = "RumorPanelTooltip"
##   add_child(tooltip)
##   tooltip.setup(rumor_panel_node)
##   tooltip.show_walkthrough()

const PERSIST_KEY := "rumor_panel_walkthrough"

# ── Palette (matches TutorialHUD dark theme) ─────────────────────────────────

const C_BACKDROP      := Color(0.04, 0.02, 0.01, 0.70)
const C_PANEL_BG      := Color(0.10, 0.07, 0.04, 1.0)
const C_PANEL_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_HEADING       := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY          := Color(0.80, 0.72, 0.55, 1.0)
const C_STEP_DIM      := Color(0.60, 0.55, 0.40, 0.8)
const C_BTN_NORMAL    := Color(0.35, 0.22, 0.08, 1.0)
const C_BTN_HOVER     := Color(0.55, 0.35, 0.12, 1.0)
const C_BTN_TEXT      := Color(0.92, 0.82, 0.60, 1.0)
const C_HIGHLIGHT     := Color(0.92, 0.78, 0.12, 0.35)

const TOOLTIP_WIDTH  := 380
const TOOLTIP_HEIGHT := 220

# ── Step definitions ─────────────────────────────────────────────────────────

const STEPS: Array = [
	{
		"title": "1. Pick a Subject",
		"body": (
			"This list shows every NPC in town.\n"
			+ "Select the person your rumour will target — their [b]faction[/b] and\n"
			+ "[b]reputation[/b] are shown alongside each name.\n"
			+ "NPCs you have [b]eavesdropped[/b] on reveal extra intel."
		),
		"anchor": "top",  # tooltip appears near the top of the panel (NPC list)
	},
	{
		"title": "2. Choose a Claim",
		"body": (
			"After picking a subject, you will see a menu of [b]claim types[/b]:\n"
			+ "Scandal, Accusation, Heresy, Praise, and more.\n"
			+ "Each claim has an [b]intensity[/b] and [b]mutability[/b] rating —\n"
			+ "stronger claims spread faster but are harder to believe."
		),
		"anchor": "middle",
	},
	{
		"title": "3. Whisper & Spread",
		"body": (
			"Finally, pick a [b]seed target[/b] — the NPC who first hears the rumour.\n"
			+ "Well-connected NPCs spread it further. Seeding costs [b]1 Whisper Token[/b]\n"
			+ "(refreshes at dawn). Press [b]Confirm & Seed[/b] to release the rumour\n"
			+ "into the town's social network."
		),
		"anchor": "bottom",
	},
]

# ── Node refs ────────────────────────────────────────────────────────────────

var _backdrop:     ColorRect      = null
var _tooltip_panel: PanelContainer = null
var _title_label:  Label          = null
var _body_label:   RichTextLabel  = null
var _step_label:   Label          = null
var _btn_next:     Button         = null
var _highlight:    ColorRect      = null

var _rumor_panel_ref: CanvasLayer = null
var _current_step: int = 0

signal walkthrough_dismissed


func _ready() -> void:
	layer = 21  # above TutorialHUD (20) and RumorPanel (15)
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()


## Wire the RumorPanel reference for positioning.
func setup(rumor_panel: CanvasLayer) -> void:
	_rumor_panel_ref = rumor_panel


## Returns true if the walkthrough has been permanently dismissed.
func is_dismissed() -> bool:
	return SettingsManager.dismissed_tooltips.get(PERSIST_KEY, false)


## Begin the 3-step walkthrough if not already dismissed.
func show_walkthrough() -> void:
	if is_dismissed():
		return
	_current_step = 0
	_show_step()
	visible = true
	_btn_next.call_deferred("grab_focus")


# ── Internal ─────────────────────────────────────────────────────────────────

func _show_step() -> void:
	if _current_step >= STEPS.size():
		_dismiss_permanently()
		return

	var step: Dictionary = STEPS[_current_step]
	_title_label.text = step["title"]
	_body_label.text  = step["body"]
	_step_label.text  = "Step %d of %d" % [_current_step + 1, STEPS.size()]

	if _current_step == STEPS.size() - 1:
		_btn_next.text = "  Got it!  "
	else:
		_btn_next.text = "  Next  "

	_position_tooltip(step.get("anchor", "middle"))


func _position_tooltip(anchor: String) -> void:
	# Position the tooltip beside the Rumor Panel (which sits on the left 40%).
	# We place the tooltip to the right of the panel, vertically aligned to the
	# relevant area.
	var screen_size := get_viewport().get_visible_rect().size
	var panel_right_x: float = screen_size.x * 0.40 + 20.0  # just right of panel edge

	# Clamp horizontally so tooltip stays on screen.
	var tx: float = minf(panel_right_x, screen_size.x - TOOLTIP_WIDTH - 16.0)

	var ty: float = 0.0
	match anchor:
		"top":
			ty = screen_size.y * 0.12
		"middle":
			ty = screen_size.y * 0.35
		"bottom":
			ty = screen_size.y * 0.55

	_tooltip_panel.position = Vector2(tx, ty)

	# Position highlight strip on the left panel area to draw the eye.
	var hy: float = 0.0
	var hh: float = 0.0
	match anchor:
		"top":
			hy = screen_size.y * 0.08
			hh = screen_size.y * 0.30
		"middle":
			hy = screen_size.y * 0.30
			hh = screen_size.y * 0.30
		"bottom":
			hy = screen_size.y * 0.52
			hh = screen_size.y * 0.35
	_highlight.position = Vector2(0, hy)
	_highlight.size = Vector2(screen_size.x * 0.40, hh)


func _advance() -> void:
	_current_step += 1
	if _current_step >= STEPS.size():
		_dismiss_permanently()
	else:
		_show_step()


func _dismiss_permanently() -> void:
	visible = false
	SettingsManager.dismissed_tooltips[PERSIST_KEY] = true
	SettingsManager.save_settings()
	walkthrough_dismissed.emit()


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen backdrop — blocks input behind the tooltip.
	_backdrop = ColorRect.new()
	_backdrop.color          = C_BACKDROP
	_backdrop.anchor_right   = 1.0
	_backdrop.anchor_bottom  = 1.0
	_backdrop.mouse_filter   = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Highlight strip — semi-transparent gold rectangle over the relevant panel area.
	_highlight = ColorRect.new()
	_highlight.color        = C_HIGHLIGHT
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight)

	# Tooltip panel (absolute positioned, not anchored).
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.custom_minimum_size = Vector2(TOOLTIP_WIDTH, TOOLTIP_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL_BG
	style.border_color = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 20.0
	style.content_margin_right  = 20.0
	style.content_margin_top    = 16.0
	style.content_margin_bottom = 16.0
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(_tooltip_panel)

	# VBox inside tooltip.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_tooltip_panel.add_child(vbox)

	# Title.
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", C_HEADING)
	_title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_title_label)

	# Separator.
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.content_margin_top    = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Body (BBCode enabled).
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content    = true
	_body_label.scroll_active  = false
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_color_override("default_color",   C_BODY)
	_body_label.add_theme_color_override("font_bold_color", C_HEADING)
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	_body_label.add_theme_font_size_override("bold_font_size",   14)
	vbox.add_child(_body_label)

	# Footer row — step counter + button.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 12)
	_step_label.add_theme_color_override("font_color", C_STEP_DIM)
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_step_label)

	_btn_next = Button.new()
	_btn_next.text = "  Next  "
	_btn_next.custom_minimum_size = Vector2(90, 30)
	_btn_next.add_theme_font_size_override("font_size", 14)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = C_BTN_NORMAL
	btn_normal.set_corner_radius_all(4)
	btn_normal.content_margin_left   = 10.0
	btn_normal.content_margin_right  = 10.0
	btn_normal.content_margin_top    = 5.0
	btn_normal.content_margin_bottom = 5.0
	_btn_next.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = C_BTN_HOVER
	btn_hover.set_corner_radius_all(4)
	btn_hover.content_margin_left   = 10.0
	btn_hover.content_margin_right  = 10.0
	btn_hover.content_margin_top    = 5.0
	btn_hover.content_margin_bottom = 5.0
	_btn_next.add_theme_stylebox_override("hover",   btn_hover)
	_btn_next.add_theme_stylebox_override("pressed", btn_hover)

	var btn_focus := StyleBoxFlat.new()
	btn_focus.bg_color    = Color(0, 0, 0, 0)
	btn_focus.draw_center = false
	btn_focus.set_border_width_all(2)
	btn_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	_btn_next.add_theme_stylebox_override("focus", btn_focus)

	_btn_next.add_theme_color_override("font_color",         C_BTN_TEXT)
	_btn_next.add_theme_color_override("font_hover_color",   C_BTN_TEXT)
	_btn_next.add_theme_color_override("font_pressed_color", C_BTN_TEXT)

	_btn_next.pressed.connect(_advance)
	footer.add_child(_btn_next)

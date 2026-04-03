extends CanvasLayer

## tutorial_hud.gd — Sprint 7 first-encounter tooltip overlay.
##
## Procedurally-built CanvasLayer (layer 20) that displays one tooltip at a
## time from a queue.  A semi-transparent backdrop blocks input while a
## tooltip is visible so the player reads it before continuing.
##
## Usage from main.gd:
##   var tutorial_hud := preload("res://scripts/tutorial_hud.gd").new()
##   tutorial_hud.name = "TutorialHUD"
##   add_child(tutorial_hud)
##   tutorial_hud.setup(tutorial_system_instance)
##   tutorial_hud.queue_tooltip("recon_actions")

# ── Palette (matches dark HUD theme) ─────────────────────────────────────────

const C_BACKDROP      := Color(0.04, 0.02, 0.01, 0.78)
const C_PANEL_BG      := Color(0.10, 0.07, 0.04, 1.0)
const C_PANEL_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_HEADING       := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_BODY          := Color(0.80, 0.72, 0.55, 1.0)   # warm parchment
const C_BTN_NORMAL    := Color(0.35, 0.22, 0.08, 1.0)
const C_BTN_HOVER     := Color(0.55, 0.35, 0.12, 1.0)
const C_BTN_TEXT      := Color(0.92, 0.82, 0.60, 1.0)

const PANEL_WIDTH  := 600
const PANEL_HEIGHT := 300

# ── Node refs (built in _ready) ───────────────────────────────────────────────

var _backdrop:    ColorRect      = null
var _panel:       PanelContainer = null
var _title_label: Label          = null
var _body_label:  RichTextLabel  = null
var _dismiss_btn: Button         = null

# ── State ─────────────────────────────────────────────────────────────────────

var _tutorial_sys: TutorialSystem = null
var _queue: Array = []           ## Array[String] of tooltip IDs waiting to display
var _active_id: String = ""      ## ID of the tooltip currently shown, or ""


func _ready() -> void:
	layer = 20
	_build_ui()
	visible = false


## Wire the TutorialSystem instance.  Must be called before queue_tooltip().
func setup(tutorial_sys: TutorialSystem) -> void:
	_tutorial_sys = tutorial_sys


## Add a tooltip to the display queue.  Silently skips if already seen or
## already queued.
func queue_tooltip(tooltip_id: String) -> void:
	if _tutorial_sys == null:
		return
	if _tutorial_sys.has_seen(tooltip_id):
		return
	if _queue.has(tooltip_id) or _active_id == tooltip_id:
		return
	_queue.append(tooltip_id)
	if _active_id == "":
		_show_next()


# ── Internal display ──────────────────────────────────────────────────────────

func _show_next() -> void:
	if _queue.is_empty():
		_active_id = ""
		visible    = false
		return

	_active_id = _queue.pop_front()
	if _tutorial_sys.has_seen(_active_id):
		_show_next()
		return

	var data: Dictionary = _tutorial_sys.get_tooltip(_active_id)
	if data.is_empty():
		_show_next()
		return

	_title_label.text = data.get("title", "")
	_body_label.text  = data.get("body", "")
	visible = true


func _on_dismiss_pressed() -> void:
	if _tutorial_sys != null and _active_id != "":
		_tutorial_sys.mark_seen(_active_id)
	_active_id = ""
	_show_next()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen semi-transparent backdrop — blocks mouse input.
	_backdrop = ColorRect.new()
	_backdrop.color               = C_BACKDROP
	_backdrop.anchor_right        = 1.0
	_backdrop.anchor_bottom       = 1.0
	_backdrop.mouse_filter        = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Outer panel, centered.
	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -PANEL_WIDTH  / 2.0
	_panel.offset_top    = -PANEL_HEIGHT / 2.0
	_panel.offset_right  =  PANEL_WIDTH  / 2.0
	_panel.offset_bottom =  PANEL_HEIGHT / 2.0
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Style the panel background.
	var style := StyleBoxFlat.new()
	style.bg_color          = C_PANEL_BG
	style.border_color      = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 24.0
	style.content_margin_right  = 24.0
	style.content_margin_top    = 18.0
	style.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# VBox inside the panel.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Title label.
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", C_HEADING)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Separator.
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.content_margin_top    = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Body text (BBCode enabled for [b] tags).
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content    = true
	_body_label.scroll_active  = false
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_color_override("default_color",    C_BODY)
	_body_label.add_theme_color_override("font_bold_color",  C_HEADING)
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	_body_label.add_theme_font_size_override("bold_font_size",   14)
	vbox.add_child(_body_label)

	# Spacer.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Dismiss button row (right-aligned).
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	_dismiss_btn = Button.new()
	_dismiss_btn.text                    = "  Got it!  "
	_dismiss_btn.custom_minimum_size     = Vector2(100, 32)
	_dismiss_btn.add_theme_font_size_override("font_size", 14)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = C_BTN_NORMAL
	btn_normal.set_corner_radius_all(4)
	btn_normal.content_margin_left   = 12.0
	btn_normal.content_margin_right  = 12.0
	btn_normal.content_margin_top    = 6.0
	btn_normal.content_margin_bottom = 6.0
	_dismiss_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = C_BTN_HOVER
	btn_hover.set_corner_radius_all(4)
	btn_hover.content_margin_left   = 12.0
	btn_hover.content_margin_right  = 12.0
	btn_hover.content_margin_top    = 6.0
	btn_hover.content_margin_bottom = 6.0
	_dismiss_btn.add_theme_stylebox_override("hover",   btn_hover)
	_dismiss_btn.add_theme_stylebox_override("pressed", btn_hover)

	_dismiss_btn.add_theme_color_override("font_color",          C_BTN_TEXT)
	_dismiss_btn.add_theme_color_override("font_hover_color",    C_BTN_TEXT)
	_dismiss_btn.add_theme_color_override("font_pressed_color",  C_BTN_TEXT)

	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	btn_row.add_child(_dismiss_btn)

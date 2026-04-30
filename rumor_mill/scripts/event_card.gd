extends CanvasLayer

## event_card.gd — SPA-953: Parchment-style event card overlay with screen dim.
##
## Displayed whenever FactionEventSystem fires event_activated.  Pauses the game
## while visible and resumes on dismiss.  Procedurally built; no scene file needed.
##
## Usage from main.gd:
##   var event_card := preload("res://scripts/event_card.gd").new()
##   event_card.name = "EventCard"
##   add_child(event_card)
##   world.faction_event_system.event_activated.connect(event_card.show_event)

# ── Palette (matches tutorial_banner.gd) ─────────────────────────────────────

const C_PANEL_BG  := Color(0.06, 0.04, 0.02, 0.95)
const C_ACCENT    := Color(0.957, 0.651, 0.227, 1.0)   # amber #F4A63A
const C_HEADING   := Color(0.96, 0.84, 0.40, 1.0)      # warm gold
const C_BODY      := Color(0.80, 0.72, 0.55, 1.0)      # parchment
const C_BTN_BG    := Color(0.30, 0.18, 0.05, 0.90)
const C_BTN_HOVER := Color(0.50, 0.30, 0.08, 1.0)
const C_BTN_TEXT  := Color(0.92, 0.82, 0.60, 1.0)
const C_DIM_MAX   := 0.5                                # target alpha for screen dim

const CARD_W := 450.0
const CARD_H := 300.0

const DIM_TIME    := 0.5   # seconds for backdrop fade-in
const CARD_TIME   := 0.25  # seconds for card fade-in after dim starts

# ── Node refs ─────────────────────────────────────────────────────────────────

var _dim:        ColorRect = null
var _card:       Panel     = null
var _title_lbl:  Label     = null
var _body_lbl:   RichTextLabel = null
var _day_lbl:    Label     = null
var _dismiss_btn: Button   = null


func _ready() -> void:
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false


## Called by main.gd when FactionEventSystem.event_activated fires.
func show_event(label: String, description: String, day: int) -> void:
	_build_ui(label, description, day)
	visible = true
	get_tree().paused = true

	# Tween dim backdrop from alpha 0 → C_DIM_MAX.
	_dim.color.a = 0.0
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dim,  "color:a",     C_DIM_MAX, DIM_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 1.0, CARD_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE) \
		.set_delay(DIM_TIME * 0.5)

	# SFX — silently skipped if the asset is absent.
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("event_sting")


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui(label: String, description: String, day: int) -> void:
	# Remove any previous card built by an earlier event this run.
	if _dim != null:
		_dim.queue_free()
	if _card != null:
		_card.queue_free()

	# Full-screen dim.
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# Parchment card panel (~450 × 300, centered).
	_card = Panel.new()
	_card.anchor_left   = 0.5
	_card.anchor_right  = 0.5
	_card.anchor_top    = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left   = -CARD_W * 0.5
	_card.offset_right  =  CARD_W * 0.5
	_card.offset_top    = -CARD_H * 0.5
	_card.offset_bottom =  CARD_H * 0.5
	_card.mouse_filter  = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = C_PANEL_BG
	card_style.border_color = C_ACCENT
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", card_style)
	add_child(_card)

	# VBox for content.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 20
	vbox.offset_right  = -20
	vbox.offset_top    = 16
	vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 10)
	_card.add_child(vbox)

	# "EVENT" badge.
	var badge := Label.new()
	badge.text = "FACTION EVENT"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.7))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	_add_divider(vbox)

	# Title (event label).
	_title_lbl = Label.new()
	_title_lbl.text = label
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", C_HEADING)
	_title_lbl.add_theme_constant_override("outline_size", 2)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 0.8))
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_lbl)

	# Day label.
	_day_lbl = Label.new()
	_day_lbl.text = "Day %d" % day
	_day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_lbl.add_theme_font_size_override("font_size", 12)
	_day_lbl.add_theme_color_override("font_color", Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.6))
	_day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_day_lbl)

	_add_divider(vbox)

	# Description body.
	_body_lbl = RichTextLabel.new()
	_body_lbl.bbcode_enabled = true
	_body_lbl.fit_content           = true
	_body_lbl.custom_minimum_size   = Vector2(0, 0)
	_body_lbl.custom_maximum_size   = Vector2(0, 120)
	_body_lbl.scroll_active         = true
	_body_lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.text = description
	_body_lbl.add_theme_color_override("default_color", C_BODY)
	_body_lbl.add_theme_font_size_override("normal_font_size", 13)
	_body_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_body_lbl)

	# Spacer pushes button to bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Dismiss button.
	var btn_center := CenterContainer.new()
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_center)

	_dismiss_btn = Button.new()
	_dismiss_btn.text = "UNDERSTOOD"
	_dismiss_btn.custom_minimum_size = Vector2(160, 36)
	_dismiss_btn.add_theme_font_size_override("font_size", 14)
	_dismiss_btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = C_BTN_BG
	btn_normal.border_color = C_ACCENT
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(8)
	_dismiss_btn.add_theme_stylebox_override("normal",  btn_normal)
	_dismiss_btn.add_theme_stylebox_override("pressed", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = C_BTN_HOVER
	btn_hover.border_color = C_ACCENT
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(8)
	_dismiss_btn.add_theme_stylebox_override("hover", btn_hover)

	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	btn_center.add_child(_dismiss_btn)
	_dismiss_btn.grab_focus()

	# Keyboard hint.
	var hint := Label.new()
	hint.text = "or press SPACE / ENTER"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42, 0.6))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)


func _add_divider(parent: VBoxContainer) -> void:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 4)
	var style := StyleBoxLine.new()
	style.color = Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.4)
	style.thickness = 1
	div.add_theme_stylebox_override("separator", style)
	parent.add_child(div)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_dismiss_pressed()


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _on_dismiss_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	var tw := create_tween()
	tw.tween_property(_dim,  "color:a",     0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	get_tree().paused = false
	visible = false

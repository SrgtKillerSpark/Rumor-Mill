extends CanvasLayer

## whats_changed_card.gd — SPA-948: Non-auto-dismiss "What's Changed" overlay
## shown for Scenarios 2-6 immediately after Mission Briefing dismiss.
##
## Displays scenario-specific bullet points highlighting new mechanics
## and win conditions.  Player must press "Got it" (or SPACE / ENTER) to
## dismiss; there is no auto-dismiss timer.
##
## Usage from main.gd:
##   var card := preload("res://scripts/whats_changed_card.gd").new()
##   card.name = "WhatsChangedCard"
##   add_child(card)
##   card.setup(title_string, bullets_array)
##   card.dismissed.connect(_on_whats_changed_dismissed)

signal dismissed

# ── Palette (matches mission_briefing.gd) ────────────────────────────────────

const C_BACKDROP    := Color(0.03, 0.02, 0.05, 0.80)
const C_CARD_BG     := Color(0.08, 0.06, 0.04, 0.95)
const C_CARD_BORDER := Color(0.957, 0.651, 0.227, 0.8)
const C_TITLE       := Color(0.96, 0.84, 0.40, 1.0)
const C_BODY        := Color(0.80, 0.72, 0.55, 1.0)
const C_PHASE_HDR   := Color(0.75, 0.65, 0.45, 0.6)
const C_BTN_NORMAL  := Color(0.15, 0.45, 0.15, 1.0)
const C_BTN_HOVER   := Color(0.20, 0.55, 0.20, 1.0)
const C_BTN_TEXT    := Color(0.95, 0.95, 0.90, 1.0)

# ── Node refs ─────────────────────────────────────────────────────────────────

var _backdrop: ColorRect     = null
var _card:     Panel         = null
var _vbox:     VBoxContainer = null
var _btn:      Button        = null


func _ready() -> void:
	layer        = 17              # above MissionBriefing (16), below pause (20)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Build and show the card.
## title:   headline shown below the "WHAT'S CHANGED" badge.
## bullets: Array of BBCode strings, one per mechanic highlight.
func setup(title: String, bullets: Array) -> void:
	_build_shell()
	_populate_content(title, bullets)


# ── Shell ─────────────────────────────────────────────────────────────────────

func _build_shell() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_card = Panel.new()
	_card.anchor_left   = 0.5
	_card.anchor_right  = 0.5
	_card.anchor_top    = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left   = -290.0
	_card.offset_right  =  290.0
	_card.offset_top    = -215.0
	_card.offset_bottom =  215.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = C_CARD_BG
	card_style.border_color = C_CARD_BORDER
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", card_style)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left   = 20
	_vbox.offset_right  = -20
	_vbox.offset_top    = 16
	_vbox.offset_bottom = -16
	_vbox.add_theme_constant_override("separation", 10)
	_card.add_child(_vbox)


# ── Content ───────────────────────────────────────────────────────────────────

func _populate_content(title: String, bullets: Array) -> void:
	# Header badge.
	var badge := Label.new()
	badge.text = "WHAT'S  CHANGED"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", C_PHASE_HDR)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(badge)

	_add_divider()

	# Scenario sub-title.
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", C_TITLE)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(title_lbl)

	_add_divider()

	# Bullet points (BBCode).
	for bullet_text in bullets:
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content    = true
		rtl.scroll_active  = false
		rtl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "• " + bullet_text
		rtl.add_theme_color_override("default_color", C_BODY)
		rtl.add_theme_font_size_override("normal_font_size", 14)
		rtl.add_theme_font_size_override("bold_font_size", 14)
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(rtl)

	_add_divider()

	# Flexible spacer pushes button to the bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(spacer)

	# "Got it" button.
	var btn_center := CenterContainer.new()
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(btn_center)

	_btn = Button.new()
	_btn.text = "GOT IT"
	_btn.custom_minimum_size = Vector2(160, 40)
	_btn.add_theme_font_size_override("font_size", 16)
	_btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = C_BTN_NORMAL
	btn_style.border_color = C_CARD_BORDER
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = C_BTN_HOVER
	btn_hover.border_color = C_CARD_BORDER
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)
	_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = C_BTN_NORMAL.darkened(0.15)
	btn_pressed.border_color = C_CARD_BORDER
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.set_content_margin_all(8)
	_btn.add_theme_stylebox_override("pressed", btn_pressed)

	var btn_focus := btn_style.duplicate()
	btn_focus.border_color = Color(0.96, 0.84, 0.40, 0.9)
	btn_focus.set_border_width_all(2)
	_btn.add_theme_stylebox_override("focus", btn_focus)

	_btn.pressed.connect(_dismiss)
	btn_center.add_child(_btn)
	_btn.grab_focus()

	# Keyboard hint below button.
	var hint_lbl := Label.new()
	hint_lbl.text = "or press SPACE / ENTER"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42, 0.6))
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(hint_lbl)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_divider() -> void:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 6)
	var style := StyleBoxLine.new()
	style.color = C_CARD_BORDER
	style.thickness = 1
	div.add_theme_stylebox_override("separator", style)
	_vbox.add_child(div)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_dismiss()


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _dismiss() -> void:
	AudioManager.play_ui("click")
	var tw := create_tween()
	tw.tween_property(_backdrop, "color:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		dismissed.emit()
		queue_free()
	)

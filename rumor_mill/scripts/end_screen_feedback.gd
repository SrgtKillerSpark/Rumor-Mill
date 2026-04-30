class_name EndScreenFeedback
extends RefCounted

## end_screen_feedback.gd — Post-game feedback prompt modal for EndScreen.
##
## Extracted from end_screen.gd (SPA-1010). Owns the full feedback overlay
## (SPA-336): preset buttons, freetext field, submit / skip logic.
##
## Call setup(parent_layer, btn_again) once. Then call show_prompt(won, scenario_id)
## from a delayed timer after the end screen is visible.

# ── Constants ─────────────────────────────────────────────────────────────────
const FEEDBACK_PRESETS := [
	"Understanding the social graph",
	"Managing whisper tokens",
	"Avoiding detection",
	"Knowing which NPCs to target",
]
const FEEDBACK_PANEL_MIN_W := 420
const FEEDBACK_PANEL_MAX_W := 560
const FEEDBACK_PANEL_MIN_H := 300
const FEEDBACK_PANEL_MAX_H := 420

# ── Palette ───────────────────────────────────────────────────────────────────
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_PRESET_NORMAL   := Color(0.22, 0.15, 0.10, 1.0)
const C_PRESET_SELECTED := Color(0.55, 0.38, 0.18, 1.0)
const FEEDBACK_CHAR_LIMIT := 200

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _parent:    CanvasLayer = null
var _btn_again: Button      = null

# ── Overlay node refs ─────────────────────────────────────────────────────────
var _feedback_backdrop:        ColorRect      = null
var _feedback_panel:           PanelContainer = null
var _feedback_preset_btns:     Array          = []
var _feedback_selected_preset: int            = -1
var _feedback_text_edit:       TextEdit       = null
var _feedback_char_lbl:        Label          = null


func setup(parent_layer: CanvasLayer, btn_again_ref: Button) -> void:
	_parent    = parent_layer
	_btn_again = btn_again_ref


## Build and show the feedback modal overlay.
## won and current_scenario_id are used when submitting the response.
func show_prompt(won: bool, current_scenario_id: String) -> void:
	if _parent == null or not _parent.visible:
		return

	_feedback_selected_preset = -1
	_feedback_preset_btns.clear()

	# ── Dimming overlay ───────────────────────────────────────────────────────
	_feedback_backdrop = ColorRect.new()
	_feedback_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_feedback_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parent.add_child(_feedback_backdrop)

	# ── Centred panel ─────────────────────────────────────────────────────────
	_feedback_panel = PanelContainer.new()
	_feedback_panel.custom_minimum_size = Vector2(FEEDBACK_PANEL_MIN_W, FEEDBACK_PANEL_MIN_H)
	_feedback_panel.custom_maximum_size = Vector2(FEEDBACK_PANEL_MAX_W, FEEDBACK_PANEL_MAX_H)
	_feedback_panel.set_anchor(SIDE_LEFT,   0.5)
	_feedback_panel.set_anchor(SIDE_RIGHT,  0.5)
	_feedback_panel.set_anchor(SIDE_TOP,    0.5)
	_feedback_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_feedback_panel.set_offset(SIDE_LEFT,   -FEEDBACK_PANEL_MIN_W / 2.0)
	_feedback_panel.set_offset(SIDE_RIGHT,   FEEDBACK_PANEL_MIN_W / 2.0)
	_feedback_panel.set_offset(SIDE_TOP,    -FEEDBACK_PANEL_MIN_H / 2.0)
	_feedback_panel.set_offset(SIDE_BOTTOM,  FEEDBACK_PANEL_MIN_H / 2.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = C_PANEL_BG
	panel_style.border_color = C_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(24)
	_feedback_panel.add_theme_stylebox_override("panel", panel_style)
	_parent.add_child(_feedback_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_feedback_panel.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.text = "Before you go\u2026"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", C_WIN)
	vbox.add_child(title_lbl)

	vbox.add_child(_make_separator())

	# ── Question ──────────────────────────────────────────────────────────────
	var question_lbl := Label.new()
	question_lbl.text = "What was the hardest part?"
	question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_lbl.add_theme_font_size_override("font_size", 15)
	question_lbl.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(question_lbl)

	# ── Preset option buttons ─────────────────────────────────────────────────
	var options_vbox := VBoxContainer.new()
	options_vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(options_vbox)

	for i in range(FEEDBACK_PRESETS.size()):
		var opt_btn := _make_preset_button(FEEDBACK_PRESETS[i], i)
		_feedback_preset_btns.append(opt_btn)
		options_vbox.add_child(opt_btn)

	# ── Freetext field ────────────────────────────────────────────────────────
	var text_label := Label.new()
	text_label.text = "Other thoughts (optional)"
	text_label.add_theme_font_size_override("font_size", 12)
	text_label.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(text_label)

	_feedback_text_edit = TextEdit.new()
	_feedback_text_edit.custom_minimum_size = Vector2(0, 52)
	_feedback_text_edit.placeholder_text = "Up to 200 characters\u2026"
	_feedback_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY

	var te_style := StyleBoxFlat.new()
	te_style.bg_color = C_CARD_BG
	te_style.border_color = C_PANEL_BORDER
	te_style.set_border_width_all(1)
	te_style.set_content_margin_all(6)
	_feedback_text_edit.add_theme_stylebox_override("normal", te_style)
	_feedback_text_edit.add_theme_stylebox_override("focus",  te_style)
	_feedback_text_edit.add_theme_color_override("font_color", C_BODY)
	_feedback_text_edit.text_changed.connect(_on_feedback_text_changed)
	vbox.add_child(_feedback_text_edit)

	# Char count indicator.
	_feedback_char_lbl = Label.new()
	_feedback_char_lbl.text = "0 / %d" % FEEDBACK_CHAR_LIMIT
	_feedback_char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feedback_char_lbl.add_theme_font_size_override("font_size", 12)
	_feedback_char_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_feedback_char_lbl)

	# ── Action buttons ────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var btn_submit := _make_button("Submit", 130)
	# Capture scenario state for the submit closure.
	var scenario_id_ref := current_scenario_id
	btn_submit.pressed.connect(func() -> void: _on_feedback_submit(scenario_id_ref))
	btn_row.add_child(btn_submit)

	var btn_skip := _make_button("Skip", 100)
	btn_skip.pressed.connect(_on_feedback_skip)
	btn_row.add_child(btn_skip)

	btn_submit.call_deferred("grab_focus")


# ── Private helpers ───────────────────────────────────────────────────────────

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _make_button(label: String, min_width: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(min_width, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_PANEL_BORDER
	normal.set_content_margin_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_PANEL_BORDER
	hover.set_content_margin_all(8)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_BTN_HOVER
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_stylebox_override("focus",  focus_style)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	return btn


func _make_preset_button(label_text: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_PRESET_NORMAL
	normal.border_color = C_PANEL_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.border_color = C_PANEL_BORDER
	hover.set_border_width_all(1)
	hover.set_content_margin_all(6)

	var focus := StyleBoxFlat.new()
	focus.bg_color = C_BTN_HOVER
	focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus.set_border_width_all(2)
	focus.set_content_margin_all(6)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus",   focus)

	btn.pressed.connect(func() -> void: _on_preset_selected(index))
	return btn


func _on_preset_selected(index: int) -> void:
	_feedback_selected_preset = index
	for i in range(_feedback_preset_btns.size()):
		var b: Button = _feedback_preset_btns[i]
		var style := b.get_theme_stylebox("normal") as StyleBoxFlat
		if style != null:
			style.bg_color = C_PRESET_SELECTED if i == index else C_PRESET_NORMAL


func _on_feedback_text_changed() -> void:
	if _feedback_text_edit == null or _feedback_char_lbl == null:
		return
	var txt := _feedback_text_edit.text
	if txt.length() > FEEDBACK_CHAR_LIMIT:
		_feedback_text_edit.text = txt.left(FEEDBACK_CHAR_LIMIT)
		_feedback_text_edit.set_caret_column(FEEDBACK_CHAR_LIMIT)
	_feedback_char_lbl.text = "%d / %d" % [_feedback_text_edit.text.length(), FEEDBACK_CHAR_LIMIT]


func _on_feedback_submit(current_scenario_id: String) -> void:
	var freetext := _feedback_text_edit.text.strip_edges() if _feedback_text_edit != null else ""
	PlayerStats.record_feedback(
		current_scenario_id,
		GameState.selected_difficulty,
		_feedback_selected_preset,
		freetext,
	)
	_dismiss()


func _on_feedback_skip() -> void:
	_dismiss()


func _dismiss() -> void:
	if _feedback_backdrop != null:
		_feedback_backdrop.queue_free()
		_feedback_backdrop = null
	if _feedback_panel != null:
		_feedback_panel.queue_free()
		_feedback_panel = null
	_feedback_text_edit = null
	_feedback_char_lbl = null
	_feedback_preset_btns.clear()
	if _btn_again != null:
		_btn_again.call_deferred("grab_focus")

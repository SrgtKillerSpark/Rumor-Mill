extends CanvasLayer

## event_choice_modal.gd — Modal overlay for mid-game narrative event choices.
##
## Displays the event description and two choice buttons.  Blocks input while
## visible (same pattern as TutorialHUD).  Emits `choice_made` when the player
## picks an option, then shows the outcome text with a dismiss button.
##
## SPA-953: Enhanced with 500ms screen-dim tween, SFX sting on presentation,
## and qualitative choicePreview text under each choice button.
##
## Usage from main.gd:
##   var modal := preload("res://scripts/event_choice_modal.gd").new()
##   modal.name = "EventChoiceModal"
##   add_child(modal)
##   modal.present_event(event_data)
##   modal.choice_made.connect(_on_event_choice_made)

# ── Palette (matches dark HUD theme) ─────────────────────────────────────────

const C_BACKDROP      := Color(0.04, 0.02, 0.01, 0.82)
const C_PANEL_BG      := Color(0.10, 0.07, 0.04, 1.0)
const C_PANEL_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_HEADING       := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_BODY          := Color(0.80, 0.72, 0.55, 1.0)   # warm parchment
const C_BTN_NORMAL    := Color(0.35, 0.22, 0.08, 1.0)
const C_BTN_HOVER     := Color(0.55, 0.35, 0.12, 1.0)
const C_BTN_TEXT      := Color(0.92, 0.82, 0.60, 1.0)
const C_OUTCOME_BG    := Color(0.08, 0.06, 0.03, 1.0)
const C_PREVIEW       := Color(0.60, 0.52, 0.38, 1.0)   # muted parchment for choicePreview

const PANEL_WIDTH  := 700
const PANEL_HEIGHT := 420

## Duration of the backdrop dim-in tween (SPA-953).
const DIM_TWEEN_SECS := 0.5

## Emitted when the player picks a choice.
## event_id: String, choice_index: int (0 or 1).
signal choice_made(event_id: String, choice_index: int)

## Emitted when the outcome text is dismissed and the modal closes.
signal dismissed()

# ── Node refs (built in _ready) ───────────────────────────────────────────────

var _backdrop:      ColorRect      = null
var _panel:         PanelContainer = null
var _title_label:   Label          = null
var _body_label:    RichTextLabel  = null
var _choice_a_btn:  Button         = null
var _choice_b_btn:  Button         = null
var _preview_a:     Label          = null
var _preview_b:     Label          = null
var _outcome_label: RichTextLabel  = null
var _dismiss_btn:   Button         = null

# ── State ─────────────────────────────────────────────────────────────────────

var _current_event_id: String = ""
var _showing_outcome: bool = false


func _ready() -> void:
	layer = 21  # Above TutorialHUD (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and _showing_outcome:
			_on_dismiss_pressed()
			get_viewport().set_input_as_handled()


## Show the event and its two choices.
func present_event(event_data: Dictionary) -> void:
	_current_event_id = str(event_data.get("id", ""))
	_showing_outcome = false

	_title_label.text = str(event_data.get("name", "Event"))
	_body_label.text = str(event_data.get("description", ""))

	var choices: Array = event_data.get("choices", [])
	if choices.size() >= 1:
		_choice_a_btn.text = str(choices[0].get("label", "Choice A"))
		_choice_a_btn.visible = true
		var prev_a: String = str(choices[0].get("choicePreview", ""))
		_preview_a.text = prev_a
		_preview_a.visible = not prev_a.is_empty()
	else:
		_choice_a_btn.visible = false
		_preview_a.visible = false

	if choices.size() >= 2:
		_choice_b_btn.text = str(choices[1].get("label", "Choice B"))
		_choice_b_btn.visible = true
		var prev_b: String = str(choices[1].get("choicePreview", ""))
		_preview_b.text = prev_b
		_preview_b.visible = not prev_b.is_empty()
	else:
		_choice_b_btn.visible = false
		_preview_b.visible = false

	_outcome_label.visible = false
	_dismiss_btn.visible = false
	_body_label.visible = true
	_choice_a_btn.visible = choices.size() >= 1
	_choice_b_btn.visible = choices.size() >= 2

	# SPA-953: Animate backdrop dim-in and play SFX sting.
	_backdrop.color.a = 0.0
	visible = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_backdrop, "color:a", C_BACKDROP.a, DIM_TWEEN_SECS)

	var audio := _get_audio_manager()
	if audio != null:
		audio.play_sfx("event_sting")

	get_tree().paused = true

	# Keyboard focus: grab the first visible choice button.
	if _choice_a_btn.visible:
		_choice_a_btn.call_deferred("grab_focus")
	elif _choice_b_btn.visible:
		_choice_b_btn.call_deferred("grab_focus")


## Show the outcome text after a choice is made.
func show_outcome(outcome_text: String) -> void:
	_showing_outcome = true
	_choice_a_btn.visible = false
	_choice_b_btn.visible = false
	_preview_a.visible = false
	_preview_b.visible = false
	_body_label.visible = false

	_outcome_label.text = outcome_text
	_outcome_label.visible = true
	_dismiss_btn.visible = true
	_dismiss_btn.grab_focus()


# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Backdrop — fullscreen semi-transparent.
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = C_BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Panel — centred.
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-PANEL_WIDTH / 2.0, -PANEL_HEIGHT / 2.0)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL_BG
	sb.border_color = C_PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# Title.
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", C_HEADING)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Description body.
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.custom_minimum_size = Vector2(0, 80)
	_body_label.add_theme_color_override("default_color", C_BODY)
	_body_label.add_theme_font_size_override("normal_font_size", 15)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_label)

	# Outcome label (hidden initially).
	_outcome_label = RichTextLabel.new()
	_outcome_label.bbcode_enabled = true
	_outcome_label.fit_content = true
	_outcome_label.scroll_active = false
	_outcome_label.custom_minimum_size = Vector2(0, 80)
	_outcome_label.add_theme_color_override("default_color", C_BODY)
	_outcome_label.add_theme_font_size_override("normal_font_size", 15)
	_outcome_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outcome_label.visible = false
	vbox.add_child(_outcome_label)

	# Choice buttons container.
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_box)

	_choice_a_btn = _make_choice_button("Choice A")
	_choice_a_btn.pressed.connect(_on_choice_a_pressed)
	btn_box.add_child(_choice_a_btn)

	_preview_a = _make_preview_label()
	btn_box.add_child(_preview_a)

	_choice_b_btn = _make_choice_button("Choice B")
	_choice_b_btn.pressed.connect(_on_choice_b_pressed)
	btn_box.add_child(_choice_b_btn)

	_preview_b = _make_preview_label()
	btn_box.add_child(_preview_b)

	# Dismiss button (hidden initially).
	_dismiss_btn = _make_choice_button("Continue")
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_dismiss_btn.visible = false
	btn_box.add_child(_dismiss_btn)

	# Focus neighbors for keyboard navigation between choice buttons.
	_choice_a_btn.focus_neighbor_bottom = _choice_b_btn.get_path()
	_choice_a_btn.focus_next           = _choice_b_btn.get_path()
	_choice_b_btn.focus_neighbor_top   = _choice_a_btn.get_path()
	_choice_b_btn.focus_previous       = _choice_a_btn.get_path()
	# Wrap around for circular navigation.
	_choice_a_btn.focus_neighbor_top   = _choice_b_btn.get_path()
	_choice_a_btn.focus_previous       = _choice_b_btn.get_path()
	_choice_b_btn.focus_neighbor_bottom = _choice_a_btn.get_path()
	_choice_b_btn.focus_next           = _choice_a_btn.get_path()


func _make_choice_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_PANEL_BORDER
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = C_BTN_HOVER
	btn.add_theme_stylebox_override("hover", hover)

	var focus := normal.duplicate()
	focus.bg_color = C_BTN_HOVER
	focus.set_border_width_all(2)
	focus.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold focus ring
	btn.add_theme_stylebox_override("focus", focus)

	var pressed := normal.duplicate()
	pressed.bg_color = C_BTN_HOVER
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", C_BTN_TEXT)
	btn.add_theme_font_size_override("font_size", 14)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	return btn


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_choice_a_pressed() -> void:
	choice_made.emit(_current_event_id, 0)


func _on_choice_b_pressed() -> void:
	choice_made.emit(_current_event_id, 1)


func _on_dismiss_pressed() -> void:
	visible = false
	get_tree().paused = false
	dismissed.emit()


## Build a small italic label for choicePreview text under a choice button.
func _make_preview_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_color_override("font_color", C_PREVIEW)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(PANEL_WIDTH - 80, 0)
	lbl.visible = false
	return lbl


## Locate the AudioManager autoload (safe to return null).
func _get_audio_manager() -> Node:
	if Engine.has_singleton("AudioManager"):
		return Engine.get_singleton("AudioManager")
	var root := get_tree().root if get_tree() != null else null
	if root != null and root.has_node("AudioManager"):
		return root.get_node("AudioManager")
	return null

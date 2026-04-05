extends CanvasLayer

## ready_overlay.gd — SPA-519 / SPA-537: Mission briefing overlay.
##
## Shown once on Day 1 game start. Replaced the old "press Space" prompt with
## a full mission briefing card that states the objective, win condition, danger,
## and first action — so the player knows exactly what to do before time starts.
##
## Reads objectiveCard data from scenarios.json via GameState + world reference.

signal dismissed

# ── Palette ──────────────────────────────────────────────────────────────────

const C_BACKDROP     := Color(0.03, 0.02, 0.05, 0.75)
const C_CARD_BG      := Color(0.08, 0.06, 0.04, 0.95)
const C_CARD_BORDER  := Color(0.957, 0.651, 0.227, 0.8)   # amber
const C_TITLE        := Color(0.96, 0.84, 0.40, 1.0)       # warm gold
const C_MISSION      := Color(1.0, 0.92, 0.70, 1.0)        # bright parchment
const C_BODY         := Color(0.80, 0.72, 0.55, 1.0)       # parchment
const C_DANGER       := Color(0.95, 0.35, 0.25, 1.0)       # red warning
const C_HINT         := Color(0.65, 0.85, 0.55, 1.0)       # soft green
const C_ACTION       := Color(0.50, 0.80, 1.00, 1.0)       # action blue
const C_PROMPT       := Color(0.95, 0.88, 0.65, 1.0)       # warm prompt

# ── Node refs ────────────────────────────────────────────────────────────────

var _backdrop:      ColorRect    = null
var _card:          Panel        = null
var _prompt_label:  Label        = null
var _pulse_tween:   Tween        = null

# ── Objective data (injected by setup()) ─────────────────────────────────────

var _objective_card: Dictionary   = {}
var _scenario_title: String       = ""
## SPA-627: When true this is a player-triggered recall, not the initial game-start briefing.
var _recall_mode: bool = false


func _ready() -> void:
	layer        = 15   # above HUD (5), below pause menu (20)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Call after adding to the tree. Provide the objectiveCard dict and scenario title.
func setup(objective_card: Dictionary, scenario_title: String) -> void:
	_objective_card = objective_card
	_scenario_title = scenario_title
	_build_ui()


## SPA-627: Re-display the briefing card mid-game (read-only, no "begin" prompt).
## Dismiss with SPACE, ENTER, or ESC — does not start/unpause the game.
func setup_recall(objective_card: Dictionary, scenario_title: String) -> void:
	_recall_mode = true
	_objective_card = objective_card
	_scenario_title = scenario_title
	_build_ui()


func _build_ui() -> void:
	# ── Full-screen dark backdrop ────────────────────────────────────────────
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# ── Centered briefing card (520 px wide, auto-height) ────────────────────
	_card = Panel.new()
	_card.anchor_left   = 0.5
	_card.anchor_right  = 0.5
	_card.anchor_top    = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left   = -260.0
	_card.offset_right  =  260.0
	_card.offset_top    = -220.0
	_card.offset_bottom =  220.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = C_CARD_BG
	card_style.border_color = C_CARD_BORDER
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", card_style)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	# ── Card content ─────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 20
	vbox.offset_right  = -20
	vbox.offset_top    = 16
	vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 8)
	_card.add_child(vbox)

	# Scenario title.
	var title := Label.new()
	title.text = _scenario_title.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", C_TITLE)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Divider.
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 6)
	div.add_theme_stylebox_override("separator", _make_line_style(C_CARD_BORDER))
	vbox.add_child(div)

	# Mission statement (large, bold feel).
	var mission := _objective_card.get("mission", "")
	if mission != "":
		var lbl := Label.new()
		lbl.text = mission
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", C_MISSION)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.02, 0.6))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	# Win condition.
	var win := _objective_card.get("winCondition", "")
	if win != "":
		_add_labeled_line(vbox, "WIN:", win, C_HINT)

	# Time limit.
	var time_limit := _objective_card.get("timeLimit", "")
	if time_limit != "":
		_add_labeled_line(vbox, "TIME:", time_limit, C_BODY)

	# Danger warning.
	var danger := _objective_card.get("danger", "")
	if danger != "":
		_add_labeled_line(vbox, "DANGER:", danger, C_DANGER)

	# Strategy hint.
	var strat := _objective_card.get("strategyHint", "")
	if strat != "":
		_add_labeled_line(vbox, "STRATEGY:", strat, C_BODY)

	# First action — what to do RIGHT NOW.
	var first_action := _objective_card.get("firstAction", "")
	if first_action != "":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(spacer)
		_add_labeled_line(vbox, "FIRST MOVE:", first_action, C_ACTION)

	# Bottom spacer.
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(bottom_spacer)

	# Prompt — pulsing.  Text depends on recall vs. first-run mode.
	_prompt_label = Label.new()
	_prompt_label.text = "—  Press  SPACE  or  ESC  to  close  —" if _recall_mode \
		else "—  Press  SPACE  or  ENTER  to  begin  —"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_color", C_PROMPT)
	_prompt_label.add_theme_constant_override("outline_size", 2)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_prompt_label)

	_start_pulse()


func _add_labeled_line(parent: VBoxContainer, label_text: String, body_text: String, body_color: Color) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content    = true
	rtl.scroll_active  = false
	rtl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(0, 0)
	rtl.text = "[b][color=#%s]%s[/color][/b] %s" % [
		C_TITLE.to_html(false), label_text, body_text
	]
	rtl.add_theme_color_override("default_color", body_color)
	rtl.add_theme_font_size_override("normal_font_size", 12)
	rtl.add_theme_font_size_override("bold_font_size", 12)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rtl)


func _make_line_style(color: Color) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	return style


func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 0.45, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 1.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var dismiss_key: bool = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
		var recall_dismiss: bool = _recall_mode and event.keycode == KEY_ESCAPE
		if dismiss_key or recall_dismiss:
			get_viewport().set_input_as_handled()
			_dismiss()


func _dismiss() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	# Quick fade-out then free.
	var tw := create_tween()
	tw.tween_property(_backdrop, "color:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		emit_signal("dismissed")
		queue_free()
	)

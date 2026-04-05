extends CanvasLayer

## ready_overlay.gd — SPA-519 / SPA-537 / SPA-625: Two-phase mission briefing overlay.
##
## Shown once on Day 1 game start. Phase 1 ("The Mission") presents the
## narrative hook, objective, and win condition.  Phase 2 ("Your Plan") shows
## the tactical details: first move, strategy, danger, and time limit with a
## visual day bar.  Recall mode (SPA-627) shows all info in a single read-only card.
##
## Reads objectiveCard + introText data from scenarios.json via GameState + world reference.

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
const C_PHASE_HEADER := Color(0.75, 0.65, 0.45, 0.6)       # subtle phase label

# ── Node refs ────────────────────────────────────────────────────────────────

var _backdrop:      ColorRect    = null
var _card:          Panel        = null
var _vbox:          VBoxContainer = null
var _prompt_label:  Label        = null
var _pulse_tween:   Tween        = null

# ── State ────────────────────────────────────────────────────────────────────

var _objective_card: Dictionary   = {}
var _scenario_title: String       = ""
var _intro_text:     String       = ""
## SPA-627: When true this is a player-triggered recall, not the initial game-start briefing.
var _recall_mode: bool = false
## Which phase is currently showing (1 or 2). In recall mode, always 0 (single card).
var _current_phase: int = 0


func _ready() -> void:
	layer        = 15   # above HUD (5), below pause menu (20)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Call after adding to the tree. Provide the objectiveCard dict, scenario title, and intro text.
func setup(objective_card: Dictionary, scenario_title: String, intro_text: String = "") -> void:
	_objective_card = objective_card
	_scenario_title = scenario_title
	_intro_text = intro_text
	_recall_mode = false
	_build_shell()
	_show_phase_1()


## SPA-627: Re-display the briefing card mid-game (read-only, no "begin" prompt).
## Shows all info in a single card. Dismiss with SPACE, ENTER, or ESC.
func setup_recall(objective_card: Dictionary, scenario_title: String, intro_text: String = "") -> void:
	_recall_mode = true
	_objective_card = objective_card
	_scenario_title = scenario_title
	_intro_text = intro_text
	_build_shell()
	_show_recall_card()


# ── Shell (backdrop + card container) ────────────────────────────────────────

func _build_shell() -> void:
	# Full-screen dark backdrop.
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Centered briefing card (580 px wide per spec, auto-height).
	_card = Panel.new()
	_card.anchor_left   = 0.5
	_card.anchor_right  = 0.5
	_card.anchor_top    = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left   = -290.0
	_card.offset_right  =  290.0
	_card.offset_top    = -240.0
	_card.offset_bottom =  240.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = C_CARD_BG
	card_style.border_color = C_CARD_BORDER
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", card_style)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	# Inner VBox for card content.
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left   = 20
	_vbox.offset_right  = -20
	_vbox.offset_top    = 16
	_vbox.offset_bottom = -16
	_vbox.add_theme_constant_override("separation", 8)
	_card.add_child(_vbox)


# ── Phase 1: "The Mission" ──────────────────────────────────────────────────

func _show_phase_1() -> void:
	_current_phase = 1
	_clear_card_content()

	# Phase label.
	_add_phase_label("THE  MISSION")

	# Scenario title.
	_add_title(_scenario_title)

	# Divider.
	_add_divider()

	# Narrative hook from introText (2-3 sentences).
	if _intro_text != "":
		var hook := _extract_hook(_intro_text)
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content    = true
		rtl.scroll_active  = false
		rtl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "[center][i]" + hook + "[/i][/center]"
		rtl.add_theme_color_override("default_color", C_BODY)
		rtl.add_theme_font_size_override("normal_font_size", 14)
		rtl.add_theme_font_size_override("italics_font_size", 14)
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(rtl)

	# Mission statement (objective one-liner) — 18pt.
	var mission := _objective_card.get("mission", "")
	if mission != "":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		_vbox.add_child(spacer)
		var lbl := Label.new()
		lbl.text = mission
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", C_MISSION)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.02, 0.6))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(lbl)

	# Win condition.
	var win := _objective_card.get("winCondition", "")
	if win != "":
		var spacer2 := Control.new()
		spacer2.custom_minimum_size = Vector2(0, 2)
		_vbox.add_child(spacer2)
		_add_labeled_line(_vbox, "WIN:", win, C_HINT)

	# Bottom spacer.
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(bottom_spacer)

	# Prompt.
	_add_prompt("—  Press  SPACE  to  see  your  plan  —")
	_start_pulse()


# ── Phase 2: "Your Plan" ────────────────────────────────────────────────────

func _show_phase_2() -> void:
	_current_phase = 2
	_clear_card_content()

	# Phase label.
	_add_phase_label("YOUR  PLAN")

	# Scenario title (smaller on phase 2).
	_add_title(_scenario_title)

	# Divider.
	_add_divider()

	# First action — 14pt blue, top priority.
	var first_action := _objective_card.get("firstAction", "")
	if first_action != "":
		_add_labeled_line(_vbox, "FIRST MOVE:", first_action, C_ACTION)

	# Strategy hint.
	var strat := _objective_card.get("strategyHint", "")
	if strat != "":
		_add_labeled_line(_vbox, "STRATEGY:", strat, C_BODY)

	# Danger warning — red.
	var danger := _objective_card.get("danger", "")
	if danger != "":
		_add_labeled_line(_vbox, "DANGER:", danger, C_DANGER)

	# Time limit with visual day bar.
	var time_limit := _objective_card.get("timeLimit", "")
	if time_limit != "":
		_add_labeled_line(_vbox, "TIME:", time_limit, C_BODY)
		_add_day_bar()

	# Bottom spacer.
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(bottom_spacer)

	# Prompt.
	_add_prompt("—  Press  SPACE  or  ENTER  to  begin  —")
	_start_pulse()


# ── Recall card (single combined view) ───────────────────────────────────────

func _show_recall_card() -> void:
	_current_phase = 0
	_clear_card_content()

	_add_title(_scenario_title)
	_add_divider()

	# Mission statement.
	var mission := _objective_card.get("mission", "")
	if mission != "":
		var lbl := Label.new()
		lbl.text = mission
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", C_MISSION)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.02, 0.6))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(lbl)

	var win := _objective_card.get("winCondition", "")
	if win != "":
		_add_labeled_line(_vbox, "WIN:", win, C_HINT)

	var time_limit := _objective_card.get("timeLimit", "")
	if time_limit != "":
		_add_labeled_line(_vbox, "TIME:", time_limit, C_BODY)

	var danger := _objective_card.get("danger", "")
	if danger != "":
		_add_labeled_line(_vbox, "DANGER:", danger, C_DANGER)

	var strat := _objective_card.get("strategyHint", "")
	if strat != "":
		_add_labeled_line(_vbox, "STRATEGY:", strat, C_BODY)

	var first_action := _objective_card.get("firstAction", "")
	if first_action != "":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		_vbox.add_child(spacer)
		_add_labeled_line(_vbox, "FIRST MOVE:", first_action, C_ACTION)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(bottom_spacer)

	_add_prompt("—  Press  SPACE  or  ESC  to  close  —")
	_start_pulse()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _clear_card_content() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	for child in _vbox.get_children():
		child.queue_free()


func _add_phase_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_PHASE_HEADER)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(lbl)


func _add_title(title_text: String) -> void:
	var title := Label.new()
	title.text = title_text.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", C_TITLE)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(title)


func _add_divider() -> void:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 6)
	div.add_theme_stylebox_override("separator", _make_line_style(C_CARD_BORDER))
	_vbox.add_child(div)


func _add_prompt(text: String) -> void:
	_prompt_label = Label.new()
	_prompt_label.text = text
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_color", C_PROMPT)
	_prompt_label.add_theme_constant_override("outline_size", 2)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_prompt_label)


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
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_font_size_override("bold_font_size", 14)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rtl)


func _add_day_bar() -> void:
	## Visual day bar — shows total days as a horizontal progress-style indicator.
	var days := _parse_days_from_time_limit(_objective_card.get("timeLimit", ""))
	if days <= 0:
		return
	var bar_container := HBoxContainer.new()
	bar_container.add_theme_constant_override("separation", 1)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Each segment is a small colored rectangle representing one day.
	var seg_width: float = maxf(2.0, minf(16.0, 480.0 / float(days)))
	for i in range(days):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(seg_width, 8)
		# Gradient: green -> yellow -> red over the day span.
		var t: float = float(i) / float(maxi(days - 1, 1))
		if t < 0.5:
			seg.color = C_HINT.lerp(Color(0.95, 0.85, 0.30, 0.8), t * 2.0)
		else:
			seg.color = Color(0.95, 0.85, 0.30, 0.8).lerp(C_DANGER.lerp(Color(1, 1, 1, 1), 0.15), (t - 0.5) * 2.0)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_container.add_child(seg)
	# Center the bar.
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(bar_container)
	_vbox.add_child(center)


func _parse_days_from_time_limit(text: String) -> int:
	## Extract the number of days from a string like "You have 30 days."
	var regex := RegEx.new()
	regex.compile("(\\d+)\\s*day")
	var result := regex.search(text)
	if result != null:
		return int(result.get_string(1))
	return 0


func _extract_hook(full_intro: String) -> String:
	## Pull the first 2-3 sentences from introText as a narrative hook.
	var sentences: PackedStringArray = full_intro.split(".")
	var hook := ""
	var count := 0
	for s in sentences:
		var trimmed := s.strip_edges()
		if trimmed == "":
			continue
		hook += trimmed + ". "
		count += 1
		if count >= 3:
			break
	return hook.strip_edges()


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
		if _recall_mode:
			# Recall mode: SPACE, ENTER, or ESC all dismiss.
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_dismiss()
		elif _current_phase == 1:
			# Phase 1: SPACE advances to phase 2.
			if event.keycode == KEY_SPACE:
				get_viewport().set_input_as_handled()
				_show_phase_2()
		elif _current_phase == 2:
			# Phase 2: SPACE or ENTER begins the game.
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
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

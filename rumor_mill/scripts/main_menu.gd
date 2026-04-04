extends CanvasLayer

## main_menu.gd — Sprint 8 pre-game UI.
##
## Three-phase overlay (layer 50, above all HUDs):
##   Phase MAIN     — game title, tagline, Play / Quit.
##   Phase SELECT   — scrollable scenario cards (title + premise + days).
##   Phase BRIEFING — full startingText for the chosen scenario + Begin / Back.
##
## Emits begin_game(scenario_id) when the player commits to a scenario.
## Wire via setup() from main.gd.

# ── Signals ───────────────────────────────────────────────────────────────────
signal begin_game(scenario_id: String)

# ── Palette (matches end_screen.gd) ──────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.95)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)   # parchment
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_CARD_HOVER   := Color(0.18, 0.13, 0.09, 1.0)
const C_CARD_BORDER  := Color(0.45, 0.30, 0.12, 1.0)
const C_CARD_SEL     := Color(0.70, 0.50, 0.15, 1.0)
const C_STAT_LABEL   := Color(0.75, 0.65, 0.50, 1.0)
const C_STAT_VALUE   := Color(0.91, 0.85, 0.70, 1.0)
const C_SCORE_WIN    := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_SCORE_FAIL   := Color(0.85, 0.18, 0.12, 1.0)   # crimson

enum Phase { MAIN, SELECT, BRIEFING, INTRO, SETTINGS, CREDITS, STATS }

# ── State ─────────────────────────────────────────────────────────────────────
var _phase:              Phase     = Phase.MAIN
var _scenarios:          Array     = []   # parsed from scenarios.json
var _selected_scenario:  Dictionary = {}  # currently highlighted scenario data

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:           ColorRect  = null
var _panel_main:         Control    = null
var _panel_select:       Control    = null
var _panel_briefing:     Control    = null

# Select-phase refs
var _scenario_cards:     Array      = []  # Array[PanelContainer]
var _selected_card_idx:  int        = -1

# HowToPlay overlay ref
var _how_to_play:        CanvasLayer = null

# Settings-phase refs
var _panel_settings:     Control    = null

# Credits-phase refs
var _panel_credits:      Control    = null
var _version_label:      Label      = null

# Stats-phase refs
var _panel_stats:        Control    = null
var _lbl_music_val:      Label      = null
var _lbl_ambient_val:    Label      = null
var _lbl_sfx_val:        Label      = null
var _lbl_speed_val:      Label      = null
var _btn_resolution:     Button     = null
var _btn_window_mode:    Button     = null

# Briefing-phase refs
var _briefing_title:     Label      = null
var _briefing_days:      Label      = null
var _briefing_body:      RichTextLabel = null
var _btn_begin:          Button     = null
var _difficulty_buttons: Dictionary = {}   # preset_id → Button

# Intro-phase refs
var _panel_intro:        Control    = null
var _intro_title:        Label      = null
var _intro_body:         RichTextLabel = null


func _ready() -> void:
	layer = 50
	_load_scenarios()
	_build_backdrop()
	_build_main_panel()
	_build_select_panel()
	_build_briefing_panel()
	_build_intro_panel()
	_build_settings_panel()
	_build_credits_panel()
	_build_stats_panel()
	_build_version_label()
	_how_to_play = preload("res://scripts/how_to_play.gd").new()
	_how_to_play.name = "HowToPlay"
	add_child(_how_to_play)
	_show_phase(Phase.MAIN)


## Load scenario metadata from scenarios.json.
func _load_scenarios() -> void:
	var file := FileAccess.open("res://data/scenarios.json", FileAccess.READ)
	if file == null:
		push_error("MainMenu: cannot open scenarios.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		_scenarios = parsed
	else:
		push_error("MainMenu: failed to parse scenarios.json")


## Returns true if the scenario at index idx is locked.
## Lock rule: each scenario requires the previous one to be completed.
## scenario_1 (idx 0) is always unlocked.
func _is_scenario_locked(idx: int) -> bool:
	if idx <= 0:
		return false
	var prev_sc: Dictionary = _scenarios[idx - 1]
	var prev_id: String = prev_sc.get("scenarioId", "")
	return not ProgressData.is_completed(prev_id)


## Returns the title of the scenario that must be completed to unlock idx.
func _unlock_requires_title(idx: int) -> String:
	if idx <= 0:
		return ""
	return _scenarios[idx - 1].get("title", "the previous scenario")


# ── Phase switching ───────────────────────────────────────────────────────────

func _show_phase(p: Phase) -> void:
	_phase = p
	_panel_main.visible     = (p == Phase.MAIN)
	_panel_select.visible   = (p == Phase.SELECT)
	_panel_briefing.visible = (p == Phase.BRIEFING)
	_panel_intro.visible    = (p == Phase.INTRO)
	_panel_settings.visible = (p == Phase.SETTINGS)
	_panel_credits.visible  = (p == Phase.CREDITS)
	_panel_stats.visible    = (p == Phase.STATS)
	# Rebuild stats panel content each time it's shown so it reflects latest data.
	if p == Phase.STATS:
		_rebuild_stats_content()
	# Set initial keyboard focus for the active phase.
	call_deferred("_set_phase_focus", p)


## Assigns keyboard focus to the first interactive element in the active phase.
func _set_phase_focus(p: Phase) -> void:
	match p:
		Phase.MAIN:
			_grab_first_button(_panel_main)
		Phase.SELECT:
			_grab_first_button(_panel_select)
		Phase.BRIEFING:
			if _btn_begin != null:
				_btn_begin.grab_focus()
		Phase.INTRO:
			_grab_first_button(_panel_intro)
		Phase.SETTINGS:
			_grab_first_button(_panel_settings)
		Phase.CREDITS:
			_grab_first_button(_panel_credits)
		Phase.STATS:
			_grab_first_button(_panel_stats)


## Finds and focuses the first Button descendant of the given node.
func _grab_first_button(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.grab_focus()
			return
		_grab_first_button(child)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			match _phase:
				Phase.SELECT:
					_on_select_back()
					get_viewport().set_input_as_handled()
				Phase.BRIEFING:
					_on_briefing_back()
					get_viewport().set_input_as_handled()
				Phase.INTRO:
					_on_intro_back()
					get_viewport().set_input_as_handled()
				Phase.SETTINGS:
					_on_settings_back()
					get_viewport().set_input_as_handled()
				Phase.CREDITS:
					_on_credits_back()
					get_viewport().set_input_as_handled()
				Phase.STATS:
					_on_stats_back()
					get_viewport().set_input_as_handled()


# ── Backdrop ──────────────────────────────────────────────────────────────────

func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)


# ── Phase 1: Main Menu panel ──────────────────────────────────────────────────

func _build_main_panel() -> void:
	_panel_main = _make_panel(480, 320)
	add_child(_panel_main)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_main.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "RUMOR MILL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	# Tagline
	var tagline := Label.new()
	tagline.text = "A medieval rumor-spreading social simulation"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 13)
	tagline.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(tagline)

	vbox.add_child(_separator())

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Buttons
	var btn_row := VBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var btn_play := _make_button("Play", 200)
	btn_play.pressed.connect(_on_play_pressed)
	btn_row.add_child(btn_play)

	var btn_howto := _make_button("How to Play", 200)
	btn_howto.pressed.connect(_on_how_to_play_pressed)
	btn_row.add_child(btn_howto)

	var btn_settings := _make_button("Settings", 200)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_row.add_child(btn_settings)

	var btn_credits := _make_button("Credits", 200)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_row.add_child(btn_credits)

	var btn_stats := _make_button("Statistics", 200)
	btn_stats.pressed.connect(_on_stats_pressed)
	btn_row.add_child(btn_stats)

	if not OS.has_feature("web"):
		var btn_quit := _make_button("Quit", 200)
		btn_quit.pressed.connect(get_tree().quit)
		btn_row.add_child(btn_quit)


# ── Phase 2: Scenario Select panel ───────────────────────────────────────────

func _build_select_panel() -> void:
	_panel_select = _make_panel(680, 460)
	add_child(_panel_select)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_select.add_child(vbox)

	# Heading
	var heading := Label.new()
	heading.text = "Choose a Scenario"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	# Scenario cards
	_scenario_cards.clear()
	for i in _scenarios.size():
		var sc: Dictionary = _scenarios[i]
		var card := _build_scenario_card(sc, i)
		vbox.add_child(card)
		_scenario_cards.append(card)

	vbox.add_child(_separator())

	# Bottom row: Back + Next
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(_on_select_back)
	btn_row.add_child(btn_back)

	var btn_next := _make_button("Next", 140)
	btn_next.pressed.connect(_on_select_next)
	btn_row.add_child(btn_next)


func _build_scenario_card(sc: Dictionary, idx: int) -> PanelContainer:
	var locked: bool = _is_scenario_locked(idx)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)

	var style_normal := _card_style(C_CARD_BG, C_CARD_BORDER)
	var style_hover  := _card_style(C_CARD_HOVER, C_CARD_BORDER)
	card.add_theme_stylebox_override("panel", style_normal)
	card.set_meta("style_normal", style_normal)
	card.set_meta("style_hover",  style_hover)
	card.set_meta("scenario_idx", idx)
	card.set_meta("locked", locked)

	# Make it mouse-interactive via a Button overlay
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover",  StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var _card_focus_ring := StyleBoxFlat.new()
	_card_focus_ring.bg_color     = Color(0, 0, 0, 0)                # transparent — card panel shows through
	_card_focus_ring.draw_center  = false
	_card_focus_ring.set_border_width_all(2)
	_card_focus_ring.border_color = Color(1.00, 0.90, 0.40, 1.0)     # gold — matches SPA-169 focus ring
	btn.add_theme_stylebox_override("focus", _card_focus_ring)
	btn.pressed.connect(_on_card_pressed.bind(idx))
	btn.mouse_entered.connect(_on_card_hover.bind(card, true))
	btn.mouse_exited.connect(_on_card_hover.bind(card, false))

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)

	var title_row := HBoxContainer.new()

	var number_lbl := Label.new()
	number_lbl.text = "  %d. " % (idx + 1)
	number_lbl.add_theme_font_size_override("font_size", 15)
	number_lbl.add_theme_color_override("font_color", C_MUTED)
	title_row.add_child(number_lbl)

	var title_lbl := Label.new()
	title_lbl.text = sc.get("title", "Unknown Scenario")
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", C_MUTED if locked else C_HEADING)
	title_row.add_child(title_lbl)

	# Days label — replaced with lock message when locked.
	var days_lbl := Label.new()
	if locked:
		days_lbl.text = "  \U0001F512 Complete \"%s\" to unlock" % _unlock_requires_title(idx)
	else:
		days_lbl.text = "  (%d days)" % int(sc.get("daysAllowed", 30))
	days_lbl.add_theme_font_size_override("font_size", 12)
	days_lbl.add_theme_color_override("font_color", C_MUTED)
	title_row.add_child(days_lbl)

	inner.add_child(title_row)

	# First sentence of startingText as a brief teaser.
	var full_text: String = sc.get("startingText", "")
	var teaser := full_text.split("\n")[0] if "\n" in full_text else full_text
	if teaser.length() > 120:
		teaser = teaser.substr(0, 117) + "..."

	var desc_lbl := Label.new()
	desc_lbl.text = teaser
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", C_MUTED if locked else C_BODY)
	inner.add_child(desc_lbl)

	# Locked message row — hidden until the card is pressed while locked.
	if locked:
		var lock_row := HBoxContainer.new()
		lock_row.visible = false
		lock_row.name = "LockMessageRow"
		lock_row.add_theme_constant_override("separation", 8)

		var lock_msg := Label.new()
		lock_msg.text = "Finish \"%s\" first." % _unlock_requires_title(idx)
		lock_msg.add_theme_font_size_override("font_size", 11)
		lock_msg.add_theme_color_override("font_color", C_MUTED)
		lock_row.add_child(lock_msg)

		var play_anyway := Button.new()
		play_anyway.text = "Play anyway \u2192"
		play_anyway.flat = true
		play_anyway.add_theme_font_size_override("font_size", 11)
		play_anyway.add_theme_color_override("font_color", C_MUTED)
		play_anyway.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		play_anyway.add_theme_stylebox_override("hover",  StyleBoxEmpty.new())
		play_anyway.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		play_anyway.pressed.connect(_on_play_anyway_pressed.bind(idx))
		lock_row.add_child(play_anyway)

		inner.add_child(lock_row)

	card.add_child(inner)
	card.add_child(btn)  # overlay last so it captures mouse events
	return card


func _on_card_hover(card: PanelContainer, entering: bool) -> void:
	var idx: int = card.get_meta("scenario_idx", -1)
	if idx == _selected_card_idx:
		return  # keep selected style
	if entering:
		AudioManager.play_sfx_pitched("ui_click", 2.0)
	var style = card.get_meta("style_hover") if entering else card.get_meta("style_normal")
	card.add_theme_stylebox_override("panel", style)


func _on_card_pressed(idx: int) -> void:
	var card: PanelContainer = _scenario_cards[idx]
	var locked: bool = card.get_meta("locked", false)

	if locked:
		# Show the lock message row; hide others.
		for i in _scenario_cards.size():
			var c: PanelContainer = _scenario_cards[i]
			var row = c.find_child("LockMessageRow", true, false)
			if row != null:
				row.visible = (i == idx)
		return

	# Deselect previous
	if _selected_card_idx >= 0 and _selected_card_idx < _scenario_cards.size():
		var prev: PanelContainer = _scenario_cards[_selected_card_idx]
		prev.add_theme_stylebox_override("panel", prev.get_meta("style_normal"))

	_selected_card_idx = idx
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_HOVER, C_CARD_SEL))
	_selected_scenario = _scenarios[idx]
	AudioManager.play_sfx("ui_click")


## Called when the player clicks "Play anyway →" on a locked scenario card.
func _on_play_anyway_pressed(idx: int) -> void:
	# Bypass the lock and treat the card as selected.
	if _selected_card_idx >= 0 and _selected_card_idx < _scenario_cards.size():
		var prev: PanelContainer = _scenario_cards[_selected_card_idx]
		prev.add_theme_stylebox_override("panel", prev.get_meta("style_normal"))

	_selected_card_idx = idx
	var card: PanelContainer = _scenario_cards[idx]
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_HOVER, C_CARD_SEL))
	_selected_scenario = _scenarios[idx]
	_populate_briefing()
	_show_phase(Phase.BRIEFING)


# ── Phase 3: Briefing panel ───────────────────────────────────────────────────

func _build_briefing_panel() -> void:
	_panel_briefing = _make_panel(600, 400)
	add_child(_panel_briefing)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_briefing.add_child(vbox)

	# Title row
	_briefing_title = Label.new()
	_briefing_title.text = ""
	_briefing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_briefing_title.add_theme_font_size_override("font_size", 20)
	_briefing_title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_briefing_title)

	_briefing_days = Label.new()
	_briefing_days.text = ""
	_briefing_days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_briefing_days.add_theme_font_size_override("font_size", 12)
	_briefing_days.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_briefing_days)

	vbox.add_child(_separator())

	# Briefing body
	_briefing_body = RichTextLabel.new()
	_briefing_body.custom_minimum_size = Vector2(0, 220)
	_briefing_body.fit_content = false
	_briefing_body.scroll_active = true
	_briefing_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_body.add_theme_font_size_override("normal_font_size", 13)
	_briefing_body.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_briefing_body)

	vbox.add_child(_separator())

	# Difficulty selector row
	var diff_label := Label.new()
	diff_label.text = "Difficulty"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 12)
	diff_label.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(diff_label)

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)

	for preset in ["apprentice", "master", "spymaster"]:
		var lbl: String = preset.capitalize()
		var btn := _make_button(lbl, 120)
		btn.pressed.connect(_on_difficulty_pressed.bind(preset))
		diff_row.add_child(btn)
		_difficulty_buttons[preset] = btn

	_refresh_difficulty_buttons()

	vbox.add_child(_separator())

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(_on_briefing_back)
	btn_row.add_child(btn_back)

	_btn_begin = _make_button("Next", 140)
	_btn_begin.pressed.connect(_on_briefing_next_pressed)
	btn_row.add_child(_btn_begin)


func _populate_briefing() -> void:
	_briefing_title.text = _selected_scenario.get("title", "")
	_update_briefing_days()
	_briefing_body.text = _selected_scenario.get("startingText", "")


func _update_briefing_days() -> void:
	if _selected_scenario.is_empty() or _briefing_days == null:
		return
	var base_days: int = int(_selected_scenario.get("daysAllowed", 30))
	var mods: Dictionary = GameState.get_difficulty_modifiers(GameState.selected_difficulty)
	var total_days: int = base_days + int(mods.get("days_bonus", 0))
	_briefing_days.text = "You have %d days." % total_days


func _on_difficulty_pressed(preset: String) -> void:
	GameState.selected_difficulty = preset
	_refresh_difficulty_buttons()
	_update_briefing_days()


func _refresh_difficulty_buttons() -> void:
	var selected: String = GameState.selected_difficulty
	for preset in _difficulty_buttons:
		var btn: Button = _difficulty_buttons[preset]
		if preset == selected:
			btn.add_theme_color_override("font_color", C_TITLE)
			btn.add_theme_stylebox_override("normal", _make_selected_stylebox())
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")


func _make_selected_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.35, 0.05, 1.0)
	sb.border_color = C_TITLE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb


# ── Button / event handlers ───────────────────────────────────────────────────

func _on_play_pressed() -> void:
	_selected_card_idx = -1
	_selected_scenario = {}
	_show_phase(Phase.SELECT)


func _on_how_to_play_pressed() -> void:
	_how_to_play.open()


func _on_select_back() -> void:
	_show_phase(Phase.MAIN)


func _on_select_next() -> void:
	if _selected_scenario.is_empty():
		# Auto-select first if none chosen
		if not _scenarios.is_empty():
			_on_card_pressed(0)
		else:
			return
	_populate_briefing()
	_show_phase(Phase.BRIEFING)


func _on_briefing_back() -> void:
	_show_phase(Phase.SELECT)


## Advance from BRIEFING to the atmospheric INTRO card.
func _on_briefing_next_pressed() -> void:
	_populate_intro()
	_show_phase(Phase.INTRO)


# ── Phase 4: Scenario Intro panel ─────────────────────────────────────────────

func _build_intro_panel() -> void:
	_panel_intro = _make_panel(700, 460)
	add_child(_panel_intro)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_intro.add_child(vbox)

	_intro_title = Label.new()
	_intro_title.text = ""
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.add_theme_font_size_override("font_size", 22)
	_intro_title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_intro_title)

	vbox.add_child(_separator())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	_intro_body = RichTextLabel.new()
	_intro_body.custom_minimum_size = Vector2(0, 240)
	_intro_body.fit_content = false
	_intro_body.scroll_active = false
	_intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_body.bbcode_enabled = true
	_intro_body.add_theme_font_size_override("normal_font_size", 17)
	_intro_body.add_theme_color_override("default_color", C_HEADING)
	vbox.add_child(_intro_body)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	vbox.add_child(_separator())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(_on_intro_back)
	btn_row.add_child(btn_back)

	var btn_begin := _make_button("Begin", 140)
	btn_begin.pressed.connect(_on_intro_begin_pressed)
	btn_row.add_child(btn_begin)


func _populate_intro() -> void:
	_intro_title.text = _selected_scenario.get("title", "")
	var intro_text: String = _selected_scenario.get("introText", "")
	_intro_body.text = "[center][i]" + intro_text + "[/i][/center]"


func _on_intro_back() -> void:
	_show_phase(Phase.BRIEFING)


func _on_intro_begin_pressed() -> void:
	var scenario_id: String = _selected_scenario.get("scenarioId", "scenario_1")
	begin_game.emit(scenario_id)


# ── Phase 5: Settings panel ───────────────────────────────────────────────────

func _build_settings_panel() -> void:
	_panel_settings = _make_panel(480, 540)
	add_child(_panel_settings)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_settings.add_child(vbox)

	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	# Display section
	var display_lbl := Label.new()
	display_lbl.text = "Display"
	display_lbl.add_theme_font_size_override("font_size", 14)
	display_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(display_lbl)

	# Resolution cycle button
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	vbox.add_child(res_row)

	var res_name := Label.new()
	res_name.text = "Resolution:"
	res_name.custom_minimum_size = Vector2(80, 0)
	res_name.add_theme_font_size_override("font_size", 13)
	res_name.add_theme_color_override("font_color", C_BODY)
	res_row.add_child(res_name)

	_btn_resolution = Button.new()
	_btn_resolution.text = SettingsManager.get_resolution_label()
	_btn_resolution.custom_minimum_size = Vector2(120, 30)
	_btn_resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_resolution.add_theme_font_size_override("font_size", 13)
	_btn_resolution.add_theme_color_override("font_color", C_BTN_TEXT)
	var res_normal := StyleBoxFlat.new()
	res_normal.bg_color = C_BTN_NORMAL
	res_normal.set_border_width_all(1)
	res_normal.border_color = C_PANEL_BORDER
	res_normal.set_content_margin_all(4)
	var res_hover := StyleBoxFlat.new()
	res_hover.bg_color = C_BTN_HOVER
	res_hover.set_border_width_all(1)
	res_hover.border_color = C_PANEL_BORDER
	res_hover.set_content_margin_all(4)
	_btn_resolution.add_theme_stylebox_override("normal", res_normal)
	_btn_resolution.add_theme_stylebox_override("hover", res_hover)
	_btn_resolution.pressed.connect(_on_resolution_cycle)
	res_row.add_child(_btn_resolution)

	# Window mode cycle button (Windowed / Borderless / Fullscreen)
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 8)
	vbox.add_child(fs_row)

	var fs_name := Label.new()
	fs_name.text = "Window:"
	fs_name.custom_minimum_size = Vector2(80, 0)
	fs_name.add_theme_font_size_override("font_size", 13)
	fs_name.add_theme_color_override("font_color", C_BODY)
	fs_row.add_child(fs_name)

	_btn_window_mode = Button.new()
	_btn_window_mode.text = SettingsManager.get_window_mode_label()
	_btn_window_mode.custom_minimum_size = Vector2(120, 30)
	_btn_window_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_window_mode.add_theme_font_size_override("font_size", 13)
	_btn_window_mode.add_theme_color_override("font_color", C_BTN_TEXT)
	var wm_normal := StyleBoxFlat.new()
	wm_normal.bg_color = C_BTN_NORMAL
	wm_normal.set_border_width_all(1)
	wm_normal.border_color = C_PANEL_BORDER
	wm_normal.set_content_margin_all(4)
	var wm_hover := StyleBoxFlat.new()
	wm_hover.bg_color = C_BTN_HOVER
	wm_hover.set_border_width_all(1)
	wm_hover.border_color = C_PANEL_BORDER
	wm_hover.set_content_margin_all(4)
	_btn_window_mode.add_theme_stylebox_override("normal", wm_normal)
	_btn_window_mode.add_theme_stylebox_override("hover", wm_hover)
	_btn_window_mode.pressed.connect(_on_window_mode_cycle)
	fs_row.add_child(_btn_window_mode)

	vbox.add_child(_separator())

	# Audio section
	var audio_lbl := Label.new()
	audio_lbl.text = "Audio"
	audio_lbl.add_theme_font_size_override("font_size", 14)
	audio_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(audio_lbl)

	_lbl_music_val = _add_slider_row(vbox, "Music",
		SettingsManager.music_volume, 0.0, 100.0, 1.0,
		_on_music_volume_changed)

	_lbl_ambient_val = _add_slider_row(vbox, "Ambient",
		SettingsManager.ambient_volume, 0.0, 100.0, 1.0,
		_on_ambient_volume_changed)

	_lbl_sfx_val = _add_slider_row(vbox, "SFX",
		SettingsManager.sfx_volume, 0.0, 100.0, 1.0,
		_on_sfx_volume_changed)

	vbox.add_child(_separator())

	# Gameplay section
	var gameplay_lbl := Label.new()
	gameplay_lbl.text = "Gameplay"
	gameplay_lbl.add_theme_font_size_override("font_size", 14)
	gameplay_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(gameplay_lbl)

	_lbl_speed_val = _add_slider_row(vbox, "Game Speed",
		SettingsManager.game_speed, 0.25, 4.0, 0.25,
		_on_game_speed_changed,
		"(lower = faster)")

	vbox.add_child(_separator())

	var btn_back := _make_button("Back", 160)
	btn_back.pressed.connect(_on_settings_back)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn_back)
	vbox.add_child(btn_row)


## Builds a labelled HSlider row. Returns the value Label for live updates.
func _add_slider_row(
		parent: VBoxContainer,
		label_text: String,
		initial_value: float,
		min_val: float, max_val: float, step: float,
		change_callback: Callable,
		hint: String = "") -> Label:

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = label_text + ":"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", C_BODY)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step      = step
	slider.value     = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(change_callback)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", C_MUTED)
	val_lbl.text = _format_slider_val(label_text, initial_value)
	row.add_child(val_lbl)

	if hint != "":
		var hint_lbl := Label.new()
		hint_lbl.text = hint
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", C_MUTED)
		parent.add_child(hint_lbl)

	return val_lbl


func _format_slider_val(label_text: String, value: float) -> String:
	if label_text == "Game Speed":
		return "%.2fs" % value
	return "%d%%" % int(value)


func _on_settings_pressed() -> void:
	_show_phase(Phase.SETTINGS)


func _on_settings_back() -> void:
	_show_phase(Phase.MAIN)


func _on_credits_pressed() -> void:
	_show_phase(Phase.CREDITS)


func _on_credits_back() -> void:
	_show_phase(Phase.MAIN)


func _on_music_volume_changed(value: float) -> void:
	SettingsManager.music_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_music_val.text = _format_slider_val("Music", value)


func _on_ambient_volume_changed(value: float) -> void:
	SettingsManager.ambient_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_ambient_val.text = _format_slider_val("Ambient", value)


func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_sfx_val.text = _format_slider_val("SFX", value)


func _on_game_speed_changed(value: float) -> void:
	SettingsManager.game_speed = value
	SettingsManager.save_settings()
	_lbl_speed_val.text = _format_slider_val("Game Speed", value)


func _on_resolution_cycle() -> void:
	SettingsManager.resolution_index = (SettingsManager.resolution_index + 1) % SettingsManager.RESOLUTIONS.size()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_resolution.text = SettingsManager.get_resolution_label()


func _on_window_mode_cycle() -> void:
	SettingsManager.window_mode = (SettingsManager.window_mode + 1) % 3
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_window_mode.text = SettingsManager.get_window_mode_label()


# ── Phase 6: Credits panel ────────────────────────────────────────────────────

func _build_credits_panel() -> void:
	_panel_credits = _make_panel(480, 480)
	add_child(_panel_credits)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_credits.add_child(vbox)

	var heading := Label.new()
	heading.text = "Credits"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var credits_body := RichTextLabel.new()
	credits_body.fit_content = true
	credits_body.scroll_active = false
	credits_body.bbcode_enabled = true
	credits_body.add_theme_font_size_override("normal_font_size", 14)
	credits_body.add_theme_color_override("default_color", C_BODY)
	var t := "[center]"
	t += "[color=#ebe8b2][b]Development Team[/b][/color]\n"
	t += "Lead Engineer\n"
	t += "UI/UX Designer\n"
	t += "Game Designer\n"
	t += "Narrative Writer\n\n"
	t += "[color=#ebe8b2][b]Studio[/b][/color]\n"
	t += "Paperclip Studio\n\n"
	t += "[color=#ebe8b2][b]Technology[/b][/color]\n"
	t += "Godot Engine 4  —  godotengine.org\n"
	t += "[color=#c8a84b]Built with AI agents powered by Paperclip[/color]\n\n"
	t += "[color=#ebe8b2][b]Music & Sound[/b][/color]\n"
	t += "Original Compositions\n\n"
	t += "[color=#ebe8b2][b]Playtesting[/b][/color]\n"
	t += "Early Access Community\n\n"
	t += "[color=#8c7a5a]v0.1.0-demo  —  All rights reserved.[/color]"
	t += "[/center]"
	credits_body.text = t
	vbox.add_child(credits_body)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	vbox.add_child(_separator())

	var btn_back := _make_button("Back", 160)
	btn_back.pressed.connect(_on_credits_back)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn_back)
	vbox.add_child(btn_row)


# ── Phase 7: Statistics panel ─────────────────────────────────────────────────

func _build_stats_panel() -> void:
	_panel_stats = _make_panel(680, 520)
	add_child(_panel_stats)

	# Content is built dynamically in _rebuild_stats_content() to reflect live data.
	# Placeholder VBox so the panel isn't empty at startup.
	var vbox := VBoxContainer.new()
	vbox.name = "StatsVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_stats.add_child(vbox)


## Rebuild stats panel content from PlayerStats.  Called each time the phase is shown.
func _rebuild_stats_content() -> void:
	var vbox: VBoxContainer = _panel_stats.get_node_or_null("StatsVBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()

	# ── Heading ───────────────────────────────────────────────────────────────
	var heading := Label.new()
	heading.text = "Statistics"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	# ── Scrollable body ───────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	if not PlayerStats.has_any_data():
		var empty_lbl := Label.new()
		empty_lbl.text = "No games recorded yet.\nPlay a scenario to start tracking your stats."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		body.add_child(empty_lbl)
	else:
		# ── Global totals ─────────────────────────────────────────────────────
		var totals := PlayerStats.get_totals()
		var totals_hdr := Label.new()
		totals_hdr.text = "Lifetime Totals"
		totals_hdr.add_theme_font_size_override("font_size", 16)
		totals_hdr.add_theme_color_override("font_color", C_HEADING)
		body.add_child(totals_hdr)

		var play_sec: int = totals.get("total_play_time_sec", 0)
		var play_str: String
		if play_sec >= 3600:
			play_str = "%dh %dm" % [play_sec / 3600, (play_sec % 3600) / 60]
		else:
			play_str = "%dm %ds" % [play_sec / 60, play_sec % 60]

		var totals_grid := GridContainer.new()
		totals_grid.columns = 2
		totals_grid.add_theme_constant_override("h_separation", 24)
		totals_grid.add_theme_constant_override("v_separation", 4)
		body.add_child(totals_grid)
		_add_grid_stat(totals_grid, "Play Time",        play_str)
		_add_grid_stat(totals_grid, "Rumors Spread",    str(totals.get("total_rumors_spread",  0)))
		_add_grid_stat(totals_grid, "NPCs Convinced",   str(totals.get("total_npcs_convinced", 0)))
		_add_grid_stat(totals_grid, "Bribes Paid",      str(totals.get("total_bribes_paid",    0)))

		body.add_child(_separator())

		# ── Per-scenario table ────────────────────────────────────────────────
		var sc_hdr := Label.new()
		sc_hdr.text = "Scenario Records"
		sc_hdr.add_theme_font_size_override("font_size", 16)
		sc_hdr.add_theme_color_override("font_color", C_HEADING)
		body.add_child(sc_hdr)

		var scenario_names := {
			"scenario_1": "1 — A Whisper in Autumn",
			"scenario_2": "2 — The Herb-Wife's Ruin",
			"scenario_3": "3 — The Fenn Succession",
			"scenario_4": "4 — The Holy Inquisition",
		}
		var diff_labels := { "apprentice": "Appr.", "master": "Master", "spymaster": "Spym." }

		for sid in PlayerStats.SCENARIO_IDS:
			var has_sc_data := false
			for diff in PlayerStats.DIFFICULTIES:
				if PlayerStats.get_scenario_stats(sid, diff).get("games_played", 0) > 0:
					has_sc_data = true
					break
			if not has_sc_data:
				continue

			var sc_name := scenario_names.get(sid, sid)
			var sc_title := Label.new()
			sc_title.text = sc_name
			sc_title.add_theme_font_size_override("font_size", 13)
			sc_title.add_theme_color_override("font_color", C_SUBHEADING)
			body.add_child(sc_title)

			# Column headers
			var header_row := HBoxContainer.new()
			header_row.add_theme_constant_override("separation", 0)
			body.add_child(header_row)
			_add_table_cell(header_row, "Difficulty", 100, C_MUTED, true)
			_add_table_cell(header_row, "Played",      60, C_MUTED, true)
			_add_table_cell(header_row, "Wins",        50, C_MUTED, true)
			_add_table_cell(header_row, "Losses",      55, C_MUTED, true)
			_add_table_cell(header_row, "Best Score",  80, C_MUTED, true)
			_add_table_cell(header_row, "Fastest Win", 90, C_MUTED, true)

			for diff in PlayerStats.DIFFICULTIES:
				var rec := PlayerStats.get_scenario_stats(sid, diff)
				if rec.get("games_played", 0) == 0:
					continue
				var fastest: int = rec.get("fastest_win_days", -1)
				var fastest_str: String = ("%d days" % fastest) if fastest >= 0 else "—"
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 0)
				body.add_child(row)
				_add_table_cell(row, diff_labels.get(diff, diff), 100, C_BODY, false)
				_add_table_cell(row, str(rec.get("games_played", 0)),   60, C_STAT_VALUE, false)
				_add_table_cell(row, str(rec.get("wins",         0)),   50, C_SCORE_WIN,  false)
				_add_table_cell(row, str(rec.get("losses",       0)),   55, C_SCORE_FAIL, false)
				_add_table_cell(row, str(rec.get("best_score",   0)),   80, C_STAT_VALUE, false)
				_add_table_cell(row, fastest_str,                       90, C_STAT_VALUE, false)

	# ── Bottom buttons ────────────────────────────────────────────────────────
	vbox.add_child(_separator())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 160)
	btn_back.pressed.connect(_on_stats_back)
	btn_row.add_child(btn_back)

	if PlayerStats.has_any_data():
		var btn_reset := _make_button("Reset Stats", 160)
		btn_reset.pressed.connect(_on_stats_reset)
		btn_row.add_child(btn_reset)


## Add a label+value pair to a 2-column GridContainer.
func _add_grid_stat(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", C_STAT_LABEL)
	lbl.add_theme_font_size_override("font_size", 13)
	grid.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", C_STAT_VALUE)
	val.add_theme_font_size_override("font_size", 13)
	grid.add_child(val)


## Add a fixed-width cell to a row HBoxContainer for the scenario table.
func _add_table_cell(row: HBoxContainer, text: String, w: int, color: Color, bold: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(w, 0)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	if bold:
		lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)


func _on_stats_pressed() -> void:
	_show_phase(Phase.STATS)


func _on_stats_back() -> void:
	_show_phase(Phase.MAIN)


func _on_stats_reset() -> void:
	PlayerStats.reset_all()
	_rebuild_stats_content()


# ── Version corner label ──────────────────────────────────────────────────────

func _build_version_label() -> void:
	_version_label = Label.new()
	_version_label.text = "v0.1.0-demo"
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", C_MUTED)
	_version_label.set_anchor(SIDE_LEFT,   1.0)
	_version_label.set_anchor(SIDE_RIGHT,  1.0)
	_version_label.set_anchor(SIDE_TOP,    1.0)
	_version_label.set_anchor(SIDE_BOTTOM, 1.0)
	_version_label.set_offset(SIDE_LEFT,   -110)
	_version_label.set_offset(SIDE_RIGHT,  -8)
	_version_label.set_offset(SIDE_TOP,    -26)
	_version_label.set_offset(SIDE_BOTTOM, -6)
	add_child(_version_label)


# ── UI helpers ────────────────────────────────────────────────────────────────

## Creates a centred PanelContainer of the given size.
func _make_panel(w: int, h: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -w / 2.0)
	panel.set_offset(SIDE_RIGHT,   w / 2.0)
	panel.set_offset(SIDE_TOP,    -h / 2.0)
	panel.set_offset(SIDE_BOTTOM,  h / 2.0)

	var style := StyleBoxFlat.new()
	style.bg_color           = C_PANEL_BG
	style.border_color       = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_button(label_text: String, w: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(w, 42)

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

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.28, 0.14, 0.04, 1.0)
	pressed_style.set_border_width_all(1)
	pressed_style.border_color = C_PANEL_BORDER
	pressed_style.set_content_margin_all(8)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_BTN_HOVER
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold — matches SPA-169 focus ring
	focus_style.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus",   focus_style)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.mouse_entered.connect(func() -> void: AudioManager.play_sfx_pitched("ui_click", 2.0))
	return btn


func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BORDER
	style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", style)
	return sep


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(10)
	return s

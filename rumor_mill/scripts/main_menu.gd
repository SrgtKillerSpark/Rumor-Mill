extends CanvasLayer

## main_menu.gd — Sprint 8 pre-game UI (SPA-589 redesign).
##
## Coordinator for the pre-game menu.  Panel construction and phase-specific logic
## are delegated to:
##   MainMenuSettingsPanel  (main_menu_settings_panel.gd)
##   MainMenuStatsPanel     (main_menu_stats_panel.gd)
##   MainMenuScenarioSelect (main_menu_scenario_select.gd)
##   MainMenuBriefingPanel  (main_menu_briefing_panel.gd)
##
## Retains: phase navigation, backdrop/silhouettes, main panel, credits panel,
## scenario-lock logic, and UI-helper factories used by all modules.
##
## Emits begin_game(scenario_id) when the player commits to a scenario.

# ── Signals ───────────────────────────────────────────────────────────────────
signal begin_game(scenario_id: String)

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.95)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_CARD_HOVER   := Color(0.18, 0.13, 0.09, 1.0)
const C_CARD_SEL     := Color(0.70, 0.50, 0.15, 1.0)
const C_SKY_TOP      := Color(0.12, 0.06, 0.18, 1.0)
const C_SKY_MID      := Color(0.22, 0.10, 0.08, 1.0)
const C_SKY_BOTTOM   := Color(0.08, 0.05, 0.03, 1.0)

enum Phase { MAIN, SELECT, BRIEFING, INTRO, SETTINGS, CREDITS, STATS }

# ── State ─────────────────────────────────────────────────────────────────────
var _phase:     Phase    = Phase.MAIN
var _scenarios: Array    = []

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:    ColorRect  = null
var _panel_main:  Control    = null
var _dusk_sky:    ColorRect  = null
var _silhouettes:        Array = []
var _silhouette_anchors: Array = []
var _silhouette_phase:   float = 0.0
var _fog_overlay:  ColorRect  = null
var _lantern_glow: ColorRect  = null

var _panel_credits: Control = null
var _version_label: Label   = null

var _how_to_play:   CanvasLayer = null
var _btn_continue:  Button      = null

# ── Phase panel refs (owned by modules, cached here for _show_phase) ──────────
var _panel_select:   Control = null
var _panel_briefing: Control = null
var _panel_intro:    Control = null
var _panel_settings: Control = null
var _panel_stats:    Control = null

# ── Sub-modules ───────────────────────────────────────────────────────────────
var _settings_module: MainMenuSettingsPanel  = null
var _stats_module:    MainMenuStatsPanel     = null
var _select_module:   MainMenuScenarioSelect = null
var _briefing_module: MainMenuBriefingPanel  = null

# ── Phase tween ───────────────────────────────────────────────────────────────
var _phase_tween: Tween = null


func _ready() -> void:
	layer = 50
	_load_scenarios()
	_build_backdrop()
	_build_main_panel()

	# Instantiate and build sub-modules.
	_settings_module = MainMenuSettingsPanel.new()
	_settings_module.name = "SettingsModule"
	add_child(_settings_module)
	_panel_settings = _settings_module.build(
		func(t: String, w: int) -> Button: return _make_button(t, w),
		func() -> HSeparator: return _separator()
	)
	add_child(_panel_settings)
	_settings_module.back_requested.connect(func() -> void: _show_phase(Phase.MAIN))

	_stats_module = MainMenuStatsPanel.new()
	_stats_module.name = "StatsModule"
	add_child(_stats_module)
	_panel_stats = _stats_module.build(
		func(t: String, w: int) -> Button: return _make_button(t, w),
		func() -> HSeparator: return _separator()
	)
	add_child(_panel_stats)
	_stats_module.back_requested.connect(func() -> void: _show_phase(Phase.MAIN))

	_select_module = MainMenuScenarioSelect.new()
	_select_module.name = "SelectModule"
	add_child(_select_module)
	_panel_select = _select_module.build(
		_scenarios,
		func(t: String, w: int) -> Button: return _make_button(t, w),
		func() -> HSeparator: return _separator(),
		func(i: int) -> bool: return _is_scenario_locked(i),
		func(i: int) -> String: return _unlock_requires_title(i)
	)
	add_child(_panel_select)
	_select_module.back_requested.connect(func() -> void: _show_phase(Phase.MAIN))
	_select_module.next_requested.connect(_on_select_next)

	_briefing_module = MainMenuBriefingPanel.new()
	_briefing_module.name = "BriefingModule"
	add_child(_briefing_module)
	_briefing_module.build(
		func(t: String, w: int) -> Button: return _make_button(t, w),
		func() -> HSeparator: return _separator()
	)
	_panel_briefing = _briefing_module.briefing_panel
	_panel_intro    = _briefing_module.intro_panel
	add_child(_panel_briefing)
	add_child(_panel_intro)
	_briefing_module.back_requested_from_briefing.connect(func() -> void: _show_phase(Phase.SELECT))
	_briefing_module.next_requested_from_briefing.connect(func() -> void: _show_phase(Phase.INTRO))
	_briefing_module.back_requested_from_intro.connect(func() -> void: _show_phase(Phase.BRIEFING))
	_briefing_module.begin_game_requested.connect(func(sid: String) -> void: begin_game.emit(sid))

	_build_credits_panel()
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
func _is_scenario_locked(idx: int) -> bool:
	if idx <= 0 or idx >= _scenarios.size():
		return false
	var prev_sc: Dictionary = _scenarios[idx - 1]
	var prev_id: String = prev_sc.get("scenarioId", "")
	return not ProgressData.is_completed(prev_id)


## Returns the title of the scenario that must be completed to unlock idx.
func _unlock_requires_title(idx: int) -> String:
	if idx <= 0 or idx >= _scenarios.size():
		return ""
	return _scenarios[idx - 1].get("title", "the previous scenario")


# ── Phase switching ───────────────────────────────────────────────────────────

func _show_phase(p: Phase) -> void:
	var old_phase := _phase
	_phase = p

	var panels: Dictionary = {
		Phase.MAIN:     _panel_main,
		Phase.SELECT:   _panel_select,
		Phase.BRIEFING: _panel_briefing,
		Phase.INTRO:    _panel_intro,
		Phase.SETTINGS: _panel_settings,
		Phase.CREDITS:  _panel_credits,
		Phase.STATS:    _panel_stats,
	}

	var outgoing: Control = panels.get(old_phase)
	var incoming: Control = panels.get(p)

	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()

	for phase_key in panels:
		var panel: Control = panels[phase_key]
		if panel == null:
			continue
		if phase_key != old_phase and phase_key != p:
			panel.visible = false

	if outgoing != null and incoming != null and outgoing != incoming:
		incoming.visible = true
		incoming.modulate.a = 0.0
		_phase_tween = create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_phase_tween.tween_property(outgoing, "modulate:a", 0.0, 0.15)
		_phase_tween.tween_property(incoming, "modulate:a", 1.0, 0.2)
		_phase_tween.chain().tween_callback(func() -> void:
			outgoing.visible = false
			outgoing.modulate.a = 1.0
		)
	else:
		for phase_key in panels:
			var panel: Control = panels[phase_key]
			if panel == null:
				continue
			panel.visible = (phase_key == p)
			panel.modulate.a = 1.0

	if p == Phase.STATS:
		_stats_module.rebuild_content()
	call_deferred("_set_phase_focus", p)


func _set_phase_focus(p: Phase) -> void:
	match p:
		Phase.MAIN:
			_grab_first_button(_panel_main)
		Phase.SELECT:
			_grab_first_button(_panel_select)
		Phase.BRIEFING:
			_grab_first_button(_panel_briefing)
		Phase.INTRO:
			_grab_first_button(_panel_intro)
		Phase.SETTINGS:
			_grab_first_button(_panel_settings)
		Phase.CREDITS:
			_grab_first_button(_panel_credits)
		Phase.STATS:
			_grab_first_button(_panel_stats)


func _grab_first_button(node: Node) -> void:
	if node == null:
		return
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
					_show_phase(Phase.MAIN)
					get_viewport().set_input_as_handled()
				Phase.BRIEFING:
					_show_phase(Phase.SELECT)
					get_viewport().set_input_as_handled()
				Phase.INTRO:
					_show_phase(Phase.BRIEFING)
					get_viewport().set_input_as_handled()
				Phase.SETTINGS:
					_show_phase(Phase.MAIN)
					get_viewport().set_input_as_handled()
				Phase.CREDITS:
					_show_phase(Phase.MAIN)
					get_viewport().set_input_as_handled()
				Phase.STATS:
					_show_phase(Phase.MAIN)
					get_viewport().set_input_as_handled()


# ── Backdrop ──────────────────────────────────────────────────────────────────

func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = C_SKY_TOP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_dusk_sky = ColorRect.new()
	_dusk_sky.color = C_SKY_MID
	_dusk_sky.set_anchor(SIDE_LEFT,   0.0)
	_dusk_sky.set_anchor(SIDE_RIGHT,  1.0)
	_dusk_sky.set_anchor(SIDE_TOP,    0.55)
	_dusk_sky.set_anchor(SIDE_BOTTOM, 1.0)
	_dusk_sky.modulate.a = 0.6
	add_child(_dusk_sky)

	_fog_overlay = ColorRect.new()
	_fog_overlay.color = Color(0.15, 0.10, 0.06, 0.35)
	_fog_overlay.set_anchor(SIDE_LEFT,   0.0)
	_fog_overlay.set_anchor(SIDE_RIGHT,  1.0)
	_fog_overlay.set_anchor(SIDE_TOP,    0.78)
	_fog_overlay.set_anchor(SIDE_BOTTOM, 1.0)
	add_child(_fog_overlay)

	_lantern_glow = ColorRect.new()
	_lantern_glow.color = Color(0.95, 0.65, 0.20, 0.08)
	_lantern_glow.set_anchor(SIDE_LEFT,   0.25)
	_lantern_glow.set_anchor(SIDE_RIGHT,  0.75)
	_lantern_glow.set_anchor(SIDE_TOP,    0.40)
	_lantern_glow.set_anchor(SIDE_BOTTOM, 0.90)
	add_child(_lantern_glow)

	_build_silhouettes()


func _build_silhouettes() -> void:
	_silhouettes.clear()
	_silhouette_anchors.clear()
	var figures: Array = [
		[0.04, 0.07, 0.28, 0.45],
		[0.10, 0.12, 0.22, 0.30],
		[0.14, 0.17, 0.25, 0.38],
		[0.83, 0.86, 0.26, 0.40],
		[0.88, 0.90, 0.20, 0.28],
		[0.93, 0.96, 0.24, 0.35],
	]
	for f in figures:
		var fig := ColorRect.new()
		fig.color = Color(0.02, 0.01, 0.01, f[3])
		fig.set_anchor(SIDE_LEFT,   f[0])
		fig.set_anchor(SIDE_RIGHT,  f[1])
		fig.set_anchor(SIDE_TOP,    1.0 - f[2])
		fig.set_anchor(SIDE_BOTTOM, 1.0)
		add_child(fig)
		_silhouettes.append(fig)
		_silhouette_anchors.append([f[0], f[1]])


func _process(delta: float) -> void:
	if not visible:
		return
	_silhouette_phase += delta * 0.4
	for i in _silhouettes.size():
		var fig: ColorRect = _silhouettes[i]
		var phase_offset: float = float(i) * 1.3
		var sway: float = sin(_silhouette_phase + phase_offset) * 0.003
		var orig: Array = _silhouette_anchors[i]
		fig.set_anchor(SIDE_LEFT,  orig[0] + sway)
		fig.set_anchor(SIDE_RIGHT, orig[1] + sway)
		var pulse: float = sin(_silhouette_phase * 0.8 + phase_offset) * 0.04
		fig.modulate.a = clampf(1.0 + pulse, 0.7, 1.3)


# ── Main panel ────────────────────────────────────────────────────────────────

func _build_main_panel() -> void:
	_panel_main = _make_parchment_panel(440, 520)
	add_child(_panel_main)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_main.add_child(vbox)

	vbox.add_child(_make_manuscript_flourish())

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer_top)

	var title := Label.new()
	title.text = "RUMOR MILL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	var title_sep := Label.new()
	title_sep.text = "\u2014  \u273D  \u2014"
	title_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sep.add_theme_font_size_override("font_size", 14)
	title_sep.add_theme_color_override("font_color", Color(0.75, 0.55, 0.20, 0.70))
	vbox.add_child(title_sep)

	var tagline := Label.new()
	tagline.text = "Whispers in the Lamplighter\u2019s Square"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(tagline)

	var subtitle := Label.new()
	subtitle.text = "A medieval rumor-spreading social simulation"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(subtitle)

	vbox.add_child(_make_manuscript_flourish())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var btn_row := VBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var btn_new_game := _make_button("New Game", 200)
	btn_new_game.pressed.connect(_on_play_pressed)
	btn_row.add_child(btn_new_game)

	_btn_continue = _make_button("Continue", 200)
	_btn_continue.pressed.connect(_on_continue_pressed)
	btn_row.add_child(_btn_continue)
	_refresh_continue_button()

	var btn_howto := _make_button("How to Play", 200)
	btn_howto.pressed.connect(_on_how_to_play_pressed)
	btn_row.add_child(btn_howto)

	var btn_settings := _make_button("Settings", 200)
	btn_settings.pressed.connect(func() -> void: _show_phase(Phase.SETTINGS))
	btn_row.add_child(btn_settings)

	var btn_credits := _make_button("Credits", 200)
	btn_credits.pressed.connect(func() -> void: _show_phase(Phase.CREDITS))
	btn_row.add_child(btn_credits)

	var btn_stats := _make_button("Statistics", 200)
	btn_stats.pressed.connect(func() -> void: _show_phase(Phase.STATS))
	btn_row.add_child(btn_stats)

	if not OS.has_feature("web"):
		var btn_quit := _make_button("Quit", 200)
		btn_quit.pressed.connect(get_tree().quit)
		btn_row.add_child(btn_quit)


# ── Credits panel ─────────────────────────────────────────────────────────────

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
	# SPA-1117: fit_content=true with scroll_active=false risks overflow; let the label
	# expand to fill available space and scroll if content exceeds the panel height.
	credits_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	credits_body.scroll_active = true
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
	btn_back.pressed.connect(func() -> void: _show_phase(Phase.MAIN))
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn_back)
	vbox.add_child(btn_row)


# ── Version label ─────────────────────────────────────────────────────────────

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


# ── Main panel helpers ────────────────────────────────────────────────────────

func _make_manuscript_flourish() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)

	var left_line := ColorRect.new()
	left_line.color = Color(0.75, 0.55, 0.20, 0.45)
	left_line.custom_minimum_size = Vector2(100, 1)
	row.add_child(left_line)

	var diamond := Label.new()
	diamond.text = " \u25C6 "
	diamond.add_theme_font_size_override("font_size", 10)
	diamond.add_theme_color_override("font_color", Color(0.75, 0.55, 0.20, 0.60))
	row.add_child(diamond)

	var right_line := ColorRect.new()
	right_line.color = Color(0.75, 0.55, 0.20, 0.45)
	right_line.custom_minimum_size = Vector2(100, 1)
	row.add_child(right_line)
	return row


func _refresh_continue_button() -> void:
	if _btn_continue == null:
		return
	var recent := SaveManager.get_most_recent_save(_scenarios)
	if recent.is_empty():
		_btn_continue.disabled = true
		_btn_continue.tooltip_text = "No saved games found."
	else:
		_btn_continue.disabled = false
		var title_str: String = recent.get("scenario_title", recent.get("scenario_id", ""))
		_btn_continue.tooltip_text = "%s — Day %d" % [title_str, recent.get("day", 1)]


func _on_continue_pressed() -> void:
	var recent := SaveManager.get_most_recent_save(_scenarios)
	if recent.is_empty():
		return
	var scenario_id: String = recent["scenario_id"]
	var slot: int = recent["slot"]
	var err: String = SaveManager.prepare_load(scenario_id, slot)
	if not err.is_empty():
		push_warning("MainMenu: continue failed — " + err)
		return
	begin_game.emit(scenario_id)


func _on_play_pressed() -> void:
	_select_module.selected_idx = -1
	_select_module.selected_scenario = {}
	_show_phase(Phase.SELECT)


func _on_how_to_play_pressed() -> void:
	_how_to_play.open()


func _on_select_next() -> void:
	_briefing_module.populate_briefing(_select_module.selected_scenario)
	_show_phase(Phase.BRIEFING)


# ── UI helpers ────────────────────────────────────────────────────────────────

func _make_parchment_panel(w: int, h: int) -> PanelContainer:
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
	style.bg_color     = Color(0.11, 0.08, 0.05, 0.92)
	style.border_color = Color(0.55, 0.38, 0.18, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	style.border_width_top = 3
	panel.add_theme_stylebox_override("panel", style)
	return panel


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
	style.bg_color     = C_PANEL_BG
	style.border_color = C_PANEL_BORDER
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
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
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

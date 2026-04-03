extends CanvasLayer

## main_menu.gd — Main menu for Rumor Mill.
##
## Screens:
##   MAIN           — Title, New Game, Settings, Credits, Quit.
##   SCENARIO_SELECT — Three scenario cards with title, duration, description.
##   SETTINGS        — Master volume slider (AudioServer bus control).
##   CREDITS         — Scrollable credits text.
##
## Medieval/parchment visual style matching the rest of the game.

# ── Palette (matches end_screen.gd) ──────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 1.0)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)   # parchment
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.50, 0.44, 0.34, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_CARD_BG      := Color(0.17, 0.12, 0.08, 1.0)
const C_CARD_HOVER   := Color(0.22, 0.16, 0.10, 1.0)
const C_CARD_BORDER  := Color(0.45, 0.30, 0.12, 1.0)

# ── Screen enum ───────────────────────────────────────────────────────────────
enum Screen { MAIN, SCENARIO_SELECT, SETTINGS, CREDITS }

var _current_screen: Screen = Screen.MAIN

# ── Panel refs ────────────────────────────────────────────────────────────────
var _panel_main:     Control = null
var _panel_scenario: Control = null
var _panel_settings: Control = null
var _panel_credits:  Control = null

# ── Scenario data ─────────────────────────────────────────────────────────────
var _scenarios: Array = []

# ── Master volume state ───────────────────────────────────────────────────────
var _volume_slider: HSlider = null


func _ready() -> void:
	layer = 50
	_load_scenarios()
	_build_ui()
	_show_screen(Screen.MAIN)
	print("MainMenu: ready")


# ── Data loading ──────────────────────────────────────────────────────────────

func _load_scenarios() -> void:
	var file := FileAccess.open("res://data/scenarios.json", FileAccess.READ)
	if file == null:
		push_warning("MainMenu: scenarios.json not found")
		return
	var json := JSON.new()
	var err  := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("MainMenu: failed to parse scenarios.json")
		return
	_scenarios = json.get_data() as Array


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen parchment backdrop.
	var bg := ColorRect.new()
	bg.color = C_BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Decorative border strip at top and bottom.
	_add_border_strip(true)
	_add_border_strip(false)

	# Build all four screens; only one shown at a time.
	_panel_main     = _build_screen_main()
	_panel_scenario = _build_screen_scenario_select()
	_panel_settings = _build_screen_settings()
	_panel_credits  = _build_screen_credits()

	add_child(_panel_main)
	add_child(_panel_scenario)
	add_child(_panel_settings)
	add_child(_panel_credits)


func _add_border_strip(is_top: bool) -> void:
	var strip := ColorRect.new()
	strip.color = C_PANEL_BORDER
	strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.set_anchor(SIDE_TOP,    0.0 if is_top else 1.0)
	strip.set_anchor(SIDE_BOTTOM, 0.0 if is_top else 1.0)
	strip.set_offset(SIDE_TOP,    0.0 if is_top else -4.0)
	strip.set_offset(SIDE_BOTTOM, 4.0 if is_top else 0.0)
	add_child(strip)


# ── MAIN screen ───────────────────────────────────────────────────────────────

func _build_screen_main() -> Control:
	var root := _centered_vbox(400, 0)

	# Title.
	var title := Label.new()
	title.text = "Rumor Mill"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_TITLE)
	root.add_child(title)

	# Subtitle.
	var sub := Label.new()
	sub.text = "A game of whispers and scheming"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", C_MUTED)
	root.add_child(sub)

	root.add_child(_spacer(24))
	root.add_child(_separator_line())
	root.add_child(_spacer(24))

	# Buttons.
	var btn_new := _make_button("New Game", 200)
	btn_new.pressed.connect(func(): _show_screen(Screen.SCENARIO_SELECT))
	root.add_child(btn_new)

	root.add_child(_spacer(8))

	var btn_settings := _make_button("Settings", 200)
	btn_settings.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	root.add_child(btn_settings)

	root.add_child(_spacer(8))

	var btn_credits := _make_button("Credits", 200)
	btn_credits.pressed.connect(func(): _show_screen(Screen.CREDITS))
	root.add_child(btn_credits)

	root.add_child(_spacer(8))

	var btn_quit := _make_button("Quit", 200)
	btn_quit.pressed.connect(func(): get_tree().quit())
	root.add_child(btn_quit)

	root.add_child(_spacer(32))

	# Version watermark.
	var ver := Label.new()
	ver.text = "v0.1.0"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", C_MUTED)
	root.add_child(ver)

	return root


# ── SCENARIO SELECT screen ────────────────────────────────────────────────────

func _build_screen_scenario_select() -> Control:
	var root := _centered_vbox(900, 0)

	var heading := Label.new()
	heading.text = "Choose Your Scheme"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	root.add_child(heading)

	root.add_child(_spacer(8))
	root.add_child(_separator_line())
	root.add_child(_spacer(16))

	# Scenario cards in a horizontal row.
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 20)
	root.add_child(cards_row)

	if _scenarios.is_empty():
		var err_lbl := Label.new()
		err_lbl.text = "No scenarios found."
		err_lbl.add_theme_color_override("font_color", C_BODY)
		cards_row.add_child(err_lbl)
	else:
		for scenario in _scenarios:
			cards_row.add_child(_build_scenario_card(scenario))

	root.add_child(_spacer(24))

	# Back button.
	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(func(): _show_screen(Screen.MAIN))
	root.add_child(btn_back)

	return root


func _build_scenario_card(scenario: Dictionary) -> Control:
	var scenario_id: String = scenario.get("scenarioId", "")
	var title:       String = scenario.get("title", "Unnamed")
	var days:        int    = int(scenario.get("daysAllowed", 30))
	var start_text:  String = scenario.get("startingText", "")

	# Trim starting text to ~200 chars for the preview.
	var preview: String = start_text
	if preview.length() > 220:
		preview = preview.substr(0, 220).rstrip(" ").rstrip("\n") + "…"

	# Card panel.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 320)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = C_CARD_BG
	style_normal.border_color = C_CARD_BORDER
	style_normal.set_border_width_all(2)
	style_normal.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style_normal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Scenario title.
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	# Duration badge.
	var days_lbl := Label.new()
	days_lbl.text = "%d days" % days
	days_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_lbl.add_theme_font_size_override("font_size", 11)
	days_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(days_lbl)

	vbox.add_child(_separator_line())

	# Preview text.
	var preview_lbl := RichTextLabel.new()
	preview_lbl.text = preview
	preview_lbl.fit_content = true
	preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_lbl.custom_minimum_size = Vector2(0, 140)
	preview_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_lbl.add_theme_color_override("default_color", C_BODY)
	preview_lbl.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(preview_lbl)

	# Play button.
	var btn := _make_button("Play", 0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _start_scenario(scenario_id))
	vbox.add_child(btn)

	# Hover style via mouse_entered/exited.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		var s := StyleBoxFlat.new()
		s.bg_color = C_CARD_HOVER
		s.border_color = C_TITLE
		s.set_border_width_all(2)
		s.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", s)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", style_normal)
	)

	return card


func _start_scenario(scenario_id: String) -> void:
	GameState.selected_scenario_id = scenario_id
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# ── SETTINGS screen ───────────────────────────────────────────────────────────

func _build_screen_settings() -> Control:
	var root := _centered_vbox(440, 0)

	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	root.add_child(heading)

	root.add_child(_spacer(8))
	root.add_child(_separator_line())
	root.add_child(_spacer(24))

	# ── Master volume row ─────────────────────────────────────────────────────
	var vol_section := Label.new()
	vol_section.text = "Audio"
	vol_section.add_theme_font_size_override("font_size", 14)
	vol_section.add_theme_color_override("font_color", C_SUBHEADING)
	root.add_child(vol_section)

	root.add_child(_spacer(8))

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	root.add_child(vol_row)

	var vol_lbl := Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.custom_minimum_size = Vector2(130, 0)
	vol_lbl.add_theme_color_override("font_color", C_BODY)
	vol_row.add_child(vol_lbl)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Initialise slider from current master bus volume.
	var master_idx := AudioServer.get_bus_index("Master")
	var current_db := AudioServer.get_bus_volume_db(master_idx)
	_volume_slider.value = db_to_linear(current_db)
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume_slider)

	var vol_pct := Label.new()
	vol_pct.custom_minimum_size = Vector2(40, 0)
	vol_pct.add_theme_color_override("font_color", C_BODY)
	vol_pct.text = "%d%%" % int(_volume_slider.value * 100)
	vol_row.add_child(vol_pct)
	# Keep percentage label live.
	_volume_slider.value_changed.connect(func(v: float):
		vol_pct.text = "%d%%" % int(v * 100)
	)

	root.add_child(_spacer(32))
	root.add_child(_separator_line())
	root.add_child(_spacer(24))

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(func(): _show_screen(Screen.MAIN))
	root.add_child(btn_back)

	return root


func _on_volume_changed(value: float) -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	# Map 0.0 → -60 dB (near-silence), 1.0 → 0 dB (full).
	var db := linear_to_db(value) if value > 0.0 else -60.0
	AudioServer.set_bus_volume_db(master_idx, db)


# ── CREDITS screen ────────────────────────────────────────────────────────────

func _build_screen_credits() -> Control:
	var root := _centered_vbox(520, 0)

	var heading := Label.new()
	heading.text = "Credits"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	root.add_child(heading)

	root.add_child(_spacer(8))
	root.add_child(_separator_line())
	root.add_child(_spacer(16))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var credits_text := [
		["Rumor Mill", ""],
		["A medieval social simulation", ""],
		["", ""],
		["Design & Narrative", "section"],
		["Scenario writing, NPC personalities", ""],
		["Social graph architecture", ""],
		["", ""],
		["Engineering", "section"],
		["Godot 4.6 — game engine", ""],
		["GDScript — scripting language", ""],
		["SIR propagation model — rumor spread", ""],
		["A* pathfinding — NPC movement", ""],
		["", ""],
		["Audio", "section"],
		["Ambient day/night crossfade system", ""],
		["Polyphonic SFX pool", ""],
		["", ""],
		["Tools", "section"],
		["Paperclip — agent coordination", ""],
		["Claude — AI assistance", ""],
		["", ""],
		["Special Thanks", "section"],
		["To every town gossip who ever", ""],
		["whispered a well-timed untruth.", ""],
	]

	for entry in credits_text:
		var text: String = entry[0]
		var kind: String = entry[1]

		if text.is_empty():
			content.add_child(_spacer(8))
			continue

		var lbl := Label.new()
		lbl.text = text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if kind == "section":
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", C_SUBHEADING)
			content.add_child(_separator_line())
			content.add_child(lbl)
		else:
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", C_BODY)
			content.add_child(lbl)

	root.add_child(_spacer(16))
	root.add_child(_separator_line())
	root.add_child(_spacer(16))

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(func(): _show_screen(Screen.MAIN))
	root.add_child(btn_back)

	return root


# ── Screen switching ──────────────────────────────────────────────────────────

func _show_screen(screen: Screen) -> void:
	_current_screen = screen
	_panel_main.visible     = (screen == Screen.MAIN)
	_panel_scenario.visible = (screen == Screen.SCENARIO_SELECT)
	_panel_settings.visible = (screen == Screen.SETTINGS)
	_panel_credits.visible  = (screen == Screen.CREDITS)


# ── UI helpers ────────────────────────────────────────────────────────────────

## Build a VBoxContainer centered on screen.
func _centered_vbox(width: float, _unused: int) -> Control:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.set_anchor(SIDE_LEFT,   0.5)
	vbox.set_anchor(SIDE_RIGHT,  0.5)
	vbox.set_anchor(SIDE_TOP,    0.5)
	vbox.set_anchor(SIDE_BOTTOM, 0.5)
	if width > 0:
		vbox.custom_minimum_size = Vector2(width, 0)
	vbox.set_offset(SIDE_LEFT,  -width / 2.0)
	vbox.set_offset(SIDE_RIGHT,  width / 2.0)
	vbox.set_offset(SIDE_TOP,   -360.0)
	vbox.set_offset(SIDE_BOTTOM, 360.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	anchor.add_child(vbox)
	return anchor


func _spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _separator_line() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BORDER
	style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", style)
	return sep


func _make_button(label: String, min_width: int) -> Button:
	var btn := Button.new()
	btn.text = label
	if min_width > 0:
		btn.custom_minimum_size = Vector2(min_width, 42)
	else:
		btn.custom_minimum_size = Vector2(0, 42)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_PANEL_BORDER
	normal.set_content_margin_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_TITLE
	hover.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	return btn

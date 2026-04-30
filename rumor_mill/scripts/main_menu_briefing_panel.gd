class_name MainMenuBriefingPanel
extends Node

## main_menu_briefing_panel.gd — Briefing and Intro phase panels for MainMenu (SPA-1004).
##
## Extracted from main_menu.gd.  Call build(...) then add `briefing_panel` and
## `intro_panel` to the parent CanvasLayer.

signal back_requested_from_briefing
signal next_requested_from_briefing
signal back_requested_from_intro
signal begin_game_requested(scenario_id: String)

# ── Palette ───────────────────────────────────────────────────────────────────
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_CARD_BORDER  := Color(0.45, 0.30, 0.12, 1.0)

# SPA-806: Sprite sheet constants for target portrait.
const _PORTRAIT_SPRITE_W        := 64
const _PORTRAIT_SPRITE_H        := 96
const _PORTRAIT_IDLE_S_COL      := 0
const _PORTRAIT_FACTION_ROW     := {"merchant": 0, "noble": 1, "clergy": 2}
const _PORTRAIT_ARCHETYPE_ROW   := {
	"guard_civic": 3, "tavern_staff": 5, "scholar": 6, "elder": 7, "spy": 8,
}
const _PORTRAIT_COMMONER_ROLES  := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
const _PORTRAIT_BODY_ROW_OFFSET := 9
const _PORTRAIT_CLOTHING_BASE   := {"merchant": 27, "noble": 30, "clergy": 33}

# ── Public panel refs ─────────────────────────────────────────────────────────
var briefing_panel: Control = null
var intro_panel:    Control = null

# ── Briefing UI refs ──────────────────────────────────────────────────────────
var _briefing_title:          Label          = null
var _briefing_days:           Label          = null
var _briefing_body:           RichTextLabel  = null
var _btn_begin:               Button         = null
var _briefing_objective:      RichTextLabel  = null
var _briefing_portrait_frame: Panel          = null
var _difficulty_buttons:      Dictionary     = {}  # preset_id → Button

# ── Intro UI refs ─────────────────────────────────────────────────────────────
var _intro_title: Label         = null
var _intro_body:  RichTextLabel = null

# ── Runtime state ─────────────────────────────────────────────────────────────
var _selected_scenario: Dictionary = {}

# ── Callables ─────────────────────────────────────────────────────────────────
var _make_button: Callable
var _separator:   Callable


## Build both the briefing and intro panels.
func build(make_button: Callable, separator: Callable) -> void:
	_make_button = make_button
	_separator   = separator
	_build_briefing_panel()
	_build_intro_panel()


## Populate and display the briefing for a selected scenario.
func populate_briefing(scenario: Dictionary) -> void:
	_selected_scenario = scenario
	_briefing_title.text = _selected_scenario.get("title", "")
	_update_briefing_days()
	_briefing_body.text = _selected_scenario.get("startingText", "")
	_populate_objective_card()


# ── Build helpers ─────────────────────────────────────────────────────────────

func _build_briefing_panel() -> void:
	briefing_panel = _make_panel(600, 540)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefing_panel.add_child(vbox)

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

	vbox.add_child(_separator.call())

	_briefing_body = RichTextLabel.new()
	_briefing_body.custom_minimum_size = Vector2(0, 140)
	_briefing_body.fit_content = false
	_briefing_body.scroll_active = true
	_briefing_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_body.add_theme_font_size_override("normal_font_size", 13)
	_briefing_body.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_briefing_body)

	vbox.add_child(_separator.call())

	# SPA-806: Objective card with optional target portrait.
	var obj_row := HBoxContainer.new()
	obj_row.add_theme_constant_override("separation", 10)

	_briefing_portrait_frame = Panel.new()
	_briefing_portrait_frame.custom_minimum_size = Vector2(64, 96)
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	pf_style.border_color = C_CARD_BORDER
	pf_style.set_border_width_all(1)
	pf_style.set_corner_radius_all(4)
	pf_style.set_content_margin_all(0)
	_briefing_portrait_frame.add_theme_stylebox_override("panel", pf_style)
	_briefing_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_portrait_frame.visible = false
	obj_row.add_child(_briefing_portrait_frame)

	_briefing_objective = RichTextLabel.new()
	_briefing_objective.custom_minimum_size = Vector2(0, 100)
	_briefing_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing_objective.fit_content = false
	_briefing_objective.scroll_active = true
	_briefing_objective.bbcode_enabled = true
	_briefing_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_objective.add_theme_font_size_override("normal_font_size", 12)
	_briefing_objective.add_theme_color_override("default_color", C_HEADING)
	obj_row.add_child(_briefing_objective)

	vbox.add_child(obj_row)
	vbox.add_child(_separator.call())

	# Difficulty selector
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
		var btn := _make_button.call(preset.capitalize(), 120)
		btn.pressed.connect(_on_difficulty_pressed.bind(preset))
		diff_row.add_child(btn)
		_difficulty_buttons[preset] = btn

	_refresh_difficulty_buttons()
	vbox.add_child(_separator.call())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button.call("Back", 140)
	btn_back.pressed.connect(func() -> void: back_requested_from_briefing.emit())
	btn_row.add_child(btn_back)

	_btn_begin = _make_button.call("Next", 140)
	_btn_begin.pressed.connect(_on_briefing_next_pressed)
	btn_row.add_child(_btn_begin)


func _build_intro_panel() -> void:
	intro_panel = _make_panel(700, 460)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_panel.add_child(vbox)

	_intro_title = Label.new()
	_intro_title.text = ""
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.add_theme_font_size_override("font_size", 22)
	_intro_title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_intro_title)

	vbox.add_child(_separator.call())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	_intro_body = RichTextLabel.new()
	_intro_body.custom_minimum_size = Vector2(0, 240)
	_intro_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_intro_body.fit_content = false
	# SPA-1179 #12: scroll_active=true prevents overflow when narrative text exceeds
	# the panel height; previously scroll_active=false caused content to clip silently.
	_intro_body.scroll_active = true
	_intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_body.bbcode_enabled = true
	_intro_body.add_theme_font_size_override("normal_font_size", 17)
	_intro_body.add_theme_color_override("default_color", C_HEADING)
	vbox.add_child(_intro_body)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	vbox.add_child(_separator.call())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button.call("Back", 140)
	btn_back.pressed.connect(func() -> void: back_requested_from_intro.emit())
	btn_row.add_child(btn_back)

	var btn_begin := _make_button.call("Begin", 140)
	btn_begin.pressed.connect(_on_intro_begin_pressed)
	btn_row.add_child(btn_begin)


# ── Briefing population ───────────────────────────────────────────────────────

func _populate_objective_card() -> void:
	if _briefing_objective == null:
		return
	var card: Dictionary = _selected_scenario.get("objectiveCard", {})
	if card.is_empty():
		_briefing_objective.text = ""
		if _briefing_portrait_frame != null:
			_briefing_portrait_frame.visible = false
		return
	var bbcode: String = "[b][color=#ebc80c]YOUR MISSION:[/color][/b] %s\n" % card.get("mission", "")
	bbcode += "[b]Goal:[/b] %s\n" % card.get("winCondition", "")
	bbcode += "[b]Time:[/b] %s\n" % card.get("timeLimit", "")
	bbcode += "[color=#d94030][b]DANGER:[/b] %s[/color]\n" % card.get("danger", "")
	bbcode += "[color=#b5a664][b]Hint:[/b] %s[/color]\n" % card.get("strategyHint", "")
	var first_action: String = card.get("firstAction", "")
	if first_action != "":
		bbcode += "\n[color=#f4a63a][b]YOUR FIRST MOVE:[/b] %s[/color]" % first_action
	_briefing_objective.text = bbcode
	_populate_briefing_portrait()


func _populate_briefing_portrait() -> void:
	if _briefing_portrait_frame == null:
		return
	for child in _briefing_portrait_frame.get_children():
		child.queue_free()

	var brief: Dictionary = _selected_scenario.get("strategicBrief", {})
	var target_id: String = brief.get("targetNpcId", "")
	if target_id == "":
		_briefing_portrait_frame.visible = false
		return

	var npc: Dictionary = _find_npc_data(target_id)
	if npc.is_empty():
		_briefing_portrait_frame.visible = false
		return

	var npc_texture: Texture2D = load("res://assets/textures/npc_sprites.png")
	if npc_texture == null:
		_briefing_portrait_frame.visible = false
		return

	var faction:      String = npc.get("faction", "merchant")
	var archetype:    String = npc.get("archetype", "")
	var role:         String = npc.get("role", "")
	var body_type:    int    = clampi(int(npc.get("body_type", 0)), 0, 2)
	var clothing_var: int    = clampi(int(npc.get("clothing_var", 0)), 0, 3)
	var row: int = 0

	if _PORTRAIT_ARCHETYPE_ROW.has(archetype):
		row = _PORTRAIT_ARCHETYPE_ROW[archetype] + body_type * _PORTRAIT_BODY_ROW_OFFSET
	elif role in _PORTRAIT_COMMONER_ROLES:
		row = 4 + body_type * _PORTRAIT_BODY_ROW_OFFSET
	elif clothing_var > 0 and _PORTRAIT_CLOTHING_BASE.has(faction):
		row = _PORTRAIT_CLOTHING_BASE[faction] + (clothing_var - 1)
	else:
		row = _PORTRAIT_FACTION_ROW.get(faction, 0) + body_type * _PORTRAIT_BODY_ROW_OFFSET

	var region := Rect2(
		float(_PORTRAIT_IDLE_S_COL * _PORTRAIT_SPRITE_W),
		float(row * _PORTRAIT_SPRITE_H),
		float(_PORTRAIT_SPRITE_W),
		float(_PORTRAIT_SPRITE_H)
	)
	var atlas := AtlasTexture.new()
	atlas.atlas  = npc_texture
	atlas.region = region

	var portrait := TextureRect.new()
	portrait.texture      = atlas
	portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_portrait_frame.add_child(portrait)
	_briefing_portrait_frame.visible = true


func _find_npc_data(npc_id: String) -> Dictionary:
	var file := FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var npcs: Array = json.data if json.data is Array else []
	for npc: Dictionary in npcs:
		if npc.get("id", "") == npc_id:
			return npc
	return {}


func _update_briefing_days() -> void:
	if _selected_scenario.is_empty() or _briefing_days == null:
		return
	var base_days: int = int(_selected_scenario.get("daysAllowed", 30))
	var mods: Dictionary = GameState.get_difficulty_modifiers(GameState.selected_difficulty)
	var total_days: int = base_days + int(mods.get("days_bonus", 0))
	_briefing_days.text = "You have %d days." % total_days


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


func _make_panel(w: int, h: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.set_anchor(SIDE_LEFT,   0.5)
	p.set_anchor(SIDE_RIGHT,  0.5)
	p.set_anchor(SIDE_TOP,    0.5)
	p.set_anchor(SIDE_BOTTOM, 0.5)
	p.set_offset(SIDE_LEFT,   -w / 2.0)
	p.set_offset(SIDE_RIGHT,   w / 2.0)
	p.set_offset(SIDE_TOP,    -h / 2.0)
	p.set_offset(SIDE_BOTTOM,  h / 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", style)
	return p


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_difficulty_pressed(preset: String) -> void:
	GameState.selected_difficulty = preset
	_refresh_difficulty_buttons()
	_update_briefing_days()


func _on_briefing_next_pressed() -> void:
	# Populate intro and ask coordinator to switch to INTRO phase.
	_intro_title.text = _selected_scenario.get("title", "")
	var intro_text: String = _selected_scenario.get("introText", "")
	_intro_body.text = "[center][i]" + intro_text + "[/i][/center]"
	next_requested_from_briefing.emit()


func _on_intro_begin_pressed() -> void:
	var scenario_id: String = _selected_scenario.get("scenarioId", "scenario_1")
	begin_game_requested.emit(scenario_id)

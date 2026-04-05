extends CanvasLayer

## story_recap.gd — SPA-589: "Story So Far" recap shown when loading a saved game.
##
## Displays a parchment-style overlay summarising the player's progress:
##   • Scenario title and current day
##   • Key reputation changes and rumour activity
##   • Current objective status
##   • Brief reminder of the win condition
##
## Shown after SaveManager.apply_pending_load() completes.
## Dismissed with any key or mouse click, then unpauses the game.
##
## Usage from main.gd:
##   var recap := preload("res://scripts/story_recap.gd").new()
##   recap.name = "StoryRecap"
##   add_child(recap)
##   recap.setup(scenario_manager, day_night, world)
##   recap.dismissed.connect(_on_recap_dismissed)

signal dismissed

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.85)
const C_PANEL_BG     := Color(0.11, 0.08, 0.05, 0.95)
const C_BORDER       := Color(0.55, 0.38, 0.18, 0.85)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_ACCENT       := Color(0.957, 0.651, 0.227, 1.0)

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:      ColorRect      = null
var _panel:         PanelContainer = null
var _title_label:   Label          = null
var _body:          RichTextLabel  = null
var _dismiss_hint:  Label          = null


func _ready() -> void:
	layer = 16  # above ready overlay (15), below tutorial layers


func setup(scenario_mgr: ScenarioManager, day_night: Node, world: Node2D) -> void:
	_build_ui()
	_populate(scenario_mgr, day_night, world)
	visible = true


func _build_ui() -> void:
	# Backdrop
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Centre panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 380)
	_panel.set_anchor(SIDE_LEFT,   0.5)
	_panel.set_anchor(SIDE_RIGHT,  0.5)
	_panel.set_anchor(SIDE_TOP,    0.5)
	_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_panel.set_offset(SIDE_LEFT,   -280)
	_panel.set_offset(SIDE_RIGHT,   280)
	_panel.set_offset(SIDE_TOP,    -190)
	_panel.set_offset(SIDE_BOTTOM,  190)
	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.border_width_top = 3
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(vbox)

	# Ornamental top flourish
	var flourish := ColorRect.new()
	flourish.color = Color(0.957, 0.651, 0.227, 0.50)
	flourish.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(flourish)

	# Title
	_title_label = Label.new()
	_title_label.text = "The Story So Far..."
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Body
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("normal_font_size", 13)
	_body.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_body)

	# Dismiss hint
	_dismiss_hint = Label.new()
	_dismiss_hint.text = "Press any key to continue..."
	_dismiss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dismiss_hint.add_theme_font_size_override("font_size", 12)
	_dismiss_hint.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_dismiss_hint)


func _populate(scenario_mgr: ScenarioManager, day_night: Node, world: Node2D) -> void:
	var bbcode: String = ""

	# Scenario title and day.
	var title: String = scenario_mgr.get_title() if scenario_mgr != null else "Unknown"
	var day: int = day_night.current_day if day_night != null else 1
	var total_days: int = scenario_mgr.get_days_allowed() if scenario_mgr != null else 30

	bbcode += "[b][color=#ebc80c]%s[/color][/b]\n" % title
	bbcode += "[color=#b5a664]Day %d of %d[/color]\n\n" % [day, total_days]

	# Win condition reminder.
	var obj_card: Dictionary = scenario_mgr.get_objective_card() if scenario_mgr != null else {}
	if not obj_card.is_empty():
		bbcode += "[b]Your Mission:[/b] %s\n" % obj_card.get("mission", "")
		bbcode += "[b]Goal:[/b] %s\n\n" % obj_card.get("winCondition", "")

	# Key NPC reputation status.
	if world != null and world.reputation_system != null:
		bbcode += "[b][color=#f4a63a]Current Status:[/color][/b]\n"
		var rep_sys = world.reputation_system
		# Show reputation of key NPCs (scenario targets).
		var key_npcs: Array = _get_key_npcs(world)
		for npc_name in key_npcs:
			var rep: int = rep_sys.get_reputation_by_name(npc_name) if rep_sys.has_method("get_reputation_by_name") else -1
			if rep >= 0:
				var tier: String = _rep_tier(rep)
				bbcode += "  [b]%s[/b] — Reputation: %d (%s)\n" % [npc_name, rep, tier]

	# Rumour activity summary.
	if world != null:
		var active_rumors: int = world.get_active_rumor_count() if world.has_method("get_active_rumor_count") else 0
		if active_rumors > 0:
			bbcode += "\n[color=#d2bd94]%d active rumour%s circulating in town.[/color]\n" % [
				active_rumors, "s" if active_rumors != 1 else ""
			]

	# Strategy hint.
	if not obj_card.is_empty():
		var hint: String = obj_card.get("strategyHint", "")
		if hint != "":
			bbcode += "\n[color=#b5a664][b]Hint:[/b] %s[/color]" % hint

	_body.text = bbcode


func _get_key_npcs(world: Node2D) -> Array:
	# Return names of scenario-relevant NPCs based on active scenario.
	var sc_id: String = world.active_scenario_id if "active_scenario_id" in world else ""
	match sc_id:
		"scenario_1":
			return ["Edric Fenn"]
		"scenario_2":
			return ["Alys Herbwife"]
		"scenario_3":
			return ["Calder Fenn", "Tomas Reeve"]
		"scenario_4":
			return ["Aldous Prior", "Vera Midwife", "Finn Monk"]
	return []


func _rep_tier(rep: int) -> String:
	if rep >= 71:
		return "Distinguished"
	elif rep >= 51:
		return "Respected"
	elif rep >= 31:
		return "Suspect"
	return "Disgraced"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or \
	   (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_dismiss()


func _dismiss() -> void:
	visible = false
	dismissed.emit()
	queue_free()

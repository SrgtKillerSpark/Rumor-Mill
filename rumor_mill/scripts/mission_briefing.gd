extends CanvasLayer

## mission_briefing.gd — SPA-841: Single consolidated Mission Briefing screen.
##
## Replaces the 3-screen chain (StrategicOverview → ReadyOverlay → MissionCard)
## with one blocking overlay on Day 1 fresh start. Shows:
##   - NPC portrait + target info (left column)
##   - Objective one-liner (gold, large)
##   - Win condition (amber)
##   - Strategy hint (parchment)
##   - First move (green)
##   - "Begin" button (no auto-dismiss)
##
## Also supports recall mode (O-key mid-game) — read-only, ESC/SPACE dismiss.

signal dismissed

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BACKDROP    := Color(0.03, 0.02, 0.05, 0.80)
const C_CARD_BG     := Color(0.08, 0.06, 0.04, 0.95)
const C_CARD_BORDER := Color(0.957, 0.651, 0.227, 0.8)
const C_TITLE       := Color(0.96, 0.84, 0.40, 1.0)       # warm gold
const C_WIN         := Color(0.95, 0.75, 0.30, 1.0)        # amber
const C_BODY        := Color(0.80, 0.72, 0.55, 1.0)        # parchment
const C_DANGER      := Color(0.95, 0.35, 0.25, 1.0)        # red warning
const C_ACTION      := Color(0.60, 0.90, 0.50, 1.0)        # green first-action
const C_PROMPT      := Color(0.95, 0.88, 0.65, 1.0)        # warm prompt
const C_PHASE_HDR   := Color(0.75, 0.65, 0.45, 0.6)        # subtle header
const C_BTN_NORMAL  := Color(0.15, 0.45, 0.15, 1.0)
const C_BTN_HOVER   := Color(0.20, 0.55, 0.20, 1.0)
const C_BTN_TEXT    := Color(0.95, 0.95, 0.90, 1.0)

# ── Portrait sprite sheet constants (mirrors npc.gd row logic) ───────────────

const SPRITE_W := 64
const SPRITE_H := 96
const _IDLE_S_COL := 0

const _FACTION_ROW := {
	"merchant": 0,
	"noble":    1,
	"clergy":   2,
}
const _ARCHETYPE_ROW := {
	"guard_civic":  3,
	"tavern_staff": 5,
	"scholar":      6,
	"elder":        7,
	"spy":          8,
}
const _COMMONER_ROLES := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
const _BODY_TYPE_ROW_OFFSET := 9
const _CLOTHING_VAR_BASE := {
	"merchant": 27,
	"noble":    30,
	"clergy":   33,
}

# ── Node refs ─────────────────────────────────────────────────────────────────

var _backdrop:     ColorRect      = null
var _card:         Panel          = null
var _vbox:         VBoxContainer  = null
var _prompt_label: Label          = null
var _begin_btn:    Button         = null
var _pulse_tween:  Tween          = null

# ── Data ──────────────────────────────────────────────────────────────────────

var _objective_one_liner: String     = ""
var _win_condition_line:  String     = ""
var _strategy_hint:       String     = ""
var _first_action:        String     = ""
var _constraint:          String     = ""
var _danger:              String     = ""
var _brief:               Dictionary = {}
var _npc_data:            Dictionary = {}
var _recall_mode:         bool       = false


func _ready() -> void:
	layer        = 16   # above HUD (5), below pause (20)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Full briefing on Day 1 game start. No auto-dismiss — requires Begin button.
func setup(
	objective_one_liner: String,
	win_condition_line: String,
	objective_card: Dictionary,
	brief: Dictionary,
	npc_data: Dictionary
) -> void:
	_objective_one_liner = objective_card.get("mission", objective_one_liner)
	_win_condition_line  = objective_card.get("winCondition", win_condition_line)
	_strategy_hint       = objective_card.get("strategyHint", "")
	_first_action        = objective_card.get("firstAction", "")
	_danger              = objective_card.get("danger", "")
	_constraint          = brief.get("primaryConstraint", "")
	_brief               = brief
	_npc_data            = npc_data
	_recall_mode         = false
	_build_shell()
	_populate_content()


## Recall mode (O-key mid-game). Read-only, dismiss with SPACE/ENTER/ESC.
func setup_recall(
	objective_one_liner: String,
	win_condition_line: String,
	objective_card: Dictionary,
	brief: Dictionary,
	npc_data: Dictionary
) -> void:
	_objective_one_liner = objective_card.get("mission", objective_one_liner)
	_win_condition_line  = objective_card.get("winCondition", win_condition_line)
	_strategy_hint       = objective_card.get("strategyHint", "")
	_first_action        = objective_card.get("firstAction", "")
	_danger              = objective_card.get("danger", "")
	_constraint          = brief.get("primaryConstraint", "")
	_brief               = brief
	_npc_data            = npc_data
	_recall_mode         = true
	_build_shell()
	_populate_content()


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
	_card.offset_left   = -310.0
	_card.offset_right  =  310.0
	_card.offset_top    = -270.0
	_card.offset_bottom =  270.0
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
	_vbox.add_theme_constant_override("separation", 9)
	_card.add_child(_vbox)


# ── Content ───────────────────────────────────────────────────────────────────

func _populate_content() -> void:
	# Header badge.
	var header_text := "MISSION  RECALL" if _recall_mode else "MISSION  BRIEFING"
	var badge := Label.new()
	badge.text = header_text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", C_PHASE_HDR)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(badge)

	_add_divider()

	# Two-column row: NPC portrait (left) + target info (right).
	var has_portrait := not _npc_data.is_empty()
	if has_portrait:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(hbox)

		_build_portrait(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 4)
		info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(info_vbox)

		_build_target_info(info_vbox)
		_add_divider()

	# Objective one-liner (gold, large).
	if _objective_one_liner != "":
		var obj_lbl := Label.new()
		obj_lbl.text = _objective_one_liner
		obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj_lbl.add_theme_font_size_override("font_size", 18)
		obj_lbl.add_theme_color_override("font_color", C_TITLE)
		obj_lbl.add_theme_constant_override("outline_size", 2)
		obj_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
		obj_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(obj_lbl)

	# Win condition (amber).
	if _win_condition_line != "":
		_add_labeled_line("WIN:", _win_condition_line, C_WIN)

	# Strategy hint.
	if _strategy_hint != "":
		_add_labeled_line("STRATEGY:", _strategy_hint, C_BODY)

	# Constraint / danger.
	if _constraint != "":
		_add_labeled_line("CONSTRAINT:", _constraint, C_DANGER)
	if _danger != "" and _danger != _constraint:
		_add_labeled_line("DANGER:", _danger, C_DANGER)

	# First move (green).
	if _first_action != "":
		_add_labeled_line("FIRST MOVE:", _first_action, C_ACTION)

	_add_divider()

	# Flexible spacer pushes button/prompt to the bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(spacer)

	if _recall_mode:
		# Recall mode: pulsing dismiss prompt.
		_prompt_label = Label.new()
		_prompt_label.text = "—  Press  SPACE  or  ESC  to  close  —"
		_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt_label.add_theme_font_size_override("font_size", 14)
		_prompt_label.add_theme_color_override("font_color", C_PROMPT)
		_prompt_label.add_theme_constant_override("outline_size", 2)
		_prompt_label.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
		_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(_prompt_label)
		_start_pulse()
	else:
		# Game-start: "Begin" button.
		var btn_center := CenterContainer.new()
		btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(btn_center)

		_begin_btn = Button.new()
		_begin_btn.text = "BEGIN"
		_begin_btn.custom_minimum_size = Vector2(180, 40)
		_begin_btn.add_theme_font_size_override("font_size", 16)
		_begin_btn.add_theme_color_override("font_color", C_BTN_TEXT)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = C_BTN_NORMAL
		btn_style.border_color = C_CARD_BORDER
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(6)
		btn_style.set_content_margin_all(8)
		_begin_btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = C_BTN_HOVER
		btn_hover.border_color = C_CARD_BORDER
		btn_hover.set_border_width_all(1)
		btn_hover.set_corner_radius_all(6)
		btn_hover.set_content_margin_all(8)
		_begin_btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = C_BTN_NORMAL.darkened(0.15)
		btn_pressed.border_color = C_CARD_BORDER
		btn_pressed.set_border_width_all(1)
		btn_pressed.set_corner_radius_all(6)
		btn_pressed.set_content_margin_all(8)
		_begin_btn.add_theme_stylebox_override("pressed", btn_pressed)

		var btn_focus := btn_style.duplicate()
		btn_focus.border_color = Color(0.96, 0.84, 0.40, 0.9)
		btn_focus.set_border_width_all(2)
		_begin_btn.add_theme_stylebox_override("focus", btn_focus)

		_begin_btn.pressed.connect(_dismiss)
		btn_center.add_child(_begin_btn)
		_begin_btn.grab_focus()

		# Subtle keyboard hint below button.
		var hint_lbl := Label.new()
		hint_lbl.text = "or press SPACE / ENTER"
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42, 0.6))
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(hint_lbl)


func _build_target_info(parent: VBoxContainer) -> void:
	var npc_name: String = _npc_data.get("name", _brief.get("targetNpcId", "Unknown"))
	var npc_role: String = _npc_data.get("role", "")
	var faction:  String = _npc_data.get("faction", "")

	var name_lbl := Label.new()
	name_lbl.text = npc_name.to_upper()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", C_TITLE)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(name_lbl)

	if npc_role != "":
		var role_lbl := Label.new()
		role_lbl.text = npc_role
		role_lbl.add_theme_font_size_override("font_size", 13)
		role_lbl.add_theme_color_override("font_color", Color(0.70, 0.62, 0.45, 0.9))
		role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(role_lbl)

	var rep_start: int = _brief.get("repStart", 70)
	_add_stat_line(parent, "REPUTATION:", "%d" % rep_start, C_BODY)

	var goal_label: String = _brief.get("goalLabel", "")
	if goal_label != "":
		_add_stat_line(parent, "GOAL:", goal_label, C_ACTION)

	if faction != "":
		_add_stat_line(parent, "FACTION:", faction.capitalize(), C_BODY)


func _build_portrait(parent: HBoxContainer) -> void:
	var npc_texture: Texture2D = load("res://assets/textures/npc_sprites.png")

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(96, 144)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	frame_style.border_color = C_CARD_BORDER
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(4)
	frame_style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)

	if npc_texture == null:
		return

	var faction:      String = _npc_data.get("faction", "merchant")
	var archetype:    String = _npc_data.get("archetype", "")
	var role:         String = _npc_data.get("role", "")
	var body_type:    int    = clampi(_npc_data.get("body_type", 0), 0, 2)
	var clothing_var: int    = clampi(_npc_data.get("clothing_var", 0), 0, 3)
	var row: int = 0

	if _ARCHETYPE_ROW.has(archetype):
		row = _ARCHETYPE_ROW[archetype] + body_type * _BODY_TYPE_ROW_OFFSET
	elif role in _COMMONER_ROLES:
		row = 4 + body_type * _BODY_TYPE_ROW_OFFSET
	elif clothing_var > 0 and _CLOTHING_VAR_BASE.has(faction):
		row = _CLOTHING_VAR_BASE[faction] + (clothing_var - 1)
	else:
		row = _FACTION_ROW.get(faction, 0) + body_type * _BODY_TYPE_ROW_OFFSET

	var region := Rect2(
		float(_IDLE_S_COL * SPRITE_W),
		float(row * SPRITE_H),
		float(SPRITE_W),
		float(SPRITE_H)
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
	frame.add_child(portrait)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_divider() -> void:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 6)
	var style := StyleBoxLine.new()
	style.color = C_CARD_BORDER
	style.thickness = 1
	div.add_theme_stylebox_override("separator", style)
	_vbox.add_child(div)


func _add_labeled_line(label_text: String, body_text: String, body_color: Color) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content    = true
	rtl.scroll_active  = false
	rtl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	rtl.text = "[b][color=#%s]%s[/color][/b] %s" % [
		C_TITLE.to_html(false), label_text, body_text
	]
	rtl.add_theme_color_override("default_color", body_color)
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_font_size_override("bold_font_size", 14)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(rtl)


func _add_stat_line(parent: VBoxContainer, label_text: String, body_text: String, body_color: Color) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content    = true
	rtl.scroll_active  = false
	rtl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	rtl.text = "[b][color=#%s]%s[/color][/b] [color=#%s]%s[/color]" % [
		C_TITLE.to_html(false), label_text,
		body_color.to_html(false), body_text
	]
	rtl.add_theme_color_override("default_color", body_color)
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_font_size_override("bold_font_size", 13)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rtl)


func _start_pulse() -> void:
	if _prompt_label == null:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 0.45, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 1.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _recall_mode:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_dismiss()
		else:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				get_viewport().set_input_as_handled()
				_dismiss()


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _dismiss() -> void:
	AudioManager.play_ui("click")
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var tw := create_tween()
	tw.tween_property(_backdrop, "color:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		dismissed.emit()
		queue_free()
	)

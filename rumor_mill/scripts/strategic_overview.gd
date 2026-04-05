extends CanvasLayer

## strategic_overview.gd — SPA-720: 15-second pre-game strategic briefing screen.
##
## Shown between the loading tips and the ReadyOverlay on Day 1 fresh start.
## Displays the primary target NPC portrait, starting reputation, numeric goal,
## primary constraint, and a one-sentence strategic hint drawn from scenarios.json.
##
## Auto-dismisses after 15 seconds (with a visible countdown bar) or immediately
## on SPACE / ENTER. Emits `dismissed` when done.

signal dismissed

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BACKDROP    := Color(0.03, 0.02, 0.05, 0.80)
const C_CARD_BG     := Color(0.08, 0.06, 0.04, 0.95)
const C_CARD_BORDER := Color(0.957, 0.651, 0.227, 0.8)
const C_TITLE       := Color(0.96, 0.84, 0.40, 1.0)
const C_BODY        := Color(0.80, 0.72, 0.55, 1.0)
const C_DANGER      := Color(0.95, 0.35, 0.25, 1.0)
const C_HINT        := Color(0.65, 0.85, 0.55, 1.0)
const C_PHASE_HDR   := Color(0.75, 0.65, 0.45, 0.6)
const C_PROMPT      := Color(0.95, 0.88, 0.65, 1.0)
const C_TIMER_BG    := Color(0.12, 0.09, 0.06, 0.8)
const C_TIMER_FG    := Color(0.957, 0.651, 0.227, 0.9)

const AUTO_DISMISS_SEC := 15.0

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
var _pulse_tween:  Tween          = null
var _timer_bar:    ColorRect      = null

# ── State ─────────────────────────────────────────────────────────────────────

var _brief:        Dictionary = {}
var _npc_data:     Dictionary = {}
var _time_left:    float      = AUTO_DISMISS_SEC
var _timer_active: bool       = false


func _ready() -> void:
	layer        = 16   # above HUD (5), ReadyOverlay (15), below pause (20)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Call after adding to the tree.
## brief: the strategicBrief dictionary from scenarios.json (via ScenarioManager).
## npc_data: the raw NPC entry from npcs.json for the target NPC.
func setup(brief: Dictionary, npc_data: Dictionary) -> void:
	_brief    = brief
	_npc_data = npc_data
	_build_shell()
	_populate_content()
	_time_left    = AUTO_DISMISS_SEC
	_timer_active = true


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
	_card.offset_top    = -230.0
	_card.offset_bottom =  230.0
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
	_vbox.add_theme_constant_override("separation", 8)
	_card.add_child(_vbox)


# ── Content ───────────────────────────────────────────────────────────────────

func _populate_content() -> void:
	# Phase header.
	var phase_lbl := Label.new()
	phase_lbl.text = "STRATEGIC  OVERVIEW"
	phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_lbl.add_theme_font_size_override("font_size", 11)
	phase_lbl.add_theme_color_override("font_color", C_PHASE_HDR)
	phase_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(phase_lbl)

	_add_divider()

	# Two-column row: portrait (left) + target info (right).
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(hbox)

	_build_portrait(hbox)

	# Right column — target info.
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 5)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	_build_target_info(info_vbox)

	_add_divider()

	# Constraint.
	var constraint: String = _brief.get("primaryConstraint", "")
	if constraint != "":
		_add_labeled_line("CONSTRAINT:", constraint, C_DANGER)

	# Strategic hint.
	var hint: String = _brief.get("strategicHint", "")
	if hint != "":
		_add_labeled_line("STRATEGY:", hint, C_BODY)

	_add_divider()

	# Countdown bar.
	_build_timer_bar()

	# Prompt.
	_prompt_label = Label.new()
	_prompt_label.text = "—  Press  SPACE  or  ENTER  to  continue  —"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", C_PROMPT)
	_prompt_label.add_theme_constant_override("outline_size", 2)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_prompt_label)

	_start_pulse()


func _build_target_info(parent: VBoxContainer) -> void:
	var npc_name: String = _npc_data.get("name", _brief.get("targetNpcId", "Unknown"))
	var npc_role: String = _npc_data.get("role", "")
	var faction:  String = _npc_data.get("faction", "")

	# NPC name (large gold).
	var name_lbl := Label.new()
	name_lbl.text = npc_name.to_upper()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", C_TITLE)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(name_lbl)

	# Role subtitle.
	if npc_role != "":
		var role_lbl := Label.new()
		role_lbl.text = npc_role
		role_lbl.add_theme_font_size_override("font_size", 13)
		role_lbl.add_theme_color_override("font_color", Color(0.70, 0.62, 0.45, 0.9))
		role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(role_lbl)

	# Spacer.
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	parent.add_child(sp)

	# Starting reputation.
	var rep_start: int = _brief.get("repStart", 70)
	_add_stat_line(parent, "REPUTATION:", "%d" % rep_start, C_BODY)

	# Goal.
	var goal_label: String = _brief.get("goalLabel", "")
	if goal_label != "":
		_add_stat_line(parent, "GOAL:", goal_label, C_HINT)

	# Faction.
	if faction != "":
		_add_stat_line(parent, "FACTION:", faction.capitalize(), C_BODY)


func _build_portrait(parent: HBoxContainer) -> void:
	var npc_texture: Texture2D = load("res://assets/textures/npc_sprites.png")

	# Portrait frame (Panel for the border).
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

	# Compute sprite sheet row (mirrors npc.gd logic).
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

	# First idle-south frame (column 0).
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


func _build_timer_bar() -> void:
	# Thin bar showing time remaining before auto-dismiss.
	var container := Control.new()
	container.custom_minimum_size = Vector2(0, 5)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(container)

	var bg := ColorRect.new()
	bg.color = C_TIMER_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	_timer_bar = ColorRect.new()
	_timer_bar.color = C_TIMER_FG
	# Anchored left — right anchor shrinks as time elapses.
	_timer_bar.anchor_left   = 0.0
	_timer_bar.anchor_top    = 0.0
	_timer_bar.anchor_bottom = 1.0
	_timer_bar.anchor_right  = 1.0
	_timer_bar.offset_left   = 0
	_timer_bar.offset_right  = 0
	_timer_bar.offset_top    = 0
	_timer_bar.offset_bottom = 0
	_timer_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	container.add_child(_timer_bar)


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
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 0.45, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_prompt_label, "modulate:a", 1.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ── Timer ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _timer_active:
		return
	_time_left -= delta
	if _timer_bar != null and is_instance_valid(_timer_bar):
		_timer_bar.anchor_right = clampf(_time_left / AUTO_DISMISS_SEC, 0.0, 1.0)
	if _time_left <= 0.0:
		_timer_active = false
		_dismiss()


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_timer_active = false
			_dismiss()


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _dismiss() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var tw := create_tween()
	tw.tween_property(_backdrop, "color:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		emit_signal("dismissed")
		queue_free()
	)

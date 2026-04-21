extends CanvasLayer

## npc_info_panel.gd — SPA-872: NPC quick-info side panel.
##
## Shown when an NPC is selected via Tab cycling or left-click.
## Displays name, role, faction, belief state, current location,
## available actions with keyboard shortcut labels, and the last
## known interaction from the intel store.
##
## Positioned on the right side so it never obscures the game view.
## Dismissed with Escape or by selecting a different NPC / clicking away.
##
## Usage:
##   setup(world, intel_store)
##   show_npc(npc_node)   — call after Tab-cycle or click selection
##   hide_panel()         — call on Escape or deselect

signal action_requested(action_key: String, npc: Node2D)

# ── Palette (shared with npc_tooltip.gd) ──────────────────────────────────────
const C_BG      := Color(0.10, 0.07, 0.05, 0.96)
const C_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE   := Color(0.92, 0.78, 0.12, 1.0)
const C_LABEL   := Color(0.82, 0.75, 0.60, 1.0)
const C_MUTED   := Color(0.58, 0.52, 0.42, 0.85)
const C_KEY     := Color(0.92, 0.78, 0.12, 0.95)
const C_ACTION  := Color(0.65, 0.90, 0.65, 1.0)
const C_FACTION := {
	"merchant": Color(0.92, 0.75, 0.18, 1.0),
	"noble":    Color(0.55, 0.65, 1.00, 1.0),
	"clergy":   Color(0.85, 0.85, 0.85, 1.0),
}
const C_BELIEF := {
	0: Color(0.65, 0.65, 0.65, 1.0),  # Unaware
	1: Color(1.00, 1.00, 0.45, 1.0),  # Evaluating
	2: Color(0.50, 1.00, 0.55, 1.0),  # Believes
	3: Color(0.70, 0.70, 0.85, 1.0),  # Rejecting
	4: Color(1.00, 0.70, 0.30, 1.0),  # Spreading
	5: Color(1.00, 0.45, 0.90, 1.0),  # Acting
	6: Color(0.80, 0.55, 1.00, 1.0),  # Contradicted
	7: Color(0.55, 0.55, 0.55, 1.0),  # Expired
	8: Color(0.45, 0.80, 1.00, 1.0),  # Defending
}
const BELIEF_LABEL := {
	0: "Unaware", 1: "Evaluating", 2: "Believes", 3: "Rejecting",
	4: "Spreading", 5: "Acting", 6: "Contradicted", 7: "Expired", 8: "Defending",
}
const BELIEF_ICON := {
	0: "○", 1: "◇", 2: "✓", 3: "✕", 4: "▶", 5: "★", 6: "⚡", 7: "—", 8: "◆",
}

## Actions shown in the panel. key → {label, shortcut, description}
const ACTIONS := [
	{"key": "eavesdrop", "label": "Eavesdrop",  "shortcut": "1", "desc": "Listen in on their conversation"},
	{"key": "bribe",     "label": "Bribe",       "shortcut": "2", "desc": "Spend a favor to reduce suspicion"},
	{"key": "seed",      "label": "Seed Rumor",  "shortcut": "3", "desc": "Plant a rumor with this NPC"},
]

# ── Node refs ──────────────────────────────────────────────────────────────────
var _panel:        Panel          = null
var _name_lbl:     Label          = null
var _role_lbl:     Label          = null
var _location_lbl: Label          = null
var _belief_lbl:   Label          = null
var _last_int_lbl: Label          = null
var _action_btns:  Array[Button]  = []
var _tween:        Tween          = null

# ── State ──────────────────────────────────────────────────────────────────────
var _current_npc:    Node2D           = null
var _world_ref:      Node2D           = null
var _intel_store:    Object           = null  # PlayerIntelStore


func _ready() -> void:
	layer   = 8  # above HUD (5), below journal (10)
	visible = false
	_build_ui()


func setup(world: Node2D, intel_store: Object) -> void:
	_world_ref   = world
	_intel_store = intel_store


## Show the panel populated with the given NPC's info.
func show_npc(npc: Node2D) -> void:
	if npc == null or not is_instance_valid(npc):
		hide_panel()
		return
	_current_npc = npc
	_refresh()
	if not visible:
		visible = true
		_panel.modulate.a = 0.0
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)


## Hide the panel and clear selection.
func hide_panel() -> void:
	if not visible:
		return
	_current_npc = null
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.14)
	_tween.tween_callback(func() -> void: visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_npc == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_trigger_action("eavesdrop")
				get_viewport().set_input_as_handled()
			KEY_2:
				_trigger_action("bribe")
				get_viewport().set_input_as_handled()
			KEY_3:
				_trigger_action("seed")
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				hide_panel()
				get_viewport().set_input_as_handled()


# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left   = 1.0
	_panel.anchor_right  = 1.0
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -260.0
	_panel.offset_right  = -8.0
	_panel.offset_top    = -200.0
	_panel.offset_bottom =  200.0
	_panel.mouse_filter  = Control.MOUSE_FILTER_PASS

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.set_border_width_all(1)
	style.border_color = C_BORDER
	style.set_corner_radius_all(5)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Close hint row.
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var close_hint := Label.new()
	close_hint.text = "[Esc] Close"
	close_hint.add_theme_font_size_override("font_size", 10)
	close_hint.add_theme_color_override("font_color", C_MUTED)
	close_row.add_child(close_hint)
	vbox.add_child(close_row)

	# Name.
	_name_lbl = Label.new()
	_name_lbl.text = ""
	_name_lbl.add_theme_font_size_override("font_size", 17)
	_name_lbl.add_theme_color_override("font_color", C_TITLE)
	_name_lbl.add_theme_constant_override("outline_size", 1)
	_name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	vbox.add_child(_name_lbl)

	# Role.
	_role_lbl = Label.new()
	_role_lbl.text = ""
	_role_lbl.add_theme_font_size_override("font_size", 12)
	_role_lbl.add_theme_color_override("font_color", C_LABEL)
	vbox.add_child(_role_lbl)

	# Separator.
	vbox.add_child(_make_separator())

	# Location row.
	var loc_row := HBoxContainer.new()
	var loc_title := Label.new()
	loc_title.text = "Location: "
	loc_title.add_theme_font_size_override("font_size", 12)
	loc_title.add_theme_color_override("font_color", C_MUTED)
	_location_lbl = Label.new()
	_location_lbl.add_theme_font_size_override("font_size", 12)
	_location_lbl.add_theme_color_override("font_color", C_LABEL)
	loc_row.add_child(loc_title)
	loc_row.add_child(_location_lbl)
	vbox.add_child(loc_row)

	# Belief row.
	var belief_row := HBoxContainer.new()
	var belief_title := Label.new()
	belief_title.text = "Belief: "
	belief_title.add_theme_font_size_override("font_size", 12)
	belief_title.add_theme_color_override("font_color", C_MUTED)
	_belief_lbl = Label.new()
	_belief_lbl.add_theme_font_size_override("font_size", 12)
	belief_row.add_child(belief_title)
	belief_row.add_child(_belief_lbl)
	vbox.add_child(belief_row)

	# Last interaction row.
	var last_row := HBoxContainer.new()
	var last_title := Label.new()
	last_title.text = "Last seen: "
	last_title.add_theme_font_size_override("font_size", 12)
	last_title.add_theme_color_override("font_color", C_MUTED)
	_last_int_lbl = Label.new()
	_last_int_lbl.add_theme_font_size_override("font_size", 12)
	_last_int_lbl.add_theme_color_override("font_color", C_LABEL)
	_last_int_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_int_lbl.custom_minimum_size = Vector2(120, 0)
	last_row.add_child(last_title)
	last_row.add_child(_last_int_lbl)
	vbox.add_child(last_row)

	# Separator.
	vbox.add_child(_make_separator())

	# Actions header.
	var actions_hdr := Label.new()
	actions_hdr.text = "Quick Actions"
	actions_hdr.add_theme_font_size_override("font_size", 12)
	actions_hdr.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(actions_hdr)

	# Action buttons (1–3).
	_action_btns.clear()
	for action in ACTIONS:
		var btn := _make_action_button(action["shortcut"], action["label"], action["desc"])
		var ak: String = action["key"]
		btn.pressed.connect(func() -> void: _trigger_action(ak))
		vbox.add_child(btn)
		_action_btns.append(btn)


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.4)
	s.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", s)
	return sep


func _make_action_button(shortcut: String, label: String, desc: String) -> Button:
	var btn := Button.new()
	btn.text = "[%s] %s" % [shortcut, label]
	btn.tooltip_text = desc
	btn.alignment    = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(220, 28)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_ACTION)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.09, 0.06, 0.7)
	normal.set_border_width_all(1)
	normal.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.5)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.18, 0.08, 0.95)
	hover.set_border_width_all(1)
	hover.border_color = C_BORDER
	hover.set_corner_radius_all(3)
	hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.25, 0.18, 0.08, 0.95)
	focus.set_border_width_all(2)
	focus.border_color = Color(1.0, 0.9, 0.4, 1.0)
	focus.set_corner_radius_all(3)
	focus.set_content_margin_all(4)
	btn.add_theme_stylebox_override("focus", focus)

	return btn


# ── Data Refresh ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _current_npc == null or not is_instance_valid(_current_npc):
		return
	var data: Dictionary = _current_npc.get("npc_data") if _current_npc.get("npc_data") != null else {}

	# Name.
	var npc_name: String = data.get("name", "Unknown")
	_name_lbl.text = npc_name

	# Role / faction.
	var role:    String = data.get("role", "")
	var faction: String = data.get("faction", "")
	var role_text: String = role if not role.is_empty() else faction.capitalize()
	var faction_color: Color = C_FACTION.get(faction, C_LABEL)
	_role_lbl.text = role_text
	_role_lbl.add_theme_color_override("font_color", faction_color)

	# Location.
	var loc_code: String = _current_npc.get("current_location_code") if _current_npc.get("current_location_code") != null else ""
	_location_lbl.text = loc_code.replace("_", " ").capitalize() if not loc_code.is_empty() else "Unknown"

	# Belief state.
	var state_int: int = 0
	if _current_npc.has_method("get_worst_rumor_state"):
		state_int = int(_current_npc.get_worst_rumor_state())
	var icon: String = BELIEF_ICON.get(state_int, "○")
	var state_name: String = BELIEF_LABEL.get(state_int, "Unaware")
	_belief_lbl.text = "%s %s" % [icon, state_name]
	_belief_lbl.add_theme_color_override("font_color", C_BELIEF.get(state_int, C_LABEL))

	# Last known interaction from intel store.
	var last_text: String = _get_last_interaction(data.get("id", ""))
	_last_int_lbl.text = last_text

	# Update action button availability.
	_refresh_action_states(data)


func _get_last_interaction(npc_id: String) -> String:
	if _intel_store == null or npc_id.is_empty():
		return "No data"
	# Check observations.
	if _intel_store.has_method("get_observations"):
		var obs: Array = _intel_store.get_observations()
		for entry in obs:
			if entry.get("npc_id", "") == npc_id or entry.get("location_id", "") != "":
				return "Observed at %s" % entry.get("location_id", "unknown").replace("_", " ").capitalize()
	# Check eavesdrop.
	if "eavesdrop_log" in _intel_store:
		var log: Array = _intel_store.eavesdrop_log
		for entry in log:
			if entry.get("npc_a", "") == npc_id or entry.get("npc_b", "") == npc_id:
				return "Eavesdropped (tick %d)" % entry.get("tick", 0)
	return "No prior contact"


func _refresh_action_states(data: Dictionary) -> void:
	if _intel_store == null:
		return
	var actions_left: int = 0
	var whispers_left: int = 0
	var bribes_left: int = 0
	if "recon_actions_remaining" in _intel_store:
		actions_left = _intel_store.recon_actions_remaining
	if "whisper_tokens_remaining" in _intel_store:
		whispers_left = _intel_store.whisper_tokens_remaining
	if "bribe_charges" in _intel_store:
		bribes_left = _intel_store.bribe_charges

	var avail := [actions_left > 0, bribes_left > 0, whispers_left > 0]
	for i in _action_btns.size():
		var btn: Button = _action_btns[i]
		if i < avail.size() and not avail[i]:
			btn.add_theme_color_override("font_color", C_MUTED)
			btn.tooltip_text += " (none remaining)"
		else:
			btn.add_theme_color_override("font_color", C_ACTION)


func _trigger_action(action_key: String) -> void:
	if _current_npc == null or not is_instance_valid(_current_npc):
		return
	AudioManager.play_sfx("ui_click")
	action_requested.emit(action_key, _current_npc)

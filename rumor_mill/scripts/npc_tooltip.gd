extends CanvasLayer

## npc_tooltip.gd — Hover tooltip panel for NPCs.
##
## Displays a styled panel near the cursor showing:
##   • NPC name and faction
##   • Role / archetype
##   • Flavor text bio (from data/flavor_text.json)
##   • Current worst rumor state (colour-coded)
##   • Number of active rumor slots
##
## Add as a child of Main and call setup(world) to connect NPC hover signals.

const C_BG      := Color(0.10, 0.07, 0.05, 0.93)
const C_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE   := Color(0.92, 0.78, 0.12, 1.0)
const C_LABEL   := Color(0.82, 0.75, 0.60, 1.0)
const C_MUTED   := Color(0.60, 0.52, 0.40, 1.0)

const FADE_IN_SEC  := 0.12
const FADE_OUT_SEC := 0.10

# Faction display names and accent colours
const FACTION_LABEL := {
	"merchant": "Merchant",
	"noble":    "Noble",
	"clergy":   "Clergy",
}
const FACTION_COLOR := {
	"merchant": Color(0.92, 0.75, 0.18, 1.0),
	"noble":    Color(0.55, 0.65, 1.00, 1.0),
	"clergy":   Color(0.85, 0.85, 0.85, 1.0),
}

# Rumor state display labels and colours (matches Rumor.RumorState enum order)
const STATE_LABEL := {
	0: "Unaware",
	1: "Evaluating",
	2: "Believes",
	3: "Spreading",
	4: "Acting",
	5: "Rejecting",
	6: "Contradicted",
	7: "Expired",
	8: "Defending",
}
const STATE_COLOR := {
	0: Color(0.65, 0.65, 0.65, 1.0),
	1: Color(1.00, 1.00, 0.45, 1.0),
	2: Color(0.50, 1.00, 0.55, 1.0),
	3: Color(1.00, 0.70, 0.30, 1.0),
	4: Color(1.00, 0.45, 0.90, 1.0),
	5: Color(0.70, 0.70, 0.85, 1.0),
	6: Color(0.80, 0.55, 1.00, 1.0),
	7: Color(0.55, 0.55, 0.55, 1.0),
	8: Color(0.45, 0.80, 1.00, 1.0),
}

const OFFSET := Vector2(18, -140)  # screen offset from cursor
const PANEL_W := 240
const PANEL_H := 165

var _panel:        PanelContainer = null
var _name_lbl:     Label          = null
var _faction_lbl:  Label          = null
var _role_lbl:     Label          = null
var _bio_lbl:      Label          = null
var _state_lbl:    Label          = null
var _rumor_lbl:    Label          = null

var _visible_flag: bool = false
var _fade_tween:   Tween = null
var _flavor_text:  Dictionary = {}


func _ready() -> void:
	layer = 9   # above social graph (8), below journal (12)
	_load_flavor_text()
	_build_panel()


func _load_flavor_text() -> void:
	var file := FileAccess.open("res://data/flavor_text.json", FileAccess.READ)
	if file == null:
		push_warning("NpcTooltip: flavor_text.json not found — bios disabled")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_flavor_text = parsed


func setup(world: Node2D) -> void:
	# Connect hover signals from every NPC in the world.
	var container: Node2D = world.get_node_or_null("NPCContainer")
	if container == null:
		push_warning("NpcTooltip: NPCContainer not found — hover disabled")
		return
	for npc in container.get_children():
		if npc.has_signal("npc_hovered"):
			npc.npc_hovered.connect(_on_npc_hovered)
		if npc.has_signal("npc_unhovered"):
			npc.npc_unhovered.connect(_on_npc_unhovered)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_npc_hovered(npc: Node2D) -> void:
	_populate(npc)
	_visible_flag = true
	_fade_to(1.0)


func _on_npc_unhovered() -> void:
	_visible_flag = false
	_fade_to(0.0)


func _fade_to(target_alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if target_alpha > 0.0:
		_panel.visible = true
	_fade_tween = create_tween()
	var duration := FADE_IN_SEC if target_alpha > 0.0 else FADE_OUT_SEC
	_fade_tween.tween_property(_panel, "modulate:a", target_alpha, duration)
	if target_alpha == 0.0:
		_fade_tween.tween_callback(func() -> void: _panel.visible = false)


# ── Per-frame: keep panel near cursor ────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _visible_flag:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var target_x: float = mouse_pos.x + OFFSET.x
	var target_y: float = mouse_pos.y + OFFSET.y
	# Clamp so the panel doesn't go off the right edge or top.
	# Use the panel's actual size so auto-sized content is clamped correctly.
	var panel_h: float = _panel.size.y if _panel.size.y > 0.0 else PANEL_H
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	target_x = clampf(target_x, 4.0, vp_size.x - PANEL_W - 4.0)
	target_y = clampf(target_y, 4.0, vp_size.y - panel_h - 4.0)
	_panel.set_position(Vector2(target_x, target_y))


# ── Build panel ───────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	_name_lbl = _make_label("", 14, C_TITLE)
	vbox.add_child(_name_lbl)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	_faction_lbl = _make_label("", 11, C_LABEL)
	vbox.add_child(_faction_lbl)

	_role_lbl = _make_label("", 10, C_MUTED)
	vbox.add_child(_role_lbl)

	_bio_lbl = _make_label("", 10, C_MUTED)
	_bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_lbl.custom_minimum_size = Vector2(PANEL_W - 20, 0)
	vbox.add_child(_bio_lbl)

	var sep2 := HSeparator.new()
	var sep2_style := StyleBoxFlat.new()
	sep2_style.bg_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.4)
	sep2.add_theme_stylebox_override("separator", sep2_style)
	vbox.add_child(sep2)

	_state_lbl = _make_label("", 11, C_LABEL)
	vbox.add_child(_state_lbl)

	_rumor_lbl = _make_label("", 10, C_MUTED)
	vbox.add_child(_rumor_lbl)

	_panel.modulate.a = 0.0
	_panel.visible = false
	add_child(_panel)


func _make_label(text_val: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


# ── Populate from NPC node ────────────────────────────────────────────────────

func _populate(npc: Node2D) -> void:
	var data: Dictionary = npc.npc_data if "npc_data" in npc else {}

	var npc_name:    String = data.get("name",    npc.name)
	var faction:     String = data.get("faction", "merchant")
	var role:        String = data.get("role",    "")
	var archetype:   String = data.get("archetype", "")
	var npc_id:      String = data.get("id", "")

	_name_lbl.text = npc_name

	var fac_label: String = FACTION_LABEL.get(faction, faction.capitalize())
	var fac_color: Color  = FACTION_COLOR.get(faction, C_LABEL)
	_faction_lbl.text = "Faction: " + fac_label
	_faction_lbl.add_theme_color_override("font_color", fac_color)

	var role_display: String = role
	if archetype != "" and archetype != "independent":
		role_display = role + " (" + archetype.replace("_", " ").capitalize() + ")"
	_role_lbl.text = role_display

	# Flavor text bio.
	var bios: Dictionary = _flavor_text.get("npc_bios", {})
	_bio_lbl.text = bios.get(npc_id, "")
	_bio_lbl.visible = not _bio_lbl.text.is_empty()

	# Determine worst rumor state.
	var worst_state_int: int = 0   # UNAWARE
	if "rumor_slots" in npc:
		for slot in npc.rumor_slots.values():
			var s: int = int(slot.state) if "state" in slot else 0
			if s > worst_state_int:
				worst_state_int = s

	var state_name:  String = STATE_LABEL.get(worst_state_int, "Unknown")
	var state_color: Color  = STATE_COLOR.get(worst_state_int, C_LABEL)
	_state_lbl.text = "State: " + state_name
	_state_lbl.add_theme_color_override("font_color", state_color)

	var rumor_count: int = npc.rumor_slots.size() if "rumor_slots" in npc else 0
	_rumor_lbl.text = "%d active rumor%s" % [rumor_count, "s" if rumor_count != 1 else ""]

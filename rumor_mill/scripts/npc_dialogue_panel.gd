extends Node

## npc_dialogue_panel.gd — SPA-683: NPC conversation panel.
##
## Replaces direct right-click → eavesdrop with a small dialogue card that
## shows the NPC's identity and offers explicit action choices:
##   Eavesdrop  |  Seed Rumor  |  Bribe (conditional)  |  Leave
##
## Created programmatically by main.gd via:
##   var dlg = preload("res://scripts/npc_dialogue_panel.gd").new()
##   dlg.setup(world, intel_store, rumor_panel_ref)
##   add_child(dlg)
##   recon_ctrl.set_dialogue_panel(dlg)
##
## The panel renders on CanvasLayer 11 (above the hover tooltip at layer 10
## but below the RumorPanel at layer 15).

## Emitted when the player chooses Eavesdrop.
signal eavesdrop_requested(npc: Node2D)

## Emitted when the player chooses Bribe.
signal bribe_requested(npc: Node2D)

## Emitted when the player clicks Seed Rumor.
signal seed_rumor_requested

## Emitted when the panel is dismissed (Leave or click-away).
signal dismissed

# ── Colour palette — matches recon_controller / rumor_panel parchment theme ──
const C_BG          := Color(0.09, 0.06, 0.04, 0.96)
const C_BORDER      := Color(0.55, 0.38, 0.18, 1.0)
const C_BORDER_MID  := Color(0.17, 0.13, 0.09, 0.47)  # INK at ~120/255 — secondary frame
const C_BORDER_INNER := Color(0.60, 0.47, 0.31, 0.80)  # PARCH_D at 80% — tertiary rule
const C_HEADER_BG   := Color(0.14, 0.10, 0.06, 1.0)
const C_NAME        := Color(0.92, 0.82, 0.58, 1.0)
const C_ROLE        := Color(0.68, 0.60, 0.42, 1.0)
const C_GREETING    := Color(0.82, 0.78, 0.62, 1.0)
const C_BTN_BG      := Color(0.22, 0.15, 0.07, 1.0)
const C_BTN_HOVER   := Color(0.38, 0.26, 0.10, 1.0)
const C_BTN_PRESSED := Color(0.30, 0.20, 0.08, 1.0)
const C_BTN_TEXT    := Color(0.92, 0.82, 0.60, 1.0)
const C_BTN_DISABLE := Color(0.42, 0.38, 0.28, 1.0)
const C_LEAVE_TEXT  := Color(0.58, 0.52, 0.38, 1.0)

const C_FACTION_MERCHANT := Color(1.00, 0.80, 0.20, 1.0)
const C_FACTION_NOBLE    := Color(0.40, 0.60, 1.00, 1.0)
const C_FACTION_CLERGY   := Color(0.90, 0.90, 0.90, 1.0)

# Faction-tinted drape backgrounds (from ART_STYLE_GUIDE — alpha 0→50).
const C_DRAPE_MERCHANT := Color(0.133, 0.220, 0.392, 0.20)  # deep blue
const C_DRAPE_NOBLE    := Color(0.275, 0.055, 0.125, 0.20)  # dark crimson
const C_DRAPE_CLERGY   := Color(0.765, 0.737, 0.675, 0.20)  # warm cream
const C_DRAPE_DEFAULT  := Color(0.243, 0.227, 0.188, 0.20)  # slate

# Panel dimensions.
const PANEL_W      := 260.0
const PORTRAIT_W   := 56.0
const PORTRAIT_H   := 70.0   # scaled from 64×80 atlas cell
const PORTRAIT_COLS := 6     # columns in ui_npc_portraits.png

# Fallback greeting lines keyed by faction, used when npc_dialogue.json has
# no entry for the NPC or has no ambient lines.
const FALLBACK_GREETINGS := {
	"merchant": [
		"Good day. What can I do for you?",
		"I'm a busy person. Make it quick.",
		"Every deal starts with a word.",
	],
	"noble": [
		"You have my attention. Briefly.",
		"State your business.",
		"I trust this is worth my time.",
	],
	"clergy": [
		"Peace be with you, traveller.",
		"Speak plainly. The truth needs no ornament.",
		"I am listening.",
	],
}
const FALLBACK_DEFAULT := ["…"]

# ── Runtime state ─────────────────────────────────────────────────────────────
var _world_ref:       Node2D           = null
var _intel_store:     PlayerIntelStore = null
var _rumor_panel_ref: CanvasLayer      = null   # toggled on Seed Rumor

var _dialogue_data:   Dictionary       = {}     # npc_id → ambient lines
var _portrait_tex:    Texture2D        = null

# Canvas layer and built panel.
var _canvas:  CanvasLayer = null
var _panel:   Panel       = null
var _current_npc: Node2D  = null


func setup(world: Node2D, intel_store: PlayerIntelStore, rumor_panel: CanvasLayer) -> void:
	_world_ref       = world
	_intel_store     = intel_store
	_rumor_panel_ref = rumor_panel
	_load_resources()
	_build_canvas()


func _load_resources() -> void:
	# Portrait atlas.
	_portrait_tex = load("res://assets/textures/ui_npc_portraits.png")

	# NPC ambient dialogue for greeting lines.
	var f := FileAccess.open("res://data/npc_dialogue.json", FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("npc_dialogue"):
		_dialogue_data = parsed["npc_dialogue"]


func _build_canvas() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 11
	_canvas.name  = "NpcDialogueCanvas"
	add_child(_canvas)

	_panel         = Panel.new()
	_panel.visible = false
	_panel.name    = "NpcDialoguePanel"
	_canvas.add_child(_panel)

	# Catch click-away (left-click outside panel).
	_canvas.set_process_input(true)


func _input(event: InputEvent) -> void:
	if _panel == null or not _panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		# Dismiss if click lands outside the panel rect.
		var local := _panel.get_global_rect()
		if not local.has_point(event.position):
			_dismiss()
			get_viewport().set_input_as_handled()


# ── Public API ────────────────────────────────────────────────────────────────

## Show the conversation panel for the given NPC, positioned near screen_pos.
func show_for_npc(npc: Node2D, screen_pos: Vector2) -> void:
	_current_npc = npc
	_rebuild_panel(npc)

	# Position: offset right of cursor, clamped to viewport.
	var vp_size := get_viewport().get_visible_rect().size
	var pos     := screen_pos + Vector2(12.0, -80.0)
	var sz      := _panel.size
	pos.x = clampf(pos.x, 4.0, vp_size.x - sz.x - 4.0)
	pos.y = clampf(pos.y, 4.0, vp_size.y - sz.y - 4.0)
	_panel.position = pos
	_panel.visible  = true


## Hide the panel without emitting dismissed.
func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false
	_current_npc = null


# ── Panel construction ────────────────────────────────────────────────────────

func _rebuild_panel(npc: Node2D) -> void:
	# Clear previous children.
	for child in _panel.get_children():
		child.queue_free()

	var npc_data:  Dictionary = npc.npc_data
	var npc_id:    String     = npc_data.get("id",      "")
	var npc_name:  String     = npc_data.get("name",    "?")
	var npc_role:  String     = npc_data.get("role",    "")
	var faction:   String     = npc_data.get("faction", "")
	var portrait_id: int      = npc_data.get("portrait_id", 0)

	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)

	# Triple-line border matching parchment 9-slice (ART_STYLE_GUIDE Art Pass 13).
	# Outer rule: INK at 100% (heavy, 2px).
	for side in ["top", "bottom", "left", "right"]:
		var rule := ColorRect.new()
		rule.color = C_BORDER
		rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		match side:
			"top":
				rule.anchor_bottom = 0.0
				rule.offset_bottom = 2.0
			"bottom":
				rule.anchor_top = 1.0
				rule.offset_top = -2.0
			"left":
				rule.anchor_right = 0.0
				rule.offset_right = 2.0
			"right":
				rule.anchor_left = 1.0
				rule.offset_left = -2.0
		_panel.add_child(rule)

	# Middle rule: INK at 120/255 (secondary frame, 2px inset).
	for side in ["top", "bottom", "left", "right"]:
		var rule := ColorRect.new()
		rule.color = C_BORDER_MID
		rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		match side:
			"top":
				rule.anchor_bottom = 0.0
				rule.offset_top = 3.0
				rule.offset_bottom = 4.0
			"bottom":
				rule.anchor_top = 1.0
				rule.offset_top = -4.0
				rule.offset_bottom = -3.0
			"left":
				rule.anchor_right = 0.0
				rule.offset_left = 3.0
				rule.offset_right = 4.0
			"right":
				rule.anchor_left = 1.0
				rule.offset_left = -4.0
				rule.offset_right = -3.0
		_panel.add_child(rule)

	# Inner rule: PARCH_D at 80% (tertiary rule, 4px inset).
	for side in ["top", "bottom", "left", "right"]:
		var rule := ColorRect.new()
		rule.color = C_BORDER_INNER
		rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		match side:
			"top":
				rule.anchor_bottom = 0.0
				rule.offset_top = 5.0
				rule.offset_bottom = 6.0
			"bottom":
				rule.anchor_top = 1.0
				rule.offset_top = -6.0
				rule.offset_bottom = -5.0
			"left":
				rule.anchor_right = 0.0
				rule.offset_left = 5.0
				rule.offset_right = 6.0
			"right":
				rule.anchor_left = 1.0
				rule.offset_left = -6.0
				rule.offset_right = -5.0
		_panel.add_child(rule)

	# Faction stripe: 1px accent colour at 90% across top interior.
	var faction_stripe := ColorRect.new()
	faction_stripe.color = Color(_faction_colour(faction).r, _faction_colour(faction).g, _faction_colour(faction).b, 0.90)
	faction_stripe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faction_stripe.anchor_bottom = 0.0
	faction_stripe.offset_top = 6.0
	faction_stripe.offset_bottom = 7.0
	faction_stripe.offset_left = 6.0
	faction_stripe.offset_right = -6.0
	_panel.add_child(faction_stripe)

	# ── Content VBox ──────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 8.0
	vbox.offset_top    = 10.0
	vbox.offset_right  = -8.0
	vbox.offset_bottom = -8.0
	vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(vbox)

	# ── Header row: portrait + identity ──────────────────────────────────────
	# Faction-tinted drape background behind the header area.
	var header_bg := ColorRect.new()
	header_bg.color = _faction_drape_colour(faction)
	header_bg.custom_minimum_size = Vector2(0.0, PORTRAIT_H + 4.0)
	header_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header_bg)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.offset_left = 4.0
	header.offset_top = 2.0
	header.offset_right = -4.0
	header.offset_bottom = -2.0
	header_bg.add_child(header)

	# Portrait with triple-line frame.
	if _portrait_tex != null:
		var port_frame := Panel.new()
		port_frame.custom_minimum_size = Vector2(PORTRAIT_W + 6.0, PORTRAIT_H + 6.0)
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = C_HEADER_BG
		frame_style.set_border_width_all(2)
		frame_style.border_color = C_BORDER
		frame_style.set_content_margin_all(3.0)
		port_frame.add_theme_stylebox_override("panel", frame_style)
		header.add_child(port_frame)

		var port := TextureRect.new()
		port.custom_minimum_size = Vector2(PORTRAIT_W, PORTRAIT_H)
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var col: int = portrait_id % PORTRAIT_COLS
		var row: int = portrait_id / PORTRAIT_COLS
		port.texture = _make_portrait_texture(col, row)
		port.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		port.offset_left = 3.0
		port.offset_top = 3.0
		port.offset_right = -3.0
		port.offset_bottom = -3.0
		port_frame.add_child(port)

	# Name / role / faction column.
	var id_col := VBoxContainer.new()
	id_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_col.add_theme_constant_override("separation", 2)
	header.add_child(id_col)

	var name_lbl := Label.new()
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", C_NAME)
	name_lbl.add_theme_constant_override("outline_size", 1)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	id_col.add_child(name_lbl)

	if not npc_role.is_empty():
		var role_lbl := Label.new()
		role_lbl.text = npc_role
		role_lbl.add_theme_font_size_override("font_size", 11)
		role_lbl.add_theme_color_override("font_color", C_ROLE)
		id_col.add_child(role_lbl)

	if not faction.is_empty():
		var fac_lbl := Label.new()
		fac_lbl.text = faction.capitalize()
		fac_lbl.add_theme_font_size_override("font_size", 11)
		fac_lbl.add_theme_color_override("font_color", _faction_colour(faction))
		fac_lbl.add_theme_constant_override("outline_size", 1)
		fac_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
		id_col.add_child(fac_lbl)

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.45)
	div.custom_minimum_size = Vector2(0.0, 1.0)
	vbox.add_child(div)

	# ── Greeting line ─────────────────────────────────────────────────────────
	var greeting_lbl := Label.new()
	greeting_lbl.text = '"%s"' % _pick_greeting(npc_id, faction)
	greeting_lbl.add_theme_font_size_override("font_size", 11)
	greeting_lbl.add_theme_color_override("font_color", C_GREETING)
	greeting_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greeting_lbl.custom_minimum_size = Vector2(PANEL_W - 20.0, 0.0)
	vbox.add_child(greeting_lbl)

	# ── Second divider ────────────────────────────────────────────────────────
	var div2 := ColorRect.new()
	div2.color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.30)
	div2.custom_minimum_size = Vector2(0.0, 1.0)
	vbox.add_child(div2)

	# ── Action buttons ────────────────────────────────────────────────────────
	var has_partner := _find_conversation_partner(npc) != null
	var can_eavesdrop := _intel_store.recon_actions_remaining > 0

	var eavesdrop_btn := _make_button(
		"Eavesdrop" + ("" if has_partner else "  (no partner nearby)"),
		can_eavesdrop and has_partner
	)
	eavesdrop_btn.pressed.connect(_on_eavesdrop_pressed)
	vbox.add_child(eavesdrop_btn)

	var seed_btn := _make_button("Seed Rumor", true)
	seed_btn.pressed.connect(_on_seed_rumor_pressed)
	vbox.add_child(seed_btn)

	# Bribe: only shown when NPC is EVALUATING and resources allow.
	var show_bribe: bool = _intel_store.bribe_charges > 0 \
		and npc.get_worst_rumor_state() == Rumor.RumorState.EVALUATING
	if show_bribe:
		var can_bribe: bool = _intel_store.recon_actions_remaining > 0 and _intel_store.whisper_tokens_remaining > 0
		var bribe_btn := _make_button(
			"Bribe  (1 Recon + 1 Token)" if can_bribe else "Bribe  — Insufficient resources",
			can_bribe
		)
		bribe_btn.pressed.connect(_on_bribe_pressed)
		vbox.add_child(bribe_btn)

	var leave_btn := _make_button("Leave", true, true)
	leave_btn.pressed.connect(_dismiss)
	vbox.add_child(leave_btn)

	# ── Resize panel to fit content ───────────────────────────────────────────
	_panel.size = Vector2(PANEL_W, 0.0)
	await get_tree().process_frame
	_panel.size = Vector2(PANEL_W, vbox.get_minimum_size().y + 20.0)


# ── Button factory ────────────────────────────────────────────────────────────

func _make_button(label: String, enabled: bool, is_leave: bool = false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.disabled = not enabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override(
		"font_color",
		C_LEAVE_TEXT if is_leave else (C_BTN_TEXT if enabled else C_BTN_DISABLE)
	)
	btn.add_theme_color_override(
		"font_hover_color",
		Color(0.70, 0.62, 0.45, 1.0) if is_leave else Color(1.0, 0.92, 0.70, 1.0)
	)
	btn.add_theme_color_override(
		"font_pressed_color",
		Color(0.50, 0.44, 0.32, 1.0) if is_leave else Color(0.85, 0.75, 0.50, 1.0)
	)

	# Normal state.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = C_BTN_BG if not is_leave else Color(0, 0, 0, 0)
	style_normal.set_content_margin_all(5.0)
	if not is_leave:
		style_normal.set_border_width_all(1)
		style_normal.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.30)
		style_normal.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", style_normal)

	# Hover state — brighter border, slight BG lift.
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = C_BTN_HOVER if not is_leave else Color(0.15, 0.10, 0.05, 0.5)
	style_hover.set_content_margin_all(5.0)
	if not is_leave:
		style_hover.set_border_width_all(1)
		style_hover.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.70)
		style_hover.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Pressed state — darker BG, inset feel via adjusted margins.
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = C_BTN_PRESSED if not is_leave else Color(0.10, 0.07, 0.03, 0.6)
	style_pressed.set_content_margin_all(5.0)
	style_pressed.content_margin_top = 6.0
	style_pressed.content_margin_bottom = 4.0
	if not is_leave:
		style_pressed.set_border_width_all(1)
		style_pressed.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.50)
		style_pressed.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# Disabled state — muted, no border accent.
	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.12, 0.09, 0.06, 0.6)
	style_disabled.set_content_margin_all(5.0)
	style_disabled.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("disabled", style_disabled)

	return btn


# ── Portrait helper ───────────────────────────────────────────────────────────

## Crop the portrait atlas to the cell for (col, row) and return an AtlasTexture.
func _make_portrait_texture(col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _portrait_tex
	at.region = Rect2(
		float(col) * 64.0, float(row) * 80.0,
		64.0, 80.0
	)
	return at


# ── Greeting picker ───────────────────────────────────────────────────────────

func _pick_greeting(npc_id: String, faction: String) -> String:
	# Prefer the NPC's own ambient lines from npc_dialogue.json.
	if _dialogue_data.has(npc_id):
		var ambient = _dialogue_data[npc_id].get("ambient", [])
		if ambient.size() > 0:
			return ambient[randi() % ambient.size()]

	# Fall back to faction-generic lines.
	var lines: Array = FALLBACK_GREETINGS.get(faction, FALLBACK_DEFAULT)
	return lines[randi() % lines.size()]


# ── Conversation partner check (mirrors recon_controller) ─────────────────────

const _EAVESDROP_RANGE := 3

func _find_conversation_partner(target: Node2D) -> Node2D:
	if _world_ref == null:
		return null
	for npc in _world_ref.npcs:
		if npc == target:
			continue
		var d: float = (npc.current_cell - target.current_cell).length()
		if d <= _EAVESDROP_RANGE:
			return npc
	return null


# ── Faction colour ────────────────────────────────────────────────────────────

func _faction_colour(faction: String) -> Color:
	match faction:
		"merchant": return C_FACTION_MERCHANT
		"noble":    return C_FACTION_NOBLE
		"clergy":   return C_FACTION_CLERGY
	return Color(0.75, 0.70, 0.55, 1.0)


func _faction_drape_colour(faction: String) -> Color:
	match faction:
		"merchant": return C_DRAPE_MERCHANT
		"noble":    return C_DRAPE_NOBLE
		"clergy":   return C_DRAPE_CLERGY
	return C_DRAPE_DEFAULT


# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_eavesdrop_pressed() -> void:
	var npc := _current_npc
	_dismiss()
	if npc != null and is_instance_valid(npc):
		eavesdrop_requested.emit(npc)


func _on_bribe_pressed() -> void:
	var npc := _current_npc
	_dismiss()
	if npc != null and is_instance_valid(npc):
		bribe_requested.emit(npc)


func _on_seed_rumor_pressed() -> void:
	_dismiss()
	seed_rumor_requested.emit()


func _dismiss() -> void:
	if _panel != null:
		_panel.visible = false
	_current_npc = null
	dismissed.emit()

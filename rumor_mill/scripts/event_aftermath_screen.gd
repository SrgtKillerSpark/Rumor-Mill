extends CanvasLayer

## event_aftermath_screen.gd — SPA-2699: Spec-aligned post-event resolution summary.
##
## Displayed immediately after the player resolves a mid-game narrative event.
## Shows:
##   - "IT IS DONE" header (per spec)
##   - Event name
##   - Outcome narrative text
##   - Consequence lines with spec-defined icons and colours:
##       ^ stat increase (forest green)
##       v stat decrease (rust red)
##       > NPC state change (dark brown)
##       + item gained (gold)
##       - item spent (muted)
##   - "Continue" button (Space/Enter) to resume the game
##
## Usage from UILayerManager:
##   var aftermath := preload("res://scripts/event_aftermath_screen.gd").new()
##   aftermath.name = "EventAftermathScreen"
##   add_child(aftermath)
##   # After event_choice_modal.dismissed fires:
##   aftermath.present(event_name, outcome_text, effects_dict, world)

# ── Palette (spec-aligned: parchment + sepia tones) ──────────────────────────

const C_BACKDROP  := Color(0.02, 0.01, 0.00, 0.78)
const C_PANEL_BG  := Color(0.08, 0.05, 0.02, 0.97)
const C_BORDER    := Color(0.60, 0.40, 0.12, 1.0)
# Spec consequence icon colours:
const C_HEADER    := Color(0.231, 0.153, 0.071, 1.0) # #3B2712 dark-brown "IT IS DONE"
const C_HEADING   := Color(0.231, 0.153, 0.071, 1.0) # dark-brown event title
const C_BODY      := Color(0.231, 0.153, 0.071, 0.90) # body text
const C_STAT_UP   := Color(0.176, 0.416, 0.310, 1.0) # #2D6A4F forest green (^ stat increase)
const C_STAT_DOWN := Color(0.545, 0.227, 0.180, 1.0) # #8B3A2E rust red     (v stat decrease)
const C_NPC_CHG   := Color(0.231, 0.153, 0.071, 1.0) # #3B2712 dark-brown  (> NPC state)
const C_ITEM_GAIN := Color(0.722, 0.525, 0.043, 1.0) # #B8860B gold         (+ item gained)
const C_ITEM_COST := Color(0.478, 0.420, 0.365, 1.0) # #7A6B5D muted        (- item spent)
const C_NEUTRAL   := Color(0.478, 0.420, 0.365, 1.0) # muted fallback
const C_BTN_BG    := Color(0.30, 0.18, 0.05, 0.90)
const C_BTN_HOVER := Color(0.722, 0.525, 0.043, 1.0) # gold accent on hover (spec)
const C_BTN_TEXT  := Color(0.92, 0.82, 0.60, 1.0)

const PANEL_W     := 560.0
const PANEL_H     := 440.0
const REVEAL_TIME := 0.3

## Emitted when the player dismisses the aftermath and the game should resume.
signal aftermath_dismissed()

# ── Node refs ─────────────────────────────────────────────────────────────────

var _backdrop:      ColorRect      = null
var _panel:         Panel          = null
var _title_lbl:     Label          = null
var _outcome_lbl:   RichTextLabel  = null
var _deltas_lbl:    RichTextLabel  = null
var _continue_btn:  Button         = null

# ── State ─────────────────────────────────────────────────────────────────────

var _world: Node = null
var _event_name: String = ""


func _ready() -> void:
	layer        = 22   # Above EventChoiceModal (21)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


## Present the aftermath screen after a mid-game event is resolved.
##
## event_name:   display name of the event (String)
## outcome_text: narrative outcome text (String)
## effects:      the raw effects Dictionary from scenarios.json choices
## world:        Node reference used to look up NPC names
func present(
	event_name: String,
	outcome_text: String,
	effects: Dictionary,
	world: Node
) -> void:
	_world = world
	_event_name = event_name
	_title_lbl.text = event_name

	_outcome_lbl.text = outcome_text

	var delta_lines: String = _format_effects(effects)
	if delta_lines.is_empty():
		_deltas_lbl.visible = false
	else:
		_deltas_lbl.text    = delta_lines
		_deltas_lbl.visible = true

	# Animate in.
	_backdrop.color.a = 0.0
	_panel.modulate.a = 0.0
	visible = true
	get_tree().paused = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_backdrop, "color:a", C_BACKDROP.a, REVEAL_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_panel, "modulate:a", 1.0, REVEAL_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _continue_btn.grab_focus())


# ── Effects Formatter ─────────────────────────────────────────────────────────

## Format effects dict into spec-aligned consequence lines.
## Spec consequence format per type:
##   ^ Stat increase  — forest green #2D6A4F
##   v Stat decrease  — rust red     #8B3A2E
##   > NPC state change — dark brown #3B2712
##   + Item gained    — gold         #B8860B
##   - Item spent     — muted        #7A6B5D
## Max 4 lines: NPC changes > faction stats > resource costs.
func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""

	# Build a list of consequence entries sorted by priority so we can cap at 4.
	# Priority: NPC state changes (2) > faction/stat changes (1) > resource costs (0)
	var entries: Array[Dictionary] = []

	# Reputation changes → stat delta (^ or v).
	var rep_changes: Array = effects.get("reputationChanges", [])
	for rc in rep_changes:
		var npc_id: String  = str(rc.get("npcId", ""))
		var delta: int      = int(rc.get("delta", 0))
		if delta == 0:
			continue
		var npc_name: String = _resolve_npc_name(npc_id)
		if delta > 0:
			entries.append({
				"priority": 1,
				"bbcode": "[color=#2D6A4F]^[/color] %s +%d" % [npc_name, delta],
				"causality": _causality_reputation(npc_id),
			})
		else:
			entries.append({
				"priority": 1,
				"bbcode": "[color=#8B3A2E]v[/color] %s %d" % [npc_name, delta],
				"causality": _causality_reputation(npc_id),
			})

	# Heat changes → stat delta (more heat is bad for the player).
	var heat_changes: Array = effects.get("heatChanges", [])
	for hc in heat_changes:
		var npc_id: String = str(hc.get("npcId", ""))
		var delta: int     = int(hc.get("delta", 0))
		if delta == 0:
			continue
		var npc_name: String = _resolve_npc_name(npc_id)
		if delta > 0:
			# More heat = bad
			entries.append({
				"priority": 1,
				"bbcode": "[color=#8B3A2E]v[/color] Suspicion +%d — %s" % [delta, npc_name],
				"causality": _causality_heat(npc_id),
			})
		else:
			entries.append({
				"priority": 1,
				"bbcode": "[color=#2D6A4F]^[/color] Suspicion %d — %s" % [delta, npc_name],
				"causality": _causality_heat(npc_id),
			})

	# Heat ceiling override → stat note.
	var hco: Dictionary = effects.get("heatCeilingOverride", {})
	if not hco.is_empty():
		var new_ceil: float = float(hco.get("newCeiling", 70))
		var dur: int        = int(hco.get("durationDays", 0))
		entries.append({
			"priority": 1,
			"bbcode": "[color=#2D6A4F]^[/color] Heat ceiling %.0f for %d day%s" % [
				new_ceil, dur, "s" if dur != 1 else ""
			],
			"causality": ("because the %s shifted public attention" % _event_name) if not _event_name.is_empty() else "",
		})

	# Instant believers → NPC state change (> priority).
	var ib: Dictionary = effects.get("instantBelievers", {})
	if not ib.is_empty():
		var count: int      = int(ib.get("count", 0))
		var subject: String = _resolve_npc_name(str(ib.get("subjectNpcId", "")))
		entries.append({
			"priority": 2,
			"bbcode": "[color=#3B2712]>[/color] %d now believe the rumour about %s" % [count, subject],
			"causality": _causality_instant_believers(ib),
		})

	# Suspicion freeze → stat improvement.
	var freeze: int = int(effects.get("suspicionFreezeDays", 0))
	if freeze > 0:
		entries.append({
			"priority": 1,
			"bbcode": "[color=#2D6A4F]^[/color] Suspicion frozen for %d day%s" % [
				freeze, "s" if freeze != 1 else ""
			],
			"causality": "",
		})

	# Ability bonuses → stat delta.
	var ability_bonuses: Array = effects.get("abilityBonuses", [])
	for ab in ability_bonuses:
		var ability: String = str(ab.get("ability", ""))
		var bonus: int      = int(ab.get("bonus", 0))
		if ability.is_empty() or bonus == 0:
			continue
		var ab_causality: String = ("because the %s changed the political balance" % _event_name) if not _event_name.is_empty() else ""
		if bonus > 0:
			entries.append({
				"priority": 1,
				"bbcode": "[color=#2D6A4F]^[/color] %s +%d" % [ability.capitalize(), bonus],
				"causality": ab_causality,
			})
		else:
			entries.append({
				"priority": 1,
				"bbcode": "[color=#8B3A2E]v[/color] %s %d" % [ability.capitalize(), bonus],
				"causality": ab_causality,
			})

	# Spec: show top 4 by magnitude; NPC state > faction stats > resource costs.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)

	var MAX_LINES := 4
	var lines: PackedStringArray = PackedStringArray()
	for i in range(min(entries.size(), MAX_LINES)):
		lines.append(str(entries[i].get("bbcode", "")))
		var causality: String = str(entries[i].get("causality", ""))
		if not causality.is_empty():
			lines.append("   [color=#7A6B5D][font_size=10]%s[/font_size][/color]" % causality)

	if entries.size() > MAX_LINES:
		lines.append("[color=#7A6B5D]...and other minor effects[/color]")

	return "\n".join(lines)


# ── Causality helpers ─────────────────────────────────────────────────────────

## Causality for a reputationChanges entry: find the rumor about npc_id with
## the most believers and report how far it spread. Returns "" when data is
## unavailable so the caller never shows "because unknown".
func _causality_reputation(npc_id: String) -> String:
	if npc_id.is_empty() or _world == null:
		return ""
	if not _world.get("propagation_engine") or _world.propagation_engine == null:
		return ""
	var best_rumor = null
	var best_count: int = 0
	var other_rumor_count: int = 0
	for rumor in _world.propagation_engine.live_rumors.values():
		if rumor.subject_npc_id != npc_id:
			continue
		var cnt: int = _count_believers_for_rumor(rumor.id)
		if cnt > best_count:
			if best_rumor != null:
				other_rumor_count += 1
			best_count = cnt
			best_rumor = rumor
		elif cnt > 0:
			other_rumor_count += 1
	if best_rumor == null or best_count == 0:
		return ""
	var claim: String = _claim_type_label(best_rumor.claim_type)
	var base: String = "because a %s rumor spread to %d NPC%s" % [claim, best_count, "s" if best_count != 1 else ""]
	if other_rumor_count > 0:
		base += " + other factors"
	return base


## Causality for a heatChanges entry: count live rumors targeting the faction
## of npc_id. Returns "" when the faction or rumor data is unavailable.
func _causality_heat(npc_id: String) -> String:
	if npc_id.is_empty() or _world == null:
		return ""
	if not _world.get("propagation_engine") or _world.propagation_engine == null:
		return ""
	var faction: String = _resolve_npc_faction(npc_id)
	if faction.is_empty():
		return ""
	# Collect IDs of NPCs in this faction.
	var faction_ids: Dictionary = {}
	for npc in _world.npcs:
		if str(npc.npc_data.get("faction", "")) == faction:
			faction_ids[str(npc.npc_data.get("id", ""))] = true
	# Count distinct live rumors whose subject is a faction member.
	var count: int = 0
	for rumor in _world.propagation_engine.live_rumors.values():
		if faction_ids.has(rumor.subject_npc_id):
			count += 1
	if count == 0:
		return ""
	return "because %d rumor%s targeted %s" % [count, "s" if count != 1 else "", faction.capitalize()]


## Causality for an instantBelievers entry: find the most-connected NPC who is
## actively spreading the relevant illness rumor and report their influence.
## Uses world.social_graph edge counts as a proxy for reach. Returns "" when
## no active spreader can be identified.
func _causality_instant_believers(ib: Dictionary) -> String:
	if _world == null:
		return ""
	if not _world.get("social_graph") or _world.social_graph == null:
		return ""
	var subject_id: String = str(ib.get("subjectNpcId", ""))
	var count: int = int(ib.get("count", 0))
	if subject_id.is_empty() or count == 0:
		return ""
	var best_name: String = ""
	var best_degree: int = -1
	for npc in _world.npcs:
		var npc_id: String = str(npc.npc_data.get("id", ""))
		if npc_id == subject_id:
			continue
		# Check if this NPC is actively spreading a rumor about subject_id.
		var spreading: bool = false
		for rid in npc.rumor_slots:
			var slot = npc.rumor_slots[rid]
			if slot.rumor != null and slot.rumor.subject_npc_id == subject_id \
					and slot.state in [Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
				spreading = true
				break
		if not spreading:
			continue
		var edges: Dictionary = _world.social_graph.edges.get(npc_id, {})
		var degree: int = edges.size()
		if degree > best_degree:
			best_degree = degree
			best_name = _resolve_npc_name(npc_id)
	if best_name.is_empty():
		return ""
	return "because %s convinced %d of their allies" % [best_name, count]


## Count NPCs currently in BELIEVE, SPREAD, or ACT state for a given rumor id.
func _count_believers_for_rumor(rumor_id: String) -> int:
	var count: int = 0
	if _world == null:
		return 0
	for npc in _world.npcs:
		if not npc.rumor_slots.has(rumor_id):
			continue
		var slot = npc.rumor_slots[rumor_id]
		if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
			count += 1
	return count


## Return the faction string for a given npc_id by scanning world.npcs.
func _resolve_npc_faction(npc_id: String) -> String:
	if _world == null or npc_id.is_empty():
		return ""
	for npc in _world.npcs:
		if str(npc.npc_data.get("id", "")) == npc_id:
			return str(npc.npc_data.get("faction", ""))
	return ""


## Human-readable label for a Rumor.ClaimType enum value.
func _claim_type_label(ct: Rumor.ClaimType) -> String:
	match ct:
		Rumor.ClaimType.ACCUSATION:        return "accusation"
		Rumor.ClaimType.SCANDAL:           return "scandal"
		Rumor.ClaimType.ILLNESS:           return "illness"
		Rumor.ClaimType.PROPHECY:          return "prophecy"
		Rumor.ClaimType.PRAISE:            return "praise"
		Rumor.ClaimType.DEATH:             return "death"
		Rumor.ClaimType.HERESY:            return "heresy"
		Rumor.ClaimType.BLACKMAIL:         return "blackmail"
		Rumor.ClaimType.SECRET_ALLIANCE:   return "secret alliance"
		Rumor.ClaimType.FORBIDDEN_ROMANCE: return "forbidden romance"
		_:                                 return "rumor"


func _resolve_npc_name(npc_id: String) -> String:
	if npc_id.is_empty():
		return "unknown"
	if _world == null:
		return npc_id
	# Try world.get_npc_by_id if available.
	if _world.has_method("get_npc_by_id"):
		var npc: Node = _world.get_npc_by_id(npc_id)
		if npc != null and npc.get("npc_data") != null:
			var disp: String = str(npc.npc_data.get("displayName", ""))
			if not disp.is_empty():
				return disp
	# Fallback: prettify the id.
	return npc_id.replace("_", " ").capitalize()


# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dim backdrop.
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = C_BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Centred parchment panel.
	_panel = Panel.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -PANEL_W * 0.5
	_panel.offset_right  =  PANEL_W * 0.5
	_panel.offset_top    = -PANEL_H * 0.5
	_panel.offset_bottom =  PANEL_H * 0.5
	_panel.mouse_filter  = Control.MOUSE_FILTER_STOP

	# Apply parchment texture if available, else dark fallback.
	var parchment_tex: Texture2D = load("res://assets/textures/ui_parchment.png") \
		if ResourceLoader.exists("res://assets/textures/ui_parchment.png") \
		else null

	if parchment_tex != null:
		# Light modulate so the parchment texture shows in its natural tan tone.
		var sb_tex := StyleBoxTexture.new()
		sb_tex.texture = parchment_tex
		sb_tex.modulate_color = Color(1.0, 1.0, 1.0, 0.97)
		sb_tex.set_content_margin_all(24)
		_panel.add_theme_stylebox_override("panel", sb_tex)
	else:
		# Fallback: parchment-tan flat style.
		var sb_flat := StyleBoxFlat.new()
		sb_flat.bg_color = Color(0.961, 0.902, 0.784, 0.97)  # #F5E6C8
		sb_flat.border_color = C_BORDER
		sb_flat.set_border_width_all(2)
		sb_flat.set_corner_radius_all(8)
		sb_flat.set_content_margin_all(24)
		_panel.add_theme_stylebox_override("panel", sb_flat)
	add_child(_panel)

	# VBox content.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 24
	vbox.offset_right  = -24
	vbox.offset_top    = 20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# Spec: "IT IS DONE" header (seal/confirmation framing).
	var badge := Label.new()
	badge.text = "IT IS DONE"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", C_HEADER)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	_add_divider(vbox)

	# Event title.
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", C_HEADING)
	_title_lbl.add_theme_constant_override("outline_size", 2)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.9))
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_lbl)

	_add_divider(vbox)

	# Outcome narrative.
	_outcome_lbl = RichTextLabel.new()
	_outcome_lbl.bbcode_enabled   = true
	_outcome_lbl.fit_content      = false
	_outcome_lbl.scroll_active    = true
	_outcome_lbl.custom_minimum_size = Vector2(0, 80)
	_outcome_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outcome_lbl.add_theme_color_override("default_color", C_BODY)
	_outcome_lbl.add_theme_font_size_override("normal_font_size", 14)
	_outcome_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_outcome_lbl)

	# Stat deltas section.
	var deltas_header := Label.new()
	deltas_header.text = "EFFECTS"
	deltas_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	deltas_header.add_theme_font_size_override("font_size", 11)
	deltas_header.add_theme_color_override("font_color", C_NEUTRAL)
	deltas_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(deltas_header)

	_deltas_lbl = RichTextLabel.new()
	_deltas_lbl.bbcode_enabled      = true
	_deltas_lbl.fit_content         = true
	_deltas_lbl.scroll_active       = false
	_deltas_lbl.custom_minimum_size = Vector2(0, 0)
	_deltas_lbl.add_theme_color_override("default_color", C_NEUTRAL)
	_deltas_lbl.add_theme_font_size_override("normal_font_size", 13)
	_deltas_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_deltas_lbl)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Continue button.
	var btn_center := CenterContainer.new()
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_center)

	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.custom_minimum_size = Vector2(160, 38)
	_continue_btn.add_theme_font_size_override("font_size", 14)
	_continue_btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = C_BTN_BG
	btn_normal.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.8)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(8)
	_continue_btn.add_theme_stylebox_override("normal",  btn_normal)
	_continue_btn.add_theme_stylebox_override("pressed", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = C_BTN_HOVER
	btn_hover.border_color = C_BORDER
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(8)
	_continue_btn.add_theme_stylebox_override("hover", btn_hover)

	_continue_btn.pressed.connect(_on_continue_pressed)
	btn_center.add_child(_continue_btn)

	# Keyboard hint.
	var hint := Label.new()
	hint.text = "or press ENTER"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.60, 0.54, 0.40, 0.55))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)


func _add_divider(parent: VBoxContainer) -> void:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 2)
	var style := StyleBoxLine.new()
	style.color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.45)
	style.thickness = 1
	div.add_theme_stylebox_override("separator", style)
	parent.add_child(div)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_on_continue_pressed()


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _on_continue_pressed() -> void:
	if AudioManager != null and AudioManager.has_method("play_ui"):
		AudioManager.play_ui("click")
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_backdrop, "color:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_panel, "modulate:a", 0.0, 0.20) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	get_tree().paused = false
	visible = false
	aftermath_dismissed.emit()

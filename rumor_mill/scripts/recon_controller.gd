extends Node

## recon_controller.gd — Sprint 3 Reconnaissance input handler.
## Sprint 9: hover highlights, cursor feedback, and interaction tooltips.
##
## Processes right-click events to trigger Observe (on buildings) and
## Eavesdrop (on NPCs in conversation) actions.
##
## Also runs _process() hover detection each frame to:
##   • Highlight the hovered NPC sprite (golden tint via NPC.set_hover).
##   • Show a floating "Right-click to…" tooltip near the cursor.
##   • Highlight the hovered building with a world-space diamond overlay.
##   • Change cursor to CURSOR_POINTING_HAND over interactable elements.
##
## Wired by main.gd after the scene tree is ready.
## setup(world, intel_store) must be called before input events arrive.

const EAVESDROP_RANGE_TILES := 3      ## Max tile distance for "in conversation"
const EAVESDROP_FAIL_CHANCE  := 0.20  ## Probability of detection when temperament > 0.7
const NPC_HIT_RADIUS_PX      := 40.0  ## World-space hit radius around NPC centre (scaled for 2x sprites)
const BUILDING_HIT_TILES     := 2     ## Grid-cell radius for location hit-test

## Highlight colour applied to a hovered NPC's modulate.
const NPC_HOVER_MODULATE  := Color(1.5, 1.3, 0.5, 1.0)
const NPC_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)

## Building highlight diamond half-extents (isometric tile = 64×32 px).
const BLDG_HALF_W := 36.0
const BLDG_HALF_H := 20.0

## Tooltip offset from the mouse cursor (screen-space pixels).
const TOOLTIP_OFFSET := Vector2(14.0, -32.0)

## Panel colours — aligned with shared palette (C_PANEL_BORDER is an exact match).
const C_PANEL_BG     := Color(0.10, 0.07, 0.05, 0.92)   ## tooltip / popup background
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)    ## border accent

## Emitted after every action attempt (success or failure).
signal action_performed(message: String, success: bool)

## Emitted when a high-temperament NPC detects the player eavesdropping.
signal player_exposed

## Emitted when the player successfully bribes an NPC (for journal logging).
signal bribe_executed(npc_name: String, tick: int)

## Emitted once the first time the player hovers over any building.
## Used by the tutorial hint system to trigger HINT-03 (hint_observe).
signal building_first_hovered

## Emitted when the player hovers an NPC that has a valid eavesdrop partner nearby.
## Used by the tutorial hint system to trigger HINT-04 (hint_eavesdrop).
signal valid_eavesdrop_hovered

var _world_ref:       Node2D           = null
var _intel_store:     PlayerIntelStore = null

# ── Hover state ───────────────────────────────────────────────────────────────
var _hovered_npc:      Node2D = null
var _hovered_location: String = ""

# ── Tutorial hint emission guards ─────────────────────────────────────────────
var _building_hover_fired:      bool = false
var _eavesdrop_hover_fired:     bool = false

# ── Hover visual nodes (created in setup) ────────────────────────────────────
var _tooltip_canvas: CanvasLayer = null
var _tooltip_panel:  Panel       = null
var _tooltip_label:  Label       = null
var _bldg_highlight: Polygon2D   = null

# ── Bribe action popup ────────────────────────────────────────────────────────
var _popup_panel: Panel  = null
var _popup_npc:   Node2D = null

# ── NPC conversation dialogue panel (SPA-683) ─────────────────────────────────
var _dialogue_panel = null   ## NpcDialoguePanel node; set via set_dialogue_panel()

# ── Building interior panels (set via set_interiors()) ────────────────────────
var _interiors: Dictionary = {}  ## location_id → BuildingInterior CanvasLayer node

## Sequence counter to safely cancel pending outdoor-ambient clear timers.
var _ambient_clear_seq: int = 0


## Register the NPC conversation dialogue panel (SPA-683).
## Called from main.gd after the panel is created and added to the tree.
func set_dialogue_panel(panel) -> void:
	_dialogue_panel = panel
	if _dialogue_panel == null:
		return
	_dialogue_panel.eavesdrop_requested.connect(_try_eavesdrop)
	_dialogue_panel.bribe_requested.connect(_try_bribe)
	_dialogue_panel.dismissed.connect(_on_dialogue_dismissed)


## Register interior panel nodes keyed by location id (e.g. "tavern", "manor", "chapel").
## Called from main.gd after the interior scenes are added to the tree.
func set_interiors(interiors: Dictionary) -> void:
	_interiors = interiors


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref   = world
	_intel_store = intel_store
	_create_hover_visuals()


# ── Hover visual setup ────────────────────────────────────────────────────────

func _create_hover_visuals() -> void:
	# Floating tooltip — rendered on a CanvasLayer so it always draws on top.
	_tooltip_canvas       = CanvasLayer.new()
	_tooltip_canvas.layer = 10
	_tooltip_canvas.name  = "HoverTooltipCanvas"
	add_child(_tooltip_canvas)

	_tooltip_panel         = Panel.new()
	_tooltip_panel.visible = false
	_tooltip_canvas.add_child(_tooltip_panel)

	var bg       := ColorRect.new()
	bg.color      = C_PANEL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_panel.add_child(bg)

	var border := ColorRect.new()
	border.color = C_PANEL_BORDER
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.offset_left   = 0.0
	border.offset_top    = 0.0
	border.offset_right  = 0.0
	border.offset_bottom = 2.0
	border.anchor_bottom = 0.0
	_tooltip_panel.add_child(border)

	_tooltip_label = Label.new()
	_tooltip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_label.offset_left   = 6.0
	_tooltip_label.offset_top    = 3.0
	_tooltip_label.offset_right  = -6.0
	_tooltip_label.offset_bottom = -3.0
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.add_theme_color_override("font_color", Color(0.82, 0.74, 0.55, 1.0))
	_tooltip_panel.add_child(_tooltip_label)

	# Building highlight — isometric diamond drawn in world space.
	_bldg_highlight         = Polygon2D.new()
	_bldg_highlight.polygon = PackedVector2Array([
		Vector2(0.0,          -BLDG_HALF_H),
		Vector2(BLDG_HALF_W,  0.0),
		Vector2(0.0,           BLDG_HALF_H),
		Vector2(-BLDG_HALF_W, 0.0),
	])
	_bldg_highlight.color   = Color(1.0, 0.9, 0.3, 0.30)
	_bldg_highlight.visible = false
	_bldg_highlight.name    = "BuildingHighlight"
	_world_ref.add_child(_bldg_highlight)


# ── Per-frame hover detection ─────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _world_ref == null or _intel_store == null:
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var screen_pos: Vector2 = viewport.get_mouse_position()
	var world_pos:  Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_pos

	# NPC takes priority.
	var new_npc := _hit_test_npc(world_pos)
	if new_npc != null:
		_set_hovered_npc(new_npc)
		_set_hovered_location("")
		_show_tooltip(screen_pos, _npc_tooltip_text(new_npc))
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
		return

	var new_loc := _hit_test_location(world_pos)
	if new_loc != "":
		_set_hovered_npc(null)
		_set_hovered_location(new_loc)
		var display := new_loc.replace("_", " ").capitalize()
		_show_tooltip(screen_pos, "Right-click to Observe — %s" % display)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
		return

	# Nothing hovered.
	_set_hovered_npc(null)
	_set_hovered_location("")
	_hide_tooltip()
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


# ── Hover visual helpers ──────────────────────────────────────────────────────

func _set_hovered_npc(npc: Node2D) -> void:
	if _hovered_npc == npc:
		return
	if _hovered_npc != null and is_instance_valid(_hovered_npc):
		_hovered_npc.call("set_hover", false)
	_hovered_npc = npc
	if _hovered_npc != null:
		_hovered_npc.call("set_hover", true)
		# Emit once when player hovers an NPC that has a valid eavesdrop partner.
		if not _eavesdrop_hover_fired and _find_conversation_partner(npc) != null:
			_eavesdrop_hover_fired = true
			valid_eavesdrop_hovered.emit()


func _set_hovered_location(loc: String) -> void:
	if _hovered_location == loc:
		return
	_hovered_location = loc
	if _bldg_highlight == null:
		return
	if loc == "":
		_bldg_highlight.visible = false
	else:
		var entry: Vector2i = _world_ref._building_entries.get(loc, Vector2i(-1, -1))
		if entry == Vector2i(-1, -1):
			_bldg_highlight.visible = false
		else:
			_bldg_highlight.position = _cell_to_world(entry)
			_bldg_highlight.visible  = true
		# Emit once when the player first hovers any building.
		if not _building_hover_fired:
			_building_hover_fired = true
			building_first_hovered.emit()


func _show_tooltip(screen_pos: Vector2, text: String) -> void:
	if _tooltip_panel == null:
		return
	_tooltip_label.text = text
	# Force label to recalculate its minimum size so we can size the panel.
	var min_sz: Vector2 = _tooltip_label.get_minimum_size()
	var panel_w: float  = min_sz.x + 12.0
	var panel_h: float  = max(min_sz.y + 6.0, 22.0)
	_tooltip_panel.size = Vector2(panel_w, panel_h)

	# Default offset: upper-right of cursor.
	var pos := screen_pos + TOOLTIP_OFFSET

	# Clamp to viewport so the tooltip never clips off screen edges.
	var vp_size := get_viewport().get_visible_rect().size
	if pos.x + panel_w > vp_size.x:
		pos.x = screen_pos.x - panel_w - 6.0   # flip left of cursor
	if pos.y < 0.0:
		pos.y = screen_pos.y + 8.0              # flip below cursor
	pos.x = maxf(pos.x, 2.0)
	pos.y = minf(pos.y, vp_size.y - panel_h - 2.0)

	_tooltip_panel.position = pos
	_tooltip_panel.visible  = true


func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false


## Build the hover tooltip text for an NPC, including their current reputation.
func _npc_tooltip_text(npc: Node2D) -> String:
	var base := "Right-click to Eavesdrop"
	if _world_ref == null or not ("reputation_system" in _world_ref):
		return base
	var rep_sys = _world_ref.reputation_system
	if rep_sys == null:
		return base
	var npc_id: String = npc.npc_data.get("id", "")
	if npc_id.is_empty():
		return base
	var snap = rep_sys.get_snapshot(npc_id)
	if snap == null:
		return base
	var result: String = "%s\nRep: %d — %s" % [base, snap.score, ReputationSystem.score_label(snap.score)]
	# Heat: show numeric value, failure ceiling (if any), and conviction penalty tier.
	if _intel_store != null and _intel_store.heat_enabled:
		var h := _intel_store.get_heat(npc_id)
		var ceiling: float = -1.0
		var sm = _world_ref.get("scenario_manager") if _world_ref != null else null
		if sm != null and sm.has_method("get_heat_ceiling"):
			ceiling = sm.get_heat_ceiling()
		var heat_str: String
		if ceiling > 0.0:
			heat_str = "Heat: %d / %d" % [int(h), int(ceiling)]
		else:
			heat_str = "Heat: %d" % int(h)
		if h >= 75.0:
			if ceiling > 0.0:
				heat_str += " — DANGER (failure at %d!)" % int(ceiling)
			result += "\n" + heat_str + "\nSuspicious — hard to convince (−30%)"
		elif h >= 50.0:
			result += "\n" + heat_str + "\nWary — harder to convince (−15%)"
		elif h > 0.0:
			result += "\n" + heat_str
	# DEFENDING state: explain who this NPC is shielding.
	if npc._is_defending:
		var def_name := _resolve_npc_name(npc._defender_target_npc_id)
		result += "\nDEFENDING %s — spreading doubt about rumors near them" % def_name
	return result


## Flash the building highlight green briefly when evidence is acquired via Observe.
## Pulses the existing highlight overlay: original gold → bright green → back.
func _flash_bldg_evidence_acquired() -> void:
	if _bldg_highlight == null or not _bldg_highlight.visible:
		return
	var orig_color := _bldg_highlight.color
	var tween := _bldg_highlight.create_tween()
	tween.tween_property(_bldg_highlight, "color", Color(0.35, 1.0, 0.45, 0.65), 0.10)
	tween.tween_property(_bldg_highlight, "color", orig_color, 0.45)


## Flash an NPC sprite teal briefly when a Witness Account evidence item is acquired.
func _flash_npc_evidence_acquired(npc: Node2D) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var tween := npc.create_tween()
	tween.tween_property(npc, "modulate", Color(0.40, 1.80, 1.30, 1.0), 0.12)
	tween.tween_property(npc, "modulate", NPC_NORMAL_MODULATE, 0.50)


## Flash the NPC sprite gold briefly to confirm a successful bribe.
## Single slow pulse: gold → normal over ~0.7 s.
func _flash_npc_bribed(npc: Node2D) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var tween := npc.create_tween()
	tween.tween_property(npc, "modulate", Color(2.0, 1.8, 0.2, 1.0), 0.12)
	tween.tween_property(npc, "modulate", NPC_NORMAL_MODULATE, 0.55)


## Flash the NPC sprite red briefly to signal they noticed the player.
## Tweens modulate red → normal over ~0.8 s with two pulses for urgency.
func _flash_npc_detected(npc: Node2D) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var tween := npc.create_tween()
	tween.tween_property(npc, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.08)
	tween.tween_property(npc, "modulate", NPC_NORMAL_MODULATE, 0.20)
	tween.tween_property(npc, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.08)
	tween.tween_property(npc, "modulate", NPC_NORMAL_MODULATE, 0.35)


## Spawn a palette-appropriate starburst above the building highlight when Observe succeeds.
## Five "*" glyphs in PARCH_L (#E4D2A8) radiate outward from the building centre —
## consistent with the ink-line pixel aesthetic; avoids OS emoji rendering.
func _show_observe_sparkle() -> void:
	if _bldg_highlight == null or not _bldg_highlight.visible:
		return
	var base_pos := _bldg_highlight.position + Vector2(0.0, -52.0)
	var burst_dirs: Array[Vector2] = [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(0.0, -1.4),
		Vector2(-1.2,  0.3), Vector2(1.2,  0.3),
	]
	for dir: Vector2 in burst_dirs:
		var lbl := Label.new()
		lbl.text = "*"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.894, 0.820, 0.659))  # PARCH_L
		lbl.position = base_pos
		lbl.z_index = 5
		_world_ref.add_child(lbl)
		var tw := lbl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "position", base_pos + dir * 18.0, 1.2)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.3)
		tw.finished.connect(lbl.queue_free)


## Spawn a palette-appropriate exclamation above the target NPC when Eavesdrop succeeds.
## "!" in FLAG_R (#B22626) rising above the NPC signals intel gathered and ties visually
## to the heat/danger colour vocabulary; avoids OS emoji rendering.
func _show_eavesdrop_success(npc: Node2D) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.698, 0.149, 0.149))  # FLAG_R
	var start_pos := npc.position + Vector2(-4.0, -68.0)
	lbl.position = start_pos
	lbl.z_index = 5
	_world_ref.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", start_pos + Vector2(0.0, -24.0), 1.3)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.3).set_delay(0.4)
	tw.finished.connect(lbl.queue_free)




# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _world_ref == null or _intel_store == null:
		return
	if not (event is InputEventMouseButton):
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var screen_pos: Vector2  = viewport.get_mouse_position()

	# Left-click outside an open action popup dismisses it.
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _popup_panel != null:
		_dismiss_action_popup()
		get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return

	# Right-click always dismisses any open popup first.
	if _popup_panel != null:
		_dismiss_action_popup()

	# Convert screen position → world position via the canvas (camera) transform.
	var world_pos: Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_pos

	# NPC hit-test takes priority over location hit-test.
	var clicked_npc := _hit_test_npc(world_pos)
	if clicked_npc != null:
		# SPA-683: show the conversation dialogue panel instead of a direct action.
		if _dialogue_panel != null:
			_dialogue_panel.show_for_npc(clicked_npc, screen_pos)
		else:
			# Fallback (no dialogue panel wired): legacy direct-action behaviour.
			if _intel_store.bribe_charges > 0 \
					and clicked_npc.get_worst_rumor_state() == Rumor.RumorState.EVALUATING:
				_show_action_popup(clicked_npc, screen_pos)
			else:
				_try_eavesdrop(clicked_npc)
		get_viewport().set_input_as_handled()
		return

	var clicked_location := _hit_test_location(world_pos)
	if clicked_location != "":
		_try_observe(clicked_location)
		get_viewport().set_input_as_handled()


# ── Hit testing ───────────────────────────────────────────────────────────────

func _hit_test_npc(world_pos: Vector2) -> Node2D:
	var best:      Node2D = null
	var best_dist: float  = NPC_HIT_RADIUS_PX
	for npc in _world_ref.npcs:
		var dist: float = npc.global_position.distance_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best      = npc
	return best


func _hit_test_location(world_pos: Vector2) -> String:
	var clicked_cell := _world_to_cell(world_pos)
	for loc_name in _world_ref._building_entries:
		var entry: Vector2i = _world_ref._building_entries[loc_name]
		var dist: float = (clicked_cell - entry).length()
		if dist <= BUILDING_HIT_TILES:
			return loc_name
	return ""


# ── Observe action ────────────────────────────────────────────────────────────

func _try_observe(location_id: String) -> void:
	# Forged Document: double-spend at market/guild when ≥2 actions remain.
	var forged_doc := _intel_store.recon_actions_remaining >= 2 \
		and (location_id == "market" or location_id == "guild")

	if not _intel_store.try_spend_action():
		emit_signal("action_performed", "No Recon Actions remaining today.", false)
		return

	if forged_doc:
		_intel_store.try_spend_action()  # consume the second action

	var tick  := _current_tick()
	var intel := PlayerIntelStore.LocationIntel.new(location_id, tick)

	# Snapshot all NPCs currently within 4 tiles of the building entry cell.
	var entry_cell: Vector2i = _world_ref._building_entries.get(location_id, Vector2i(-1, -1))
	for npc in _world_ref.npcs:
		if (npc.current_cell - entry_cell).length() <= 4:
			intel.npcs_seen.append({
				"npc_id":        npc.npc_data.get("id", ""),
				"npc_name":      npc.npc_data.get("name", ""),
				"faction":       npc.npc_data.get("faction", ""),
				"arrival_tick":  tick,
				"departure_tick": tick + 4,  # approx: one schedule slot = 4 ticks
			})

	_intel_store.add_location_intel(intel)

	var n    := intel.npcs_seen.size()
	var loc_display := location_id.replace("_", " ").capitalize()
	var msg  := "Observed %s — %d NPC%s noted. (%d Recon left)" % [
		loc_display, n, "s" if n != 1 else "",
		_intel_store.recon_actions_remaining
	]

	# Evidence acquisition.
	if forged_doc:
		var ev := PlayerIntelStore.EvidenceItem.new(
			"Forged Document", 0.20, 0.0,
			["ACCUSATION", "SCANDAL", "HERESY"], tick)
		_intel_store.add_evidence(ev)
		_flash_bldg_evidence_acquired()
		msg += "\n[+] Forged Document acquired."
	elif tick % 24 > 18 \
			and (location_id == "manor" or location_id == "chapel"):
		var ev := PlayerIntelStore.EvidenceItem.new(
			"Incriminating Artifact", 0.25, 0.0,
			["SCANDAL", "HERESY"], tick)
		_intel_store.add_evidence(ev)
		_flash_bldg_evidence_acquired()
		msg += "\n[+] Incriminating Artifact acquired."

	emit_signal("action_performed", msg, true)
	_show_observe_sparkle()
	# Cancel any pending outdoor-ambient clear timer from a previous observe.
	_ambient_clear_seq += 1
	# Show the building interior panel (lore/flavour) if one is registered.
	if _interiors.has(location_id):
		_interiors[location_id].show_interior()
	else:
		# Outdoor locations (e.g. market): play location ambient, auto-clear after 10s.
		AudioManager.set_location_ambient(location_id)
		var seq := _ambient_clear_seq
		get_tree().create_timer(10.0).timeout.connect(
			func() -> void:
				if _ambient_clear_seq == seq:
					AudioManager.clear_location_ambient()
		, CONNECT_ONE_SHOT)
	# Trigger an "observe" dialogue bubble on each NPC present at the location.
	for npc in _world_ref.npcs:
		if (npc.current_cell - entry_cell).length() <= 4:
			npc.show_observed()


# ── Eavesdrop action ──────────────────────────────────────────────────────────

func _try_eavesdrop(target: Node2D) -> void:
	var partner := _find_conversation_partner(target)
	if partner == null:
		var name_a: String = target.npc_data.get("name", "?")
		emit_signal("action_performed",
			"%s is not in conversation (no one within %d tiles)." % [name_a, EAVESDROP_RANGE_TILES],
			false)
		return

	if not _intel_store.try_spend_action():
		emit_signal("action_performed", "No Recon Actions remaining today.", false)
		return

	# Detection risk: temperament > 0.7 → 20% chance of being noticed.
	var temperament: float = float(target.npc_data.get("temperament", 0.5))
	if temperament > 0.7 and randf() < EAVESDROP_FAIL_CHANCE:
		var name_a: String = target.npc_data.get("name", "?")
		_flash_npc_detected(target)
		# Heat: +4 on detection failure to both NPCs involved.
		_intel_store.add_heat(target.npc_data.get("id", ""), 4.0)
		_intel_store.add_heat(partner.npc_data.get("id", ""), 4.0)
		emit_signal("action_performed",
			"\"%s seemed to glance your way.\" [+4 suspicion] (%d Recon left)" % [
				name_a, _intel_store.recon_actions_remaining],
			false)
		player_exposed.emit()
		return

	# Record relationship intel.
	var tick    := _current_tick()
	var id_a:   String = target.npc_data.get("id",      "")
	var id_b:   String = partner.npc_data.get("id",     "")
	var name_a: String = target.npc_data.get("name",    "")
	var name_b: String = partner.npc_data.get("name",   "")
	var weight: float  = 0.0
	if _world_ref.social_graph != null:
		weight = _world_ref.social_graph.get_weight(id_a, id_b)

	# Witness Account: check prior observation BEFORE overwriting with new intel.
	var prior := _intel_store.get_relationship_intel(id_a, id_b)
	var witness_account := prior != null and (tick - prior.observed_at) >= 24

	var intel := PlayerIntelStore.RelationshipIntel.new(
		id_a, id_b, name_a, name_b, weight, tick
	)

	# Rich context: active rumor belief states with trend direction.
	var belief_ctx := _belief_context(target, partner)
	intel.rich_context = belief_ctx

	# Critical context: DEFENDING state reveals loyalty tier and protected target.
	var critical_ctx := _critical_context(target, partner)
	intel.critical_context = critical_ctx

	_intel_store.add_relationship_intel(intel)

	# Heat: +8 on successful eavesdrop to both NPCs.
	_intel_store.add_heat(id_a, 8.0)
	_intel_store.add_heat(id_b, 8.0)

	var _bars := mini(intel.bars(), 3)
	var bar_str := "[" + "*".repeat(_bars) + " ".repeat(3 - _bars) + "]"
	var belief_line   := ("\n" + belief_ctx)   if not belief_ctx.is_empty()   else ""
	var critical_line := ("\n" + critical_ctx) if not critical_ctx.is_empty() else ""
	var heat_line := ""
	if _intel_store.heat_enabled:
		heat_line = "\n[+8 suspicion]"
	var msg := "Eavesdropped: %s <-> %s  %s %s (%s)%s%s%s  (%d Recon left)" % [
		name_a, name_b,
		bar_str, intel.affinity_label.capitalize(), intel.strength_label(),
		belief_line,
		critical_line,
		heat_line,
		_intel_store.recon_actions_remaining
	]

	if witness_account:
		var ev := PlayerIntelStore.EvidenceItem.new(
			"Witness Account", 0.15, -0.15, [], tick)
		_intel_store.add_evidence(ev)
		_flash_npc_evidence_acquired(target)
		msg += "\n[+] Witness Account acquired."

	emit_signal("action_performed", msg, true)
	_show_eavesdrop_success(target)
	# Trigger an "eavesdrop" dialogue bubble on the target NPC.
	target.show_eavesdropped()


## Returns a short string describing what beliefs either NPC currently holds
## (BELIEVE / SPREAD / ACT states only), with trend direction.
## Empty string if neither NPC has an active rumor belief.
func _belief_context(npc_a: Node2D, npc_b: Node2D) -> String:
	var snippets: Array[String] = []
	var active_states := [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]
	for npc in [npc_a, npc_b]:
		var npc_name: String = npc.npc_data.get("name", "?")
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state in active_states:
				var claim_label := Rumor.claim_type_name(slot.rumor.claim_type)
				var subject_name := _resolve_npc_name(slot.rumor.subject_npc_id)
				var trend := _belief_trend(slot.ticks_in_state)
				snippets.append("%s [%s: %s about %s, %s]" % [
					npc_name,
					Rumor.state_name(slot.state),
					claim_label,
					subject_name,
					trend
				])
				break  # one snippet per NPC is enough
	return "\n".join(snippets)


## Returns a trend direction string based on how long the NPC has held their belief.
## Short stays = rising (freshly convinced); long stays = fading (losing conviction).
func _belief_trend(ticks_in_state: int) -> String:
	if ticks_in_state <= 3:
		return "↑ rising"
	elif ticks_in_state <= 8:
		return "→ stable"
	return "↓ fading"


## Returns a critical intelligence string when either NPC is in DEFENDING state.
## Reveals the NPC's loyalty tier and who they are shielding.
## Empty string if neither NPC is defending.
func _critical_context(npc_a: Node2D, npc_b: Node2D) -> String:
	var snippets: Array[String] = []
	for npc in [npc_a, npc_b]:
		if not npc._is_defending:
			continue
		var npc_name: String  = npc.npc_data.get("name", "?")
		var target_name: String = _resolve_npc_name(npc._defender_target_npc_id)
		var loyalty_tier: String
		if npc._loyalty > 0.7:
			loyalty_tier = "high"
		elif npc._loyalty > 0.4:
			loyalty_tier = "moderate"
		else:
			loyalty_tier = "low"
		snippets.append("⚠ %s DEFENDING %s (loyalty: %s)" % [npc_name, target_name, loyalty_tier])
	return "\n".join(snippets)


## Resolve a NPC id to a display name using the world NPC list.
func _resolve_npc_name(npc_id: String) -> String:
	if _world_ref == null:
		return npc_id
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc.npc_data.get("name", npc_id)
	return npc_id


func _find_conversation_partner(target: Node2D) -> Node2D:
	var best:      Node2D = null
	var best_dist: float  = float(EAVESDROP_RANGE_TILES) + 0.01
	for npc in _world_ref.npcs:
		if npc == target:
			continue
		var tile_dist: float = (npc.current_cell - target.current_cell).length()
		if tile_dist <= EAVESDROP_RANGE_TILES and tile_dist < best_dist:
			best_dist = tile_dist
			best      = npc
	return best


# ── Coordinate conversion ─────────────────────────────────────────────────────

## Inverse of npc.gd's _cell_to_world():
##   world_x = (cx - cy) * 32,  world_y = (cx + cy) * 16
## → cx = world_x/64 + world_y/32,  cy = world_y/32 - world_x/64
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var cx := world_pos.x / 64.0 + world_pos.y / 32.0
	var cy := world_pos.y / 32.0 - world_pos.x / 64.0
	return Vector2i(int(round(cx)), int(round(cy)))


## Forward of _world_to_cell() — matches npc.gd's _cell_to_world().
func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * 32.0,
		float(cell.x + cell.y) * 16.0
	)


func _current_tick() -> int:
	var dn = _world_ref.day_night if _world_ref != null else null
	if dn != null and "current_tick" in dn:
		return int(dn.current_tick)
	return 0


# ── Bribe action popup ────────────────────────────────────────────────────────

## Show a two-button popup (Eavesdrop / Bribe) near the cursor for an EVALUATING NPC.
func _show_action_popup(npc: Node2D, screen_pos: Vector2) -> void:
	_dismiss_action_popup()
	_popup_npc = npc

	_popup_panel = Panel.new()
	_popup_panel.name = "ActionPopup"
	_tooltip_canvas.add_child(_popup_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.07, 0.04, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_panel.add_child(bg)

	var border_top := ColorRect.new()
	border_top.color = C_PANEL_BORDER
	border_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_top.anchor_bottom = 0.0
	border_top.offset_bottom = 2.0
	_popup_panel.add_child(border_top)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 4.0
	vbox.offset_top    = 4.0
	vbox.offset_right  = -4.0
	vbox.offset_bottom = -4.0
	vbox.add_theme_constant_override("separation", 3)
	_popup_panel.add_child(vbox)

	var btn_eavesdrop := Button.new()
	btn_eavesdrop.text = "Eavesdrop"
	btn_eavesdrop.add_theme_font_size_override("font_size", 12)
	btn_eavesdrop.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55, 1.0))
	btn_eavesdrop.pressed.connect(_on_popup_eavesdrop)
	vbox.add_child(btn_eavesdrop)

	var can_bribe: bool = _intel_store.recon_actions_remaining > 0 \
		and _intel_store.whisper_tokens_remaining > 0 \
		and _intel_store.bribe_charges > 0
	var btn_bribe := Button.new()
	btn_bribe.add_theme_font_size_override("font_size", 12)
	if can_bribe:
		btn_bribe.text = "Bribe  (1 Recon + 1 Token)"
		btn_bribe.pressed.connect(_on_popup_bribe)
	else:
		btn_bribe.text = "Bribe  — Insufficient resources"
		btn_bribe.disabled = true
	vbox.add_child(btn_bribe)

	# Size and position near cursor.
	_popup_panel.size = Vector2(196, 56)
	var pos := screen_pos + Vector2(4.0, 4.0)
	var vp_size := get_viewport().get_visible_rect().size
	if pos.x + 196.0 > vp_size.x:
		pos.x = screen_pos.x - 196.0 - 4.0
	if pos.y + 56.0 > vp_size.y:
		pos.y = screen_pos.y - 56.0 - 4.0
	_popup_panel.position = pos


func _on_dialogue_dismissed() -> void:
	pass  # Reserved for future dismiss-side effects (e.g. analytics).


func _dismiss_action_popup() -> void:
	if _popup_panel != null:
		_popup_panel.queue_free()
		_popup_panel = null
	_popup_npc = null


func _on_popup_eavesdrop() -> void:
	var npc := _popup_npc
	_dismiss_action_popup()
	if npc != null and is_instance_valid(npc):
		_try_eavesdrop(npc)


func _on_popup_bribe() -> void:
	var npc := _popup_npc
	_dismiss_action_popup()
	if npc != null and is_instance_valid(npc):
		_try_bribe(npc)


# ── Bribe action ──────────────────────────────────────────────────────────────

func _try_bribe(target: Node2D) -> void:
	var npc_name: String = target.npc_data.get("name", "?")

	# Scenario 3: block bribe on Calder-faction NPCs.
	if _world_ref != null and _world_ref.active_scenario_id == "scenario_3":
		var npc_faction: String = target.npc_data.get("faction", "")
		var calder_faction := _get_calder_faction()
		if not calder_faction.is_empty() and npc_faction == calder_faction:
			emit_signal("action_performed",
				"This NPC is too close to Calder — they would report the approach.", false)
			return

	# SPA-593: pre-check eligibility before spending any resources.
	if not target.has_evaluating_rumor():
		emit_signal("action_performed",
			"No pending rumor to reinforce — %s is not currently evaluating." % npc_name, false)
		return
	if _intel_store.bribe_charges <= 0:
		emit_signal("action_performed", "No Favors remaining for bribe.", false)
		return

	# Cost: 1 Recon Action + 1 Whisper Token.
	if not _intel_store.try_spend_action():
		emit_signal("action_performed", "No Recon Actions remaining for bribe.", false)
		return
	if not _intel_store.try_spend_whisper():
		# Refund recon action.
		_intel_store.recon_actions_remaining = mini(
			_intel_store.recon_actions_remaining + 1, PlayerIntelStore.MAX_DAILY_ACTIONS)
		emit_signal("action_performed", "No Whisper Tokens remaining for bribe.", false)
		return

	# Execute: force EVALUATING → BELIEVE.
	var forced_id: String = target.force_believe()
	if forced_id.is_empty():
		# Safety net: state changed between pre-check and execution — refund and abort.
		_intel_store.recon_actions_remaining = mini(
			_intel_store.recon_actions_remaining + 1, PlayerIntelStore.MAX_DAILY_ACTIONS)
		_intel_store.whisper_tokens_remaining = mini(
			_intel_store.whisper_tokens_remaining + 1, PlayerIntelStore.MAX_DAILY_WHISPERS)
		emit_signal("action_performed", "Bribe failed — %s is no longer evaluating." % npc_name, false)
		return

	# Consume bribe charge.
	_intel_store.try_spend_bribe()

	_flash_npc_bribed(target)
	target.show_bribed_effect()

	var tick := _current_tick()
	emit_signal("action_performed",
		"Bribed %s — they now believe the rumor.  (%d Favors left)" % [
			npc_name, _intel_store.bribe_charges], true)
	emit_signal("bribe_executed", npc_name, tick)


## Return Calder Fenn's faction string, or "" if not found.
func _get_calder_faction() -> String:
	if _world_ref == null:
		return ""
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == "calder_fenn":
			return npc.npc_data.get("faction", "")
	return ""

extends Node

## recon_controller.gd — Sprint 3 Reconnaissance input handler.
## Sprint 9: hover highlights, cursor feedback, and interaction tooltips.
##
## Processes right-click events to trigger Observe (on buildings) and
## Eavesdrop (on NPCs in conversation) actions.
##
## Also runs _process() hover detection each frame to:
##   • Highlight the hovered NPC sprite (golden modulate).
##   • Show a floating "Right-click to…" tooltip near the cursor.
##   • Highlight the hovered building with a world-space diamond overlay.
##   • Change cursor to CURSOR_POINTING_HAND over interactable elements.
##
## Wired by main.gd after the scene tree is ready.
## setup(world, intel_store) must be called before input events arrive.

const EAVESDROP_RANGE_TILES := 3      ## Max tile distance for "in conversation"
const EAVESDROP_FAIL_CHANCE  := 0.20  ## Probability of detection when temperament > 0.7
const NPC_HIT_RADIUS_PX      := 28.0  ## World-space hit radius around NPC centre
const BUILDING_HIT_TILES     := 2     ## Grid-cell radius for location hit-test

## Highlight colour applied to a hovered NPC's modulate.
const NPC_HOVER_MODULATE  := Color(1.5, 1.3, 0.5, 1.0)
const NPC_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)

## Building highlight diamond half-extents (isometric tile = 64×32 px).
const BLDG_HALF_W := 36.0
const BLDG_HALF_H := 20.0

## Tooltip offset from the mouse cursor (screen-space pixels).
const TOOLTIP_OFFSET := Vector2(14.0, -32.0)

## Emitted after every action attempt (success or failure).
signal action_performed(message: String, success: bool)

## Emitted when a high-temperament NPC detects the player eavesdropping.
signal player_exposed

var _world_ref:       Node2D           = null
var _intel_store:     PlayerIntelStore = null

# ── Hover state ───────────────────────────────────────────────────────────────
var _hovered_npc:      Node2D = null
var _hovered_location: String = ""

# ── Hover visual nodes (created in setup) ────────────────────────────────────
var _tooltip_canvas: CanvasLayer = null
var _tooltip_panel:  Panel       = null
var _tooltip_label:  Label       = null
var _bldg_highlight: Polygon2D   = null


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
	bg.color      = Color(0.87, 0.80, 0.62, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_panel.add_child(bg)

	_tooltip_label = Label.new()
	_tooltip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_label.offset_left   = 6.0
	_tooltip_label.offset_top    = 3.0
	_tooltip_label.offset_right  = -6.0
	_tooltip_label.offset_bottom = -3.0
	_tooltip_label.add_theme_font_size_override("font_size", 11)
	_tooltip_label.add_theme_color_override("font_color", Color(0.28, 0.16, 0.06, 1.0))
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
		_hovered_npc.modulate = NPC_NORMAL_MODULATE
	_hovered_npc = npc
	if _hovered_npc != null:
		_hovered_npc.modulate = NPC_HOVER_MODULATE


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


func _show_tooltip(screen_pos: Vector2, text: String) -> void:
	if _tooltip_panel == null:
		return
	_tooltip_label.text = text
	# Force label to recalculate its minimum size so we can size the panel.
	var min_sz: Vector2 = _tooltip_label.get_minimum_size()
	var panel_w: float  = min_sz.x + 12.0
	var panel_h: float  = max(min_sz.y + 6.0, 22.0)
	_tooltip_panel.size     = Vector2(panel_w, panel_h)
	_tooltip_panel.position = screen_pos + TOOLTIP_OFFSET
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
	return "%s\nRep: %d — %s" % [base, snap.score, _rep_tier_label(snap.score)]


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


## Map a 0-100 reputation score to a human-readable tier label.
func _rep_tier_label(score: int) -> String:
	if score >= 85: return "Revered"
	elif score >= 70: return "Distinguished"
	elif score >= 50: return "Respected"
	elif score >= 35: return "Suspicious"
	elif score >= 20: return "Disgraced"
	else: return "Despised"


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _world_ref == null or _intel_store == null:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	# Convert screen position → world position via the canvas (camera) transform.
	var screen_pos: Vector2  = viewport.get_mouse_position()
	var world_pos:  Vector2  = viewport.get_canvas_transform().affine_inverse() * screen_pos

	# NPC hit-test takes priority over location hit-test.
	var clicked_npc := _hit_test_npc(world_pos)
	if clicked_npc != null:
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
		var dist := npc.global_position.distance_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best      = npc
	return best


func _hit_test_location(world_pos: Vector2) -> String:
	var clicked_cell := _world_to_cell(world_pos)
	for loc_name in _world_ref._building_entries:
		var entry: Vector2i = _world_ref._building_entries[loc_name]
		var dist := (clicked_cell - entry).length()
		if dist <= BUILDING_HIT_TILES:
			return loc_name
	return ""


# ── Observe action ────────────────────────────────────────────────────────────

func _try_observe(location_id: String) -> void:
	if not _intel_store.try_spend_action():
		emit_signal("action_performed", "No Recon Actions remaining today.", false)
		return

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
	emit_signal("action_performed", msg, true)
	print("[Recon] Observe '%s' tick=%d — %d NPC(s) recorded" % [location_id, tick, n])


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
		emit_signal("action_performed",
			"\"%s seemed to glance your way.\" (%d Recon left)" % [
				name_a, _intel_store.recon_actions_remaining],
			false)
		print("[Recon] Eavesdrop NOTICED by %s (temperament=%.2f)" % [name_a, temperament])
		_flash_npc_detected(target)
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

	var intel := PlayerIntelStore.RelationshipIntel.new(
		id_a, id_b, name_a, name_b, weight, tick
	)
	_intel_store.add_relationship_intel(intel)

	var bar_str := "[" + "*".repeat(intel.bars()) + " ".repeat(3 - intel.bars()) + "]"
	var msg := "Eavesdropped: %s <-> %s  %s %s (%s)  (%d Recon left)" % [
		name_a, name_b,
		bar_str, intel.affinity_label.capitalize(), intel.strength_label(),
		_intel_store.recon_actions_remaining
	]
	emit_signal("action_performed", msg, true)
	print("[Recon] Eavesdrop %s <-> %s  weight=%.2f  label=%s" % [
		name_a, name_b, weight, intel.affinity_label])


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

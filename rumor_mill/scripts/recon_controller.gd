extends Node

## recon_controller.gd — Sprint 3 Reconnaissance input handler.
##
## Processes right-click events to trigger Observe (on buildings) and
## Eavesdrop (on NPCs in conversation) actions.
##
## Wired by main.gd after the scene tree is ready.
## setup(world, intel_store) must be called before input events arrive.

const EAVESDROP_RANGE_TILES := 3      ## Max tile distance for "in conversation"
const EAVESDROP_FAIL_CHANCE  := 0.20  ## Probability of detection when temperament > 0.7
const NPC_HIT_RADIUS_PX      := 28.0  ## World-space hit radius around NPC centre
const BUILDING_HIT_TILES     := 2     ## Grid-cell radius for location hit-test

## Emitted after every action attempt (success or failure).
## message: human-readable result string
## success: true = action succeeded, false = failed / no actions left
signal action_performed(message: String, success: bool)

## Emitted when a high-temperament NPC detects the player eavesdropping.
signal player_exposed

var _world_ref:       Node2D           = null
var _intel_store:     PlayerIntelStore = null


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref   = world
	_intel_store = intel_store


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


func _current_tick() -> int:
	var dn = _world_ref.day_night if _world_ref != null else null
	if dn != null and "current_tick" in dn:
		return int(dn.current_tick)
	return 0

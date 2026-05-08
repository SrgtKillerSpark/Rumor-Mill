## npc_movement.gd — Movement, pathfinding, and schedule waypoint logic for NPC.
## Extracted from npc.gd (SPA-1009).  Owns the path buffer, movement tween, and
## schedule slot state.  Call setup() from npc.init_from_data().

class_name NpcMovement
extends Node

const MOVE_SPEED          := 180.0   # pixels/second (mirrors npc.gd constant)
const _MICRO_WANDER_CHANCE := 0.20

var _npc: Node2D = null

## Current facing direction — updated by _walk_to, persists into idle.
## "south" | "north" | "east" | "west"
var _facing_dir:           String           = "south"
var _path:                 Array[Vector2i]  = []
var _waypoint_index:       int              = -1  # -1 so first advance lands on index 0
var _is_moving:            bool             = false
var _tween:                Tween            = null
var _micro_wander_cooldown: int             = 0
var _last_schedule_slot:   int              = -1

var _pathfinder:      AstarPathfinder  = null
var _walkable:        Array[Vector2i]  = []
## Pre-sampled 64-cell subset used by _cell_furthest_from to avoid scanning ~1000 cells.
var _walkable_sample: Array[Vector2i]  = []


## Inject dependencies and initialise position.  Called from npc.init_from_data().
func setup(
		npc: Node2D,
		pathfinder: AstarPathfinder,
		walkable: Array[Vector2i],
		start_cell: Vector2i
) -> void:
	_npc        = npc
	_pathfinder = pathfinder
	_walkable   = walkable

	_walkable_sample = walkable.duplicate()
	_walkable_sample.shuffle()
	if _walkable_sample.size() > 64:
		_walkable_sample.resize(64)

	_npc.current_cell = start_cell
	_npc.position     = cell_to_world(start_cell)
	_advance_waypoint()


# ── Per-tick entry ────────────────────────────────────────────────────────────

func step_movement() -> void:
	if _is_moving:
		return
	if _npc._is_chapel_frozen():
		return
	if _path.is_empty():
		_advance_waypoint()
	if _path.is_empty():
		_maybe_micro_wander()
		return
	var next_cell: Vector2i = _path[0]
	_path.remove_at(0)
	_walk_to(next_cell)


# ── Schedule ──────────────────────────────────────────────────────────────────

func update_tick_schedule(slot: int, day: int, gathering_points: Dictionary) -> void:
	if _npc._is_schedule_overridden():
		return
	if slot == _last_schedule_slot:
		return
	_last_schedule_slot = slot

	var location_code: String = NpcSchedule.get_location(
		_npc.archetype, slot, _npc.work_location,
		_npc.tick_overrides, _npc.day_pattern_overrides, day
	)
	location_code = _npc._reroute_if_avoided(location_code)
	# SPA-868: outside NPCs avoid quarantined buildings — reroute to previous location.
	if _npc.quarantine_ref != null and _npc.quarantine_ref.is_quarantined(location_code) \
			and location_code != _npc.current_location_code:
		location_code = _npc.current_location_code if not _npc.current_location_code.is_empty() else "home"
	# SPA-874: non-believers avoid illness hotspot buildings (3+ believers present).
	if _npc.illness_hotspot_buildings.has(location_code) \
			and location_code != _npc.current_location_code \
			and not _npc._believes_illness():
		location_code = _npc.current_location_code if not _npc.current_location_code.is_empty() else "home"
	_npc.current_location_code = location_code

	# Visual schedule clarity (SPA-586): dim NPC when asleep at home during night slots.
	var sleeping: bool = (location_code == "home") and (slot == 0 or slot == 1)
	_npc.modulate.a = 0.45 if sleeping else 1.0

	var target: Vector2i
	if location_code == "home":
		target = _npc._home_cell
	elif gathering_points.has(location_code):
		target = gathering_points[location_code]
	else:
		return

	_npc.schedule_waypoints = [target]
	_waypoint_index = 0
	if _pathfinder == null:
		return
	_path = _pathfinder.get_path(_npc.current_cell, target)
	if _path.is_empty() and target != _npc.current_cell:
		var fallback := AstarPathfinder.nearest_walkable(target, _walkable)
		if fallback != target:
			_path = _pathfinder.get_path(_npc.current_cell, fallback)
	if _path.size() > 0 and _path[0] == _npc.current_cell:
		_path.remove_at(0)


# ── Movement helpers ──────────────────────────────────────────────────────────

func _maybe_micro_wander() -> void:
	if _npc._is_schedule_overridden():
		return
	if _npc._is_chapel_frozen():
		return
	if _micro_wander_cooldown > 0:
		_micro_wander_cooldown -= 1
		return
	if randf() >= _MICRO_WANDER_CHANCE:
		return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d: Vector2i in dirs:
		var candidate: Vector2i = _npc.current_cell + d
		if _walkable.has(candidate):
			_path = [candidate]
			_micro_wander_cooldown = randi_range(3, 8)
			return


func _advance_waypoint() -> void:
	if _npc.schedule_waypoints.is_empty() or _pathfinder == null:
		return
	_waypoint_index = (_waypoint_index + 1) % _npc.schedule_waypoints.size()
	var target: Vector2i = _npc.schedule_waypoints[_waypoint_index]
	_path = _pathfinder.get_path(_npc.current_cell, target)
	if _path.is_empty() and target != _npc.current_cell:
		var fallback := AstarPathfinder.nearest_walkable(target, _walkable)
		if fallback != target:
			_path = _pathfinder.get_path(_npc.current_cell, fallback)
	if _path.size() > 0 and _path[0] == _npc.current_cell:
		_path.remove_at(0)


func _walk_to(cell: Vector2i) -> void:
	if cell == _npc.current_cell:
		return
	_is_moving = true
	# Determine cardinal facing from isometric grid delta (SPA-585).
	var cdx: int = cell.x - _npc.current_cell.x
	var cdy: int = cell.y - _npc.current_cell.y
	if abs(cdx) >= abs(cdy):
		_facing_dir = "west" if cdx < 0 else "east"
	else:
		_facing_dir = "south" if cdy > 0 else "north"
	var spr: AnimatedSprite2D = _npc.sprite
	if spr != null and spr.sprite_frames != null:
		match _facing_dir:
			"south": spr.flip_h = false; spr.play("walk_south")
			"north": spr.flip_h = false; spr.play("walk_north")
			"east":  spr.flip_h = false; spr.play("walk_east")
			"west":  spr.flip_h = true;  spr.play("walk_east")
	var world_pos   := cell_to_world(cell)
	var eff_speed   := MOVE_SPEED * maxf(_npc.mood_speed_scale, 0.1)
	var duration    := maxf(_npc.position.distance_to(world_pos) / eff_speed, 0.05)
	if _tween:
		_tween.kill()
	_tween = _npc.create_tween()
	_tween.tween_property(_npc, "position", world_pos, duration).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_move_finished.bind(cell), CONNECT_ONE_SHOT)


func _on_move_finished(arrived_cell: Vector2i) -> void:
	_npc.current_cell = arrived_cell
	_is_moving        = false
	var spr: AnimatedSprite2D = _npc.sprite
	if spr != null and spr.sprite_frames != null:
		match _facing_dir:
			"north": spr.play("idle_north")
			"east":  spr.flip_h = false; spr.play("idle_east")
			"west":  spr.flip_h = true;  spr.play("idle_east")
			_:       spr.play("idle_south")
	# SPA-909: Landing squash — wide-and-short on impact, spring back to rest.
	if spr != null:
		spr.scale = Vector2(1.07, 0.93)
		var _land := _npc.create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		_land.tween_property(spr, "scale", Vector2.ONE, 0.35)


# ── Navigation helpers (used by rumor processing) ─────────────────────────────

## Move toward or away from subject_id depending on sentiment.
## toward=true → seek (praise); toward=false → flee (accusation/scandal/etc.)
func navigate_relative_to_subject(subject_id: String, toward: bool) -> void:
	if _pathfinder == null or _walkable.is_empty():
		return
	var subj_node = _npc._npc_id_dict.get(subject_id, null)
	if subj_node == null:
		return
	var subject_cell: Vector2i = subj_node.current_cell
	var target_cell: Vector2i  = subject_cell if toward else _cell_furthest_from(subject_cell)
	_path = _pathfinder.get_path(_npc.current_cell, target_cell)
	if _path.is_empty() and target_cell != _npc.current_cell:
		var fallback := AstarPathfinder.nearest_walkable(target_cell, _walkable)
		if fallback != target_cell:
			_path = _pathfinder.get_path(_npc.current_cell, fallback)
	if _path.size() > 0 and _path[0] == _npc.current_cell:
		_path.remove_at(0)


## Move toward the nearest NPC who is also BELIEVE/SPREAD for the same rumor.
func start_spread_clustering(rumor: Rumor) -> void:
	if _pathfinder == null:
		return
	var best: Node2D = null
	var best_dist    := INF
	for other in _npc.all_npcs_ref:
		if other == _npc:
			continue
		var s: Rumor.RumorState = other.get_state_for_rumor(rumor.id)
		if s in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD]:
			var d: float = float(((other.current_cell as Vector2i) - _npc.current_cell).length_squared())
			if d < best_dist:
				best_dist = d
				best      = other
	if best == null:
		return
	_path = _pathfinder.get_path(_npc.current_cell, best.current_cell)
	if _path.is_empty() and best.current_cell != _npc.current_cell:
		var fallback := AstarPathfinder.nearest_walkable(best.current_cell, _walkable)
		if fallback != best.current_cell:
			_path = _pathfinder.get_path(_npc.current_cell, fallback)
	if _path.size() > 0 and _path[0] == _npc.current_cell:
		_path.remove_at(0)


## Return the walkable cell that maximises squared distance from from_cell.
## Uses the pre-sampled 64-cell candidate list.
func _cell_furthest_from(from_cell: Vector2i) -> Vector2i:
	var best_cell: Vector2i = _npc.current_cell
	var best_dist: int = 0
	for cell in _walkable_sample:
		var d: int = (cell - from_cell).length_squared()
		if d > best_dist:
			best_dist = d
			best_cell = cell
	return best_cell


## Isometric tile → world position conversion.
func cell_to_world(cell: Vector2i) -> Vector2:
	return IsoTile.cell_to_world(cell)

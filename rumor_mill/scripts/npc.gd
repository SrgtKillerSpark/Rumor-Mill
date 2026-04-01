extends Node2D

## npc.gd — Sprint 2 rewrite.
## Each NPC holds personality data, a rumor-slot state machine, a schedule of
## waypoints, and uses A* pathfinding to move between them each game tick.

const TILE_W := 64
const TILE_H := 32
const MOVE_SPEED := 180.0  # pixels/second

# ── Data set by World ────────────────────────────────────────────────────────
var npc_data: Dictionary = {}       # full row from npcs.json
var schedule_waypoints: Array[Vector2i] = []
var all_npcs_ref: Array = []        # reference to world's npc list (set by World)
var social_graph_ref: SocialGraph = null

# ── Schedule archetype (populated in init_from_data) ─────────────────────────
var archetype: NpcSchedule.ScheduleArchetype = NpcSchedule.ScheduleArchetype.INDEPENDENT
var work_location: String = ""
var tick_overrides: Dictionary = {}
var day_pattern_overrides: Array = []
var _home_cell: Vector2i = Vector2i.ZERO
var _last_schedule_slot: int = -1  # avoids re-pathing on every tick within the same slot

# Personality shorthands (populated in init_from_data)
var _credulity:   float = 0.5
var _sociability: float = 0.5
var _loyalty:     float = 0.5
var _temperament: float = 0.5

# ── State ────────────────────────────────────────────────────────────────────
var current_cell: Vector2i = Vector2i.ZERO
var _path: Array[Vector2i] = []          # remaining steps to next waypoint
var _waypoint_index: int = 0
var _is_moving: bool = false
var _tween: Tween = null

# rumor_id → Rumor.NpcRumorSlot
var rumor_slots: Dictionary = {}

var _pathfinder: AstarPathfinder = null
var _walkable: Array[Vector2i] = []

# ── Visuals ──────────────────────────────────────────────────────────────────
const FACTION_COLORS := {
	"merchant": Color(1.0, 0.8, 0.2),
	"noble":    Color(0.4, 0.6, 1.0),
	"clergy":   Color(0.9, 0.9, 0.9),
}

@onready var sprite: ColorRect = $Sprite
@onready var name_label: Label  = $NameLabel


func _ready() -> void:
	sprite.size     = Vector2(16, 16)
	sprite.position = Vector2(-8, -16)
	name_label.position = Vector2(-24, -30)


# ── Initialisation ───────────────────────────────────────────────────────────

func init_from_data(
		data: Dictionary,
		start_cell: Vector2i,
		walkable: Array[Vector2i],
		pathfinder: AstarPathfinder
) -> void:
	npc_data     = data
	_pathfinder  = pathfinder
	_walkable    = walkable
	current_cell = start_cell
	_home_cell   = start_cell

	_credulity   = float(data.get("credulity",   0.5))
	_sociability = float(data.get("sociability",  0.5))
	_loyalty     = float(data.get("loyalty",      0.5))
	_temperament = float(data.get("temperament",  0.5))

	archetype            = NpcSchedule.archetype_from_string(data.get("archetype", "independent"))
	work_location        = str(data.get("work_location", ""))
	tick_overrides       = data.get("tick_overrides", {})
	day_pattern_overrides = data.get("day_pattern_overrides", [])

	var faction: String = data.get("faction", "merchant")
	sprite.color = FACTION_COLORS.get(faction, Color.WHITE)
	name_label.text = data.get("name", "NPC")

	position = _cell_to_world(start_cell)
	_advance_waypoint()


# ── Per-tick entry point ─────────────────────────────────────────────────────

func on_tick(tick: int) -> void:
	_step_movement()
	_process_rumor_slots(tick)
	_update_label()


# ── Archetype schedule ───────────────────────────────────────────────────────

## Called by World before on_tick each game tick.
## gathering_points maps location code → Vector2i grid cell.
func update_tick_schedule(slot: int, day: int, gathering_points: Dictionary) -> void:
	if _is_schedule_overridden():
		return
	if slot == _last_schedule_slot:
		return  # Same slot — no re-path needed.
	_last_schedule_slot = slot

	var location_code: String = NpcSchedule.get_location(
		archetype, slot, work_location, tick_overrides, day_pattern_overrides, day
	)

	var target: Vector2i
	if location_code == "home":
		target = _home_cell
	elif gathering_points.has(location_code):
		target = gathering_points[location_code]
	else:
		return  # Unknown location code — keep current movement.

	# Update movement path toward the new tick target.
	schedule_waypoints = [target]
	_waypoint_index    = 0
	_path = _pathfinder.get_path(current_cell, target)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


func _is_schedule_overridden() -> bool:
	for slot in rumor_slots.values():
		if slot.state in [Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
			return true
	return false


# ── Movement ─────────────────────────────────────────────────────────────────

func _step_movement() -> void:
	if _is_moving:
		return  # tween still running

	if _path.is_empty():
		# Reached current waypoint; pick the next one.
		_advance_waypoint()

	if _path.is_empty():
		return  # no path available

	var next_cell: Vector2i = _path[0]
	_path.remove_at(0)
	_walk_to(next_cell)


func _advance_waypoint() -> void:
	if schedule_waypoints.is_empty():
		return
	_waypoint_index = (_waypoint_index + 1) % schedule_waypoints.size()
	var target: Vector2i = schedule_waypoints[_waypoint_index]
	_path = _pathfinder.get_path(current_cell, target)
	# Drop the first element — it's always current_cell.
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


func _walk_to(cell: Vector2i) -> void:
	if cell == current_cell:
		return
	_is_moving = true
	var world_pos := _cell_to_world(cell)
	var duration  := maxf(position.distance_to(world_pos) / MOVE_SPEED, 0.05)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", world_pos, duration).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_move_finished.bind(cell), CONNECT_ONE_SHOT)


func _on_move_finished(arrived_cell: Vector2i) -> void:
	current_cell = arrived_cell
	_is_moving   = false


# ── Rumor ingestion ──────────────────────────────────────────────────────────

func hear_rumor(rumor: Rumor, source_faction: String) -> void:
	var rid := rumor.id
	if rumor_slots.has(rid):
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		# Already in a terminal state — ignore.
		if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.REJECT,
						   Rumor.RumorState.SPREAD,  Rumor.RumorState.ACT]:
			return
		# Reinforcement: heard from another source.
		slot.heard_from_count += 1
		return

	var slot := Rumor.NpcRumorSlot.new(rumor, source_faction)
	rumor_slots[rid] = slot
	var npc_name: String = npc_data.get("name", "?")
	print("[Rumor] %s → EVALUATING '%s'" % [npc_name, rid])


# ── State machine ────────────────────────────────────────────────────────────

func _process_rumor_slots(tick: int) -> void:
	var npc_name: String = npc_data.get("name", "?")
	var faction:  String = npc_data.get("faction", "")

	for rid in rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		slot.ticks_in_state += 1

		match slot.state:
			Rumor.RumorState.EVALUATING:
				_tick_evaluating(slot, npc_name, faction, rid)

			Rumor.RumorState.BELIEVE:
				_tick_believe(slot, npc_name, faction, rid, tick)

			Rumor.RumorState.SPREAD:
				_tick_spread(slot, npc_name, faction, rid, tick)

			Rumor.RumorState.REJECT, Rumor.RumorState.ACT:
				pass  # terminal — absorbed


func _tick_evaluating(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		rid: String
) -> void:
	var rumor := slot.rumor
	var believe_chance := _credulity * rumor.current_believability

	# Same-faction source bonus.
	if slot.source_faction == faction:
		believe_chance += 0.15

	# Subject is same faction as hearer — penalty.
	# (subject_npc_id is the id string; compare faction via world lookup if needed;
	#  for Sprint 2 we just apply a heuristic based on the id prefix convention.)
	# We'll skip the lookup and just apply the rule when we can derive it.
	# This is intentionally kept simple — see Sprint 3 for richer subject lookup.

	# Corroboration bonus (max +0.30 for 3+ extra sources).
	var extra := min(slot.heard_from_count - 1, 3)
	believe_chance += extra * 0.10

	believe_chance = clamp(believe_chance, 0.0, 1.0)

	if randf() < believe_chance:
		slot.state = Rumor.RumorState.BELIEVE
		slot.ticks_in_state = 0
		print("[Rumor] %s BELIEVE '%s' (p=%.2f)" % [npc_name, rid, believe_chance])
	else:
		slot.state = Rumor.RumorState.REJECT
		slot.ticks_in_state = 0
		print("[Rumor] %s REJECT '%s' (p=%.2f)" % [npc_name, rid, believe_chance])


func _tick_believe(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		rid: String,
		_tick: int
) -> void:
	# Check ACT threshold first.
	var act_threshold: int = roundi(8.0 * (1.0 - _temperament))
	if slot.ticks_in_state >= act_threshold:
		slot.state = Rumor.RumorState.ACT
		slot.ticks_in_state = 0
		print("[Rumor] %s ACT on '%s' after %d ticks" % [npc_name, rid, act_threshold])
		return

	# Try to spread.
	var spread_chance := _sociability * 0.4
	if randf() < spread_chance:
		var target_npc := _find_spread_target(slot.rumor)
		if target_npc != null:
			target_npc.hear_rumor(slot.rumor, faction)
			slot.state = Rumor.RumorState.SPREAD
			slot.ticks_in_state = 0
			print("[Rumor] %s SPREAD '%s' → %s" % [
				npc_name, rid, target_npc.npc_data.get("name", "?")])


func _tick_spread(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		rid: String,
		_tick: int
) -> void:
	# Continue spreading each tick; check for twist.
	var spread_chance := _sociability * 0.4
	if randf() < spread_chance:
		var target_npc := _find_spread_target(slot.rumor)
		if target_npc != null:
			# Possible twist.
			var spread_rumor := slot.rumor
			if randf() < slot.rumor.mutability * 0.2:
				spread_rumor = _twist_rumor(slot.rumor, _tick)
				print("[Rumor] %s TWIST '%s' → '%s'" % [npc_name, rid, spread_rumor.id])
			target_npc.hear_rumor(spread_rumor, faction)


func _find_spread_target(rumor: Rumor) -> Node2D:
	if all_npcs_ref.is_empty():
		return null

	const SPREAD_RADIUS := 8  # tiles

	var candidates: Array = []
	for other in all_npcs_ref:
		if other == self:
			continue
		# Must be in 8-tile manhattan radius.
		var dist := (current_cell - other.current_cell).length()
		if dist > SPREAD_RADIUS:
			continue
		# Skip if already believes or spreads.
		var other_state := other.get_state_for_rumor(rumor.id)
		if other_state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
			continue
		candidates.append(other)

	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _twist_rumor(original: Rumor, tick: int) -> Rumor:
	# Sprint 2 twist: swap subject to a random NPC id.
	if all_npcs_ref.is_empty():
		return original
	var random_npc: Node2D = all_npcs_ref[randi() % all_npcs_ref.size()]
	var new_subject: String = random_npc.npc_data.get("id", original.subject_npc_id)
	var twisted := Rumor.create(
		original.id + "_t",
		new_subject,
		original.claim_type,
		original.intensity,
		original.mutability,
		tick,
		original.shelf_life_ticks,
		original.id
	)
	return twisted


# ── Query helpers ────────────────────────────────────────────────────────────

func get_state_for_rumor(rumor_id: String) -> Rumor.RumorState:
	if rumor_slots.has(rumor_id):
		return rumor_slots[rumor_id].state
	return Rumor.RumorState.UNAWARE


func get_worst_rumor_state() -> Rumor.RumorState:
	# Priority order for display: ACT > SPREAD > BELIEVE > EVALUATING > REJECT > UNAWARE
	var priority := [
		Rumor.RumorState.ACT,
		Rumor.RumorState.SPREAD,
		Rumor.RumorState.BELIEVE,
		Rumor.RumorState.EVALUATING,
		Rumor.RumorState.REJECT,
		Rumor.RumorState.UNAWARE,
	]
	for p in priority:
		for rid in rumor_slots:
			if rumor_slots[rid].state == p:
				return p
	return Rumor.RumorState.UNAWARE


# ── Label update ─────────────────────────────────────────────────────────────

func _update_label() -> void:
	var state_str := Rumor.state_name(get_worst_rumor_state())
	var short_name: String = npc_data.get("name", "NPC")
	if rumor_slots.is_empty():
		name_label.text = short_name
	else:
		name_label.text = "%s\n[%s]" % [short_name, state_str]


# ── Utility ──────────────────────────────────────────────────────────────────

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0)
	)

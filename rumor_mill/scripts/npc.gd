extends Node2D

## npc.gd — Sprint 5 update (Art Pass 1): AnimatedSprite2D, faction sprites.
## Sprint 4: full SIR diffusion model.
##
## Spread uses the β formula via PropagationEngine:
##   β = sociability_spreader × credulity_target × edge_weight × faction_mod × 2.5
## Recovery from BELIEVE uses the γ formula:
##   γ = loyalty × (1 − temperament) × 0.35
## Mutations use PropagationEngine.try_mutate() (4 independent types).
## Shelf-life expiry is detected via Rumor.is_expired() after PropagationEngine.tick_decay().
##
## Sprite sheet layout (assets/textures/npc_sprites.png, 224×144):
##   Row 0 = merchant (deep blue/gold)   Row 1 = noble (burgundy/silver)
##   Row 2 = clergy (cream/black)
##   Cols 0-2 = idle frames (32×48 each); Cols 3-6 = walk frames

const TILE_W := 64
const TILE_H := 32
const MOVE_SPEED := 180.0  # pixels/second
const SPREAD_RADIUS := 8   # tiles (manhattan distance)

# ── Data set by World ────────────────────────────────────────────────────────
var npc_data: Dictionary = {}
var schedule_waypoints: Array[Vector2i] = []
var all_npcs_ref: Array = []
var social_graph_ref: SocialGraph = null
var propagation_engine_ref: PropagationEngine = null

# ── Schedule archetype ───────────────────────────────────────────────────────
var archetype: NpcSchedule.ScheduleArchetype = NpcSchedule.ScheduleArchetype.INDEPENDENT
var work_location: String = ""
var tick_overrides: Dictionary = {}
var day_pattern_overrides: Array = []
var _home_cell: Vector2i = Vector2i.ZERO
var _last_schedule_slot: int = -1

# Personality shorthands
var _credulity:   float = 0.5
var _sociability: float = 0.5
var _loyalty:     float = 0.5
var _temperament: float = 0.5

# ── State ────────────────────────────────────────────────────────────────────
var current_cell: Vector2i = Vector2i.ZERO
var _path: Array[Vector2i] = []
var _waypoint_index: int = 0
var _is_moving: bool = false
var _tween: Tween = null

# rumor_id → Rumor.NpcRumorSlot
var rumor_slots: Dictionary = {}

var _pathfinder: AstarPathfinder = null
var _walkable: Array[Vector2i] = []

# ── Visuals ──────────────────────────────────────────────────────────────────
# Faction row index in npc_sprites.png
const FACTION_ROW := {
	"merchant": 0,
	"noble":    1,
	"clergy":   2,
}
# Sprite frame dimensions
const SPRITE_W := 32
const SPRITE_H := 48

@onready var sprite:     AnimatedSprite2D = $Sprite
@onready var name_label: Label            = $NameLabel

var _faction: String = "merchant"


func _ready() -> void:
	pass  # sprite setup deferred to init_from_data after faction is known


# ── Sprite setup ─────────────────────────────────────────────────────────────

func _setup_sprite(faction: String) -> void:
	var tex := load("res://assets/textures/npc_sprites.png") as Texture2D
	if tex == null:
		push_warning("NPC: npc_sprites.png not found; falling back to placeholder")
		return

	var row: int = FACTION_ROW.get(faction, 0)
	var frames := SpriteFrames.new()

	# ── idle animation (3 frames at 4 fps) ───────────────────────────────────
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_loop("idle", true)
	for col in range(3):
		var at := AtlasTexture.new()
		at.atlas  = tex
		at.region = Rect2(col * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)
		frames.add_frame("idle", at)

	# ── walk animation (4 frames at 8 fps) ───────────────────────────────────
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for col in range(3, 7):
		var at := AtlasTexture.new()
		at.atlas  = tex
		at.region = Rect2(col * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)
		frames.add_frame("walk", at)

	sprite.sprite_frames = frames
	sprite.play("idle")


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

	archetype             = NpcSchedule.archetype_from_string(data.get("archetype", "independent"))
	work_location         = str(data.get("work_location", ""))
	tick_overrides        = data.get("tick_overrides", {})
	day_pattern_overrides = data.get("day_pattern_overrides", [])

	var faction: String = data.get("faction", "merchant")
	_faction = faction
	_setup_sprite(faction)
	name_label.text = data.get("name", "NPC")

	position = _cell_to_world(start_cell)
	_advance_waypoint()


# ── Per-tick entry point ─────────────────────────────────────────────────────

func on_tick(tick: int) -> void:
	_step_movement()
	_process_rumor_slots(tick)
	_update_label()


# ── Archetype schedule ───────────────────────────────────────────────────────

func update_tick_schedule(slot: int, day: int, gathering_points: Dictionary) -> void:
	if _is_schedule_overridden():
		return
	if slot == _last_schedule_slot:
		return
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
		return

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
		return

	if _path.is_empty():
		_advance_waypoint()

	if _path.is_empty():
		return

	var next_cell: Vector2i = _path[0]
	_path.remove_at(0)
	_walk_to(next_cell)


func _advance_waypoint() -> void:
	if schedule_waypoints.is_empty():
		return
	_waypoint_index = (_waypoint_index + 1) % schedule_waypoints.size()
	var target: Vector2i = schedule_waypoints[_waypoint_index]
	_path = _pathfinder.get_path(current_cell, target)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


func _walk_to(cell: Vector2i) -> void:
	if cell == current_cell:
		return
	_is_moving = true
	if sprite.sprite_frames != null:
		sprite.play("walk")
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
	if sprite.sprite_frames != null:
		sprite.play("idle")


# ── Rumor ingestion ──────────────────────────────────────────────────────────

func hear_rumor(rumor: Rumor, source_faction: String) -> void:
	var rid := rumor.id

	# Register with the engine so it decays and appears in the lineage tree.
	if propagation_engine_ref != null:
		propagation_engine_ref.register_rumor(rumor)

	if rumor_slots.has(rid):
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.REJECT,
						   Rumor.RumorState.SPREAD,  Rumor.RumorState.ACT,
						   Rumor.RumorState.EXPIRED]:
			return
		# Reinforcement from another source.
		slot.heard_from_count += 1
		return

	var slot := Rumor.NpcRumorSlot.new(rumor, source_faction)
	rumor_slots[rid] = slot
	if OS.is_debug_build():
		print("[Rumor] %s → EVALUATING '%s'" % [npc_data.get("name", "?"), rid])


# ── State machine ────────────────────────────────────────────────────────────

func _process_rumor_slots(tick: int) -> void:
	var npc_name: String = npc_data.get("name", "?")
	var faction:  String = npc_data.get("faction", "")

	for rid in rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		slot.ticks_in_state += 1

		# ── Shelf-life expiry check ──────────────────────────────────────────
		# PropagationEngine.tick_decay() is called before on_tick(); check result here.
		if slot.rumor.is_expired() and slot.state not in [
				Rumor.RumorState.REJECT, Rumor.RumorState.ACT, Rumor.RumorState.EXPIRED]:
			slot.state = Rumor.RumorState.EXPIRED
			slot.ticks_in_state = 0
			if OS.is_debug_build():
				print("[Rumor] %s EXPIRED '%s' (believability decayed to 0)" % [npc_name, rid])
			continue

		match slot.state:
			Rumor.RumorState.EVALUATING:
				_tick_evaluating(slot, npc_name, faction, rid)

			Rumor.RumorState.BELIEVE:
				_tick_believe(slot, npc_name, faction, rid, tick)

			Rumor.RumorState.SPREAD:
				_tick_spread(slot, npc_name, faction, rid, tick)

			Rumor.RumorState.REJECT, Rumor.RumorState.ACT, Rumor.RumorState.EXPIRED:
				pass  # terminal states


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

	# Corroboration bonus (max +0.30 for 3+ extra sources).
	var extra := min(slot.heard_from_count - 1, 3)
	believe_chance += extra * 0.10

	believe_chance = clamp(believe_chance, 0.0, 1.0)

	if randf() < believe_chance:
		slot.state = Rumor.RumorState.BELIEVE
		slot.ticks_in_state = 0
		if OS.is_debug_build():
			print("[Rumor] %s BELIEVE '%s' (p=%.2f)" % [npc_name, rid, believe_chance])
	else:
		slot.state = Rumor.RumorState.REJECT
		slot.ticks_in_state = 0
		if OS.is_debug_build():
			print("[Rumor] %s REJECT '%s' (p=%.2f)" % [npc_name, rid, believe_chance])


func _tick_believe(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		rid: String,
		tick: int
) -> void:
	# ── γ: recovery check — NPC may forget/reject the rumor ──────────────────
	if propagation_engine_ref != null:
		var gamma := propagation_engine_ref.calc_gamma(_loyalty, _temperament)
		if randf() < gamma:
			slot.state = Rumor.RumorState.REJECT
			slot.ticks_in_state = 0
			if OS.is_debug_build():
				print("[Rumor] %s RECOVERED (REJECT) '%s' (γ=%.2f)" % [npc_name, rid, gamma])
			return

	# ── ACT threshold ────────────────────────────────────────────────────────
	var act_threshold: int = roundi(8.0 * (1.0 - _temperament))
	if slot.ticks_in_state >= act_threshold:
		slot.state = Rumor.RumorState.ACT
		slot.ticks_in_state = 0
		if OS.is_debug_build():
			print("[Rumor] %s ACT on '%s' after %d ticks" % [npc_name, rid, act_threshold])
		return

	# ── β: spread attempt to each nearby neighbour ───────────────────────────
	if _spread_to_neighbours(slot, faction, tick):
		slot.state = Rumor.RumorState.SPREAD
		slot.ticks_in_state = 0


func _tick_spread(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		_rid: String,
		tick: int
) -> void:
	# Continue spreading each tick.
	_spread_to_neighbours(slot, faction, tick)


# ── β spread helper ───────────────────────────────────────────────────────────

## Attempt to spread slot.rumor to each nearby NPC using the β formula.
## Returns true if at least one NPC received the rumor this tick.
func _spread_to_neighbours(
		slot: Rumor.NpcRumorSlot,
		spreader_faction: String,
		tick: int
) -> bool:
	if all_npcs_ref.is_empty():
		return false

	var npc_id: String = npc_data.get("id", "")
	var neighbours: Dictionary = {}
	if social_graph_ref != null:
		neighbours = social_graph_ref.get_neighbours(npc_id)

	var spread_happened := false

	for other in all_npcs_ref:
		if other == self:
			continue

		# Proximity gate: compare squared lengths to avoid sqrt().
		var dist_sq := (current_cell - other.current_cell).length_squared()
		if dist_sq > SPREAD_RADIUS * SPREAD_RADIUS:
			continue

		# Skip if already in a non-receptive state.
		var other_state := other.get_state_for_rumor(slot.rumor.id)
		if other_state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD,
						   Rumor.RumorState.ACT,    Rumor.RumorState.EXPIRED]:
			continue

		# Determine edge weight (0 fallback = no direct social connection).
		var tid: String = other.npc_data.get("id", "")
		var edge_w: float = neighbours.get(tid, 0.2)  # 0.2 floor for proximity-only contacts

		var t_credulity: float = float(other.npc_data.get("credulity", 0.5))
		var t_faction:   String = other.npc_data.get("faction", "")

		# β formula.
		var beta: float
		if propagation_engine_ref != null:
			beta = propagation_engine_ref.calc_beta(
				_sociability, t_credulity, edge_w, spreader_faction, t_faction
			)
		else:
			beta = _sociability * t_credulity * edge_w * 2.5

		if randf() >= beta:
			continue

		# Roll mutations before passing the rumor on.
		var spread_rumor := slot.rumor
		if propagation_engine_ref != null:
			spread_rumor = propagation_engine_ref.try_mutate(slot.rumor, tick, all_npcs_ref)

		other.hear_rumor(spread_rumor, spreader_faction)
		spread_happened = true

	return spread_happened


# ── Query helpers ────────────────────────────────────────────────────────────

func get_state_for_rumor(rumor_id: String) -> Rumor.RumorState:
	if rumor_slots.has(rumor_id):
		return rumor_slots[rumor_id].state
	return Rumor.RumorState.UNAWARE


func get_worst_rumor_state() -> Rumor.RumorState:
	# Priority order for display: ACT > SPREAD > BELIEVE > EVALUATING > REJECT > EXPIRED > UNAWARE
	var priority := [
		Rumor.RumorState.ACT,
		Rumor.RumorState.SPREAD,
		Rumor.RumorState.BELIEVE,
		Rumor.RumorState.EVALUATING,
		Rumor.RumorState.REJECT,
		Rumor.RumorState.EXPIRED,
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

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
## Sprite sheet layout (assets/textures/npc_sprites.png, 224×240):
##   Row 0 = merchant (deep blue/gold)   Row 1 = noble (burgundy/silver)
##   Row 2 = clergy (cream/black)
##   Row 3 = guard   (stone tabard/helmet — archetype "guard_civic")
##   Row 4 = commoner (drab linen — craftsmen, laborers, etc.)
##   Cols 0-2 = idle frames (32×48 each); Cols 3-6 = walk frames

## Emitted once when this NPC first receives a rumor (UNAWARE → EVALUATING).
signal first_npc_became_evaluating

## Emitted whenever this NPC's worst rumor state changes (for journal + overlay).
signal rumor_state_changed(npc_name: String, new_state_name: String, rumor_id: String)

## Emitted when this NPC successfully transmits a rumor to another NPC.
signal rumor_transmitted(from_name: String, to_name: String, rumor_id: String)

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
# Faction row index in npc_sprites.png (rows 0-2)
const FACTION_ROW := {
	"merchant": 0,
	"noble":    1,
	"clergy":   2,
}
# Archetype overrides — these rows take priority over faction (rows 3-4)
const ARCHETYPE_ROW := {
	"guard_civic": 3,
}
# Roles that map to the commoner archetype row (row 4)
const COMMONER_ROLES := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
# Sprite frame dimensions
const SPRITE_W := 32
const SPRITE_H := 48

@onready var sprite:     AnimatedSprite2D = $Sprite
@onready var name_label: Label            = $NameLabel

var _faction: String = "merchant"

# Sprite modulate tints per worst rumor state — subtle colour shifts so the
# player can read NPC state at a glance without squinting at the state badge.
const STATE_TINT := {
	Rumor.RumorState.UNAWARE:    Color(1.00, 1.00, 1.00, 1.0),  # normal
	Rumor.RumorState.EVALUATING: Color(1.00, 1.00, 0.70, 1.0),  # warm yellow
	Rumor.RumorState.BELIEVE:    Color(0.70, 1.00, 0.72, 1.0),  # soft green
	Rumor.RumorState.SPREAD:     Color(1.00, 0.75, 0.45, 1.0),  # orange
	Rumor.RumorState.ACT:          Color(1.00, 0.55, 0.90, 1.0),  # magenta-pink
	Rumor.RumorState.REJECT:       Color(0.80, 0.80, 0.85, 1.0),  # cool grey-blue
	Rumor.RumorState.CONTRADICTED: Color(0.75, 0.55, 1.00, 1.0),  # muted purple
	Rumor.RumorState.EXPIRED:      Color(0.65, 0.65, 0.65, 1.0),  # grey
}

# Tracks last worst state so we only emit rumor_state_changed on actual changes.
var _last_worst_state: Rumor.RumorState = Rumor.RumorState.UNAWARE


func _ready() -> void:
	pass  # sprite setup deferred to init_from_data after faction is known


# ── Sprite setup ─────────────────────────────────────────────────────────────

func _setup_sprite(faction: String) -> void:
	var tex := load("res://assets/textures/npc_sprites.png") as Texture2D
	if tex == null:
		push_warning("NPC: npc_sprites.png not found; falling back to placeholder")
		return

	# Archetype overrides faction: guards use row 3, commoners row 4.
	var npc_archetype: String = npc_data.get("archetype", "")
	var npc_role: String = npc_data.get("role", "")
	var row: int
	if ARCHETYPE_ROW.has(npc_archetype):
		row = ARCHETYPE_ROW[npc_archetype]
	elif npc_role in COMMONER_ROLES:
		row = 4
	else:
		row = FACTION_ROW.get(faction, 0)
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
	emit_signal("first_npc_became_evaluating")
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

			Rumor.RumorState.REJECT, Rumor.RumorState.ACT, \
			Rumor.RumorState.CONTRADICTED, Rumor.RumorState.EXPIRED:
				pass  # terminal states

	# ── Post-pass: detect CONTRADICTED (conflicting sentiments for same subject) ──
	var active_by_subject: Dictionary = {}  # subject_npc_id -> Array[NpcRumorSlot]
	for rid in rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD]:
			var sid: String = slot.rumor.subject_npc_id
			if not active_by_subject.has(sid):
				active_by_subject[sid] = []
			active_by_subject[sid].append(slot)

	for sid in active_by_subject:
		var slots_for_subject: Array = active_by_subject[sid]
		var has_positive := false
		var has_negative := false
		for sl in slots_for_subject:
			if Rumor.is_positive_claim(sl.rumor.claim_type):
				has_positive = true
			else:
				has_negative = true
		if has_positive and has_negative:
			# Transition the newest slot to CONTRADICTED.
			var newest: Rumor.NpcRumorSlot = slots_for_subject[0]
			for sl in slots_for_subject:
				if sl.rumor.created_tick > newest.rumor.created_tick:
					newest = sl
			if newest.state != Rumor.RumorState.CONTRADICTED:
				newest.state = Rumor.RumorState.CONTRADICTED
				newest.ticks_in_state = 0
				if OS.is_debug_build():
					print("[Rumor] %s CONTRADICTED for subject '%s'" % [npc_name, sid])


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
		_start_act_behavior(slot.rumor)
		return

	# ── β: spread attempt to each nearby neighbour ───────────────────────────
	if _spread_to_neighbours(slot, faction, tick):
		slot.state = Rumor.RumorState.SPREAD
		slot.ticks_in_state = 0
		_start_spread_clustering(slot.rumor)


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

		# Visual: show a floating speech bubble from this NPC toward the target.
		_show_spread_bubble(other)
		emit_signal("rumor_transmitted",
			npc_data.get("name", "?"),
			other.npc_data.get("name", "?"),
			spread_rumor.id)

	return spread_happened


# ── Spread bubble ────────────────────────────────────────────────────────────

## Spawns a small floating speech-bubble Label above this NPC that drifts up
## and fades out over ~1.5 seconds, indicating rumor transmission.
func _show_spread_bubble(_target_npc: Node2D) -> void:
	var lbl := Label.new()
	lbl.text = "💬"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-8.0, -60.0)  # start just above the NPC sprite
	lbl.modulate = Color(1.0, 0.85, 0.3, 1.0)
	add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -24.0), 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.chain().tween_callback(lbl.queue_free)


# ── ACT / SPREAD behavior ─────────────────────────────────────────────────────

## Called when this NPC enters ACT state.  Shows a pulsing ⚡ icon and navigates
## relative to the rumor's subject: flee if negative claim, seek if positive.
func _start_act_behavior(rumor: Rumor) -> void:
	_show_act_icon()
	var positive := Rumor.is_positive_claim(rumor.claim_type)
	_navigate_relative_to_subject(rumor.subject_npc_id, positive)


## Pulsing ⚡ label above the NPC for ~2 seconds — signals ACT state onset.
func _show_act_icon() -> void:
	var lbl := Label.new()
	lbl.text = "⚡"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(-8.0, -76.0)
	lbl.modulate = Color(1.0, 0.85, 0.1, 1.0)
	add_child(lbl)
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_property(lbl, "modulate:a", 0.2, 0.35)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.chain().tween_callback(lbl.queue_free)


## Move toward or away from subject_id depending on sentiment.
## toward=true → seek (praise); toward=false → flee (accusation / scandal etc.)
func _navigate_relative_to_subject(subject_id: String, toward: bool) -> void:
	if _pathfinder == null or _walkable.is_empty():
		return
	var subject_cell := Vector2i(-1, -1)
	for npc in all_npcs_ref:
		if npc.npc_data.get("id", "") == subject_id:
			subject_cell = npc.current_cell
			break
	if subject_cell == Vector2i(-1, -1):
		return
	var target_cell: Vector2i = subject_cell if toward else _cell_furthest_from(subject_cell)
	_path = _pathfinder.get_path(current_cell, target_cell)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


## Return the walkable cell that maximises squared distance from from_cell.
func _cell_furthest_from(from_cell: Vector2i) -> Vector2i:
	var best_cell := current_cell
	var best_dist := 0
	for cell in _walkable:
		var d := (cell - from_cell).length_squared()
		if d > best_dist:
			best_dist = d
			best_cell = cell
	return best_cell


## Called when entering SPREAD state.  Move toward the nearest other NPC who is
## also BELIEVE or SPREAD for the same rumor — visible social clustering.
func _start_spread_clustering(rumor: Rumor) -> void:
	if _pathfinder == null:
		return
	var best: Node2D = null
	var best_dist := INF
	for other in all_npcs_ref:
		if other == self:
			continue
		var s := other.get_state_for_rumor(rumor.id)
		if s in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD]:
			var d := float((other.current_cell - current_cell).length_squared())
			if d < best_dist:
				best_dist = d
				best = other
	if best == null:
		return
	_path = _pathfinder.get_path(current_cell, best.current_cell)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


# ── Query helpers ────────────────────────────────────────────────────────────

func get_state_for_rumor(rumor_id: String) -> Rumor.RumorState:
	if rumor_slots.has(rumor_id):
		return rumor_slots[rumor_id].state
	return Rumor.RumorState.UNAWARE


func get_worst_rumor_state() -> Rumor.RumorState:
	# Priority order for display: ACT > SPREAD > CONTRADICTED > BELIEVE > EVALUATING > REJECT > EXPIRED > UNAWARE
	var priority := [
		Rumor.RumorState.ACT,
		Rumor.RumorState.SPREAD,
		Rumor.RumorState.CONTRADICTED,
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
	var worst := get_worst_rumor_state()
	var state_str := Rumor.state_name(worst)
	var short_name: String = npc_data.get("name", "NPC")
	if rumor_slots.is_empty():
		name_label.text = short_name
	else:
		name_label.text = "%s\n[%s]" % [short_name, state_str]

	# Apply sprite tint based on worst rumor state.
	if sprite != null and sprite.sprite_frames != null:
		var tint: Color = STATE_TINT.get(worst, Color.WHITE)
		sprite.modulate = tint

	# Emit state-change signal so the journal + overlay can react.
	if worst != _last_worst_state:
		_last_worst_state = worst
		# Find the rumor_id that corresponds to the worst state.
		var wrid := ""
		for rid in rumor_slots:
			if rumor_slots[rid].state == worst:
				wrid = rid
				break
		emit_signal("rumor_state_changed", short_name, state_str, wrid)


# ── Utility ──────────────────────────────────────────────────────────────────

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0)
	)

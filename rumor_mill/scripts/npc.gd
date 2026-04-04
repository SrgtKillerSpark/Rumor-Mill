extends Node2D

## npc.gd — Sprint 5 update (Art Pass 2 / SPA-99): heat shimmer VFX, coin bribe flash.
## Sprint 5: AnimatedSprite2D, faction sprites, heat/bribery visual polish.
## Sprint 4: full SIR diffusion model.
##
## Spread uses the β formula via PropagationEngine:
##   β = sociability_spreader × credulity_target × edge_weight × faction_mod × 1.8
## Recovery from BELIEVE uses the γ formula:
##   γ = loyalty × (1 − temperament) × 0.30
## Mutations use PropagationEngine.try_mutate() (4 independent types).
## Shelf-life expiry is detected via Rumor.is_expired() after PropagationEngine.tick_decay().
##
## Sprite sheet layout (assets/textures/npc_sprites.png, 224×288):
##   Row 0 = merchant (deep blue/gold)   Row 1 = noble (burgundy/silver)
##   Row 2 = clergy (cream/black)
##   Row 3 = guard   (stone tabard/helmet — archetype "guard_civic")
##   Row 4 = commoner (drab linen — craftsmen, laborers, etc.)
##   Row 5 = tavern_staff (apron, warm amber — archetype "tavern_staff")
##   Cols 0-2 = idle frames (32×48 each); Cols 3-6 = walk frames

## Emitted once when this NPC first receives a rumor (UNAWARE → EVALUATING).
signal first_npc_became_evaluating

## Emitted whenever this NPC's worst rumor state changes (for journal + overlay).
signal rumor_state_changed(npc_name: String, new_state_name: String, rumor_id: String)

## Emitted when this NPC successfully transmits a rumor to another NPC.
signal rumor_transmitted(from_name: String, to_name: String, rumor_id: String)

## Emitted when this NPC enters ACT state and mutates a social graph edge.
signal graph_edge_mutated(actor_name: String, subject_name: String, delta: float)

## Emitted when the player's mouse enters/exits this NPC's hover area.
signal npc_hovered(npc: Node2D)
signal npc_unhovered()

const TILE_W := 64
const TILE_H := 32
const MOVE_SPEED := 180.0  # pixels/second
const SPREAD_RADIUS := 8   # tiles (manhattan distance)

# ── Data set by World ────────────────────────────────────────────────────────
var npc_data: Dictionary = {}
var schedule_waypoints: Array[Vector2i] = []
var all_npcs_ref: Array = []:
	set(value):
		all_npcs_ref = value
		_rebuild_npc_id_dict()
## NPC id → NPC node; rebuilt whenever all_npcs_ref is assigned. Gives O(1) subject lookups.
var _npc_id_dict: Dictionary = {}
## Pre-sampled subset of _walkable for _cell_furthest_from (avoids scanning ~1000 cells).
var _walkable_sample: Array[Vector2i] = []
var social_graph_ref: SocialGraph = null
var propagation_engine_ref: PropagationEngine = null

# ── Schedule archetype ───────────────────────────────────────────────────────
var archetype: NpcSchedule.ScheduleArchetype = NpcSchedule.ScheduleArchetype.INDEPENDENT
var work_location: String = ""
var tick_overrides: Dictionary = {}
var day_pattern_overrides: Array = []
var _home_cell: Vector2i = Vector2i.ZERO
var _last_schedule_slot: int = -1
## Current schedule location code (e.g. "market", "tavern", "home").
## Updated each time the NPC's schedule slot changes. Used by RivalAgent.
var current_location_code: String = ""

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
## Dirty flag: set true whenever rumor_slots content or _is_defending changes.
## get_worst_rumor_state() uses this to skip recomputation when nothing changed.
var _worst_state_dirty: bool = true
var _worst_state_cache: Rumor.RumorState = Rumor.RumorState.UNAWARE

var _pathfinder: AstarPathfinder = null
var _walkable: Array[Vector2i] = []
var _flash_tween: Tween = null
var _base_color: Color = Color.WHITE

# ── Visuals ──────────────────────────────────────────────────────────────────
# Faction row index in npc_sprites.png (rows 0-2)
const FACTION_ROW := {
	"merchant": 0,
	"noble":    1,
	"clergy":   2,
}
# Archetype overrides — these rows take priority over faction (rows 3-5)
const ARCHETYPE_ROW := {
	"guard_civic":  3,
	"tavern_staff": 5,
}
# Roles that map to the commoner archetype row (row 4)
const COMMONER_ROLES := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
# Sprite frame dimensions
const SPRITE_W := 32
const SPRITE_H := 48

@onready var sprite:      AnimatedSprite2D = $Sprite
@onready var name_label:  Label            = $NameLabel
@onready var hover_area:  Area2D           = $HoverArea

var _faction: String = "merchant"

# ── Defender state (NPC-level, not per rumor slot) ───────────────────────────
var _is_defending:            bool   = false
var _defender_target_npc_id:  String = ""
var _defender_ticks_remaining: int   = 0
const _DEFENDER_PENALTY:      float  = 0.15
const _DEFENDER_DURATION:     int    = 5
const _DEFENSE_PENALTY_CAP:   float  = 0.30

# subject_npc_id → float (accumulated penalty applied to this NPC's credulity)
var _defense_modifiers: Dictionary = {}
# subject_npc_id → int (ticks remaining before penalty expires)
var _defense_modifier_ticks: Dictionary = {}
const _DEFENSE_MOD_DURATION: int = 3

# ── Rumor memory & relationship consequence tracking ──────────────────────────
# Each entry: { "rumor_id": str, "subject_id": str, "claim_type": int,
#               "outcome": str ("believed"|"act"|"rejected"), "tick": int }
var rumor_history: Array = []
# Subject NPC ids whose work-location this NPC will avoid after believing
# a negative rumor about them.  Entries persist for the whole run.
var _avoided_subject_ids: Array[String] = []
# Cumulative credulity modifier from memory consequences.  Drives both
# _credulity and npc_data["credulity"] so the change is visible everywhere.
var _credulity_modifier:       float = 0.0
const _CREDULITY_MODIFIER_FLOOR: float = -0.15   # rejection penalty cap
const _CREDULITY_ACT_GAIN:       float =  0.10   # reward for acting on a rumor
const _CREDULITY_REJECT_PENALTY: float = -0.05   # penalty per rejection

# Minimum ticks an NPC must spend in EVALUATING before the believe/reject
# roll fires.  Gives corroboration time to arrive and makes early rumor
# seeding less coin-flippy.
const _MIN_EVAL_TICKS: int = 3

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
	Rumor.RumorState.DEFENDING:    Color(0.50, 0.80, 1.00, 1.0),  # sky blue
}

# Tracks last worst state so we only emit rumor_state_changed on actual changes.
var _last_worst_state: Rumor.RumorState = Rumor.RumorState.UNAWARE

# Hover tint applied directly to sprite.modulate while this NPC is hovered.
# Keeping it on the sprite (not the parent modulate) prevents compounding with
# the parent node's modulate, which would muddy state colours.
const NPC_HOVER_TINT := Color(1.5, 1.3, 0.5, 1.0)
var _hovered: bool = false

# ── Heat shimmer state ───────────────────────────────────────────────────────
# The heat shimmer oscillates sprite.modulate in _process() between the state
# tint and a warm red/orange glow, signalling that this NPC is suspicious/wary.
# _cached_state_tint is refreshed each game tick by _update_label().
var _cached_state_tint: Color = Color.WHITE
var _heat_pulse_phase:  float = 0.0

# ── Speech bubble system ──────────────────────────────────────────────────────
## Dialogue lines loaded once from data/npc_dialogue.json (shared across all NPCs).
static var _dialogue_data:   Dictionary = {}
static var _dialogue_loaded: bool       = false
## Global count of bubbles currently visible; capped at _MAX_BUBBLES.
static var _active_bubbles:  int        = 0
const  _MAX_BUBBLES:         int        = 2

## Key into _dialogue_data for this NPC (matches npc_data["id"]).
var _npc_dialogue_key:     String = ""
## Ticks until this NPC next shows an idle ambient line.
var _idle_bubble_cooldown: int    = 0
## True while this NPC owns a visible bubble (prevents double-show).
var _has_bubble:           bool   = false


## Load npc_dialogue.json once; subsequent calls are no-ops.
static func _load_dialogue_db() -> void:
	if _dialogue_loaded:
		return
	var f := FileAccess.open("res://data/npc_dialogue.json", FileAccess.READ)
	if f == null:
		_dialogue_loaded = true
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("npc_dialogue"):
		_dialogue_data = parsed["npc_dialogue"]
	_dialogue_loaded = true


func _ready() -> void:
	# sprite setup deferred to init_from_data after faction is known
	if hover_area != null:
		hover_area.mouse_entered.connect(_on_hover_enter)
		hover_area.mouse_exited.connect(_on_hover_exit)


func _on_hover_enter() -> void:
	npc_hovered.emit(self)


func _on_hover_exit() -> void:
	npc_unhovered.emit()


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

func _rebuild_npc_id_dict() -> void:
	_npc_id_dict.clear()
	for npc in all_npcs_ref:
		var nid: String = npc.npc_data.get("id", "")
		if nid != "":
			_npc_id_dict[nid] = npc


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

	# Pre-sample walkable cells so _cell_furthest_from avoids a full ~1000-cell scan.
	_walkable_sample = walkable.duplicate()
	_walkable_sample.shuffle()
	if _walkable_sample.size() > 64:
		_walkable_sample.resize(64)

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

	# Speech bubble setup — stagger initial cooldown so NPCs don't all talk at once.
	_npc_dialogue_key     = data.get("id", "")
	_load_dialogue_db()
	_idle_bubble_cooldown = randi_range(0, 50)


# ── Per-tick entry point ─────────────────────────────────────────────────────

func on_tick(tick: int) -> void:
	_step_movement()
	_process_rumor_slots(tick)
	_tick_defender(tick)
	# Idle ambient bubble — fires every 30-60 ticks, staggered per NPC.
	_idle_bubble_cooldown -= 1
	if _idle_bubble_cooldown <= 0:
		_idle_bubble_cooldown = randi_range(30, 60)
		_show_dialogue_bubble("ambient")
	_tick_defense_modifiers()
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
	location_code = _reroute_if_avoided(location_code)
	current_location_code = location_code

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
	# Flip sprite to face direction of travel.
	var dx := world_pos.x - position.x
	if abs(dx) > 1.0 and sprite.sprite_frames != null:
		sprite.flip_h = dx < 0
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
	_worst_state_dirty = true
	emit_signal("first_npc_became_evaluating")


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
			_worst_state_dirty = true
			continue

		match slot.state:
			Rumor.RumorState.EVALUATING:
				_tick_evaluating(slot, npc_name, faction, rid, tick)

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
				_worst_state_dirty = true


func _tick_evaluating(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		rid: String,
		tick: int
) -> void:
	# Minimum dwell time: let corroboration accumulate before rolling.
	if slot.ticks_in_state < _MIN_EVAL_TICKS:
		return

	var rumor := slot.rumor
	var effective_credulity := _credulity

	# Defense penalty: reduce credulity if a neighbor is defending the rumor's subject.
	var subject_id: String = rumor.subject_npc_id
	if _defense_modifiers.has(subject_id):
		effective_credulity = maxf(effective_credulity - _defense_modifiers[subject_id], 0.0)

	var believe_chance := effective_credulity * rumor.current_believability

	# Same-faction source bonus.
	if slot.source_faction == faction:
		believe_chance += 0.15

	# Corroboration bonus (max +0.30 for 3+ extra sources).
	var extra: int = min(slot.heard_from_count - 1, 3)
	believe_chance += extra * 0.10

	believe_chance = clamp(believe_chance, 0.0, 1.0)

	if randf() < believe_chance:
		slot.state = Rumor.RumorState.BELIEVE
		slot.ticks_in_state = 0
		_record_rumor_history(rumor, subject_id, "believed", tick)
		_update_schedule_avoidance(rumor)
	else:
		slot.state = Rumor.RumorState.REJECT
		slot.ticks_in_state = 0
		# High-loyalty NPCs who reject a negative rumor about a close ally enter DEFENDING.
		if _loyalty > 0.7 and not Rumor.is_positive_claim(rumor.claim_type) \
				and not _is_defending:
			_is_defending = true
			_worst_state_dirty = true
			_defender_target_npc_id = subject_id
			_defender_ticks_remaining = _DEFENDER_DURATION
			emit_signal("rumor_state_changed", npc_name, "DEFENDING", rid)
		_record_rumor_history(rumor, subject_id, "rejected", tick)
		_apply_credulity_modifier(_CREDULITY_REJECT_PENALTY)


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
			return

	# ── ACT threshold ────────────────────────────────────────────────────────
	var act_threshold: int = roundi(8.0 * (1.0 - _temperament))
	if slot.ticks_in_state >= act_threshold:
		slot.state = Rumor.RumorState.ACT
		slot.ticks_in_state = 0
		_start_act_behavior(slot.rumor, tick)
		_record_rumor_history(slot.rumor, slot.rumor.subject_npc_id, "act", tick)
		_apply_credulity_modifier(_CREDULITY_ACT_GAIN)
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
		var dist_sq: int = (current_cell - (other.current_cell as Vector2i)).length_squared()
		if dist_sq > SPREAD_RADIUS * SPREAD_RADIUS:
			continue

		# Skip if already in a non-receptive state.
		var other_state: Rumor.RumorState = other.get_state_for_rumor(slot.rumor.id)
		if other_state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD,
						   Rumor.RumorState.ACT,    Rumor.RumorState.EXPIRED]:
			continue

		# Determine edge weight (0 fallback = no direct social connection).
		var tid: String = other.npc_data.get("id", "")
		var edge_w: float = neighbours.get(tid, 0.2)  # 0.2 floor for proximity-only contacts

		var t_credulity: float = float(other.npc_data.get("credulity", 0.5))
		var t_faction:   String = other.npc_data.get("faction", "")

		# Heat modifier: wary/suspicious targets are harder to convince.
		var heat_mod := 0.0
		if propagation_engine_ref != null and propagation_engine_ref.intel_store_ref != null \
				and propagation_engine_ref.intel_store_ref.heat_enabled:
			var h := propagation_engine_ref.intel_store_ref.get_heat(tid)
			if h >= 75.0:
				heat_mod = 0.30
			elif h >= 50.0:
				heat_mod = 0.15

		# β formula.
		var beta: float
		if propagation_engine_ref != null:
			beta = propagation_engine_ref.calc_beta(
				_sociability, t_credulity, edge_w, spreader_faction, t_faction, heat_mod
			)
		else:
			beta = _sociability * t_credulity * edge_w * 1.8

		if randf() >= beta:
			continue

		# Roll mutations before passing the rumor on.
		var spread_rumor := slot.rumor
		if propagation_engine_ref != null:
			spread_rumor = propagation_engine_ref.try_mutate(slot.rumor, tick, all_npcs_ref)

		other.hear_rumor(spread_rumor, spreader_faction)
		spread_happened = true

		# Relay heat: +2 to this NPC (spreader) if rumor traces to a player seed.
		if propagation_engine_ref != null:
			propagation_engine_ref.apply_relay_heat(npc_id, spread_rumor.id)

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
## Also mutates the social graph edge between actor and subject.
func _start_act_behavior(rumor: Rumor, tick: int) -> void:
	_show_act_icon()
	var positive := Rumor.is_positive_claim(rumor.claim_type)
	_navigate_relative_to_subject(rumor.subject_npc_id, positive)

	# Determine edge delta from claim type.
	var delta: float = 0.0
	match rumor.claim_type:
		Rumor.ClaimType.ACCUSATION, Rumor.ClaimType.SCANDAL, \
		Rumor.ClaimType.HERESY, Rumor.ClaimType.ILLNESS, \
		Rumor.ClaimType.BLACKMAIL, Rumor.ClaimType.SECRET_ALLIANCE, \
		Rumor.ClaimType.FORBIDDEN_ROMANCE:
			delta = -0.15
		Rumor.ClaimType.PRAISE:
			delta = 0.10
		# PROPHECY, DEATH: no graph mutation.

	if delta != 0.0 and social_graph_ref != null:
		var actor_id: String = npc_data.get("id", "")
		social_graph_ref.mutate_edge(actor_id, rumor.subject_npc_id, delta, tick)
		social_graph_ref.mutate_edge(rumor.subject_npc_id, actor_id, delta * 0.5, tick)

		var subject_name := rumor.subject_npc_id
		var subj_node = _npc_id_dict.get(rumor.subject_npc_id, null)
		if subj_node != null:
			subject_name = subj_node.npc_data.get("name", rumor.subject_npc_id)
		emit_signal("graph_edge_mutated", npc_data.get("name", ""), subject_name, delta)


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
	var subj_node = _npc_id_dict.get(subject_id, null)
	if subj_node == null:
		return
	var subject_cell: Vector2i = subj_node.current_cell
	var target_cell: Vector2i = subject_cell if toward else _cell_furthest_from(subject_cell)
	_path = _pathfinder.get_path(current_cell, target_cell)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


## Return the walkable cell that maximises squared distance from from_cell.
## Uses a pre-sampled 64-cell candidate list instead of scanning all ~1000 walkable cells.
func _cell_furthest_from(from_cell: Vector2i) -> Vector2i:
	var best_cell := current_cell
	var best_dist := 0
	for cell in _walkable_sample:
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
		var s: Rumor.RumorState = other.get_state_for_rumor(rumor.id)
		if s in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD]:
			var d: float = float(((other.current_cell as Vector2i) - current_cell).length_squared())
			if d < best_dist:
				best_dist = d
				best = other
	if best == null:
		return
	_path = _pathfinder.get_path(current_cell, best.current_cell)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


# ── Defender tick logic ───────────────────────────────────────────────────────

## Called each tick to advance the defending NPC's countdown and broadcast the
## credibility penalty to all social-graph neighbours.
func _tick_defender(tick: int) -> void:
	if not _is_defending:
		return
	_defender_ticks_remaining -= 1
	if _defender_ticks_remaining <= 0:
		_is_defending = false
		_worst_state_dirty = true
		_defender_target_npc_id = ""
		_defender_ticks_remaining = 0
		return
	_broadcast_defense(tick)


## Broadcast a credulity penalty for the defended subject to all neighbours.
func _broadcast_defense(_tick: int) -> void:
	if social_graph_ref == null or all_npcs_ref.is_empty():
		return
	var npc_id: String = npc_data.get("id", "")
	var neighbours: Dictionary = social_graph_ref.get_neighbours(npc_id)

	for tid in neighbours:
		var other = _npc_id_dict.get(tid, null)
		if other == null or other == self:
			continue
		other._apply_defense_penalty(_defender_target_npc_id, _DEFENDER_PENALTY)


## Apply (or refresh) a credulity penalty on this NPC for the given subject.
## Penalties are capped at _DEFENSE_PENALTY_CAP and last _DEFENSE_MOD_DURATION ticks.
func _apply_defense_penalty(subject_id: String, penalty: float) -> void:
	var current: float = _defense_modifiers.get(subject_id, 0.0)
	_defense_modifiers[subject_id] = minf(current + penalty, _DEFENSE_PENALTY_CAP)
	_defense_modifier_ticks[subject_id] = _DEFENSE_MOD_DURATION


## Tick down defense modifier expiry; removes expired entries.
func _tick_defense_modifiers() -> void:
	var to_remove: Array = []
	for sid in _defense_modifier_ticks.keys():
		_defense_modifier_ticks[sid] -= 1
		if _defense_modifier_ticks[sid] <= 0:
			to_remove.append(sid)
	for sid in to_remove:
		_defense_modifiers.erase(sid)
		_defense_modifier_ticks.erase(sid)


# ── Rumor memory helpers ──────────────────────────────────────────────────────

## Append an outcome entry to rumor_history.
func _record_rumor_history(rumor: Rumor, subject_id: String, outcome: String, tick: int) -> void:
	rumor_history.append({
		"rumor_id":   rumor.id,
		"subject_id": subject_id,
		"claim_type": rumor.claim_type,
		"outcome":    outcome,
		"tick":       tick,
	})


## Apply delta to _credulity_modifier, clamped to _CREDULITY_MODIFIER_FLOOR.
## Keeps _credulity and npc_data["credulity"] in sync so both own-belief
## decisions and other NPCs' spread calculations reflect the change.
func _apply_credulity_modifier(delta: float) -> void:
	var prev := _credulity_modifier
	_credulity_modifier = maxf(_credulity_modifier + delta, _CREDULITY_MODIFIER_FLOOR)
	var actual_delta := _credulity_modifier - prev
	if abs(actual_delta) < 0.0001:
		return
	_credulity = clamp(_credulity + actual_delta, 0.0, 1.0)
	npc_data["credulity"] = _credulity


## Record that this NPC should avoid the subject's work-location.
## Only applies to negative claim types; no-ops on positive claims or duplicates.
func _update_schedule_avoidance(rumor: Rumor) -> void:
	if Rumor.is_positive_claim(rumor.claim_type):
		return
	var subject_id := rumor.subject_npc_id
	if _avoided_subject_ids.has(subject_id):
		return
	_avoided_subject_ids.append(subject_id)


## If location_code is the work-location of any avoided subject, return "home".
## No-ops when avoidance list is empty or location is already "home".
func _reroute_if_avoided(location_code: String) -> String:
	if _avoided_subject_ids.is_empty() or location_code == "home":
		return location_code
	for other in all_npcs_ref:
		var tid: String = other.npc_data.get("id", "")
		if _avoided_subject_ids.has(tid) and other.work_location == location_code:
			return "home"
	return location_code


# ── Query helpers ────────────────────────────────────────────────────────────

## Force the highest-priority EVALUATING slot to BELIEVE (bribe effect).
## Returns the forced rumor_id, or "" if no EVALUATING slot exists.
func force_believe() -> String:
	for rid in rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		if slot.state == Rumor.RumorState.EVALUATING:
			slot.state = Rumor.RumorState.BELIEVE
			slot.ticks_in_state = 0
			return rid
	return ""


func get_state_for_rumor(rumor_id: String) -> Rumor.RumorState:
	if rumor_slots.has(rumor_id):
		return rumor_slots[rumor_id].state
	return Rumor.RumorState.UNAWARE


func get_worst_rumor_state() -> Rumor.RumorState:
	if not _worst_state_dirty:
		return _worst_state_cache
	# Priority order for display: ACT > DEFENDING > SPREAD > CONTRADICTED > BELIEVE > EVALUATING > REJECT > EXPIRED > UNAWARE
	if _is_defending:
		_worst_state_cache = Rumor.RumorState.DEFENDING
		_worst_state_dirty = false
		return _worst_state_cache
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
				_worst_state_cache = p
				_worst_state_dirty = false
				return _worst_state_cache
	_worst_state_cache = Rumor.RumorState.UNAWARE
	_worst_state_dirty = false
	return _worst_state_cache


# ── Label update ─────────────────────────────────────────────────────────────

func _update_label() -> void:
	var worst := get_worst_rumor_state()
	var state_str := Rumor.state_name(worst)
	var short_name: String = npc_data.get("name", "NPC")
	if rumor_slots.is_empty():
		name_label.text = short_name
	else:
		name_label.text = "%s\n[%s]" % [short_name, state_str]

	# Cache state tint so _process() can blend heat shimmer against it.
	_cached_state_tint = STATE_TINT.get(worst, Color.WHITE)

	# Apply sprite tint when not hovered and heat shimmer is not active.
	# When heat >= 50 and heat_enabled, _process() drives modulate every frame.
	if not _hovered:
		if sprite != null and sprite.sprite_frames != null:
			if _get_heat() < 50.0:
				sprite.modulate = _cached_state_tint

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
		# Show a reaction speech bubble matching the new state.
		var cat := _state_to_dialogue_category(worst)
		if cat != "":
			_show_dialogue_bubble(cat)


# ── Hover highlight ──────────────────────────────────────────────────────────

## Called by recon_controller to apply or remove the hover highlight.
## Applies NPC_HOVER_TINT directly to sprite.modulate so the parent node's
## modulate stays at Color(1,1,1,1) and doesn't multiply with state tints.
func set_hover(hovered: bool) -> void:
	_hovered = hovered
	if sprite == null or sprite.sprite_frames == null:
		return
	if _hovered:
		sprite.modulate = NPC_HOVER_TINT
	else:
		# If heat shimmer is active _process() will take over next frame.
		# Otherwise restore the state tint immediately.
		if _get_heat() < 50.0:
			var worst := get_worst_rumor_state()
			sprite.modulate = STATE_TINT.get(worst, Color.WHITE)


# ── Heat shimmer (per-frame) ─────────────────────────────────────────────────

## Returns the raw heat value for this NPC (0.0 if heat is disabled).
func _get_heat() -> float:
	if propagation_engine_ref == null:
		return 0.0
	if propagation_engine_ref.intel_store_ref == null:
		return 0.0
	if not propagation_engine_ref.intel_store_ref.heat_enabled:
		return 0.0
	return propagation_engine_ref.intel_store_ref.get_heat(npc_data.get("id", ""))


## Drives the heat shimmer animation every frame.
## When heat >= 50 this overrides sprite.modulate with a pulsing warm glow
## that blends between the current state colour and a red/orange alert.
func _process(delta: float) -> void:
	if _hovered or sprite == null or sprite.sprite_frames == null:
		return
	var h := _get_heat()
	if h < 50.0:
		return  # _update_label() sets sprite.modulate directly when heat is low
	_heat_pulse_phase += delta * (3.0 if h >= 75.0 else 2.0)
	var pulse := sin(_heat_pulse_phase) * 0.5 + 0.5  # 0.0 → 1.0
	var heat_color: Color
	if h >= 75.0:
		heat_color = Color(1.45, 0.40, 0.25, 1.0)  # red-orange alarm
	else:
		heat_color = Color(1.30, 0.65, 0.35, 1.0)  # amber warning
	sprite.modulate = _cached_state_tint.lerp(heat_color, pulse * 0.45)


# ── Bribery feedback ─────────────────────────────────────────────────────────

## Show a dialogue bubble from the "observe" category when the player
## successfully observes the location this NPC is currently at.
## Called by recon_controller after a successful Observe action.
func show_observed() -> void:
	_show_dialogue_bubble("observe")


## Show a dialogue bubble from the "eavesdrop" category when the player
## successfully eavesdrops on this NPC.
## Called by recon_controller after a successful Eavesdrop action.
func show_eavesdropped() -> void:
	_show_dialogue_bubble("eavesdrop")


## Spawns a floating coin-burst label above this NPC confirming a successful
## bribe.  Called by recon_controller immediately after force_believe().
func show_bribed_effect() -> void:
	var lbl := Label.new()
	lbl.text = "🪙"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(-8.0, -72.0)
	lbl.modulate = Color(1.0, 0.90, 0.2, 1.0)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -20.0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


# ── Ambient / reaction speech bubbles ────────────────────────────────────────

## Maps a rumor state to the matching dialogue category key, or "" for states
## that have no dedicated dialogue (UNAWARE, EXPIRED, CONTRADICTED).
func _state_to_dialogue_category(state: Rumor.RumorState) -> String:
	match state:
		Rumor.RumorState.EVALUATING: return "hear"
		Rumor.RumorState.BELIEVE:    return "believe"
		Rumor.RumorState.REJECT:     return "reject"
		Rumor.RumorState.SPREAD:     return "spread"
		Rumor.RumorState.ACT:        return "act"
		Rumor.RumorState.DEFENDING:  return "defending"
	return ""


## Spawns a parchment-style speech bubble above this NPC with a random line
## from the given dialogue category.  Respects the global 2-bubble cap and
## skips if this NPC already owns a visible bubble.
func _show_dialogue_bubble(category: String) -> void:
	if _has_bubble:
		return
	if _active_bubbles >= _MAX_BUBBLES:
		return
	if _npc_dialogue_key == "":
		return

	var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
	var lines: Array          = npc_lines.get(category, [])
	if lines.is_empty():
		return

	var text: String = lines[randi() % lines.size()]

	# ── Build parchment panel ─────────────────────────────────────────────────
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.88, 0.78, 0.58, 0.93)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left          = 1
	style.border_width_right         = 1
	style.border_width_top           = 1
	style.border_width_bottom        = 1
	style.border_color               = Color(0.55, 0.42, 0.25, 0.85)
	style.content_margin_left        = 6.0
	style.content_margin_right       = 6.0
	style.content_margin_top         = 4.0
	style.content_margin_bottom      = 4.0
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text                    = text
	lbl.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size     = Vector2(80.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.25, 0.18, 0.08, 1.0))
	panel.add_child(lbl)

	# Position above the NameLabel (which sits at Y = -100).
	panel.modulate.a = 0.0
	panel.position   = Vector2(-44.0, -152.0)
	add_child(panel)

	_active_bubbles += 1
	_has_bubble      = true

	# Fade in → hold → fade out.
	var hold_time := randf_range(3.0, 4.0)
	var tw        := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold_time)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_on_bubble_finished.bind(panel))


func _on_bubble_finished(panel: PanelContainer) -> void:
	_active_bubbles = maxi(_active_bubbles - 1, 0)
	_has_bubble     = false
	if is_instance_valid(panel):
		panel.queue_free()


# ── Click feedback ───────────────────────────────────────────────────────────

## Brief highlight flash when the player clicks to observe/eavesdrop this NPC.
func flash_click() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "color", Color.WHITE, 0.08)
	_flash_tween.tween_property(sprite, "color", _base_color,  0.20)


# ── Utility ──────────────────────────────────────────────────────────────────

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0)
	)

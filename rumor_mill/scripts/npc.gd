extends Node2D

## npc.gd — Art Pass 15 (SPA-686): body_type (0=standard/1=slim/2=stocky) + clothing_var rows.
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
## Sprite sheet layout (assets/textures/npc_sprites.png, 960×3456, 15 cols × 36 rows, 64×96/frame):
##   Body block 0 (standard, rows  0- 8): merchant noble clergy guard commoner tavern scholar elder spy
##   Body block 1 (slim,     rows  9-17): same archetypes, narrower silhouette
##   Body block 2 (stocky,   rows 18-26): same archetypes, wider silhouette
##   Clothing variants (rows 27-35):
##     27=merchant-rustic  28=merchant-neutral  29=merchant-guild-red
##     30=noble-pragmatic  31=noble-navy        32=noble-russet
##     33=clergy-greyfriar 34=clergy-augustine  35=clergy-blackrobe
##   Cols  0-1  = idle_south (2 frames)   Cols  2-4  = walk_south (3 frames)
##   Cols  5-6  = idle_north (2 frames)   Cols  7-9  = walk_north (3 frames)
##   Cols 10-11 = idle_east  (2 frames)   Cols 12-14 = walk_east  (3 frames)
##   west = flip_h of east (handled in code)

## Emitted once when this NPC first receives a rumor (UNAWARE → EVALUATING).
signal first_npc_became_evaluating

## Emitted whenever this NPC's worst rumor state changes (for journal + overlay).
signal rumor_state_changed(npc_name: String, new_state_name: String, rumor_id: String, diagnostic: String)

## Emitted when this NPC successfully transmits a rumor to another NPC.
## outcome: "believed" (receiver already in BELIEVE/SPREAD/ACT), "rejected" (receiver in
## REJECT/CONTRADICTED), or "evaluating" (receiver newly processing the rumor).
signal rumor_transmitted(from_name: String, to_name: String, rumor_id: String, outcome: String)

## Emitted when this NPC enters ACT state and mutates a social graph edge.
signal graph_edge_mutated(actor_name: String, subject_name: String, delta: float)

## Emitted when the player's mouse enters/exits this NPC's hover area.
signal npc_hovered(npc: Node2D)
signal npc_unhovered()

## Emitted once each time this NPC's heat crosses 75 going upward (danger zone).
signal suspicion_danger(npc_name: String)

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
## SPA-868: quarantine system ref — set by World for S2.
var quarantine_ref: QuarantineSystem = null
## SPA-874: buildings with 3+ illness believers that non-believers should avoid.
## Updated by World each day; keys are location codes, value is always true.
var illness_hotspot_buildings: Dictionary = {}

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
var _waypoint_index: int = -1  # -1 so first _advance_waypoint() lands on index 0
var _is_moving: bool = false
var _tween: Tween = null
var _micro_wander_cooldown: int = 0

const _MICRO_WANDER_CHANCE := 0.20  # probability per idle tick of taking a small wander step

# rumor_id → Rumor.NpcRumorSlot
var rumor_slots: Dictionary = {}
## Dirty flag: set true whenever rumor_slots content or _is_defending changes.
## get_worst_rumor_state() uses this to skip recomputation when nothing changed.
var _worst_state_dirty: bool = true
var _worst_state_cache: Rumor.RumorState = Rumor.RumorState.UNAWARE
## Diagnostic reason strings for terminal rumor states, keyed by rumor_id.
## Populated when a slot enters EXPIRED or CONTRADICTED; read in _update_label().
var _slot_diagnostics: Dictionary = {}

var _pathfinder: AstarPathfinder = null
var _walkable: Array[Vector2i] = []
var _flash_tween: Tween = null
var _base_color: Color = Color.WHITE
## Gold diamond ring drawn under the NPC while it is the player's selected/followed target.
var _selection_ring: Polygon2D = null

# ── SPA-561: Visual feedback state ──────────────────────────────────────────
var _ripple_radius: float = 0.0
var _ripple_alpha: float = 0.0
var _ripple_tween: Tween = null
var _emote_tween: Tween = null

# ── Visuals ──────────────────────────────────────────────────────────────────
# Faction row index in npc_sprites.png (rows 0-2, standard body block)
const FACTION_ROW := {
	"merchant": 0,
	"noble":    1,
	"clergy":   2,
}
# Archetype overrides — these rows take priority over faction (rows 3-8, standard body block)
const ARCHETYPE_ROW := {
	"guard_civic":  3,
	"tavern_staff": 5,
	"scholar":      6,
	"elder":        7,
	"spy":          8,
}
# Roles that map to the commoner archetype row (row 4)
const COMMONER_ROLES := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
# Body-type row offset: rows 9-17 = slim, rows 18-26 = stocky (SPA-686)
const BODY_TYPE_ROW_OFFSET := 9
# Clothing variant base rows for faction archetypes (rows 27-35, standard body proportions)
const CLOTHING_VAR_BASE := {
	"merchant": 27,
	"noble":    30,
	"clergy":   33,
}
# Sprite frame dimensions (SPA-585: 64×96 per frame, 2× upscale from 32×48 base)
const SPRITE_W := 64
const SPRITE_H := 96
# Column positions within each row (see header comment for full layout)
const _IDLE_S_COL  := 0   # south idle start
const _WALK_S_COL  := 2   # south walk start
const _IDLE_N_COL  := 5   # north idle start
const _WALK_N_COL  := 7   # north walk start
const _IDLE_E_COL  := 10  # east idle start
const _WALK_E_COL  := 12  # east walk start
const _IDLE_FRAMES := 2
const _WALK_FRAMES := 3

@onready var sprite:      AnimatedSprite2D = $Sprite
@onready var name_label:  Label            = $NameLabel
@onready var hover_area:  Area2D           = $HoverArea

var _faction: String = "merchant"
# Current facing direction — updated by _walk_to, persists into idle
# "south" | "north" | "east" | "west"
var _facing_dir: String = "south"

# ── SPA-695: Town mood + thought bubble state ────────────────────────────────
## Speed multiplier applied by TownMoodController when guards are on high alert.
var mood_speed_scale: float = 1.0
## Thought bubble child node — created in init_from_data.
var _thought_bubble: NpcThoughtBubble = null
## Convenience property: returns the NPC's current worst rumor state.
var visual_state: Rumor.RumorState:
	get:
		return get_worst_rumor_state()

# ── Defender state (NPC-level, not per rumor slot) ───────────────────────────
var _is_defending:            bool   = false
var _defender_target_npc_id:  String = ""
var _defender_ticks_remaining: int   = 0
const _DEFENDER_PENALTY:      float  = 0.15
const _DEFENDER_DURATION:     int    = 5
const _DEFENSE_PENALTY_CAP:   float  = 0.30
## Persistent shield icon shown above this NPC while it is in DEFENDING state.
var _defending_icon: Label = null

## Faction badge dot displayed next to name label (SPA-724).
var _faction_badge: ColorRect = null

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
const _CREDULITY_MODIFIER_FLOOR:   float = -0.15   # rejection penalty cap
const _CREDULITY_MODIFIER_CEILING: float =  0.15   # act-on-rumor reward cap
const _CREDULITY_ACT_GAIN:        float =  0.10   # reward for acting on a rumor
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
## SPA-777: Cool cyan-white tint — visually distinct from the gold selection ring.
const NPC_HOVER_TINT := Color(1.0, 1.6, 1.8, 1.0)
var _hovered: bool = false

# ── Heat shimmer state ───────────────────────────────────────────────────────
# The heat shimmer oscillates sprite.modulate in _process() between the state
# tint and a warm red/orange glow, signalling that this NPC is suspicious/wary.
# _cached_state_tint is refreshed each game tick by _update_label().
var _cached_state_tint: Color = Color.WHITE
var _heat_pulse_phase:  float = 0.0
var _prev_heat:         float = 0.0  # tracks last frame's heat for threshold detection

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
## Current hour of day (0-23), updated each tick for time-of-day dialogue selection.
var _current_hour:         int    = 0
## Ticks until this NPC next shows a scenario-gossip bubble.
var _gossip_cooldown:      int    = 0
## Ticks until this NPC next shows an NPC-chatter bubble when near another NPC.
var _chatter_cooldown:     int    = 0


## Load npc_dialogue.json (and npc_dialogue_extended.json) once; subsequent calls are no-ops.
## Extended file adds time-of-day, scenario gossip, and chatter categories per NPC.
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
	# Merge extended dialogue (time-of-day, scenario gossip, chatter).
	var ef := FileAccess.open("res://data/npc_dialogue_extended.json", FileAccess.READ)
	if ef != null:
		var ext: Variant = JSON.parse_string(ef.get_as_text())
		ef.close()
		if ext is Dictionary:
			for npc_id in ext:
				if _dialogue_data.has(npc_id):
					var base: Dictionary = _dialogue_data[npc_id]
					var additions: Dictionary = ext[npc_id]
					for cat in additions:
						base[cat] = additions[cat]
	_dialogue_loaded = true


func _ready() -> void:
	# sprite setup deferred to init_from_data after faction is known
	if hover_area != null:
		hover_area.mouse_entered.connect(_on_hover_enter)
		hover_area.mouse_exited.connect(_on_hover_exit)


func _exit_tree() -> void:
	if _has_bubble:
		_active_bubbles = maxi(_active_bubbles - 1, 0)
		_has_bubble = false
	if hover_area != null:
		if hover_area.mouse_entered.is_connected(_on_hover_enter):
			hover_area.mouse_entered.disconnect(_on_hover_enter)
		if hover_area.mouse_exited.is_connected(_on_hover_exit):
			hover_area.mouse_exited.disconnect(_on_hover_exit)


func _on_hover_enter() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	set_hover(true)
	npc_hovered.emit(self)


func _on_hover_exit() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	set_hover(false)
	npc_unhovered.emit()


# ── Sprite setup ─────────────────────────────────────────────────────────────

func _setup_sprite(faction: String) -> void:
	var tex := load("res://assets/textures/npc_sprites.png") as Texture2D
	if tex == null:
		push_warning("NPC: npc_sprites.png not found; falling back to placeholder")
		return

	# Determine sprite sheet row from archetype, role, faction, body_type, clothing_var.
	var npc_archetype: String = npc_data.get("archetype", "")
	var npc_role: String = npc_data.get("role", "")
	var body_type: int = clampi(npc_data.get("body_type", 0), 0, 2)
	var clothing_var: int = clampi(npc_data.get("clothing_var", 0), 0, 3)
	var row: int
	if ARCHETYPE_ROW.has(npc_archetype):
		# Specialty archetypes (guard/tavern/scholar/elder/spy) support body_type only.
		row = ARCHETYPE_ROW[npc_archetype] + body_type * BODY_TYPE_ROW_OFFSET
	elif npc_role in COMMONER_ROLES:
		# Commoner row supports body_type only.
		row = 4 + body_type * BODY_TYPE_ROW_OFFSET
	elif clothing_var > 0 and CLOTHING_VAR_BASE.has(faction):
		# Clothing variant rows 27-35 (standard body proportions, alternative palette).
		row = CLOTHING_VAR_BASE[faction] + (clothing_var - 1)
	else:
		# Faction rows 0-2 with body_type block offset.
		row = FACTION_ROW.get(faction, 0) + body_type * BODY_TYPE_ROW_OFFSET
	var frames := SpriteFrames.new()

	# Helper to add an animation with frames from consecutive columns
	var _add_anim := func(anim: String, start_col: int, count: int, fps: float) -> void:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, true)
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas  = tex
			at.region = Rect2((start_col + i) * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)
			frames.add_frame(anim, at)

	# ── 6 directional animations (SPA-585) ───────────────────────────────────
	_add_anim.call("idle_south", _IDLE_S_COL, _IDLE_FRAMES, 3.0)
	_add_anim.call("walk_south", _WALK_S_COL, _WALK_FRAMES, 8.0)
	_add_anim.call("idle_north", _IDLE_N_COL, _IDLE_FRAMES, 3.0)
	_add_anim.call("walk_north", _WALK_N_COL, _WALK_FRAMES, 8.0)
	_add_anim.call("idle_east",  _IDLE_E_COL, _IDLE_FRAMES, 3.0)
	_add_anim.call("walk_east",  _WALK_E_COL, _WALK_FRAMES, 8.0)

	sprite.sprite_frames = frames
	sprite.play("idle_south")


# ── Faction badge (SPA-724) ──────────────────────────────────────────────────

## Build a small faction-colored dot to the left of the name label so players
## can identify NPC faction affiliation at a glance.
func _build_faction_badge(faction: String) -> void:
	var badge := ColorRect.new()
	badge.color = FactionPalette.badge_color(faction)
	badge.custom_minimum_size = Vector2(8, 8)
	badge.size = Vector2(8, 8)
	# Position the dot just to the left of the name label, vertically centred.
	badge.position = Vector2(name_label.position.x - 11, name_label.position.y + 6)
	# Subtle dark outline via a slightly larger rect behind.
	var outline := ColorRect.new()
	outline.color = Color(0, 0, 0, 0.6)
	outline.custom_minimum_size = Vector2(10, 10)
	outline.size = Vector2(10, 10)
	outline.position = Vector2(badge.position.x - 1, badge.position.y - 1)
	add_child(outline)
	add_child(badge)
	_faction_badge = badge


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
	_build_faction_badge(faction)

	position = _cell_to_world(start_cell)
	_advance_waypoint()

	# Speech bubble setup — stagger initial cooldown so NPCs don't all talk at once.
	_npc_dialogue_key     = data.get("id", "")
	_load_dialogue_db()
	_idle_bubble_cooldown = randi_range(1, 50)
	_gossip_cooldown      = randi_range(60, 120)
	_chatter_cooldown     = randi_range(20, 50)

	# SPA-695: Thought bubble for rumor-state visual feedback.
	_thought_bubble = NpcThoughtBubble.new()
	add_child(_thought_bubble)


# ── Per-tick entry point ─────────────────────────────────────────────────────

func on_tick(tick: int) -> void:
	_current_hour = tick % 24
	_step_movement()
	_process_rumor_slots(tick)
	_tick_defender(tick)
	# Idle ambient bubble — fires every 30-60 ticks, staggered per NPC.
	# Prefers time-of-day variant (ambient_morning/evening/night) when available.
	_idle_bubble_cooldown -= 1
	if _idle_bubble_cooldown <= 0:
		_idle_bubble_cooldown = randi_range(30, 60)
		var phase_cat := "ambient_" + _get_time_phase()
		var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
		if npc_lines.has(phase_cat) and not (npc_lines[phase_cat] as Array).is_empty():
			_show_dialogue_bubble(phase_cat)
		else:
			_show_dialogue_bubble("ambient")
	# Scenario gossip bubble — fires every 60-120 ticks.
	_gossip_cooldown -= 1
	if _gossip_cooldown <= 0:
		_gossip_cooldown = randi_range(60, 120)
		var sid: String = GameState.selected_scenario_id  # e.g. "scenario_1"
		var short: String = sid.replace("scenario_", "s")   # -> "s1"
		_show_dialogue_bubble("gossip_" + short)
	# NPC chatter bubble — fires every 40-80 ticks when near another NPC.
	_chatter_cooldown -= 1
	if _chatter_cooldown <= 0:
		_chatter_cooldown = randi_range(40, 80)
		_try_chatter_bubble()
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
	# SPA-874: Outside NPCs avoid quarantined buildings — reroute to previous location.
	if quarantine_ref != null and quarantine_ref.is_quarantined(location_code) \
			and location_code != current_location_code:
		location_code = current_location_code if not current_location_code.is_empty() else "home"
	# SPA-874: Non-believers avoid illness hotspot buildings (3+ believers present).
	if illness_hotspot_buildings.has(location_code) and location_code != current_location_code \
			and not _believes_illness():
		location_code = current_location_code if not current_location_code.is_empty() else "home"
	current_location_code = location_code

	# Visual schedule clarity (SPA-586): dim NPC when indoors/asleep at home
	# during night-time slots (0 = midnight, 1 = dawn).  Uses the parent node
	# modulate so it is independent of sprite.modulate state tints.
	var sleeping: bool = (location_code == "home") and (slot == 0 or slot == 1)
	modulate.a = 0.45 if sleeping else 1.0

	var target: Vector2i
	if location_code == "home":
		target = _home_cell
	elif gathering_points.has(location_code):
		target = gathering_points[location_code]
	else:
		return

	schedule_waypoints = [target]
	_waypoint_index    = 0
	if _pathfinder == null:
		return
	_path = _pathfinder.get_path(current_cell, target)
	if _path.is_empty() and target != current_cell:
		var fallback := AstarPathfinder.nearest_walkable(target, _walkable)
		if fallback != target:
			_path = _pathfinder.get_path(current_cell, fallback)
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
	# SPA-874: Chapel NPCs stop moving while the chapel is quarantined.
	if _is_chapel_frozen():
		return

	if _path.is_empty():
		_advance_waypoint()

	if _path.is_empty():
		_maybe_micro_wander()
		return

	var next_cell: Vector2i = _path[0]
	_path.remove_at(0)
	_walk_to(next_cell)


## When idle at a destination, occasionally take one step to a random adjacent walkable cell,
## making NPCs look like they're milling about rather than frozen in place.
func _maybe_micro_wander() -> void:
	if _is_schedule_overridden():
		return
	# SPA-874: Chapel NPCs stop micro-wandering while the chapel is quarantined.
	if _is_chapel_frozen():
		return
	if _micro_wander_cooldown > 0:
		_micro_wander_cooldown -= 1
		return
	if randf() >= _MICRO_WANDER_CHANCE:
		return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d: Vector2i in dirs:
		var candidate: Vector2i = current_cell + d
		if _walkable.has(candidate):
			_path = [candidate]
			_micro_wander_cooldown = randi_range(3, 8)
			return


func _advance_waypoint() -> void:
	if schedule_waypoints.is_empty() or _pathfinder == null:
		return
	_waypoint_index = (_waypoint_index + 1) % schedule_waypoints.size()
	var target: Vector2i = schedule_waypoints[_waypoint_index]
	_path = _pathfinder.get_path(current_cell, target)
	if _path.is_empty() and target != current_cell:
		var fallback := AstarPathfinder.nearest_walkable(target, _walkable)
		if fallback != target:
			_path = _pathfinder.get_path(current_cell, fallback)
	if _path.size() > 0 and _path[0] == current_cell:
		_path.remove_at(0)


func _walk_to(cell: Vector2i) -> void:
	if cell == current_cell:
		return
	_is_moving = true
	# Determine cardinal facing from grid cell delta (SPA-585).
	# In isometric: cell.x++ = screen right+down (east), cell.y++ = screen left+down (south).
	var cdx := cell.x - current_cell.x
	var cdy := cell.y - current_cell.y
	if abs(cdx) >= abs(cdy):
		# East/west movement dominates.
		_facing_dir = "west" if cdx < 0 else "east"
	else:
		_facing_dir = "south" if cdy > 0 else "north"
	if sprite.sprite_frames != null:
		match _facing_dir:
			"south": sprite.flip_h = false; sprite.play("walk_south")
			"north": sprite.flip_h = false; sprite.play("walk_north")
			"east":  sprite.flip_h = false; sprite.play("walk_east")
			"west":  sprite.flip_h = true;  sprite.play("walk_east")
	var world_pos := _cell_to_world(cell)
	var effective_speed := MOVE_SPEED * maxf(mood_speed_scale, 0.1)
	var duration  := maxf(position.distance_to(world_pos) / effective_speed, 0.05)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", world_pos, duration).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_move_finished.bind(cell), CONNECT_ONE_SHOT)


func _on_move_finished(arrived_cell: Vector2i) -> void:
	current_cell = arrived_cell
	_is_moving   = false
	if sprite.sprite_frames != null:
		match _facing_dir:
			"north": sprite.play("idle_north")
			"east":  sprite.flip_h = false; sprite.play("idle_east")
			"west":  sprite.flip_h = true;  sprite.play("idle_east")
			_:       sprite.play("idle_south")


# ── Helpers ──────────────────────────────────────────────────────────────────

func _has_engine() -> bool:
	return propagation_engine_ref != null


# ── Rumor ingestion ──────────────────────────────────────────────────────────

func hear_rumor(rumor: Rumor, source_faction: String) -> void:
	var rid := rumor.id

	# Register with the engine so it decays and appears in the lineage tree.
	if _has_engine():
		propagation_engine_ref.register_rumor(rumor)

	if rumor_slots.has(rid):
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		if slot.state in [Rumor.RumorState.BELIEVE,      Rumor.RumorState.REJECT,
						   Rumor.RumorState.SPREAD,       Rumor.RumorState.ACT,
						   Rumor.RumorState.CONTRADICTED, Rumor.RumorState.EXPIRED]:
			return
		# Reinforcement from another source.
		slot.heard_from_count += 1
		return

	var slot := Rumor.NpcRumorSlot.new(rumor, source_faction)
	rumor_slots[rid] = slot
	_worst_state_dirty = true
	_show_hear_reaction()
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
			_slot_diagnostics[rid] = "Shelf-life elapsed after %d ticks" % slot.rumor.shelf_life_ticks
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
				var subj_name := sid
				var subj_node = _npc_id_dict.get(sid, null)
				if subj_node != null:
					subj_name = subj_node.npc_data.get("name", sid)
				_slot_diagnostics[newest.rumor.id] = \
					"Contradicted: opposing claims about %s cancel out" % subj_name
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
		_worst_state_dirty = true
		_record_rumor_history(rumor, subject_id, "believed", tick)
		_update_schedule_avoidance(rumor)
		_show_believe_reaction()
	else:
		slot.state = Rumor.RumorState.REJECT
		slot.ticks_in_state = 0
		_worst_state_dirty = true
		_show_reject_reaction()
		# High-loyalty NPCs who reject a negative rumor about a close ally enter DEFENDING.
		if _loyalty > 0.7 and not Rumor.is_positive_claim(rumor.claim_type) \
				and not _is_defending:
			_is_defending = true
			_worst_state_dirty = true
			_defender_target_npc_id = subject_id
			_defender_ticks_remaining = _DEFENDER_DURATION
			_show_defending_icon()
			emit_signal("rumor_state_changed", npc_name, "DEFENDING", rid, "")
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
	if _has_engine():
		var gamma := propagation_engine_ref.calc_gamma(_loyalty, _temperament)
		if randf() < gamma:
			slot.state = Rumor.RumorState.REJECT
			slot.ticks_in_state = 0
			_worst_state_dirty = true
			return

	# ── ACT threshold ────────────────────────────────────────────────────────
	var act_threshold: int = roundi(8.0 * (1.0 - _temperament))
	if slot.ticks_in_state >= act_threshold:
		slot.state = Rumor.RumorState.ACT
		slot.ticks_in_state = 0
		_worst_state_dirty = true
		_start_act_behavior(slot.rumor, tick)
		_record_rumor_history(slot.rumor, slot.rumor.subject_npc_id, "act", tick)
		_apply_credulity_modifier(_CREDULITY_ACT_GAIN)
		return

	# ── β: spread attempt to each nearby neighbour ───────────────────────────
	if _spread_to_neighbours(slot, faction, tick):
		slot.state = Rumor.RumorState.SPREAD
		slot.ticks_in_state = 0
		_worst_state_dirty = true
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

	# SPA-868: NPCs inside quarantined buildings cannot spread rumors.
	if quarantine_ref != null and quarantine_ref.is_quarantined(current_location_code):
		return false

	var npc_id: String = npc_data.get("id", "")
	var neighbours: Dictionary = {}
	if social_graph_ref != null:
		neighbours = social_graph_ref.get_neighbours(npc_id)

	var spread_happened := false

	for other in all_npcs_ref:
		if other == self:
			continue

		# Proximity gate: manhattan distance matches SPREAD_RADIUS tile documentation.
		var delta: Vector2i = current_cell - (other.current_cell as Vector2i)
		var dist_manhattan: int = absi(delta.x) + absi(delta.y)
		if dist_manhattan > SPREAD_RADIUS:
			continue

		# SPA-868: skip targets inside quarantined buildings.
		if quarantine_ref != null and quarantine_ref.is_quarantined(other.current_location_code):
			continue

		# Skip if already in a non-receptive state.
		var other_state: Rumor.RumorState = other.get_state_for_rumor(slot.rumor.id)
		if other_state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD,
						   Rumor.RumorState.ACT,    Rumor.RumorState.EXPIRED,
						   Rumor.RumorState.REJECT,  Rumor.RumorState.CONTRADICTED]:
			continue

		# Determine edge weight (0 fallback = no direct social connection).
		var tid: String = other.npc_data.get("id", "")
		var edge_w: float = neighbours.get(tid, 0.2)  # 0.2 floor for proximity-only contacts

		var t_credulity: float = float(other.npc_data.get("credulity", 0.5))
		var t_faction:   String = other.npc_data.get("faction", "")

		# Heat modifier: wary/suspicious targets are harder to convince.
		var heat_mod := 0.0
		if _has_engine() and propagation_engine_ref.intel_store_ref != null \
				and propagation_engine_ref.intel_store_ref.heat_enabled:
			var h := propagation_engine_ref.intel_store_ref.get_heat(tid)
			if h >= 75.0:
				heat_mod = 0.30
			elif h >= 50.0:
				heat_mod = 0.15

		# β formula.
		var beta: float
		if _has_engine():
			beta = propagation_engine_ref.calc_beta(
				_sociability, t_credulity, edge_w, spreader_faction, t_faction, heat_mod
			)
		else:
			beta = _sociability * t_credulity * edge_w * 1.8

		if randf() >= beta:
			continue

		# Roll mutations before passing the rumor on.
		var spread_rumor := slot.rumor
		if _has_engine():
			spread_rumor = propagation_engine_ref.try_mutate(slot.rumor, tick, all_npcs_ref)

		other.hear_rumor(spread_rumor, spreader_faction)
		spread_happened = true

		# Relay heat: +2 to this NPC (spreader) if rumor traces to a player seed.
		if _has_engine():
			propagation_engine_ref.apply_relay_heat(npc_id, spread_rumor.id)

		# Visual: show a floating speech bubble from this NPC toward the target.
		_show_spread_bubble(other)
		show_spread_ripple()  # SPA-561: expanding ring on rumor spread
		other._show_whisper_received()
		other.show_rumor_received_glow()  # SPA-777: cyan glow flash on receiver
		# SPA-854: determine receiver's current slot state to color the pulse line.
		var _pulse_outcome := "evaluating"
		if other.rumor_slots.has(spread_rumor.id):
			var _rstate: int = other.rumor_slots[spread_rumor.id].state
			if _rstate in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
				_pulse_outcome = "believed"
			elif _rstate in [Rumor.RumorState.REJECT, Rumor.RumorState.CONTRADICTED]:
				_pulse_outcome = "rejected"
		emit_signal("rumor_transmitted",
			npc_data.get("name", "?"),
			other.npc_data.get("name", "?"),
			spread_rumor.id,
			_pulse_outcome)

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


## Creates a persistent shield label above this NPC for the duration of DEFENDING
## state.  The icon is removed by _tick_defender() when the state expires.
func _show_defending_icon() -> void:
	if is_instance_valid(_defending_icon):
		return  # already showing
	var lbl := Label.new()
	lbl.text = "🛡"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-6.0, -88.0)
	lbl.modulate = Color(0.55, 0.85, 1.0, 1.0)  # sky blue matching DEFENDING tint
	add_child(lbl)
	_defending_icon = lbl


## Spawns a brief "?" icon above this NPC when they first hear a new rumor,
## giving immediate visual feedback before the state machine processes the slot.
func _show_hear_reaction() -> void:
	var lbl := Label.new()
	lbl.text = "?"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-4.0, -72.0)
	lbl.modulate = Color(1.0, 1.0, 0.5, 1.0)  # warm yellow
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -16.0), 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


## Spawns a large bright "!" above this NPC when they transition EVALUATING → BELIEVE,
## with a pop-scale bounce so the belief moment reads clearly from a distance.
func _show_believe_reaction() -> void:
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = Vector2(-6.0, -84.0)
	lbl.modulate = Color(0.30, 1.00, 0.42, 1.0)  # bright green matching BELIEVE tint
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.18).set_delay(0.18)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -22.0), 1.6).set_delay(0.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.55)
	tw.chain().tween_callback(lbl.queue_free)


## Spawns a brief "✗" above this NPC when they transition EVALUATING → REJECT,
## signalling scepticism/disbelief.
func _show_reject_reaction() -> void:
	var lbl := Label.new()
	lbl.text = "✗"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(-6.0, -76.0)
	lbl.modulate = Color(0.80, 0.80, 0.85, 1.0)  # cool grey matching REJECT tint
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -14.0), 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


## Spawns a brief ear-shaped icon above this NPC when they receive a whispered
## rumor from another NPC, making the receiver's reaction visible to the player.
func _show_whisper_received() -> void:
	var lbl := Label.new()
	lbl.text = "👂"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = Vector2(4.0, -68.0)
	lbl.modulate = Color(1.0, 0.90, 0.55, 1.0)  # soft gold
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -14.0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.4)
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


## Returns the top-n most likely first-hop spread targets for this NPC,
## ranked by estimated β (transmission probability).
## Used by the UI to show a "likely spread path" preview after seeding.
func get_spread_preview(n: int = 3) -> Array[Dictionary]:
	if social_graph_ref == null or all_npcs_ref.is_empty():
		return []
	var npc_id: String = npc_data.get("id", "")
	var spreader_faction: String = npc_data.get("faction", "")
	# Fetch more than n so we can filter invalid entries and still return n.
	var top: Array = social_graph_ref.get_top_neighbours(npc_id, n + 3)
	var result: Array[Dictionary] = []
	for pair in top:
		var tid: String  = pair[0]
		var weight: float = pair[1]
		var other_node = _npc_id_dict.get(tid, null)
		if other_node == null:
			continue
		var t_credulity: float  = float(other_node.npc_data.get("credulity", 0.5))
		var t_faction:   String = other_node.npc_data.get("faction", "")
		var faction_mod := 1.2 if t_faction == spreader_faction else 1.0
		var beta_est: float = _sociability * t_credulity * weight * faction_mod * 1.8
		result.append({
			"name":    other_node.npc_data.get("name", "?"),
			"faction": t_faction,
			"beta":    beta_est,
		})
		if result.size() >= n:
			break
	return result


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
	if _path.is_empty() and target_cell != current_cell:
		var fallback := AstarPathfinder.nearest_walkable(target_cell, _walkable)
		if fallback != target_cell:
			_path = _pathfinder.get_path(current_cell, fallback)
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
	if _path.is_empty() and best.current_cell != current_cell:
		var fallback := AstarPathfinder.nearest_walkable(best.current_cell, _walkable)
		if fallback != best.current_cell:
			_path = _pathfinder.get_path(current_cell, fallback)
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
		if is_instance_valid(_defending_icon):
			_defending_icon.queue_free()
		_defending_icon = null
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
	_credulity_modifier = clampf(_credulity_modifier + delta, _CREDULITY_MODIFIER_FLOOR, _CREDULITY_MODIFIER_CEILING)
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


## SPA-874: Returns true if this NPC currently believes (or is spreading/acting on)
## any illness rumor, making hotspot avoidance not apply to them.
func _believes_illness() -> bool:
	for slot in rumor_slots.values():
		if slot.rumor == null:
			continue
		if slot.rumor.claim_type == Rumor.ClaimType.ILLNESS \
				and slot.state in [Rumor.RumorState.BELIEVE,
								   Rumor.RumorState.SPREAD,
								   Rumor.RumorState.ACT]:
			return true
	return false


## SPA-874: Returns true when the chapel is quarantined and this NPC is inside it.
## Chapel NPCs freeze in place (no movement, no micro-wander) while sealed.
func _is_chapel_frozen() -> bool:
	return quarantine_ref != null \
		and quarantine_ref.is_quarantined("chapel") \
		and current_location_code == "chapel"


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

## Returns true when this NPC has at least one rumor slot in EVALUATING state.
## Use this to pre-check bribe eligibility BEFORE spending player resources.
func has_evaluating_rumor() -> bool:
	for rid in rumor_slots.keys():
		if rumor_slots[rid].state == Rumor.RumorState.EVALUATING:
			return true
	return false


## Force the highest-priority EVALUATING slot to BELIEVE (bribe effect).
## Returns the forced rumor_id, or "" if no EVALUATING slot exists.
func force_believe() -> String:
	for rid in rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		if slot.state == Rumor.RumorState.EVALUATING:
			slot.state = Rumor.RumorState.BELIEVE
			slot.ticks_in_state = 0
			_worst_state_dirty = true
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
	# Check ACT first (highest priority) before the _is_defending flag.
	for rid in rumor_slots:
		if rumor_slots[rid].state == Rumor.RumorState.ACT:
			_worst_state_cache = Rumor.RumorState.ACT
			_worst_state_dirty = false
			return _worst_state_cache
	if _is_defending:
		_worst_state_cache = Rumor.RumorState.DEFENDING
		_worst_state_dirty = false
		return _worst_state_cache
	var priority := [
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
	# SPA-724: Show faction abbreviation when idle, rumor state when active.
	var faction_abbr := {"merchant": "M", "noble": "N", "clergy": "C"}.get(_faction, "")
	if rumor_slots.is_empty():
		if faction_abbr != "":
			name_label.text = "%s [%s]" % [short_name, faction_abbr]
		else:
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
		emit_signal("rumor_state_changed", short_name, state_str, wrid, _slot_diagnostics.get(wrid, ""))
		# SPA-561: Show emote icon for the new state.
		show_state_emote(state_str)
		# SPA-751: Sprite scale bounce on high-impact belief transitions.
		if (worst == Rumor.RumorState.BELIEVE or worst == Rumor.RumorState.ACT) and sprite != null:
			var _sb := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_sb.tween_property(sprite, "scale", Vector2(1.18, 1.18), 0.12)
			_sb.tween_property(sprite, "scale", Vector2.ONE, 0.22)
		# SPA-861: Conviction flash — thought bubble override for key transitions.
		if _thought_bubble != null:
			match worst:
				Rumor.RumorState.BELIEVE:
					_thought_bubble.show_override("✓", Color(0.40, 1.00, 0.50, 1.0), 1.4)
				Rumor.RumorState.ACT:
					_thought_bubble.show_override("!!", Color(1.00, 0.40, 0.90, 1.0), 1.2)
				Rumor.RumorState.REJECT:
					_thought_bubble.show_override("✗", Color(0.80, 0.55, 0.55, 1.0), 1.0)
		# Show a reaction speech bubble matching the new state.
		var cat := _state_to_dialogue_category(worst)
		if cat != "":
			_show_dialogue_bubble(cat)

	# SPA-695: Refresh thought bubble every tick (handles on-screen check too).
	if _thought_bubble != null:
		_thought_bubble.refresh(worst)


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
		# Brief scale pulse for tactile hover feedback.
		var _hw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hw.tween_property(sprite, "scale", Vector2(1.08, 1.08), 0.10)
		_hw.tween_property(sprite, "scale", Vector2.ONE, 0.15)
	else:
		# If heat shimmer is active _process() will take over next frame.
		# Otherwise restore the state tint immediately.
		if _get_heat() < 50.0:
			var worst := get_worst_rumor_state()
			sprite.modulate = STATE_TINT.get(worst, Color.WHITE)


# ── Selection ring ───────────────────────────────────────────────────────────

## Shows or hides the gold diamond selection ring drawn under the NPC.
## Called by recon_controller when the player left-clicks (follows) or unselects.
func set_selected(selected: bool) -> void:
	if selected:
		if _selection_ring != null and is_instance_valid(_selection_ring):
			return  # already showing
		var ring := Polygon2D.new()
		ring.polygon = PackedVector2Array([
			Vector2(0, -18), Vector2(24, 0), Vector2(0, 18), Vector2(-24, 0)
		])
		ring.color = Color(1.0, 0.85, 0.20, 0.60)
		ring.position = Vector2(0, 8)
		ring.z_index = -1
		add_child(ring)
		_selection_ring = ring
	else:
		if _selection_ring != null and is_instance_valid(_selection_ring):
			_selection_ring.queue_free()
		_selection_ring = null


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
	# Emit suspicion_danger once when heat crosses 75 upward (checked every frame).
	var h := _get_heat()
	if _prev_heat < 75.0 and h >= 75.0:
		emit_signal("suspicion_danger", npc_data.get("name", "NPC"))
	_prev_heat = h
	if _hovered or sprite == null or sprite.sprite_frames == null:
		return
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
## Uses the "observe_wary" variant when this NPC's heat is >= 50, signalling
## a noticeably colder/suspicious reaction.
## Called by recon_controller after a successful Observe action.
func show_observed() -> void:
	if _get_heat() >= 50.0:
		var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
		if not (npc_lines.get("observe_wary", []) as Array).is_empty():
			_show_dialogue_bubble("observe_wary")
			return
	var base_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
	if (base_lines.get("observe", []) as Array).is_empty():
		push_warning("NPC '%s': missing 'observe' dialogue category — skipping bubble" % _npc_dialogue_key)
		return
	_show_dialogue_bubble("observe")


## Show a dialogue bubble from the "eavesdrop" category when the player
## successfully eavesdrops on this NPC.
## Uses the "eavesdrop_wary" variant when this NPC's heat is >= 50, signalling
## a more guarded or accusatory reaction.
## Called by recon_controller after a successful Eavesdrop action.
func show_eavesdropped() -> void:
	if _get_heat() >= 50.0:
		var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
		if not (npc_lines.get("eavesdrop_wary", []) as Array).is_empty():
			_show_dialogue_bubble("eavesdrop_wary", true)
			return
	var base_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
	if (base_lines.get("eavesdrop", []) as Array).is_empty():
		push_warning("NPC '%s': missing 'eavesdrop' dialogue category — skipping bubble" % _npc_dialogue_key)
		return
	_show_dialogue_bubble("eavesdrop", true)


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


## Spawns a floating "+N" or "−N" label above this NPC to indicate a reputation
## change.  Uses palette colours: gold (MERCH_T) for gain, red (FLAG_R) for loss.
## Called by the reputation system or scenario evaluator on significant deltas.
func show_reputation_change(delta: int) -> void:
	if delta == 0:
		return
	# SPA-561: Brief sprite colour flash on rep change.
	flash_reputation(delta > 0)
	var lbl := Label.new()
	lbl.text = ("+" if delta > 0 else "") + str(delta)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = Vector2(-10.0, -68.0)
	# MERCH_T gold for gain, FLAG_R crimson for loss — both from the locked palette
	lbl.modulate = Color(0.784, 0.635, 0.180, 1.0) if delta > 0 else Color(0.698, 0.149, 0.149, 1.0)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -18.0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)


## Spawns a small "!" glyph in muted stone colour above this NPC for ~1 second,
## signalling that suspicion was raised.  Kept subtle (STONE_L, no bloom) so it
## reads as a quiet warning rather than an alarm — the heat shimmer handles
## the escalated-danger state.
func show_suspicion_raised() -> void:
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-4.0, -72.0)
	# STONE_L (#A29C8A) — muted, consistent with the ink-line pixel aesthetic
	lbl.modulate = Color(0.635, 0.612, 0.545, 1.0)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 0.3, 0.25)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.50).set_delay(0.2)
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


## Returns the broad time-of-day phase for ambient dialogue selection.
## morning: 05-11, day: 12-16, evening: 17-21, night: 22-04.
func _get_time_phase() -> String:
	if _current_hour >= 5 and _current_hour <= 11:
		return "morning"
	elif _current_hour >= 12 and _current_hour <= 16:
		return "day"
	elif _current_hour >= 17 and _current_hour <= 21:
		return "evening"
	else:
		return "night"


## Shows a chatter bubble when at least one other NPC is within 3 tiles.
func _try_chatter_bubble() -> void:
	for other in all_npcs_ref:
		if other == self:
			continue
		var dist: int = abs(other.current_cell.x - current_cell.x) + \
						abs(other.current_cell.y - current_cell.y)
		if dist <= 3:
			_show_dialogue_bubble("chatter")
			return


## Spawns a parchment-style speech bubble above this NPC with a random line
## from the given dialogue category.  Respects the global 2-bubble cap and
## skips if this NPC already owns a visible bubble.
## prominent=true uses larger text and a longer hold (for eavesdrop readability).
func _show_dialogue_bubble(category: String, prominent: bool = false) -> void:
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
	lbl.custom_minimum_size     = Vector2(100.0 if prominent else 80.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11 if prominent else 9)
	lbl.add_theme_color_override("font_color", Color(0.25, 0.18, 0.08, 1.0))
	panel.add_child(lbl)

	# Position above the NameLabel (which sits at Y = -100).
	panel.modulate.a = 0.0
	panel.position   = Vector2(-50.0 if prominent else -44.0, -160.0 if prominent else -152.0)
	add_child(panel)

	_active_bubbles += 1
	_has_bubble      = true

	# Fade in → hold → fade out.
	var hold_time := randf_range(5.0, 6.5) if prominent else randf_range(3.0, 4.0)
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


# ── SPA-561: Visual feedback effects ────────────────────────────────────────

## Draw expanding ripple ring when a rumor spreads from this NPC.
func _draw() -> void:
	if _ripple_alpha > 0.01:
		draw_arc(Vector2(0.0, -36.0), _ripple_radius, 0.0, TAU, 32,
			Color(1.0, 0.85, 0.3, _ripple_alpha), 2.0, true)


## Plays an expanding ripple ring (rumor spread visual).
func show_spread_ripple() -> void:
	_ripple_radius = 8.0
	_ripple_alpha = 0.7
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	_ripple_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ripple_tween.tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.45)
	_ripple_tween.tween_property(self, "_ripple_radius", 48.0, 0.45)
	_ripple_tween.tween_property(self, "_ripple_alpha", 0.0, 0.45)


## Brief colour flash on the NPC sprite when reputation changes.
func flash_reputation(gained: bool) -> void:
	if sprite == null:
		return
	var flash_color := Color(0.4, 1.0, 0.5, 1.0) if gained else Color(1.0, 0.3, 0.2, 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.self_modulate = flash_color
	_flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.35)


## SPA-788: Dark vignette border flash when this NPC first flips to belief.
## Plunges sprite to near-black then fades back — signals a conviction shift.
func flash_belief_vignette() -> void:
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.self_modulate = Color(0.12, 0.12, 0.18, 1.0)  # dark vignette
	_flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.55)


## SPA-788: Apply / remove the belief-shaken speed penalty (0.72× for rest of day).
## Skipped for GUARD_CIVIC — their pace is owned by TownMoodController.
func set_belief_shaken(shaken: bool) -> void:
	if archetype == NpcSchedule.ScheduleArchetype.GUARD_CIVIC:
		return
	mood_speed_scale = 0.72 if shaken else 1.0


## Shows a floating emote icon above the NPC on rumor state change.
const STATE_EMOTES: Dictionary = {
	"EVALUATING": "🤔",
	"BELIEVE":    "💡",   # SPA-861: conviction pop when NPC first believes
	"SPREAD":     "📢",
	"ACT":        "⚡",
	"REJECT":     "✋",
	"DEFENDING":  "🛡️",
}

func show_state_emote(state_name: String) -> void:
	var icon: String = STATE_EMOTES.get(state_name, "")
	if icon.is_empty():
		return
	var lbl := Label.new()
	lbl.text = icon
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(12.0, -76.0)
	lbl.modulate.a = 0.0
	add_child(lbl)
	if _emote_tween != null and _emote_tween.is_valid():
		_emote_tween.kill()
	_emote_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lbl.scale = Vector2(0.5, 0.5)
	_emote_tween.tween_property(lbl, "modulate:a", 1.0, 0.12)
	_emote_tween.tween_property(lbl, "scale", Vector2.ONE, 0.2)
	_emote_tween.chain().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(1.0)
	_emote_tween.chain().tween_callback(lbl.queue_free)


# ── Click feedback ───────────────────────────────────────────────────────────

## Brief highlight flash when the player clicks to select/interact with this NPC.
## Immediately sets self_modulate to a bright gold-white burst, then tweens back.
## SPA-869: Also plays a quick scale pulse (1.0 → 1.1 → 1.0 over 0.15 s).
func flash_click() -> void:
	if sprite == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	sprite.self_modulate = Color(2.0, 1.8, 0.8, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.28)
	# Scale pulse independent of the colour tween so both run simultaneously.
	sprite.scale = Vector2.ONE
	var _sp := create_tween()
	_sp.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.075) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sp.tween_property(sprite, "scale", Vector2.ONE, 0.075) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## SPA-777: Shows a brief name + faction label above the NPC when the player clicks it.
## Floats upward and fades after ~1.5 s.
func show_name_popup() -> void:
	var npc_name: String = npc_data.get("name", "?")
	var faction:  String = npc_data.get("faction", "")
	var text: String = npc_name if faction.is_empty() else "%s\n[%s]" % [npc_name, faction.capitalize()]

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-32.0, -88.0)
	add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -16.0), 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)


## SPA-777: Brief cyan glow flash on the sprite when this NPC receives a new rumor.
## Signals to the player that information has spread to this target.
func show_rumor_received_glow() -> void:
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.self_modulate = Color(0.6, 2.0, 1.8, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.50)


## SPA-903: Warm amber burst on the sprite when the player targets this NPC with a
## seeded rumor — immediate visual confirmation before the ripple VFX lands.
func flash_seed_confirmation() -> void:
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.self_modulate = Color(1.8, 1.2, 0.4, 1.0)  # warm amber
	_flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.45)
	# Brief scale bounce for extra tactile feel.
	sprite.scale = Vector2.ONE
	var _sp := create_tween()
	_sp.tween_property(sprite, "scale", Vector2(1.12, 1.12), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sp.tween_property(sprite, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ── Utility ──────────────────────────────────────────────────────────────────

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0)
	)

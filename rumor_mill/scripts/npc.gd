extends Node2D

## npc.gd — Art Pass 15 (SPA-686): body_type (0=standard/1=slim/2=stocky) + clothing_var rows.
## Sprint 5: AnimatedSprite2D, faction sprites, heat/bribery visual polish.
## Sprint 4: full SIR diffusion model.
##
## SPA-1009: Decomposed into four subsystem modules (NpcMovement, NpcDialogue,
## NpcVisuals, NpcRumorProcessing).  This file is the thin coordinator; all
## tested state vars and public-API methods live here.
##
## Spread uses the β formula via PropagationEngine:
##   β = sociability_spreader × credulity_target × edge_weight × faction_mod × 1.8
## Recovery from BELIEVE uses the γ formula:
##   γ = loyalty × (1 − temperament) × 0.30
## Mutations use PropagationEngine.try_mutate() (4 independent types).
## Shelf-life expiry is detected via Rumor.is_expired() after PropagationEngine.tick_decay().

## Emitted once when this NPC first receives a rumor (UNAWARE → EVALUATING).
signal first_npc_became_evaluating

## Emitted whenever this NPC's worst rumor state changes (for journal + overlay).
signal rumor_state_changed(npc_name: String, new_state_name: String, rumor_id: String, diagnostic: String)

## Emitted when this NPC successfully transmits a rumor to another NPC.
signal rumor_transmitted(from_name: String, to_name: String, rumor_id: String, outcome: String)

## Emitted when this NPC enters ACT state and mutates a social graph edge.
signal graph_edge_mutated(actor_name: String, subject_name: String, delta: float)

## Emitted when the player's mouse enters/exits this NPC's hover area.
signal npc_hovered(npc: Node2D)
signal npc_unhovered()

## Emitted once each time this NPC's heat crosses 75 going upward (danger zone).
signal suspicion_danger(npc_name: String)

const TILE_W       := 64
const TILE_H       := 32
const SPREAD_RADIUS := 8   # tiles (manhattan distance)

# ── Data set by World ────────────────────────────────────────────────────────
var npc_data: Dictionary = {}
var schedule_waypoints: Array[Vector2i] = []
var all_npcs_ref: Array = []:
	set(value):
		all_npcs_ref = value
		_rebuild_npc_id_dict()
## NPC id → NPC node; rebuilt whenever all_npcs_ref is assigned.
var _npc_id_dict: Dictionary = {}
var social_graph_ref: SocialGraph = null
var propagation_engine_ref: PropagationEngine = null
## SPA-868: quarantine system ref — set by World for S2.
var quarantine_ref: QuarantineSystem = null
## SPA-874: buildings with 3+ illness believers that non-believers should avoid.
var illness_hotspot_buildings: Dictionary = {}

# ── Schedule archetype ───────────────────────────────────────────────────────
var archetype: NpcSchedule.ScheduleArchetype = NpcSchedule.ScheduleArchetype.INDEPENDENT
var work_location: String = ""
var tick_overrides: Dictionary = {}
var day_pattern_overrides: Array = []
var _home_cell: Vector2i = Vector2i.ZERO
## Current schedule location code (e.g. "market", "tavern", "home").
var current_location_code: String = ""

# ── Personality shorthands ───────────────────────────────────────────────────
var _credulity:   float = 0.5
var _sociability: float = 0.5
var _loyalty:     float = 0.5
var _temperament: float = 0.5

# ── Grid position ────────────────────────────────────────────────────────────
var current_cell: Vector2i = Vector2i.ZERO

# ── Rumor knowledge ──────────────────────────────────────────────────────────
# rumor_id → Rumor.NpcRumorSlot
var rumor_slots: Dictionary = {}
## Dirty flag: set true whenever rumor_slots content or _is_defending changes.
var _worst_state_dirty: bool = true
var _worst_state_cache: Rumor.RumorState = Rumor.RumorState.UNAWARE
## Diagnostic reason strings for terminal rumor states, keyed by rumor_id.
var _slot_diagnostics: Dictionary = {}

# ── Visual / dialogue state (read by modules) ────────────────────────────────
var _faction: String = "merchant"
## Current hour of day (0-23), updated each tick.
var _current_hour: int = 0
## Tracks last worst state so we only emit rumor_state_changed on actual changes.
var _last_worst_state: Rumor.RumorState = Rumor.RumorState.UNAWARE
## Speed multiplier applied by TownMoodController when guards are on high alert.
var mood_speed_scale: float = 1.0
## Convenience property: returns the NPC's current worst rumor state.
var visual_state: Rumor.RumorState:
	get:
		return get_worst_rumor_state()

# ── Defender state ───────────────────────────────────────────────────────────
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

# ── Rumor memory ─────────────────────────────────────────────────────────────
var rumor_history: Array = []
# Subject NPC ids whose work-location this NPC avoids after believing a negative rumor.
var _avoided_subject_ids: Array[String] = []
var _credulity_modifier:       float = 0.0
const _CREDULITY_MODIFIER_FLOOR:   float = -0.15
const _CREDULITY_MODIFIER_CEILING: float =  0.15
const _CREDULITY_ACT_GAIN:        float =  0.10
const _CREDULITY_REJECT_PENALTY: float = -0.05

# ── Subsystem modules ────────────────────────────────────────────────────────
var _movement:         NpcMovement         = null
var _dialogue:         NpcDialogue         = null
var _visuals:          NpcVisuals          = null
var _rumor_processing: NpcRumorProcessing  = null

@onready var sprite:      AnimatedSprite2D = $Sprite
@onready var name_label:  Label            = $NameLabel
@onready var hover_area:  Area2D           = $HoverArea


func _ready() -> void:
	if hover_area != null:
		hover_area.mouse_entered.connect(_on_hover_enter)
		hover_area.mouse_exited.connect(_on_hover_exit)


func _exit_tree() -> void:
	if _dialogue != null:
		_dialogue.on_exit_tree()
	if hover_area != null:
		if hover_area.mouse_entered.is_connected(_on_hover_enter):
			hover_area.mouse_entered.disconnect(_on_hover_enter)
		if hover_area.mouse_exited.is_connected(_on_hover_exit):
			hover_area.mouse_exited.disconnect(_on_hover_exit)


func _on_hover_enter() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	if _visuals != null:
		_visuals.set_hover(true)
	npc_hovered.emit(self)


func _on_hover_exit() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _visuals != null:
		_visuals.set_hover(false)
	npc_unhovered.emit()


# ── Initialisation ────────────────────────────────────────────────────────────

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
	npc_data              = data
	_home_cell            = start_cell
	_credulity            = float(data.get("credulity",   0.5))
	_sociability          = float(data.get("sociability",  0.5))
	_loyalty              = float(data.get("loyalty",      0.5))
	_temperament          = float(data.get("temperament",  0.5))
	archetype             = NpcSchedule.archetype_from_string(data.get("archetype", "independent"))
	work_location         = str(data.get("work_location", ""))
	tick_overrides        = data.get("tick_overrides", {})
	day_pattern_overrides = data.get("day_pattern_overrides", [])
	_faction              = data.get("faction", "merchant")

	# ── Movement module ───────────────────────────────────────────────────────
	_movement = NpcMovement.new()
	add_child(_movement)
	_movement.setup(self, pathfinder, walkable, start_cell)

	# ── Dialogue module ───────────────────────────────────────────────────────
	_dialogue = NpcDialogue.new()
	add_child(_dialogue)
	_dialogue.setup(self, data.get("id", ""))

	# ── Visuals module ────────────────────────────────────────────────────────
	_visuals = NpcVisuals.new()
	add_child(_visuals)
	_visuals.setup(self, sprite, name_label, _faction)

	# ── Rumor processing module ───────────────────────────────────────────────
	_rumor_processing = NpcRumorProcessing.new()
	add_child(_rumor_processing)
	_rumor_processing.setup(self)

	name_label.text = data.get("name", "NPC")


# ── Per-tick entry point ──────────────────────────────────────────────────────

func on_tick(tick: int) -> void:
	_current_hour = tick % 24
	if _movement != null:
		_movement.step_movement()
	if _rumor_processing != null:
		_rumor_processing.process_rumor_slots(tick)
		_rumor_processing.tick_defender(tick)
	if _dialogue != null:
		_dialogue.tick_bubbles(tick, _current_hour)
	_tick_defense_modifiers()
	if _visuals != null:
		_visuals.update_label(_faction, _dialogue)


# ── Public schedule entry (called by World) ───────────────────────────────────

func update_tick_schedule(slot: int, day: int, gathering_points: Dictionary) -> void:
	if _movement != null:
		_movement.update_tick_schedule(slot, day, gathering_points)


# ── Rumor ingestion ───────────────────────────────────────────────────────────

func hear_rumor(rumor: Rumor, source_faction: String) -> void:
	var rid := rumor.id
	if _has_engine():
		propagation_engine_ref.register_rumor(rumor)
	if rumor_slots.has(rid):
		var slot: Rumor.NpcRumorSlot = rumor_slots[rid]
		if slot.state in [Rumor.RumorState.BELIEVE,      Rumor.RumorState.REJECT,
						   Rumor.RumorState.SPREAD,       Rumor.RumorState.ACT,
						   Rumor.RumorState.CONTRADICTED, Rumor.RumorState.EXPIRED]:
			return
		slot.heard_from_count += 1
		return
	var slot := Rumor.NpcRumorSlot.new(rumor, source_faction)
	rumor_slots[rid] = slot
	_worst_state_dirty = true
	if _dialogue != null:
		_dialogue.show_hear_reaction()
	emit_signal("first_npc_became_evaluating")


# ── Query helpers ─────────────────────────────────────────────────────────────

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


func _is_schedule_overridden() -> bool:
	for slot in rumor_slots.values():
		if slot.state in [Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
			return true
	return false


# ── Rumor memory helpers ──────────────────────────────────────────────────────

func _record_rumor_history(rumor: Rumor, subject_id: String, outcome: String, tick: int) -> void:
	rumor_history.append({
		"rumor_id":   rumor.id,
		"subject_id": subject_id,
		"claim_type": rumor.claim_type,
		"outcome":    outcome,
		"tick":       tick,
	})


func _apply_credulity_modifier(delta: float) -> void:
	var prev := _credulity_modifier
	_credulity_modifier = clampf(
		_credulity_modifier + delta,
		_CREDULITY_MODIFIER_FLOOR, _CREDULITY_MODIFIER_CEILING
	)
	var actual_delta := _credulity_modifier - prev
	if abs(actual_delta) < 0.0001:
		return
	_credulity = clamp(_credulity + actual_delta, 0.0, 1.0)
	npc_data["credulity"] = _credulity


func _update_schedule_avoidance(rumor: Rumor) -> void:
	if Rumor.is_positive_claim(rumor.claim_type):
		return
	var subject_id := rumor.subject_npc_id
	if _avoided_subject_ids.has(subject_id):
		return
	_avoided_subject_ids.append(subject_id)


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


func _is_chapel_frozen() -> bool:
	return quarantine_ref != null \
		and quarantine_ref.is_quarantined("chapel") \
		and current_location_code == "chapel"


func _reroute_if_avoided(location_code: String) -> String:
	if _avoided_subject_ids.is_empty() or location_code == "home":
		return location_code
	for other in all_npcs_ref:
		var tid: String = other.npc_data.get("id", "")
		if _avoided_subject_ids.has(tid) and other.work_location == location_code:
			return "home"
	return location_code


# ── Defense helpers ───────────────────────────────────────────────────────────

func _apply_defense_penalty(subject_id: String, penalty: float) -> void:
	var current: float = _defense_modifiers.get(subject_id, 0.0)
	_defense_modifiers[subject_id] = minf(current + penalty, _DEFENSE_PENALTY_CAP)
	_defense_modifier_ticks[subject_id] = _DEFENSE_MOD_DURATION


func _tick_defense_modifiers() -> void:
	var to_remove: Array = []
	for sid in _defense_modifier_ticks.keys():
		_defense_modifier_ticks[sid] -= 1
		if _defense_modifier_ticks[sid] <= 0:
			to_remove.append(sid)
	for sid in to_remove:
		_defense_modifiers.erase(sid)
		_defense_modifier_ticks.erase(sid)


# ── Dialogue category + time helpers (tested — must stay here) ────────────────

## Maps a rumor state to the matching dialogue category key, or "" for states
## that have no dedicated dialogue.
func _state_to_dialogue_category(state: Rumor.RumorState) -> String:
	match state:
		Rumor.RumorState.EVALUATING: return "hear"
		Rumor.RumorState.BELIEVE:    return "believe"
		Rumor.RumorState.REJECT:     return "reject"
		Rumor.RumorState.SPREAD:     return "spread"
		Rumor.RumorState.ACT:        return "act"
		Rumor.RumorState.DEFENDING:  return "defending"
	return ""


## Returns the broad time-of-day phase.
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


# ── Internal helper ───────────────────────────────────────────────────────────

func _has_engine() -> bool:
	return propagation_engine_ref != null


# ── Per-frame / per-draw ──────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _visuals != null:
		_visuals.process_heat(delta)


func _draw() -> void:
	if _visuals != null and _visuals._ripple_alpha > 0.01:
		draw_arc(Vector2(0.0, -36.0), _visuals._ripple_radius, 0.0, TAU, 32,
			Color(1.0, 0.85, 0.3, _visuals._ripple_alpha), 2.0, true)


# ── Public API — delegated to modules ────────────────────────────────────────

func set_hover(hovered: bool) -> void:
	if _visuals != null:
		_visuals.set_hover(hovered)


func set_selected(selected: bool) -> void:
	if _visuals != null:
		_visuals.set_selected(selected)


func set_belief_shaken(shaken: bool) -> void:
	if _visuals != null:
		_visuals.set_belief_shaken(shaken)


func show_spread_ripple() -> void:
	if _visuals != null:
		_visuals.show_spread_ripple()


func flash_reputation(gained: bool) -> void:
	if _visuals != null:
		_visuals.flash_reputation(gained)


func flash_belief_vignette() -> void:
	if _visuals != null:
		_visuals.flash_belief_vignette()


func flash_interaction_greeting() -> void:
	if _visuals != null:
		_visuals.flash_interaction_greeting()


func flash_action_failed() -> void:
	if _visuals != null:
		_visuals.flash_action_failed()


func flash_click() -> void:
	if _visuals != null:
		_visuals.flash_click()


func flash_seed_confirmation() -> void:
	if _visuals != null:
		_visuals.flash_seed_confirmation()


func show_name_popup() -> void:
	if _visuals != null:
		_visuals.show_name_popup()


func show_rumor_received_glow() -> void:
	if _visuals != null:
		_visuals.show_rumor_received_glow()


func show_bribed_effect() -> void:
	if _visuals != null:
		_visuals.show_bribed_effect()


func show_reputation_change(delta: int) -> void:
	if _visuals != null:
		_visuals.show_reputation_change(delta)


func show_suspicion_raised() -> void:
	if _visuals != null:
		_visuals.show_suspicion_raised()


func show_observed() -> void:
	if _dialogue != null:
		_dialogue.show_observed(_visuals.get_heat() if _visuals != null else 0.0)


func show_eavesdropped() -> void:
	if _dialogue != null:
		_dialogue.show_eavesdropped(_visuals.get_heat() if _visuals != null else 0.0)


func get_spread_preview(n: int = 3) -> Array[Dictionary]:
	if _rumor_processing != null:
		return _rumor_processing.get_spread_preview(n)
	return []

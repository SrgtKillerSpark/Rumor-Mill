## faction_event_system.gd — Fires 1-2 random faction events per scenario run.
##
## Events make the town feel alive by mutating the social graph,
## temporarily overriding NPC schedules, and adjusting gameplay parameters.
##
## Four event types (drawn randomly on scenario start):
##   market_dispute     — shifts 2-3 merchant edge weights, creates eavesdrop cluster
##   religious_festival — clergy gather at chapel, faction sentiment boost for 2 days
##   noble_feast        — nobles gather at manor, eavesdrop opportunity for 2 days
##   guard_crackdown    — heat decay slows to 3/day for 2 days
##
## Ownership: World creates and owns this class. World.on_day_changed() drives it.
##
## Usage:
##   var fes := FactionEventSystem.new()
##   fes.initialize(self)                   # call after all subsystems are ready
##   # then in _on_day_changed(day): fes.on_day_changed(day)

class_name FactionEventSystem


const ALL_EVENT_TYPES: Array = [
	"market_dispute",
	"religious_festival",
	"noble_feast",
	"guard_crackdown",
]

const MIN_TRIGGER_DAY := 2
const MAX_TRIGGER_DAY := 7

## 1 or 2 events per scenario run.
const MAX_EVENTS := 2

## Faction sentiment flat bonus applied to each clergy NPC during religious_festival.
const RELIGIOUS_FESTIVAL_SENTIMENT_BONUS := 10.0

## Duration in days for timed effects.
const TIMED_EVENT_DURATION := 2

## Heat decay rate during guard_crackdown (normal: 6/day — see intel_store.gd).
const GUARD_CRACKDOWN_HEAT_DECAY := 3.0

## Foreshadow hint text shown 2 days before each event type activates (SPA-952).
const FORESHADOW_TEXT: Dictionary = {
	"market_dispute":     "Merchants in the market square are growing restless — tensions between them may spill over soon.",
	"religious_festival": "The clergy have begun preparations for a gathering — devotion will run high across town.",
	"noble_feast":        "Nobles have started sending invitations around town — a feast at the manor appears imminent.",
	"guard_crackdown":    "Guards have been seen conferring in hushed tones — expect a much tighter watch on the streets soon.",
}


# ---------------------------------------------------------------------------
# Internal event record
# ---------------------------------------------------------------------------

class FactionEvent:
	var event_type:       String
	var trigger_day:      int
	var duration_days:    int     ## 0 = permanent side effects (e.g. edge mutations)
	var affected_npc_ids: Array   ## String ids
	var metadata:         Dictionary
	var is_active:        bool = false
	var is_expired:       bool = false


# ---------------------------------------------------------------------------
# Subsystem references (injected by initialize())
# ---------------------------------------------------------------------------

var _world:             Node   = null
var _social_graph:      Object = null  ## SocialGraph
var _intel_store:       Object = null  ## PlayerIntelStore
var _reputation_system: Object = null  ## ReputationSystem
var _npcs:              Array  = []

## Scheduled events for this run.
var _events: Array = []

## Eavesdrop hotspots surfaced to the ReconController.
## Key = location_code string, value = day the hotspot expires (-1 = permanent).
var eavesdrop_hotspots: Dictionary = {}


# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Must be called once after World has initialised all subsystems.
func initialize(world: Node) -> void:
	_world             = world
	_social_graph      = world.social_graph
	_intel_store       = world.intel_store
	_reputation_system = world.reputation_system
	_npcs              = world.npcs
	_schedule_events()


## Restore serialised state after a save-game load.
## Called by SaveManager.apply_pending_load() after initialize() has already run.
## Replaces the freshly-scheduled events with the saved schedule and re-applies
## any side-effects that were active at save time.
func restore_from_data(d: Dictionary) -> void:
	if d.is_empty():
		return
	_events.clear()
	for ed in d.get("events", []):
		var ev       := FactionEvent.new()
		ev.event_type       = str(ed.get("event_type", ""))
		ev.trigger_day      = int(ed.get("trigger_day", 0))
		ev.duration_days    = int(ed.get("duration_days", 0))
		ev.affected_npc_ids = ed.get("affected_npc_ids", []).duplicate()
		ev.metadata         = ed.get("metadata", {}).duplicate(true)
		ev.is_active        = bool(ed.get("is_active", false))
		ev.is_expired       = bool(ed.get("is_expired", false))
		_events.append(ev)
	eavesdrop_hotspots = d.get("eavesdrop_hotspots", {}).duplicate()
	# Re-apply side-effects for events that were active at save time.
	for ev in _events:
		if ev.is_active and not ev.is_expired:
			_reapply_active_effects(ev)


## Re-applies side-effects for an active event without re-running full activation.
## Avoids re-mutating the social graph (already restored), re-emitting signals,
## or duplicating NPC schedule overrides.
func _reapply_active_effects(ev: FactionEvent) -> void:
	match ev.event_type:
		"guard_crackdown":
			if _intel_store != null:
				_intel_store.heat_decay_override = GUARD_CRACKDOWN_HEAT_DECAY
		"religious_festival", "noble_feast":
			var injected_map: Dictionary = ev.metadata.get("injected_overrides", {})
			for npc_id in injected_map:
				var npc: Node = _find_npc(npc_id)
				if npc == null:
					continue
				for entry in injected_map[npc_id]:
					if not npc.day_pattern_overrides.has(entry):
						npc.day_pattern_overrides.append(entry)


## Randomly picks 1-2 distinct event types and assigns staggered trigger days.
func _schedule_events() -> void:
	var pool: Array = ALL_EVENT_TYPES.duplicate()
	pool.shuffle()
	var count: int = randi_range(1, MAX_EVENTS)
	var used_days: Array = []

	for i in range(mini(count, pool.size())):
		var ev  := FactionEvent.new()
		ev.event_type  = pool[i]
		ev.trigger_day = _pick_unique_day(used_days)
		used_days.append(ev.trigger_day)
		_configure_event(ev)
		_events.append(ev)


func _pick_unique_day(used: Array) -> int:
	for _attempt in range(20):
		var d: int = randi_range(MIN_TRIGGER_DAY, MAX_TRIGGER_DAY)
		if not used.has(d):
			return d
	return randi_range(MIN_TRIGGER_DAY, MAX_TRIGGER_DAY)


## Pre-compute which NPCs are affected (called once at schedule time).
func _configure_event(ev: FactionEvent) -> void:
	match ev.event_type:
		"market_dispute":
			ev.duration_days    = 0   ## edge mutations are permanent within mutation cap
			var merchants: Array = _npcs_by_faction("merchant")
			merchants.shuffle()
			ev.affected_npc_ids = _pick_ids(merchants, 2)

		"religious_festival":
			ev.duration_days    = TIMED_EVENT_DURATION
			ev.affected_npc_ids = _npc_ids_by_faction("clergy")

		"noble_feast":
			ev.duration_days    = TIMED_EVENT_DURATION
			ev.affected_npc_ids = _npc_ids_by_faction("noble")

		"guard_crackdown":
			ev.duration_days    = TIMED_EVENT_DURATION
			ev.affected_npc_ids = []


# ---------------------------------------------------------------------------
# Per-day driver
# ---------------------------------------------------------------------------

## Call once per new game day (from World._on_day_changed).
func on_day_changed(day: int) -> void:
	for ev in _events:
		if ev.is_expired:
			continue
		if not ev.is_active and day == ev.trigger_day:
			_activate_event(ev, day)
		elif ev.is_active and ev.duration_days > 0:
			var elapsed: int = day - ev.trigger_day
			if elapsed >= ev.duration_days:
				_expire_event(ev, day)

	# Prune stale eavesdrop hotspots.
	var to_erase: Array = []
	for loc in eavesdrop_hotspots:
		var expiry: int = eavesdrop_hotspots[loc]
		if expiry >= 0 and day >= expiry:
			to_erase.append(loc)
	for loc in to_erase:
		eavesdrop_hotspots.erase(loc)


# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

func _activate_event(ev: FactionEvent, day: int) -> void:
	ev.is_active = true
	match ev.event_type:
		"market_dispute":     _activate_market_dispute(ev, day)
		"religious_festival": _activate_religious_festival(ev, day)
		"noble_feast":        _activate_noble_feast(ev, day)
		"guard_crackdown":    _activate_guard_crackdown(ev)
	pass


## Market Dispute: mutate 2-3 edges between disputing merchants and open a
## market eavesdrop hotspot for 3 days.
func _activate_market_dispute(ev: FactionEvent, day: int) -> void:
	if _social_graph == null or ev.affected_npc_ids.size() < 2:
		return
	var a: String = ev.affected_npc_ids[0]
	var b: String = ev.affected_npc_ids[1]
	var tick: int = (day - 1) * 24   ## approximate game tick at start of day
	var delta := -0.3

	# Mutate a→b and b→a.
	_social_graph.mutate_edge(a, b, delta, tick)
	_social_graph.mutate_edge(b, a, delta, tick)

	# Mutate a third edge: highest-weight neighbour of 'a' that isn't 'b'.
	var top: Array = _social_graph.get_top_neighbours(a, 5)
	for entry in top:
		if entry[0] != b:
			_social_graph.mutate_edge(a, entry[0], delta, tick)
			break

	# Eavesdrop hotspot at market for 3 days.
	eavesdrop_hotspots["market"] = day + 3
	ev.metadata["eavesdrop_location"] = "market"


## Religious Festival: send all clergy to chapel for 2 days and apply a
## flat faction sentiment bonus to each clergy NPC via the ReputationSystem.
func _activate_religious_festival(ev: FactionEvent, day: int) -> void:
	var injected_map: Dictionary = {}
	for npc_id in ev.affected_npc_ids:
		var npc: Node = _find_npc(npc_id)
		if npc == null:
			continue
		var injected: Array = []
		for d in [day, day + 1]:
			for slot in range(NpcSchedule.SLOTS_PER_DAY):
				var entry := {"day": d, "tick": slot, "location": "chapel"}
				npc.day_pattern_overrides.append(entry)
				injected.append(entry)
		injected_map[npc_id] = injected

	ev.metadata["injected_overrides"] = injected_map

	if _reputation_system != null:
		for npc_id in ev.affected_npc_ids:
			_reputation_system.set_faction_sentiment_bonus(
				npc_id, RELIGIOUS_FESTIVAL_SENTIMENT_BONUS)


## Noble Feast: send nobles to manor for 2 days (waking hours only) and
## expose a manor eavesdrop hotspot for the duration.
func _activate_noble_feast(ev: FactionEvent, day: int) -> void:
	var injected_map: Dictionary = {}
	for npc_id in ev.affected_npc_ids:
		var npc: Node = _find_npc(npc_id)
		if npc == null:
			continue
		var injected: Array = []
		for d in [day, day + 1]:
			# Slots 1-5 only (slot 0 = night; nobles sleep at home).
			for slot in range(1, NpcSchedule.SLOTS_PER_DAY):
				var entry := {"day": d, "tick": slot, "location": "manor"}
				npc.day_pattern_overrides.append(entry)
				injected.append(entry)
		injected_map[npc_id] = injected

	ev.metadata["injected_overrides"] = injected_map

	eavesdrop_hotspots["manor"] = day + ev.duration_days
	ev.metadata["eavesdrop_location"] = "manor"


## Guard Crackdown: slow heat decay to GUARD_CRACKDOWN_HEAT_DECAY/day for 2 days.
func _activate_guard_crackdown(ev: FactionEvent) -> void:
	if _intel_store != null:
		_intel_store.heat_decay_override = GUARD_CRACKDOWN_HEAT_DECAY


# ---------------------------------------------------------------------------
# Expiry
# ---------------------------------------------------------------------------

func _expire_event(ev: FactionEvent, day: int) -> void:
	ev.is_expired = true
	ev.is_active  = false
	match ev.event_type:
		"religious_festival":
			_remove_injected_overrides(ev)
			if _reputation_system != null:
				for npc_id in ev.affected_npc_ids:
					_reputation_system.clear_faction_sentiment_bonus(npc_id)
		"noble_feast":
			_remove_injected_overrides(ev)
			var loc: String = ev.metadata.get("eavesdrop_location", "")
			if not loc.is_empty():
				eavesdrop_hotspots.erase(loc)
		"guard_crackdown":
			if _intel_store != null:
				_intel_store.heat_decay_override = -1.0   ## restore default
	pass


func _remove_injected_overrides(ev: FactionEvent) -> void:
	var injected_map: Dictionary = ev.metadata.get("injected_overrides", {})
	for npc_id in injected_map:
		var npc: Node = _find_npc(npc_id)
		if npc == null:
			continue
		for entry in injected_map[npc_id]:
			# Value-based removal: after save/load, dict references differ.
			for i in range(npc.day_pattern_overrides.size() - 1, -1, -1):
				if npc.day_pattern_overrides[i].hash() == entry.hash():
					npc.day_pattern_overrides.remove_at(i)
					break


# ---------------------------------------------------------------------------
# Public queries
# ---------------------------------------------------------------------------

## Returns labels of currently active (non-expired) events for HUD display.
func get_active_event_labels() -> Array:
	var result: Array = []
	for ev in _events:
		if ev.is_active and not ev.is_expired:
			result.append(_label(ev.event_type))
	return result


## Returns true if a given location code is an active eavesdrop hotspot.
func is_eavesdrop_hotspot(location_code: String) -> bool:
	return eavesdrop_hotspots.has(location_code)


## Returns foreshadow hint texts for events scheduled to trigger on day + 2 (SPA-952).
## Called by main.gd from _on_ctx_day_changed to prime the player two days early.
func get_foreshadow_for_day(day: int) -> Array:
	var result: Array = []
	for ev in _events:
		if not ev.is_expired and not ev.is_active and ev.trigger_day == day + 2:
			var text: String = FORESHADOW_TEXT.get(ev.event_type, "")
			if not text.is_empty():
				result.append(text)
	return result


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _npcs_by_faction(faction: String) -> Array:
	var result: Array = []
	for npc in _npcs:
		if npc.npc_data.get("faction", "") == faction:
			result.append(npc)
	return result


func _npc_ids_by_faction(faction: String) -> Array:
	var ids: Array = []
	for npc in _npcs:
		if npc.npc_data.get("faction", "") == faction:
			ids.append(npc.npc_data.get("id", ""))
	return ids


func _pick_ids(npc_list: Array, count: int) -> Array:
	var ids: Array = []
	for npc in npc_list:
		ids.append(npc.npc_data.get("id", ""))
		if ids.size() >= count:
			break
	return ids


func _find_npc(npc_id: String) -> Node:
	for npc in _npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc
	return null


func _label(event_type: String) -> String:
	match event_type:
		"market_dispute":     return "Market Dispute"
		"religious_festival": return "Religious Festival"
		"noble_feast":        return "Noble Feast"
		"guard_crackdown":    return "Guard Crackdown"
	return event_type

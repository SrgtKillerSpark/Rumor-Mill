## faction_memory_horizon.gd — A3.2 SPA-3295: Faction memory horizons.
##
## Each player action against a faction is recorded as a time-decaying
## disposition delta. Per-tick effective disposition is:
##
##   faction_disposition = base_disposition + sum(
##       original_delta * max(0.0, 1.0 - (ticks_elapsed / horizon_ticks))
##       for each entry in action_memory
##   )
##
## Severity horizons:
##   Major    (72 ticks ~12 days): rep loss >= 15, "faction_schism" source
##   Moderate (42 ticks ~7 days) : "seed", "evidence"
##   Minor    (18 ticks ~3 days) : "observe", "eavesdrop"
##
## Stack cap: max 10 entries per faction; oldest entry pruned on overflow.
## Pruning: entries with zero remaining impact removed by on_tick().
##
## Dialog hint qualifiers: when any entry is below 50% of original impact
## AND disposition is >= 3 points from nearest band boundary, a qualifier
## string is returned by get_dialog_qualifier(faction_id, current_tick).
##
## Band layout (disposition scale):
##   Hostile  : disposition <= -10
##   Wary     : -10 < disposition <= 0
##   Warm     : 0 < disposition <= 10
##   Friendly : disposition > 10
##
## Usage (world.gd on_game_tick):
##   faction_memory_horizon.on_tick(current_tick)
##
## Record a player action:
##   faction_memory_horizon.record_action(faction_id, delta, current_tick, source)

class_name FactionMemoryHorizon
extends RefCounted

# ── Severity horizon lengths in ticks ────────────────────────────────────────

## Major: faction schism event, or reputation delta magnitude >= MAJOR_DELTA_THRESHOLD.
const HORIZON_MAJOR: int = 72
## Moderate: seeding a rumor at a faction member, evidence attachment.
const HORIZON_MODERATE: int = 42
## Minor: observing a faction location, undetected eavesdrop.
const HORIZON_MINOR: int = 18

## Delta magnitude threshold for Major severity classification.
const MAJOR_DELTA_THRESHOLD: int = 15

## Maximum action memory entries per faction stack.
const STACK_CAP: int = 10

# ── Disposition band boundaries ───────────────────────────────────────────────

## Disposition <= BAND_HOSTILE_MAX → "Hostile".
const BAND_HOSTILE_MAX: float = -10.0
## BAND_HOSTILE_MAX < disposition <= BAND_WARY_MAX → "Wary".
const BAND_WARY_MAX: float = 0.0
## BAND_WARY_MAX < disposition <= BAND_WARM_MAX → "Warm".
const BAND_WARM_MAX: float = 10.0
## disposition > BAND_WARM_MAX → "Friendly".

## Minimum distance from nearest band boundary to show fading qualifier.
const QUALIFIER_MARGIN: float = 3.0

# ── Action source sets for severity classification ────────────────────────────

const MINOR_SOURCES: Array    = ["observe", "eavesdrop"]
const MODERATE_SOURCES: Array = ["seed", "evidence"]

# ── Internal data ─────────────────────────────────────────────────────────────

## Per-faction action memory stacks.
## faction_id → Array of { delta: int, tick: int, horizon: int, source: String }
var _action_memory: Dictionary = {}

## Per-faction base dispositions. Default 0.0 when absent.
var _base_disposition: Dictionary = {}


# ── Public API ────────────────────────────────────────────────────────────────

## Record a player action that modifies faction disposition.
## source:  "seed", "evidence", "eavesdrop", "observe", "faction_schism",
##          or any custom string (falls back to Moderate horizon).
## delta:   signed integer — negative damages, positive builds goodwill.
func record_action(faction_id: String, delta: int, tick: int, source: String) -> void:
	var horizon: int = _classify_horizon(delta, source)
	if not _action_memory.has(faction_id):
		_action_memory[faction_id] = []
	var stack: Array = _action_memory[faction_id]
	stack.append({"delta": delta, "tick": tick, "horizon": horizon, "source": source})
	# Enforce stack cap: remove the oldest entry when over limit.
	while stack.size() > STACK_CAP:
		stack.remove_at(0)


## Compute the current effective disposition for a faction at current_tick.
## Returns base_disposition (default 0) when no action memory exists.
func get_disposition(faction_id: String, current_tick: int) -> float:
	var base: float = _base_disposition.get(faction_id, 0.0)
	var stack: Array = _action_memory.get(faction_id, [])
	var total: float = 0.0
	for entry in stack:
		total += _remaining_impact(entry, current_tick)
	return base + total


## Set the permanent base disposition for a faction.
## Use positive values for starting goodwill, negative for starting hostility.
func set_base_disposition(faction_id: String, value: float) -> void:
	_base_disposition[faction_id] = value


## Prune entries whose remaining impact rounds to zero across all faction stacks.
## Call once per game tick (from world.on_game_tick).
func on_tick(current_tick: int) -> void:
	for faction_id in _action_memory:
		var stack: Array = _action_memory[faction_id]
		for i in range(stack.size() - 1, -1, -1):
			if absf(_remaining_impact(stack[i], current_tick)) < 0.001:
				stack.remove_at(i)


## Returns the disposition band name for a given disposition value.
## Used by dialog hint rendering and tests.
static func get_band(disposition: float) -> String:
	if disposition <= BAND_HOSTILE_MAX:
		return "Hostile"
	elif disposition <= BAND_WARY_MAX:
		return "Wary"
	elif disposition <= BAND_WARM_MAX:
		return "Warm"
	else:
		return "Friendly"


## Returns a fading qualifier string when both conditions hold:
##   1. At least one memory entry is below 50% of its original impact.
##   2. Disposition is >= QUALIFIER_MARGIN points from the nearest band boundary.
## Returns "" when the condition is not met or the faction has no memory.
func get_dialog_qualifier(faction_id: String, current_tick: int) -> String:
	if not _is_actively_decaying(faction_id, current_tick):
		return ""
	var disp: float = get_disposition(faction_id, current_tick)
	if not _is_far_from_boundary(disp):
		return ""
	match get_band(disp):
		"Hostile":  return "...but memories are fading"
		"Wary":     return "...though less so than before"
		"Warm":     return "...though the goodwill is fading"
		"Friendly": return "...but old favors are being forgotten"
	return ""


## Serialize state to a Dictionary for save/load.
func to_dict() -> Dictionary:
	return {
		"action_memory":    _action_memory.duplicate(true),
		"base_disposition": _base_disposition.duplicate(),
	}


## Restore serialized state. No-op when d is empty (preserves existing state).
func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	_action_memory    = d.get("action_memory",    {}).duplicate(true)
	_base_disposition = d.get("base_disposition",  {}).duplicate()


# ── Internal helpers ──────────────────────────────────────────────────────────

## How much impact the action entry still has at current_tick.
## Returns 0.0 when ticks_elapsed >= horizon.
func _remaining_impact(entry: Dictionary, current_tick: int) -> float:
	var ticks_elapsed: int = current_tick - int(entry.get("tick", 0))
	var horizon: int = int(entry.get("horizon", HORIZON_MINOR))
	if ticks_elapsed >= horizon:
		return 0.0
	var fraction: float = 1.0 - float(ticks_elapsed) / float(horizon)
	return float(int(entry.get("delta", 0))) * fraction


## Returns true if any entry has decayed past 50% of its original impact
## (i.e. more than half its horizon has elapsed).
func _is_actively_decaying(faction_id: String, current_tick: int) -> bool:
	var stack: Array = _action_memory.get(faction_id, [])
	for entry in stack:
		var horizon: int = int(entry.get("horizon", HORIZON_MINOR))
		if horizon <= 0:
			continue
		var ticks_elapsed: int = current_tick - int(entry.get("tick", 0))
		if float(ticks_elapsed) / float(horizon) > 0.5:
			return true
	return false


## Returns true when disposition is >= QUALIFIER_MARGIN points from the
## nearest band boundary (-10, 0, or 10).
static func _is_far_from_boundary(disposition: float) -> bool:
	var min_dist: float = INF
	for b in [BAND_HOSTILE_MAX, BAND_WARY_MAX, BAND_WARM_MAX]:
		var dist: float = absf(disposition - b)
		if dist < min_dist:
			min_dist = dist
	return min_dist >= QUALIFIER_MARGIN


## Classify the severity horizon for an action based on source and delta.
func _classify_horizon(delta: int, source: String) -> int:
	if source == "faction_schism":
		return HORIZON_MAJOR
	if absi(delta) >= MAJOR_DELTA_THRESHOLD:
		return HORIZON_MAJOR
	if MODERATE_SOURCES.has(source):
		return HORIZON_MODERATE
	if MINOR_SOURCES.has(source):
		return HORIZON_MINOR
	return HORIZON_MODERATE  # unknown source defaults to Moderate

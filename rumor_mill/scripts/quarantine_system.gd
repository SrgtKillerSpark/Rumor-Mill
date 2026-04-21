## quarantine_system.gd — S2-only quarantine zone mechanic (SPA-868).
##
## Allows the player to spend 2 Whisper tokens to quarantine a building.
## NPCs inside a quarantined building cannot spread rumors for 3 ticks
## and cannot be interacted with (seed/observe/eavesdrop).
##
## Integration:
##   - World instantiates QuarantineSystem and calls activate() for scenario_2.
##   - World.on_game_tick() calls quarantine_system.tick() each tick.
##   - Scenario2Hud adds a "Quarantine" button that calls try_quarantine().

class_name QuarantineSystem

## Emitted when a building is quarantined. building_name: String, expires_tick: int.
signal building_quarantined(building_name: String, expires_tick: int)
## Emitted when a quarantine expires. building_name: String.
signal quarantine_expired(building_name: String)

## Number of whisper tokens required to quarantine a building.
const QUARANTINE_COST := 2
## Duration of quarantine in game ticks.
const QUARANTINE_DURATION_TICKS := 3

var _active: bool = false

## building_name → expires_tick (tick at which quarantine lifts).
var _quarantined: Dictionary = {}


func activate() -> void:
	_active = true
	_quarantined.clear()


## Attempt to quarantine a building. Returns true on success.
## Caller must provide the intel_store (for token spending) and current tick.
func try_quarantine(building_name: String, intel_store: PlayerIntelStore, current_tick: int) -> bool:
	if not _active:
		return false
	if _quarantined.has(building_name):
		return false  # already quarantined
	# Need 2 whisper tokens — spend them one at a time.
	if intel_store.whisper_tokens_remaining < QUARANTINE_COST:
		return false
	# Spend both tokens.
	for i in QUARANTINE_COST:
		if not intel_store.try_spend_whisper():
			return false  # shouldn't happen after the check above
	var expires := current_tick + QUARANTINE_DURATION_TICKS
	_quarantined[building_name] = expires
	building_quarantined.emit(building_name, expires)
	return true


## Called each game tick to expire quarantines.
func tick(current_tick: int) -> void:
	if not _active:
		return
	var expired_keys: Array = []
	for building_name in _quarantined:
		if current_tick >= _quarantined[building_name]:
			expired_keys.append(building_name)
	for key in expired_keys:
		_quarantined.erase(key)
		quarantine_expired.emit(key)


## Returns true if the given building is currently quarantined.
func is_quarantined(building_name: String) -> bool:
	return _quarantined.has(building_name)


## Returns the set of currently quarantined building names.
func get_quarantined_buildings() -> Array:
	return _quarantined.keys()


## Returns the tick at which a quarantine expires, or -1 if not quarantined.
func get_expiry_tick(building_name: String) -> int:
	return _quarantined.get(building_name, -1)


## Returns true if the system is active (S2 only).
func is_active() -> bool:
	return _active

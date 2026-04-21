## quarantine_system.gd — S2-only quarantine zone mechanic (SPA-868 / SPA-874).
##
## Allows the player to spend 1 Recon Action + 1 Whisper Token to quarantine a
## building for 2 in-game days. Outside NPCs avoid the quarantined building
## (schedule override). The mechanic is limited to one active quarantine at a
## time; re-quarantining the same building is blocked for 3 days after expiry.
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

## Recon actions required to quarantine a building.
const QUARANTINE_RECON_COST := 1
## Whisper tokens required to quarantine a building.
const QUARANTINE_WHISPER_COST := 1
## Legacy alias kept for HUD compatibility.
const QUARANTINE_COST := QUARANTINE_WHISPER_COST
## Duration of quarantine in game ticks (2 days at default 24 tph).
const QUARANTINE_DURATION_TICKS := 48
## Cooldown in game ticks before the same building can be quarantined again
## (3 days at default 24 tph).
const QUARANTINE_COOLDOWN_TICKS := 72

var _active: bool = false

## building_name → expires_tick (tick at which quarantine lifts).
var _quarantined: Dictionary = {}

## SPA-874: building_name → cooldown_until_tick (cannot quarantine again until this tick).
var _cooldown_until: Dictionary = {}


func activate() -> void:
	_active = true
	_quarantined.clear()
	_cooldown_until.clear()


## Returns true if the building is within its post-expiry cooldown window.
func is_on_cooldown(building_name: String, current_tick: int) -> bool:
	if not _cooldown_until.has(building_name):
		return false
	return current_tick < _cooldown_until[building_name]


## Attempt to quarantine a building. Returns true on success.
## Caller must provide the intel_store (for resource spending) and current tick.
## SPA-874: Cost changed to 1 Recon Action + 1 Whisper Token.  Max 1 active
## quarantine at a time; per-building cooldown of 3 days after expiry.
func try_quarantine(building_name: String, intel_store: PlayerIntelStore, current_tick: int) -> bool:
	if not _active:
		return false
	if _quarantined.has(building_name):
		return false  # already quarantined
	# SPA-874: only one quarantine may be active at a time.
	if not _quarantined.is_empty():
		return false
	# SPA-874: per-building cooldown check.
	if is_on_cooldown(building_name, current_tick):
		return false
	# Use a free charge (granted by s2_infected_cart decision event) if available,
	# otherwise require the normal 1 Recon Action + 1 Whisper Token cost.
	if intel_store.free_quarantine_charges > 0:
		intel_store.free_quarantine_charges -= 1
	else:
		if intel_store.recon_actions_remaining < QUARANTINE_RECON_COST:
			return false
		if intel_store.whisper_tokens_remaining < QUARANTINE_WHISPER_COST:
			return false
		if not intel_store.try_spend_action():
			return false
		if not intel_store.try_spend_whisper():
			return false  # shouldn't happen after the checks above
	var expires := current_tick + QUARANTINE_DURATION_TICKS
	_quarantined[building_name] = expires
	building_quarantined.emit(building_name, expires)
	return true


## Called each game tick to expire quarantines and start per-building cooldowns.
func tick(current_tick: int) -> void:
	if not _active:
		return
	var expired_keys: Array = []
	for building_name in _quarantined:
		if current_tick >= _quarantined[building_name]:
			expired_keys.append(building_name)
	for key in expired_keys:
		_quarantined.erase(key)
		# SPA-874: start the 3-day cooldown so the same building cannot be
		# immediately re-quarantined.
		_cooldown_until[key] = current_tick + QUARANTINE_COOLDOWN_TICKS
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

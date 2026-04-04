## scenario_analytics.gd — SPA-212: Collects per-tick gameplay data for the
## post-scenario analytics screen (rumor timeline, influence map, key moments).
##
## Wire via setup(world, day_night) from main.gd after world is ready.
## Read via get_timeline_data(), get_influence_ranking(), get_key_moments().

class_name ScenarioAnalytics

var _world_ref: Node2D = null
var _day_night_ref: Node = null

# ── Per-day rumor timeline ───────────────────────────────────────────────────
# Array of { "day": int, "live_count": int, "believer_count": int }
# Sampled once per day at the last tick of each day.
var timeline: Array = []

# ── Transmission log (for influence ranking) ─────────────────────────────────
# npc_name → { "spread_count": int, "received_count": int }
var _npc_transmission: Dictionary = {}

# ── Key moments ──────────────────────────────────────────────────────────────
# Array of { "day": int, "tick": int, "text": String, "type": String }
# type: "seed", "peak", "state_change", "social_death", "contradiction", "mutation"
var key_moments: Array = []

# ── Internal tracking ────────────────────────────────────────────────────────
var _peak_live_count: int = 0
var _peak_day: int = 0
var _last_sampled_day: int = -1
var _first_seed_recorded: bool = false
var _started: bool = false


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref = world
	_day_night_ref = day_night
	_started = true

	# Connect to game tick for periodic sampling.
	if day_night != null and day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_game_tick)

	# Connect to world rumor events for key moment detection.
	if world != null:
		if world.has_signal("rumor_event"):
			world.rumor_event.connect(_on_rumor_event)
		if world.has_signal("socially_dead_triggered"):
			world.socially_dead_triggered.connect(_on_socially_dead)

		# Connect to each NPC's rumor_transmitted for influence tracking.
		if "npcs" in world:
			for npc in world.npcs:
				if npc.has_signal("rumor_transmitted"):
					npc.rumor_transmitted.connect(_on_rumor_transmitted)


func _on_game_tick(current_tick: int) -> void:
	if _world_ref == null or _day_night_ref == null:
		return

	var current_day: int = _day_night_ref.current_day if "current_day" in _day_night_ref else 0

	# Sample once per day (on tick change to a new day).
	if current_day != _last_sampled_day:
		if _last_sampled_day >= 0:
			_sample_day(_last_sampled_day)
		_last_sampled_day = current_day

	# Track peak for key moments.
	var pe: PropagationEngine = _world_ref.propagation_engine if "propagation_engine" in _world_ref else null
	if pe != null:
		var live_count: int = pe.live_rumors.size()
		if live_count > _peak_live_count:
			_peak_live_count = live_count
			_peak_day = current_day


func _sample_day(day: int) -> void:
	var live_count := 0
	var believer_count := 0

	var pe: PropagationEngine = _world_ref.propagation_engine if "propagation_engine" in _world_ref else null
	if pe != null:
		live_count = pe.live_rumors.size()

	if "npcs" in _world_ref:
		for npc in _world_ref.npcs:
			if "rumor_slots" in npc:
				for slot_key in npc.rumor_slots:
					var state: int = npc.rumor_slots[slot_key]
					# Rumor.RumorState.BELIEVE = 2, SPREAD = 4, ACT = 5
					if state == 2 or state == 4 or state == 5:
						believer_count += 1
						break  # Count NPC once even if believing multiple rumors.

	timeline.append({
		"day": day,
		"live_count": live_count,
		"believer_count": believer_count,
	})


func _on_rumor_transmitted(from_name: String, to_name: String, _rumor_id: String) -> void:
	if not _npc_transmission.has(from_name):
		_npc_transmission[from_name] = { "spread_count": 0, "received_count": 0 }
	_npc_transmission[from_name]["spread_count"] += 1

	if not _npc_transmission.has(to_name):
		_npc_transmission[to_name] = { "spread_count": 0, "received_count": 0 }
	_npc_transmission[to_name]["received_count"] += 1


func _on_rumor_event(message: String, tick: int) -> void:
	var day: int = 0
	if _day_night_ref != null and "current_day" in _day_night_ref:
		day = _day_night_ref.current_day

	# Detect first seed.
	if not _first_seed_recorded and "seeded" in message.to_lower():
		_first_seed_recorded = true
		key_moments.append({
			"day": day, "tick": tick,
			"text": message,
			"type": "seed",
		})
		return

	# Detect state transitions to DEFENDING or CONTRADICTED.
	if "DEFENDING" in message:
		key_moments.append({
			"day": day, "tick": tick,
			"text": message,
			"type": "state_change",
		})
	elif "CONTRADICTED" in message or "REJECT" in message:
		key_moments.append({
			"day": day, "tick": tick,
			"text": message,
			"type": "contradiction",
		})


func _on_socially_dead(npc_id: String, npc_name: String, tick: int) -> void:
	var day: int = 0
	if _day_night_ref != null and "current_day" in _day_night_ref:
		day = _day_night_ref.current_day
	key_moments.append({
		"day": day, "tick": tick,
		"text": "%s reputation collapsed (socially dead)" % npc_name,
		"type": "social_death",
	})


## Call at scenario end to finalize data (sample current day, add peak moment).
func finalize() -> void:
	if _day_night_ref != null and "current_day" in _day_night_ref:
		_sample_day(_day_night_ref.current_day)

	# Add peak rumor spread as a key moment if we had any activity.
	if _peak_live_count > 0:
		key_moments.append({
			"day": _peak_day, "tick": 0,
			"text": "Peak rumor activity: %d active rumors" % _peak_live_count,
			"type": "peak",
		})

	# Sort key moments by day then tick.
	key_moments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["day"] != b["day"]:
			return a["day"] < b["day"]
		return a["tick"] < b["tick"]
	)


# ── Public API ───────────────────────────────────────────────────────────────

## Returns timeline data sorted by day.
func get_timeline_data() -> Array:
	return timeline


## Returns top N NPCs ranked by spread influence.
## Each entry: { "name": String, "spread_count": int, "received_count": int }
func get_influence_ranking(top_n: int = 5) -> Array:
	var entries: Array = []
	for npc_name in _npc_transmission:
		var data: Dictionary = _npc_transmission[npc_name]
		entries.append({
			"name": npc_name,
			"spread_count": data["spread_count"],
			"received_count": data["received_count"],
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["spread_count"] > b["spread_count"]
	)
	return entries.slice(0, top_n)


## Returns all recorded key moments.
func get_key_moments() -> Array:
	return key_moments

## inquisitor_agent.gd — Autonomous inquisitor that seeds heresy rumors in Scenario 4.
##
## Ghost system: no sprite, no movement. Activates only in Scenario 4.
## Each day the inquisitor may seed one HERESY rumor targeting one of the three
## protected NPCs, following a cooldown / intensity schedule tied to the game day.
##
## Integration:
##   - World instantiates InquisitorAgent and calls activate() when scenario_4 loads.
##   - World._on_day_changed() calls inquisitor_agent.tick(current_day, self, scenario_manager).

class_name InquisitorAgent

## Emitted each time the inquisitor successfully seeds a heresy rumor.
signal inquisitor_acted(day: int, claim_type: String, subject_id: String)

const PROTECTED_NPC_IDS: Array[String] = ["aldous_prior", "vera_midwife", "finn_monk"]

var _active: bool = false
var _last_seed_day: int = 0
var _target_index: int = 0  # cycles through protected NPCs

## Difficulty modifier applied to every cooldown tier (positive = slower inquisitor).
## Set by World._apply_active_scenario() before activate() is called.
var cooldown_offset: int = 0


func activate() -> void:
	_active = true
	_last_seed_day = 0
	_target_index = 0


## Called once per in-game day from World._on_day_changed().
func tick(current_day: int, world: Node, scenario_mgr: ScenarioManager) -> void:
	if not _active:
		return
	var cooldown := _get_cooldown(current_day)
	if current_day - _last_seed_day < cooldown:
		return
	_seed_heresy_rumor(current_day, world, scenario_mgr)
	_last_seed_day = current_day


func _get_cooldown(day: int) -> int:
	var base: int
	if day <= 5:
		base = 3   # Slow start: seed every 3 days
	elif day <= 12:
		base = 2   # Mid-game pressure: every 2 days
	else:
		base = 1   # Endgame: every day
	return maxi(1, base + cooldown_offset)


func _seed_heresy_rumor(day: int, world: Node, scenario_mgr: ScenarioManager) -> void:
	var intensity: int
	if day >= 15:
		intensity = 4
	elif day >= 8:
		intensity = 3
	else:
		intensity = 2

	# Pick the protected NPC with the highest reputation (most threatening to inquisitor).
	var rep: ReputationSystem = world.reputation_system
	var subject_id: String = _pick_target(rep)
	var claim_type_str: String = _pick_claim_type(day)

	var seed_npc_id := _pick_seed_npc(world)
	if seed_npc_id.is_empty():
		return

	var rumor_id: String = world.inject_rumor(seed_npc_id, claim_type_str, intensity, subject_id, "inquisitor")
	if not rumor_id.is_empty():
		inquisitor_acted.emit(day, claim_type_str, subject_id)


func _pick_target(rep: ReputationSystem) -> String:
	if rep == null:
		# Round-robin fallback.
		var target := PROTECTED_NPC_IDS[_target_index % PROTECTED_NPC_IDS.size()]
		_target_index += 1
		return target

	# Target whichever protected NPC currently has the highest reputation
	# (hardest for the player to lose, most impactful to attack).
	var best_id: String = PROTECTED_NPC_IDS[0]
	var best_score: int = -1
	for npc_id in PROTECTED_NPC_IDS:
		var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
		var score: int = snap.score if snap != null else 50
		if score > best_score:
			best_score = score
			best_id = npc_id
	return best_id


func _pick_claim_type(day: int) -> String:
	# Mix heresy with accusations and scandals for variety.
	if day <= 5:
		return "heresy"
	elif day % 5 == 0:
		return "scandal"
	elif day % 3 == 0:
		return "accusation"
	else:
		return "heresy"


## Picks the highest-sociability NPC not in the protected set, with heat <= 50,
## who is not currently in SPREAD or ACT state.
func _pick_seed_npc(world: Node) -> String:
	var intel_store: PlayerIntelStore = world.intel_store

	var excluded_ids: Dictionary = {}
	for pid in PROTECTED_NPC_IDS:
		excluded_ids[pid] = true
	for npc in world.npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state == Rumor.RumorState.SPREAD or slot.state == Rumor.RumorState.ACT:
				excluded_ids[npc.npc_data.get("id", "")] = true
				break

	var social_candidates: Array = []
	var fallback_candidates: Array = []

	for npc in world.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if excluded_ids.has(npc_id):
			continue
		var heat: float = intel_store.get_heat(npc_id) if intel_store != null else 0.0
		if heat > 50.0:
			continue
		fallback_candidates.append(npc)
		var loc: String = npc.current_location_code
		if loc == "market" or loc == "tavern" or loc == "chapel":
			social_candidates.append(npc)

	var pool: Array = social_candidates if not social_candidates.is_empty() else fallback_candidates
	if pool.is_empty():
		return ""

	var best_npc: Node2D = null
	var best_soc: float  = -1.0
	for npc in pool:
		var soc: float = float(npc.npc_data.get("sociability", 0.5))
		if soc > best_soc:
			best_soc = soc
			best_npc = npc

	return best_npc.npc_data.get("id", "") if best_npc != null else ""

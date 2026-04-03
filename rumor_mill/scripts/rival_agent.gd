## rival_agent.gd — Autonomous rival that seeds counter-rumors in Scenario 3.
##
## Ghost system: no sprite, no movement. Activates only in Scenario 3.
## Each day the rival may seed one rumor via world.inject_rumor(), following
## a cooldown / intensity schedule tied to the current game day.
##
## Integration:
##   - World instantiates RivalAgent and calls activate() when scenario_3 loads.
##   - World._on_day_changed() calls rival_agent.tick(current_day, self, scenario_manager).

class_name RivalAgent

const TOMAS_REEVE_ID := "tomas_reeve"
const CALDER_FENN_ID := "calder_fenn"

var _active: bool = false
var _last_seed_day: int = 0
var _alternate_flag: bool = false  # flips each seed during days 8–15


func activate() -> void:
	_active = true
	_last_seed_day = 0
	_alternate_flag = false


## Called once per in-game day from World._on_day_changed().
## world must expose: inject_rumor(), npcs, intel_store, reputation_system.
## scenario_mgr must expose: get_scenario_3_progress(rep).
func tick(current_day: int, world: Node, scenario_mgr: ScenarioManager) -> void:
	if not _active:
		return
	var cooldown := _get_cooldown(current_day)
	if current_day - _last_seed_day < cooldown:
		return
	_seed_counter_rumor(current_day, world, scenario_mgr)
	_last_seed_day = current_day


func _get_cooldown(day: int) -> int:
	if day <= 7:
		return 3
	elif day <= 15:
		return 2
	else:
		return 1


func _seed_counter_rumor(day: int, world: Node, scenario_mgr: ScenarioManager) -> void:
	var intensity: int = 4 if day >= 20 else (3 if day >= 8 else 2)
	var claim_type_str: String
	var subject_id: String

	if day <= 7:
		# Days 1–7: always PRAISE Tomas, intensity 2
		claim_type_str = "praise"
		subject_id     = TOMAS_REEVE_ID
	elif day <= 15:
		# Days 8–15: alternate PRAISE/Tomas and SCANDAL/Calder, intensity 3
		if _alternate_flag:
			claim_type_str = "scandal"
			subject_id     = CALDER_FENN_ID
		else:
			claim_type_str = "praise"
			subject_id     = TOMAS_REEVE_ID
		_alternate_flag = not _alternate_flag
	else:
		# Days 16+: metric-driven target — prioritise whichever metric the
		# player is closest to failing on.
		var rep: ReputationSystem = world.reputation_system
		if rep == null:
			push_warning("[RivalAgent] reputation_system is null on day %d — defaulting to praise/Tomas" % day)
			claim_type_str = "praise"
			subject_id     = TOMAS_REEVE_ID
		else:
			var progress: Dictionary = scenario_mgr.get_scenario_3_progress(rep)
			var calder_score: int = progress.get("calder_score", 50)
			var tomas_score:  int = progress.get("tomas_score",  50)

			# Rival goal: push Tomas up, Calder down.
			# calder_gap: distance above the fail floor (smaller = nearer to fail)
			var calder_gap: int = calder_score - ScenarioManager.S3_FAIL_CALDER_BELOW
			# tomas_gap: distance below the win ceiling for Tomas (smaller = Tomas
			# is already low, so rival should push him up)
			var tomas_gap: int = ScenarioManager.S3_WIN_TOMAS_MAX - tomas_score

			if calder_gap <= tomas_gap:
				claim_type_str = "scandal"
				subject_id     = CALDER_FENN_ID
			else:
				claim_type_str = "praise"
				subject_id     = TOMAS_REEVE_ID

	var seed_npc_id := _pick_seed_npc(world)
	if seed_npc_id.is_empty():
		print("[RivalAgent] No eligible seed NPC found for day %d — skipping" % day)
		return

	var rumor_id: String = world.inject_rumor(seed_npc_id, claim_type_str, intensity, subject_id, "rival")
	if not rumor_id.is_empty():
		print("[RivalAgent] Day %d: seeded '%s' about %s (intensity %d) via %s [%s]" % [
			day, claim_type_str, subject_id, intensity, seed_npc_id, rumor_id])


## Picks the highest-sociability NPC at a market or tavern whose heat is <= 50
## and who is not currently in SPREAD or ACT state for any rumor.
## Falls back to any non-excluded NPC if no social-location NPCs qualify.
func _pick_seed_npc(world: Node) -> String:
	var intel_store: PlayerIntelStore = world.intel_store

	# Build exclusion set: NPCs already spreading or acting on any rumor.
	var excluded_ids: Dictionary = {}
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
		if loc == "market" or loc == "tavern":
			social_candidates.append(npc)

	var pool: Array = social_candidates if not social_candidates.is_empty() else fallback_candidates
	if pool.is_empty():
		return ""

	# Select highest sociability within the pool.
	var best_npc: Node2D = null
	var best_soc: float  = -1.0
	for npc in pool:
		var soc: float = float(npc.npc_data.get("sociability", 0.5))
		if soc > best_soc:
			best_soc = soc
			best_npc = npc

	return best_npc.npc_data.get("id", "") if best_npc != null else ""

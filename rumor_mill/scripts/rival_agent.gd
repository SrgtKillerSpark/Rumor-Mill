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

## Emitted each time the rival successfully seeds a counter-rumor.
signal rival_acted(day: int, claim_type: String, subject_id: String)
## Emitted when the player successfully disrupts the rival.
signal rival_disrupted(day: int)
## SPA-868: Emitted when the rival degrades an NPC's belief by one tier.
signal belief_degraded(day: int, npc_id: String, old_state: int, new_state: int)

const TOMAS_REEVE_ID := "tomas_reeve"
const CALDER_FENN_ID := "calder_fenn"

## Number of extra cooldown days added while a disruption is active.
const DISRUPTION_COOLDOWN_BONUS := 3
## SPA-874: Maximum disruption uses per scenario (charges are NOT dawn-refreshed).
const MAX_DISRUPT_CHARGES := 3

var _active: bool = false
var _last_seed_day: int = 0
var _alternate_flag: bool = false  # flips each seed during days 8–15

## Days remaining on the current disruption effect (0 = no disruption).
var _disruption_days_remaining: int = 0
## SPA-874: Remaining one-time disruption charges for this scenario run.
var disrupt_charges_remaining: int = MAX_DISRUPT_CHARGES

## Difficulty modifier applied to every cooldown tier (positive = slower rival).
## Set by World._apply_active_scenario() before activate() is called.
var cooldown_offset: int = 0

## SPA-868: Pre-computed next degradation target NPC id (set at end of each tick).
## Empty if no valid target exists. Revealed to player via scout action.
var _next_degrade_target_id: String = ""

## SPA-868: Last action description for Journal timeline integration.
var last_action_description: String = ""


func activate() -> void:
	_active = true
	_last_seed_day = 0
	_alternate_flag = false
	_disruption_days_remaining = 0
	_next_degrade_target_id = ""
	last_action_description = ""
	disrupt_charges_remaining = MAX_DISRUPT_CHARGES  # SPA-874: reset charges on scenario start


## Called once per in-game day from World._on_day_changed().
## world must expose: inject_rumor(), npcs, intel_store, reputation_system.
## scenario_mgr must expose: get_scenario_3_progress(rep).
func tick(current_day: int, world: Node, scenario_mgr: ScenarioManager) -> void:
	if not _active:
		return
	# Decay disruption effect one day at a time.
	if _disruption_days_remaining > 0:
		_disruption_days_remaining -= 1

	# SPA-868: Daily belief degradation — rival undermines one NPC's belief each day.
	_degrade_one_belief(current_day, world)

	var cooldown := _get_cooldown(current_day)
	if current_day - _last_seed_day < cooldown:
		# Pre-compute next degradation target for scouting.
		_next_degrade_target_id = _pick_degrade_target(world)
		return
	_seed_counter_rumor(current_day, world, scenario_mgr)
	_last_seed_day = current_day
	# Pre-compute next degradation target for scouting.
	_next_degrade_target_id = _pick_degrade_target(world)


func _get_cooldown(day: int) -> int:
	var base: int
	if day <= 7:
		base = 4
	elif day <= 17:
		base = 2   # SPA-550: extended mid-phase from day 15→17 — daily seeding was overwhelming
	else:
		base = 1
	# cooldown_offset > 0 slows the rival (easier); < 0 speeds it up (harder).
	# Disruption adds a temporary bonus on top of the difficulty offset.
	var disruption_bonus: int = DISRUPTION_COOLDOWN_BONUS if _disruption_days_remaining > 0 else 0
	return maxi(1, base + cooldown_offset + disruption_bonus)


## Apply a counter-intel disruption that slows the rival for DISRUPTION_COOLDOWN_BONUS days.
## Costs the caller one recon action (checked and spent by the caller before calling this).
## Returns false if a disruption is already active, the rival hasn't acted yet, or no
## charges remain (SPA-874: limited to MAX_DISRUPT_CHARGES uses per scenario).
func apply_disruption(current_day: int) -> bool:
	if not can_be_disrupted():
		return false
	disrupt_charges_remaining -= 1  # SPA-874: consume one charge
	_disruption_days_remaining = DISRUPTION_COOLDOWN_BONUS
	rival_disrupted.emit(current_day)
	return true


## Returns true when the rival can currently be disrupted by the player.
## SPA-874: Also requires at least one charge remaining.
func can_be_disrupted() -> bool:
	return _active and _last_seed_day > 0 and _disruption_days_remaining <= 0 \
		and disrupt_charges_remaining > 0


func _seed_counter_rumor(day: int, world: Node, scenario_mgr: ScenarioManager) -> void:
	var intensity: int = 3 if day >= 8 else 2
	var claim_type_str: String
	var subject_id: String

	if day <= 7:
		# Days 1–7: always PRAISE Tomas, intensity 2
		claim_type_str = "praise"
		subject_id     = TOMAS_REEVE_ID
	elif day <= 17:
		# Days 8–17: alternate PRAISE/Tomas and SCANDAL/Calder, intensity 3
		if _alternate_flag:
			claim_type_str = "scandal"
			subject_id     = CALDER_FENN_ID
		else:
			claim_type_str = "praise"
			subject_id     = TOMAS_REEVE_ID
		_alternate_flag = not _alternate_flag
	else:
		# Days 18+: metric-driven target — prioritise whichever metric the
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
			var calder_gap: int = calder_score - ScenarioConfig.S3_FAIL_CALDER_BELOW
			# tomas_gap: distance below the win ceiling for Tomas (smaller = Tomas
			# is already low, so rival should push him up)
			var tomas_gap: int = ScenarioConfig.S3_WIN_TOMAS_MAX - tomas_score

			if tomas_gap <= 0:
				# Tomas already above ceiling - focus on attacking Calder
				claim_type_str = "scandal"
				subject_id     = CALDER_FENN_ID
			elif calder_gap < 10:
				# Urgency: Calder near fail floor, always attack.
				claim_type_str = "scandal"
				subject_id     = CALDER_FENN_ID
			elif calder_gap <= tomas_gap:
				claim_type_str = "scandal"
				subject_id     = CALDER_FENN_ID
			else:
				claim_type_str = "praise"
				subject_id     = TOMAS_REEVE_ID

	var seed_npc_id := _pick_seed_npc(world)
	if seed_npc_id.is_empty():
		return

	var rumor_id: String = world.inject_rumor(seed_npc_id, claim_type_str, intensity, subject_id, "rival")
	if not rumor_id.is_empty():
		rival_acted.emit(day, claim_type_str, subject_id)


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


# ── SPA-868: Belief degradation ──────────────────────────────────────────────

## State demotion mapping: current state → one tier lower.
## ACT→SPREAD, SPREAD→BELIEVE, BELIEVE→EVALUATING.
const _DEGRADE_MAP := {
	Rumor.RumorState.ACT:     Rumor.RumorState.SPREAD,
	Rumor.RumorState.SPREAD:  Rumor.RumorState.BELIEVE,
	Rumor.RumorState.BELIEVE: Rumor.RumorState.EVALUATING,
}

## Pick a random NPC currently in BELIEVE/SPREAD/ACT for any player-seeded rumor.
## Prefers NPCs whose belief helps the player (scandal on Tomas or praise on Calder).
func _pick_degrade_target(world: Node) -> String:
	var candidates: Array = []  # Array of {npc_id, rumor_id, state}
	for npc in world.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		for rid in npc.rumor_slots:
			var slot = npc.rumor_slots[rid]
			if slot.state in _DEGRADE_MAP:
				# Only target player-originated rumors (not rival-seeded ones).
				if slot.rumor != null and slot.rumor.lineage_parent_id != "rival":
					candidates.append({"npc_id": npc_id, "rumor_id": rid, "state": slot.state})
	if candidates.is_empty():
		return ""
	# Random pick from candidates.
	var pick: Dictionary = candidates[randi() % candidates.size()]
	return pick["npc_id"]


## Degrade one NPC's belief state by one tier each day.
func _degrade_one_belief(current_day: int, world: Node) -> void:
	var target_id: String = _next_degrade_target_id if not _next_degrade_target_id.is_empty() else _pick_degrade_target(world)
	if target_id.is_empty():
		return

	for npc in world.npcs:
		if npc.npc_data.get("id", "") != target_id:
			continue
		# Find the first degradable slot (player-seeded rumor in BELIEVE/SPREAD/ACT).
		for rid in npc.rumor_slots:
			var slot = npc.rumor_slots[rid]
			if slot.state in _DEGRADE_MAP and slot.rumor != null and slot.rumor.lineage_parent_id != "rival":
				var old_state: int = slot.state
				slot.state = _DEGRADE_MAP[old_state]
				slot.ticks_in_state = 0
				last_action_description = "Rival degraded %s's belief (Day %d)" % [
					npc.npc_data.get("name", target_id), current_day]
				belief_degraded.emit(current_day, target_id, old_state, slot.state)
				return
		break


# ── SPA-868: Rival scouting ─────────────────────────────────────────────────

## Spend 1 recon action to discover the rival's next degradation target.
## Returns the NPC id of the next target, or "" if no target exists.
## The caller must check and spend the recon action before calling this.
func scout_next_target(current_day: int) -> String:
	if not _active:
		return ""
	var target: String = _next_degrade_target_id
	return target


## Returns the pre-computed next degradation target (for UI display after scouting).
func get_scouted_target() -> String:
	return _next_degrade_target_id

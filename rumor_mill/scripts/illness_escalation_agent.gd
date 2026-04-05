## illness_escalation_agent.gd — Autonomous agent that escalates illness reports in Scenario 2.
##
## Ghost system: no sprite, no movement. Activates only in Scenario 2.
## On a cooldown schedule, seeds illness rumors about alys_herbwife through susceptible
## NPCs — simulating the plague scare gaining momentum without player intervention.
## This creates urgency: auto-spreading rumors increase the risk that Sister Maren
## will notice, so the player must win before escalation makes containment impossible.
##
## Integration:
##   - World instantiates IllnessEscalationAgent and calls activate() for scenario_2.
##   - World._on_day_changed() calls illness_escalation_agent.tick(day, self).

class_name IllnessEscalationAgent

## Emitted each time the agent successfully seeds an escalation rumor.
signal illness_escalated(day: int, claim_type: String, subject_id: String)

const ALYS_HERBWIFE_ID := "alys_herbwife"
const MAREN_NUN_ID     := "maren_nun"

var _active: bool = false
var _last_seed_day: int = 0

## Difficulty modifier applied to every cooldown tier (positive = slower escalation).
## Set by World._apply_active_scenario() before activate() is called.
var cooldown_offset: int = 0


func activate() -> void:
	_active = true
	_last_seed_day = 0


## Called once per in-game day from World._on_day_changed().
## world must expose: inject_rumor(), npcs, intel_store.
func tick(current_day: int, world: Node) -> void:
	if not _active:
		return
	var cooldown := _get_cooldown(current_day)
	if current_day - _last_seed_day < cooldown:
		return
	_seed_illness_rumor(current_day, world)
	_last_seed_day = current_day


func _get_cooldown(day: int) -> int:
	# Slow start (town rumors trickle in), escalating pace mid-game.
	var base: int
	if day <= 6:
		base = 5   # Early: seed every 5 days
	elif day <= 13:
		base = 3   # Mid:   seed every 3 days
	else:
		base = 2   # Late:  seed every 2 days
	return maxi(1, base + cooldown_offset)


func _seed_illness_rumor(day: int, world: Node) -> void:
	var intensity: int
	if day >= 14:
		intensity = 4   # Late-game panic — high intensity
	elif day >= 8:
		intensity = 3
	else:
		intensity = 2   # Early murmurs — low intensity

	var seed_npc_id := _pick_seed_npc(world)
	if seed_npc_id.is_empty():
		return

	var rumor_id: String = world.inject_rumor(
		seed_npc_id, "illness", intensity, ALYS_HERBWIFE_ID, "escalation")
	if not rumor_id.is_empty():
		illness_escalated.emit(day, "illness", ALYS_HERBWIFE_ID)


## Picks the most credulous NPC at market or tavern (where illness fears spread fastest).
## Excludes Maren (would reject) and Alys herself. Avoids high-heat NPCs.
func _pick_seed_npc(world: Node) -> String:
	var intel_store: PlayerIntelStore = world.intel_store

	var social_candidates: Array = []
	var fallback_candidates: Array = []

	for npc in world.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id == MAREN_NUN_ID or npc_id == ALYS_HERBWIFE_ID:
			continue
		var heat: float = intel_store.get_heat(npc_id) if intel_store != null else 0.0
		if heat > 60.0:
			continue

		fallback_candidates.append(npc)
		var loc: String = npc.current_location_code
		if loc == "market" or loc == "tavern":
			social_candidates.append(npc)

	var pool: Array = social_candidates if not social_candidates.is_empty() else fallback_candidates
	if pool.is_empty():
		return ""

	# Credulous NPCs spread illness rumors fastest — fearful gossip runs on credulity.
	var best_npc: Node2D = null
	var best_cred: float = -1.0
	for npc in pool:
		var cred: float = float(npc.npc_data.get("credulity", 0.5))
		if cred > best_cred:
			best_cred = cred
			best_npc  = npc

	return best_npc.npc_data.get("id", "") if best_npc != null else ""

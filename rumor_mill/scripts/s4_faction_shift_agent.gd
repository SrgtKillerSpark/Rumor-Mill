## s4_faction_shift_agent.gd — Fires faction-specific reputation shifts in Scenario 4.
##
## Ghost system: no sprite, no movement. Activates only in Scenario 4.
## Three mid-game events fire at scheduled day windows to shift the power balance:
##
##   Phase 1 (days 5-7):   "Merchant Sympathy"  — townsfolk rally; weakest protected
##                          NPC gets a praise rumor seeded through a merchant.
##   Phase 2 (days 10-13): "Bishop Pressure"    — the Bishop writes; inquisitor
##                          cooldown_offset drops by 2, increasing accusation pace
##                          for the remainder of the run.
##   Phase 3 (days 14-17): "Clergy Solidarity"  — clergy stand together; all three
##                          protected NPCs receive a low-intensity praise rumor.
##
## These events ensure S4 has mid-game momentum changes and are not purely a
## static defence grind — the player must react to both helping and hurting shifts.
##
## Integration:
##   - World creates S4FactionShiftAgent and calls activate() for scenario_4.
##   - World sets inquisitor_ref before calling activate().
##   - World._on_day_changed() calls s4_faction_shift_agent.tick(day, self).

class_name S4FactionShiftAgent

## Emitted each time a faction shift event fires.
## event_type: "merchant_sympathy" | "bishop_pressure" | "clergy_solidarity"
signal faction_shift_occurred(day: int, event_type: String, description: String)

## Day windows and NPC list sourced from ScenarioConfig (single source of truth).
const PROTECTED_NPC_IDS := ScenarioConfig.S4_PROTECTED_NPC_IDS
const PHASE_1_WINDOW    := ScenarioConfig.S4_PHASE_1_WINDOW
const PHASE_2_WINDOW    := ScenarioConfig.S4_PHASE_2_WINDOW
const PHASE_3_WINDOW    := ScenarioConfig.S4_PHASE_3_WINDOW

var _active: bool = false
var _phase_1_fired: bool = false
var _phase_2_fired: bool = false
var _phase_3_fired: bool = false

## Injected by World so Phase 2 can accelerate the inquisitor.
var inquisitor_ref: InquisitorAgent = null


func activate() -> void:
	_active = true


## Called once per in-game day from World._on_day_changed().
func tick(current_day: int, world: Node) -> void:
	if not _active:
		return

	if not _phase_1_fired \
			and current_day >= PHASE_1_WINDOW[0] \
			and current_day <= PHASE_1_WINDOW[1]:
		_fire_merchant_sympathy(current_day, world)
		_phase_1_fired = true

	if not _phase_2_fired \
			and current_day >= PHASE_2_WINDOW[0] \
			and current_day <= PHASE_2_WINDOW[1]:
		_fire_bishop_pressure(current_day)
		_phase_2_fired = true

	if not _phase_3_fired \
			and current_day >= PHASE_3_WINDOW[0] \
			and current_day <= PHASE_3_WINDOW[1]:
		_fire_clergy_solidarity(current_day, world)
		_phase_3_fired = true


# ---------------------------------------------------------------------------
# Phase handlers
# ---------------------------------------------------------------------------

## Phase 1: A merchant speaks up for the most endangered accused NPC.
func _fire_merchant_sympathy(day: int, world: Node) -> void:
	var rep: ReputationSystem = world.reputation_system
	var weakest_id: String    = _weakest_protected_npc(rep)

	var seed_npc := _pick_npc_by_faction(world, "merchant")
	if not seed_npc.is_empty():
		world.inject_rumor(seed_npc, "praise", 3, weakest_id, "faction_shift")

	var display: String = weakest_id.replace("_", " ").capitalize()
	faction_shift_occurred.emit(day, "merchant_sympathy",
		"Merchants speak up for %s" % display)


## Phase 2: The Bishop's letter arrives — inquisitor accelerates.
func _fire_bishop_pressure(day: int) -> void:
	if inquisitor_ref != null:
		# Drop cooldown_offset by 2 (min −2), permanently increasing aggression.
		inquisitor_ref.cooldown_offset = maxi(inquisitor_ref.cooldown_offset - 2, -2)
	faction_shift_occurred.emit(day, "bishop_pressure",
		"Bishop pressures the Inquisitor — accusations will increase")


## Phase 3: Clergy stand together — a low-intensity praise rumor for each accused.
func _fire_clergy_solidarity(day: int, world: Node) -> void:
	for npc_id in PROTECTED_NPC_IDS:
		var seed_npc := _pick_npc_by_faction(world, "clergy")
		if not seed_npc.is_empty():
			world.inject_rumor(seed_npc, "praise", 2, npc_id, "faction_shift")
	faction_shift_occurred.emit(day, "clergy_solidarity",
		"Clergy stand together for the accused")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _weakest_protected_npc(rep: ReputationSystem) -> String:
	var weakest_id:    String = PROTECTED_NPC_IDS[0]
	var weakest_score: int    = 999
	for npc_id in PROTECTED_NPC_IDS:
		var snap: ReputationSystem.ReputationSnapshot = \
			rep.get_snapshot(npc_id) if rep != null else null
		var score: int = snap.score if snap != null else 50
		if score < weakest_score:
			weakest_score = score
			weakest_id    = npc_id
	return weakest_id


func _pick_npc_by_faction(world: Node, faction: String) -> String:
	var candidates: Array = []
	for npc in world.npcs:
		if npc.npc_data.get("faction", "") == faction:
			candidates.append(npc)
	if candidates.is_empty():
		return ""
	candidates.shuffle()
	return candidates[0].npc_data.get("id", "")

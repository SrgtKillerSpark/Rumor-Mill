## intel_store.gd — Player intelligence data store.
## Holds LocationIntel and RelationshipIntel records collected via recon actions.
## Plain-data class (no Node inheritance) owned by World.

class_name PlayerIntelStore

const MAX_DAILY_ACTIONS  := 3
const MAX_DAILY_WHISPERS := 2
const MAX_EVIDENCE       := 3

var recon_actions_remaining:   int = MAX_DAILY_ACTIONS
var whisper_tokens_remaining:  int = MAX_DAILY_WHISPERS

## location_id (building name string) → Array[LocationIntel]
var location_intel: Dictionary = {}

## canonical pair key "idA:idB" (sorted) → RelationshipIntel
var relationship_intel: Dictionary = {}

## Per-NPC heat values (0–100). Tracks how suspicious NPCs are of the player
## as a rumor source. Only active from Scenario 2 onward.
var heat: Dictionary = {}
var heat_enabled: bool = false
## When >= 0, overrides the default 6.0/day decay (used by FactionEventSystem
## guard_crackdown event). Reset to -1.0 to restore the default.
var heat_decay_override: float = -1.0

## Bribe charges (2 per scenario, not dawn-refreshed). Active from Scenario 2+.
## 0 means bribery is disabled (Scenario 1 / tutorial).
var bribe_charges: int = 0

## Collectible evidence items the player can attach to a seeded rumor (max 3).
var evidence_inventory: Array = []

## Running total of evidence items consumed this run (for end-screen stats).
var evidence_used_count: int = 0


# ---------------------------------------------------------------------------
# LocationIntel — snapshot of which NPCs were at a location during one tick.
# ---------------------------------------------------------------------------
class LocationIntel:
	var location_id: String
	var observed_at: int          # game tick when the observation was made
	## Array of Dicts: {npc_id, npc_name, faction, arrival_tick, departure_tick}
	var npcs_seen: Array = []

	func _init(loc_id: String, tick: int) -> void:
		location_id = loc_id
		observed_at = tick
		npcs_seen   = []


# ---------------------------------------------------------------------------
# RelationshipIntel — eavesdropped relationship between two NPCs.
# ---------------------------------------------------------------------------
class RelationshipIntel:
	var npc_a_id:   String
	var npc_b_id:   String
	var npc_a_name: String
	var npc_b_name: String
	var edge_weight: float   ## Raw social graph weight 0.0–1.0 (hidden from player UI)
	var affinity_label: String  ## "allied" | "neutral" | "suspicious"
	var observed_at: int
	## Rich context: rumor subjects, belief states, and trend directions for active
	## rumors either NPC was discussing at observation time. Empty if neither believed.
	var rich_context: String = ""
	## Critical context: DEFENDING state disclosure — loyalty tier and protected target.
	## Non-empty only when at least one NPC was in the DEFENDING state.
	var critical_context: String = ""

	func _init(
			a_id: String, b_id: String,
			a_name: String, b_name: String,
			weight: float, tick: int
	) -> void:
		npc_a_id    = a_id
		npc_b_id    = b_id
		npc_a_name  = a_name
		npc_b_name  = b_name
		edge_weight = weight
		observed_at = tick
		affinity_label = _label_from_weight(weight)

	## Returns 1, 2, or 3 — the relationship bar count shown in UI.
	func bars() -> int:
		if edge_weight > 0.60:
			return 3
		elif edge_weight > 0.33:
			return 2
		return 1

	## Human-readable strength label.
	func strength_label() -> String:
		match bars():
			3: return "strong"
			2: return "moderate"
			_: return "weak"

	static func _label_from_weight(w: float) -> String:
		if w > 0.60:
			return "allied"
		elif w > 0.33:
			return "neutral"
		return "suspicious"


# ---------------------------------------------------------------------------
# Action budget
# ---------------------------------------------------------------------------

## Attempt to spend one action. Returns false if budget is exhausted.
func try_spend_action() -> bool:
	if recon_actions_remaining <= 0:
		return false
	recon_actions_remaining -= 1
	return true


## Attempt to spend one whisper token. Returns false if none remain.
func try_spend_whisper() -> bool:
	if whisper_tokens_remaining <= 0:
		return false
	whisper_tokens_remaining -= 1
	return true


## Called at dawn (day_changed signal) to restore the daily budget.
func replenish() -> void:
	recon_actions_remaining  = MAX_DAILY_ACTIONS
	whisper_tokens_remaining = MAX_DAILY_WHISPERS
	decay_heat()


# ---------------------------------------------------------------------------
# Heat system (active from Scenario 2+)
# ---------------------------------------------------------------------------

func get_heat(npc_id: String) -> float:
	return heat.get(npc_id, 0.0)


func add_heat(npc_id: String, amount: float) -> void:
	if not heat_enabled:
		return
	heat[npc_id] = clamp(heat.get(npc_id, 0.0) + amount, 0.0, 100.0)


func decay_heat() -> void:
	if not heat_enabled:
		return
	var decay_amount: float = 6.0 if heat_decay_override < 0.0 else heat_decay_override
	for npc_id in heat.keys():
		heat[npc_id] = maxf(0.0, heat[npc_id] - decay_amount)  # SPA-98: default 6.0; overrideable by guard_crackdown event


# ---------------------------------------------------------------------------
# Bribe charges
# ---------------------------------------------------------------------------

## Consume one bribe charge. Returns false if none remain.
func try_spend_bribe() -> bool:
	if bribe_charges <= 0:
		return false
	bribe_charges -= 1
	return true


# ---------------------------------------------------------------------------
# Location intel
# ---------------------------------------------------------------------------

func add_location_intel(intel: LocationIntel) -> void:
	if not location_intel.has(intel.location_id):
		location_intel[intel.location_id] = []
	location_intel[intel.location_id].append(intel)


func get_location_intel(location_id: String) -> Array:
	return location_intel.get(location_id, [])


# ---------------------------------------------------------------------------
# Relationship intel
# ---------------------------------------------------------------------------

## Add or overwrite relationship intel (newest observation wins).
func add_relationship_intel(intel: RelationshipIntel) -> void:
	var key := _pair_key(intel.npc_a_id, intel.npc_b_id)
	relationship_intel[key] = intel


func get_relationship_intel(npc_a_id: String, npc_b_id: String) -> RelationshipIntel:
	var key := _pair_key(npc_a_id, npc_b_id)
	return relationship_intel.get(key, null)


## Returns all RelationshipIntel entries involving the given NPC id.
func get_relationships_for_npc(npc_id: String) -> Array:
	var results: Array = []
	for key in relationship_intel:
		var intel: RelationshipIntel = relationship_intel[key]
		if intel.npc_a_id == npc_id or intel.npc_b_id == npc_id:
			results.append(intel)
	return results


## Canonical sort so (A,B) and (B,A) share the same key.
static func _pair_key(a: String, b: String) -> String:
	return (a + ":" + b) if a < b else (b + ":" + a)


# ---------------------------------------------------------------------------
# EvidenceItem — collectible item that boosts a seeded rumor's credibility.
# ---------------------------------------------------------------------------
class EvidenceItem:
	var type: String
	var believability_bonus: float
	var mutability_modifier: float
	var compatible_claims: Array  # empty = any claim type
	var acquired_tick: int

	func _init(
			ev_type: String,
			bel_bonus: float,
			mut_mod: float,
			compat: Array,
			tick: int
	) -> void:
		type = ev_type
		believability_bonus = bel_bonus
		mutability_modifier = mut_mod
		compatible_claims = compat
		acquired_tick = tick


# ---------------------------------------------------------------------------
# Evidence inventory
# ---------------------------------------------------------------------------

## Add an evidence item. If over MAX_EVIDENCE, the oldest is discarded with a warning.
func add_evidence(item: EvidenceItem) -> void:
	evidence_inventory.append(item)
	if evidence_inventory.size() > MAX_EVIDENCE:
		var discarded: EvidenceItem = evidence_inventory.pop_front()
		push_warning("[IntelStore] Evidence inventory full — discarded oldest item: %s" % discarded.type)


## Remove a specific evidence item from the inventory after it is consumed.
func consume_evidence(item: EvidenceItem) -> void:
	evidence_inventory.erase(item)
	evidence_used_count += 1


## Returns all inventory items whose compatible_claims include claim_type_upper,
## or that accept any claim type (compatible_claims is empty).
func get_compatible_evidence(claim_type_upper: String) -> Array:
	var result: Array = []
	for item in evidence_inventory:
		if item.compatible_claims.is_empty() or claim_type_upper in item.compatible_claims:
			result.append(item)
	return result

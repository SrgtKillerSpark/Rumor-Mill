## propagation_engine.gd — Sprint 4: SIR rumor diffusion engine.
##
## Responsibilities:
##   • β formula  — spread probability per transmission
##   • γ formula  — recovery/rejection probability per BELIEVE tick
##   • 4 mutation types — exaggeration, softening, target-shift, detail-addition
##   • Rumor lineage registry — tracks every copy back to its origin
##   • Shelf-life decay — reduces believability once per game tick
##
## Usage:
##   var engine := PropagationEngine.new()
##   # Register each seeded rumor:
##   engine.register_rumor(rumor)
##   # Each game tick (before NPC ticks):
##   engine.tick_decay()
##   # NPC spread logic calls:
##   var p := engine.calc_beta(sociability, credulity, edge_weight, from_faction, to_faction)
##   var recover := engine.calc_gamma(loyalty, temperament)
##   var spread_rumor := engine.try_mutate(source_rumor, tick, all_npcs)

class_name PropagationEngine

# ── Faction modifier constants ───────────────────────────────────────────────
const FACTION_MOD_SAME     := 1.2   # same faction spreads easier
const FACTION_MOD_NEUTRAL  := 0.8
const FACTION_MOD_OPPOSING := 0.5

# Mirrors SocialGraph.OPPOSING_PAIRS (no cross-file constant reference needed).
const OPPOSING_PAIRS: Array = [
	["merchant", "noble"],
	["noble", "clergy"],
	["merchant", "clergy"],
]

# ── Chain type constants ──────────────────────────────────────────────────────
enum ChainType { NONE, SAME_TYPE, ESCALATION, CONTRADICTION }

# Escalation pairs: seeding the value type when the key type is already active
# on the same subject triggers an escalation chain.
const ESCALATION_PAIRS: Dictionary = {
	Rumor.ClaimType.SCANDAL:  Rumor.ClaimType.HERESY,
	Rumor.ClaimType.ILLNESS:  Rumor.ClaimType.DEATH,
}

# ── Live rumor registry ───────────────────────────────────────────────────────
# rumor_id → Rumor  (all active, non-expired rumors)
var live_rumors: Dictionary = {}

# ── Scenario-specific mutation filters ───────────────────────────────────────
# NPC ids that must never be picked as a target_shift destination.
# Set by the scenario loader (e.g. world._apply_active_scenario) before play.
var target_shift_excluded_ids: Array[String] = []

# ── Lineage registry ─────────────────────────────────────────────────────────
# rumor_id → { "parent_id": String, "mutation_type": String, "tick": int }
var lineage: Dictionary = {}
var _mutation_counter: int = 0

## Reference to the player intel store for heat tracking. Set by World.
var intel_store_ref: PlayerIntelStore = null

## Time pressure bonus added to spread probability in the final 25% of a scenario.
## Set each tick by World based on scenario progress. 0.0 = no bonus, 0.20 = +20%.
var time_pressure_bonus: float = 0.0

## Incremented each time an NPC transitions to CONTRADICTED/REJECT due to a
## credible public rebuttal (wired from NPC.gd where that state fires).
## Used by the Scenario 2 end-screen bonus stat.
var contradiction_count: int = 0


# ── Registration ─────────────────────────────────────────────────────────────

## Register a newly created rumor (seeded or mutated).
## Idempotent — safe to call on already-registered ids.
func register_rumor(rumor: Rumor) -> void:
	live_rumors[rumor.id] = rumor
	if not lineage.has(rumor.id):
		lineage[rumor.id] = {
			"parent_id":     rumor.lineage_parent_id,
			"mutation_type": "original" if rumor.lineage_parent_id.is_empty() else "mutation",
			"tick":          rumor.created_tick,
		}


# ── Shelf-life decay ─────────────────────────────────────────────────────────

## Decay every live rumor's believability by one tick.
## Expired rumors are removed from live_rumors but kept in the lineage registry.
## Call this once per game tick, before NPC on_tick() calls.
func tick_decay() -> void:
	var expired_ids: Array = []
	for rid in live_rumors:
		var r: Rumor = live_rumors[rid]
		r.decay_one_tick()
		if r.is_expired():
			expired_ids.append(rid)
	for rid in expired_ids:
		live_rumors.erase(rid)


# ── β — spread probability ────────────────────────────────────────────────────

## β = sociability_spreader × credulity_target × edge_weight × faction_modifier × scale
##
## heat_modifier reduces effective credulity: 0.15 at heat ≥ 50, 0.30 at heat ≥ 75.
## Returns a clamped [0.0, 1.0] probability for one transmission attempt.
func calc_beta(
		sociability:    float,
		credulity:      float,
		edge_weight:    float,
		from_faction:   String,
		to_faction:     String,
		heat_modifier:  float = 0.0
) -> float:
	var faction_mod := _faction_modifier(from_faction, to_faction)
	var effective_credulity := clamp(credulity - heat_modifier, 0.0, 1.0)
	# Scale factor 1.8 keeps probabilities in a useful range given all inputs ∈ [0,1].
	# Reduced from 2.5 (SPA-98 balance pass): highly social NPCs still spread briskly,
	# but moderate NPCs no longer guarantee daily spread to every connected neighbor.
	var base := clamp(sociability * effective_credulity * edge_weight * faction_mod * 1.8, 0.0, 1.0)
	# Time pressure: in the final 25% of a scenario, spread probability increases.
	return clamp(base + time_pressure_bonus, 0.0, 1.0)


# ── γ — recovery probability ──────────────────────────────────────────────────

## γ = loyalty × (1 − temperament) × 0.30
##
## Returns a clamped [0.0, 1.0] per-tick probability of transitioning from
## BELIEVE back to REJECT (the NPC recovers from / forgets the rumor).
## High loyalty + low temperament → higher recovery chance.
## Reduced from 0.35 (SPA-98 balance pass): beliefs persist longer before
## natural rejection, giving planted rumors more staying power.
func calc_gamma(loyalty: float, temperament: float) -> float:
	return clamp(loyalty * (1.0 - temperament) * 0.30, 0.0, 1.0)


# ── Mutation system ───────────────────────────────────────────────────────────

## Roll all 4 mutation types independently and return a (possibly mutated) Rumor.
## If no mutation fires, returns source unchanged — no new object created.
##
## Mutation types:
##   exaggeration — intensity + 1 (max 5)
##   softening    — intensity − 1 (min 1); mutually exclusive with exaggeration
##   target_shift — subject_npc_id reassigned to a randomly connected NPC
##   detail_add   — no mechanical change; logged in lineage for narrative flavour
func try_mutate(source: Rumor, tick: int, all_npcs: Array) -> Rumor:
	var base_p := source.mutability * 0.15

	var do_exaggerate  := randf() < base_p and source.intensity < 5
	var do_soften      := randf() < base_p and source.intensity > 1 and not do_exaggerate
	var do_target_shift := randf() < base_p
	var do_detail_add   := randf() < base_p

	if not (do_exaggerate or do_soften or do_target_shift or do_detail_add):
		return source   # No mutation — return original reference

	var new_intensity := source.intensity
	var new_subject   := source.subject_npc_id
	var mut_tags: Array[String] = []

	if do_exaggerate:
		new_intensity = min(new_intensity + 1, 5)
		mut_tags.append("exaggerate")

	if do_soften:
		new_intensity = max(new_intensity - 1, 1)
		mut_tags.append("soften")

	if do_target_shift and not all_npcs.is_empty():
		var shift_candidates: Array = all_npcs.filter(
			func(n: Node2D) -> bool:
				var nid: String = n.npc_data.get("id", "")
				return nid != source.subject_npc_id and not target_shift_excluded_ids.has(nid)
		)
		if not shift_candidates.is_empty():
			var target_npc: Node2D = shift_candidates.pick_random()
			new_subject = target_npc.npc_data.get("id", source.subject_npc_id)
			mut_tags.append("target_shift")

	if do_detail_add:
		mut_tags.append("detail_add")

	# Build unique id: parent_id + monotonic counter suffix.
	_mutation_counter += 1
	var new_id := source.id + "_m%d" % _mutation_counter

	# Carry forward remaining shelf life so mutations cannot reset the decay clock.
	var elapsed_ticks := maxi(tick - source.created_tick, 0)
	var remaining_shelf := maxi(source.shelf_life_ticks - elapsed_ticks, 1)

	var mutated := Rumor.create(
		new_id,
		new_subject,
		source.claim_type,
		new_intensity,
		source.mutability,
		tick,
		remaining_shelf,
		source.id          # lineage_parent_id
	)
	# Inherit the parent's current (decayed) believability so mutations don't
	# reset the decay progress.  If intensity changed, scale proportionally.
	if source.intensity > 0:
		mutated.current_believability = source.current_believability * (float(new_intensity) / float(source.intensity))
	else:
		mutated.current_believability = source.current_believability

	# Register the new copy.
	live_rumors[new_id] = mutated
	lineage[new_id] = {
		"parent_id":     source.id,
		"mutation_type": ",".join(mut_tags),
		"tick":          tick,
	}

	return mutated


# ── Lineage queries ───────────────────────────────────────────────────────────

## Returns the chain from root rumor down to rumor_id (inclusive).
## Example: ["r_acc_1000", "r_acc_1000_m0", "r_acc_1000_m0_m1"]
func get_lineage_chain(rumor_id: String) -> Array:
	var chain: Array = []
	var current := rumor_id
	var seen: Dictionary = {}
	while not current.is_empty() and not seen.has(current):
		seen[current] = true
		chain.append(current)
		if lineage.has(current):
			current = str(lineage[current].get("parent_id", ""))
		else:
			break
	chain.reverse()
	return chain


## Returns a human-readable multi-line summary of the full lineage registry.
func get_lineage_summary() -> String:
	if lineage.is_empty():
		return "(no rumors in lineage registry)"

	# Group children under parents for a tree-like display.
	var lines: Array = []
	var roots: Array = []
	var children: Dictionary = {}   # parent_id → Array of child_ids

	for rid in lineage:
		var entry: Dictionary = lineage[rid]
		var parent: String = entry.get("parent_id", "")
		if parent.is_empty():
			roots.append(rid)
		else:
			if not children.has(parent):
				children[parent] = []
			children[parent].append(rid)

	for root in roots:
		var tick: int = lineage[root].get("tick", 0)
		lines.append("[ROOT] %s (tick %d)" % [root, tick])
		_append_children(root, children, lines, 1)

	return "\n".join(lines)


func _append_children(parent_id: String, children: Dictionary, lines: Array, depth: int) -> void:
	if not children.has(parent_id):
		return
	for child_id in children[parent_id]:
		var entry: Dictionary = lineage[child_id]
		var mut: String = entry.get("mutation_type", "?")
		var tick: int   = entry.get("tick", 0)
		var indent := "  ".repeat(depth)
		lines.append("%s└─ %s [%s] (tick %d)" % [indent, child_id, mut, tick])
		_append_children(child_id, children, lines, depth + 1)


# ── Heat relay tracking ───────────────────────────────────────────────────────

## Add +2 heat to npc_id if rumor_id traces back to a player-seeded origin (rp_ prefix).
## Called by npc._spread_to_neighbours() after each successful transmission.
func apply_relay_heat(npc_id: String, rumor_id: String) -> void:
	if intel_store_ref == null or not intel_store_ref.heat_enabled:
		return
	var chain := get_lineage_chain(rumor_id)
	for rid in chain:
		if rid.begins_with("rp_"):
			intel_store_ref.add_heat(npc_id, 2.0)
			return


# ── Rumor chain detection & bonuses ──────────────────────────────────────────

## Detect whether seeding a new rumor of `new_claim_type` about `subject_npc_id`
## would form a chain with an already-active rumor on the same subject.
## Returns { "chain_type": ChainType, "existing_rumor": Rumor or null }.
func detect_chain(subject_npc_id: String, new_claim_type: Rumor.ClaimType) -> Dictionary:
	var result := { "chain_type": ChainType.NONE, "existing_rumor": null }

	for rid in live_rumors:
		var r: Rumor = live_rumors[rid]
		if r.subject_npc_id != subject_npc_id:
			continue

		# Escalation: existing rumor is the "from" type and new claim is the "to" type.
		if ESCALATION_PAIRS.has(r.claim_type) and ESCALATION_PAIRS[r.claim_type] == new_claim_type:
			result.chain_type = ChainType.ESCALATION
			result.existing_rumor = r
			return result  # Escalation takes priority

		# Contradiction: one positive, one negative about the same subject.
		var existing_positive := Rumor.is_positive_claim(r.claim_type)
		var new_positive      := Rumor.is_positive_claim(new_claim_type)
		if existing_positive != new_positive:
			if result.chain_type != ChainType.ESCALATION:
				result.chain_type = ChainType.CONTRADICTION
				result.existing_rumor = r
				# Don't return — keep scanning for a possible escalation match.

		# Same-type: identical claim type already active on same subject.
		if r.claim_type == new_claim_type:
			if result.chain_type == ChainType.NONE:
				result.chain_type = ChainType.SAME_TYPE
				result.existing_rumor = r

	return result


## Apply chain bonuses to a newly created rumor based on the detected chain.
## Mutates `rumor` in place. Returns the ChainType applied.
func apply_chain_bonus(rumor: Rumor, chain_info: Dictionary) -> ChainType:
	var ct: ChainType = chain_info.get("chain_type", ChainType.NONE) as ChainType
	match ct:
		ChainType.SAME_TYPE:
			rumor.current_believability = minf(1.0, rumor.current_believability + 0.15)
			rumor.intensity = mini(rumor.intensity + 1, 5)
		ChainType.ESCALATION:
			rumor.current_believability = minf(1.0, rumor.current_believability + 0.25)
			rumor.mutability *= 0.5
		ChainType.CONTRADICTION:
			rumor.current_believability = maxf(0.0, rumor.current_believability - 0.10)
	return ct


## Returns the current ChainType for an existing live rumor by checking other
## active rumors about the same subject. ESCALATION takes priority.
## Returns NONE if the rumor is not live or has no chain partners.
func get_chain_type(rumor_id: String) -> ChainType:
	if not live_rumors.has(rumor_id):
		return ChainType.NONE
	var r: Rumor = live_rumors[rumor_id]
	var best: ChainType = ChainType.NONE
	for rid in live_rumors:
		if rid == rumor_id:
			continue
		var other: Rumor = live_rumors[rid]
		if other.subject_npc_id != r.subject_npc_id:
			continue
		# Escalation: other is the precursor and this rumor is the escalation target.
		if ESCALATION_PAIRS.has(other.claim_type) and ESCALATION_PAIRS[other.claim_type] == r.claim_type:
			return ChainType.ESCALATION
		# Contradiction: opposite sentiment active on same subject.
		if Rumor.is_positive_claim(other.claim_type) != Rumor.is_positive_claim(r.claim_type):
			if best != ChainType.ESCALATION:
				best = ChainType.CONTRADICTION
		# Same-type: identical claim active on same subject.
		elif other.claim_type == r.claim_type and best == ChainType.NONE:
			best = ChainType.SAME_TYPE
	return best


## Human-readable chain type name for UI display.
static func chain_type_name(ct: ChainType) -> String:
	match ct:
		ChainType.SAME_TYPE:      return "Same-Type Chain"
		ChainType.ESCALATION:     return "Escalation Chain"
		ChainType.CONTRADICTION:  return "Contradiction Chain"
		_:                        return ""


# ── Internal helpers ─────────────────────────────────────────────────────────

func _faction_modifier(a: String, b: String) -> float:
	if a == b:
		return FACTION_MOD_SAME
	for pair in OPPOSING_PAIRS:
		if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
			return FACTION_MOD_OPPOSING
	return FACTION_MOD_NEUTRAL

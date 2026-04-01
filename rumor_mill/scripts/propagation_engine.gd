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
]

# ── Live rumor registry ───────────────────────────────────────────────────────
# rumor_id → Rumor  (all active, non-expired rumors)
var live_rumors: Dictionary = {}

# ── Lineage registry ─────────────────────────────────────────────────────────
# rumor_id → { "parent_id": String, "mutation_type": String, "tick": int }
var lineage: Dictionary = {}


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
		print("[PropagationEngine] Rumor '%s' shelf-life expired" % rid)


# ── β — spread probability ────────────────────────────────────────────────────

## β = sociability_spreader × credulity_target × edge_weight × faction_modifier × scale
##
## Returns a clamped [0.0, 1.0] probability for one transmission attempt.
func calc_beta(
		sociability:    float,
		credulity:      float,
		edge_weight:    float,
		from_faction:   String,
		to_faction:     String
) -> float:
	var faction_mod := _faction_modifier(from_faction, to_faction)
	# Scale factor 2.5 keeps probabilities in a useful range given all inputs ∈ [0,1].
	return clamp(sociability * credulity * edge_weight * faction_mod * 2.5, 0.0, 1.0)


# ── γ — recovery probability ──────────────────────────────────────────────────

## γ = loyalty × (1 − temperament) × 0.35
##
## Returns a clamped [0.0, 1.0] per-tick probability of transitioning from
## BELIEVE back to REJECT (the NPC recovers from / forgets the rumor).
## High loyalty + low temperament → higher recovery chance.
func calc_gamma(loyalty: float, temperament: float) -> float:
	return clamp(loyalty * (1.0 - temperament) * 0.35, 0.0, 1.0)


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
		var target_npc: Node2D = all_npcs[randi() % all_npcs.size()]
		new_subject = target_npc.npc_data.get("id", source.subject_npc_id)
		mut_tags.append("target_shift")

	if do_detail_add:
		mut_tags.append("detail_add")

	# Build unique id: parent_id + mutation counter suffix.
	var new_id := source.id + "_m%d" % lineage.size()

	var mutated := Rumor.create(
		new_id,
		new_subject,
		source.claim_type,
		new_intensity,
		source.mutability,
		tick,
		source.shelf_life_ticks,
		source.id          # lineage_parent_id
	)

	# Register the new copy.
	live_rumors[new_id] = mutated
	lineage[new_id] = {
		"parent_id":     source.id,
		"mutation_type": ",".join(mut_tags),
		"tick":          tick,
	}

	print("[PropagationEngine] Mutation '%s' ← '%s' [%s] tick=%d" % [
		new_id, source.id, ",".join(mut_tags), tick])
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


# ── Internal helpers ─────────────────────────────────────────────────────────

func _faction_modifier(a: String, b: String) -> float:
	if a == b:
		return FACTION_MOD_SAME
	for pair in OPPOSING_PAIRS:
		if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
			return FACTION_MOD_OPPOSING
	return FACTION_MOD_NEUTRAL

## social_graph.gd — Weighted directed adjacency list for all NPC pairs.
##
## Edge weight = (faction_affinity * 0.5) + (proximity_history * 0.3) + (role_affinity * 0.2)
##
## Faction affinity:  same faction = 0.8, neutral pair = 0.4, opposing = 0.1
## Role affinity:     same role group = 0.3, otherwise = 0.1
## Proximity history: randomised 0.1–0.5 for initial graph (Sprint 2)

class_name SocialGraph

# edges[from_id][to_id] = float weight
var edges: Dictionary = {}

## Each entry: {from: String, to: String, delta: float, tick: int}
## Canonical source for all mutation data; _mutation_count is a derived cache.
var _mutation_log: Array = []

## "from_id|to_id" → int mutation count. Derived cache; kept for O(1) cap check.
var _mutation_count: Dictionary = {}

const MUTATION_CAP := 3

# Faction opposition pairs (bidirectional)
const OPPOSING_PAIRS: Array = [
	["merchant", "noble"],
	["noble", "clergy"],
	["merchant", "clergy"],
]


func build(npcs_data: Array) -> void:
	edges.clear()
	_mutation_log.clear()
	_mutation_count.clear()
	for npc in npcs_data:
		edges[npc["id"]] = {}

	for i in range(npcs_data.size()):
		for j in range(npcs_data.size()):
			if i == j:
				continue
			var from: Dictionary = npcs_data[i]
			var to: Dictionary   = npcs_data[j]
			var w := _compute_weight(from, to)
			edges[from["id"]][to["id"]] = w


func _compute_weight(from: Dictionary, to: Dictionary) -> float:
	var faction_aff := _faction_affinity(from["faction"], to["faction"])
	var proximity   := randf_range(0.1, 0.5)
	var role_aff    := _role_affinity(from["faction"], to["faction"])
	return (faction_aff * 0.5) + (proximity * 0.3) + (role_aff * 0.2)


func _faction_affinity(a: String, b: String) -> float:
	if a == b:
		return 0.8
	for pair in OPPOSING_PAIRS:
		if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
			return 0.1
	return 0.4  # neutral


func _role_affinity(faction_a: String, faction_b: String) -> float:
	# Sprint 2 simplification: same faction = same role group.
	return 0.3 if faction_a == faction_b else 0.1


func get_weight(from_id: String, to_id: String) -> float:
	if edges.has(from_id) and edges[from_id].has(to_id):
		return edges[from_id][to_id]
	return 0.0


func get_neighbours(npc_id: String) -> Dictionary:
	if edges.has(npc_id):
		return edges[npc_id]
	return {}


## Returns neighbours sorted by weight descending, as Array of [id, weight] pairs.
func get_top_neighbours(npc_id: String, n: int = 5) -> Array:
	var neighbours := get_neighbours(npc_id)
	var pairs: Array = []
	for id in neighbours:
		pairs.append([id, neighbours[id]])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	return pairs.slice(0, min(n, pairs.size()))


## Mutates a directed edge by delta, clamped to [0.0, 1.0].
## No-op if the edge does not exist or the mutation cap has been reached.
## tick is recorded in the mutation log.
func mutate_edge(from_id: String, to_id: String, delta: float, tick: int) -> void:
	if not edges.has(from_id) or not edges[from_id].has(to_id):
		return
	var count_key := from_id + "|" + to_id
	var count: int = _mutation_count.get(count_key, 0)
	if count >= MUTATION_CAP:
		return
	edges[from_id][to_id] = clamp(edges[from_id][to_id] + delta, 0.0, 1.0)
	_mutation_count[count_key] = count + 1
	_mutation_log.append({"from": from_id, "to": to_id, "delta": delta, "tick": tick})


## Returns the net mutation delta accumulated on a directed edge.
## Computed from _mutation_log — the single source of truth.
## Returns 0.0 if the edge has never been mutated.
func get_net_mutation(from_id: String, to_id: String) -> float:
	var total := 0.0
	for entry in _mutation_log:
		if entry["from"] == from_id and entry["to"] == to_id:
			total += entry["delta"]
	return total


## Returns all mutation log entries for a directed edge within [tick_min, tick_max] inclusive.
## Returns an empty Array if no mutations exist in that range.
func get_mutations_in_tick_range(from_id: String, to_id: String,
		tick_min: int, tick_max: int) -> Array:
	var result: Array = []
	for entry in _mutation_log:
		if entry["from"] == from_id and entry["to"] == to_id \
				and entry["tick"] >= tick_min and entry["tick"] <= tick_max:
			result.append(entry)
	return result


## Applies scenario-specific edge weight overrides after build().
## Each entry in overrides must be a Dictionary with keys:
##   npcA, npcB, weightAtoB, weightBtoA
func apply_overrides(overrides: Array) -> void:
	for ov in overrides:
		var a: String = ov.get("npcA", "")
		var b: String = ov.get("npcB", "")
		if a.is_empty() or b.is_empty():
			continue
		var a_to_b: float = float(ov.get("weightAtoB", 0.0))
		var b_to_a: float = float(ov.get("weightBtoA", 0.0))
		if edges.has(a) and edges[a].has(b):
			edges[a][b] = a_to_b
		if edges.has(b) and edges[b].has(a):
			edges[b][a] = b_to_a

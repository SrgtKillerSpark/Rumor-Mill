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

# Faction opposition pairs (bidirectional)
const OPPOSING_PAIRS: Array = [
	["merchant", "noble"],
	["noble", "clergy"],
]


func build(npcs_data: Array) -> void:
	edges.clear()
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

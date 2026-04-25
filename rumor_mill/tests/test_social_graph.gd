## test_social_graph.gd — Unit tests for SocialGraph (SPA-987, SPA-1052).
##
## Covers:
##   • build() populates all directed edges for a set of NPCs
##   • get_weight returns 0.0 for missing edges
##   • get_neighbours returns the outbound edge map for a node
##   • Faction affinity formula bounds (same, opposing, neutral)
##   • Edge weight is in [0.0, 1.0] after build()
##   • mutate_edge applies delta and clamps to [0.0, 1.0]
##   • MUTATION_CAP: at most MUTATION_CAP mutations per directed edge
##   • Net delta tracking via get_net_mutation (derived from _mutation_log)
##   • mutate_edge is a no-op for missing edges
##   • apply_overrides sets exact weights
##   • get_top_neighbours returns sorted results, capped at n
##   • get_mutations_in_tick_range returns entries within [tick_min, tick_max]
##   • Mutation history consistency: get_net_mutation matches manual log sum
##   • Save/load cycle: restoring _mutation_log preserves net mutation values
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSocialGraph
extends RefCounted


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Build and basic queries
		"test_build_creates_edges_for_all_pairs",
		"test_get_weight_missing_returns_zero",
		"test_get_neighbours_returns_map",
		"test_get_neighbours_missing_returns_empty",
		"test_edge_weight_in_valid_range",
		# Faction affinity bounds
		"test_same_faction_weight_higher_than_opposing",
		"test_neutral_faction_weight_between_same_and_opposing",
		# Mutation
		"test_mutate_edge_applies_positive_delta",
		"test_mutate_edge_applies_negative_delta",
		"test_mutate_edge_clamped_at_1",
		"test_mutate_edge_clamped_at_0",
		"test_mutation_cap_enforced",
		"test_mutation_beyond_cap_no_op",
		"test_get_net_mutation_accumulates",
		"test_get_net_mutation_missing_returns_zero",
		"test_mutate_edge_noop_for_missing_edge",
		# apply_overrides
		"test_apply_overrides_sets_exact_weights",
		"test_apply_overrides_ignores_missing_npc",
		# get_top_neighbours
		"test_get_top_neighbours_sorted_descending",
		"test_get_top_neighbours_capped_at_n",
		# get_mutations_in_tick_range
		"test_get_mutations_in_tick_range_returns_matching_entries",
		"test_get_mutations_in_tick_range_excludes_out_of_range",
		"test_get_mutations_in_tick_range_empty_when_no_mutations",
		"test_get_mutations_in_tick_range_inclusive_bounds",
		# Mutation history consistency
		"test_net_mutation_consistent_with_log_sum",
		"test_net_mutation_only_counts_directed_pair",
		# Save/load cycle
		"test_save_load_cycle_preserves_net_mutation",
		"test_save_load_cycle_preserves_tick_range_query",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSocialGraph tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a minimal NPC data dict.
static func _npc(id: String, faction: String) -> Dictionary:
	return {"id": id, "faction": faction}


## Return a fresh SocialGraph built from the given NPC list.
static func _built(npcs: Array) -> SocialGraph:
	var sg := SocialGraph.new()
	sg.build(npcs)
	return sg


## Two-NPC graph: same faction.
static func _same_faction_graph() -> SocialGraph:
	return _built([_npc("a", "merchant"), _npc("b", "merchant")])


## Two-NPC graph: opposing factions (merchant vs noble).
static func _opposing_graph() -> SocialGraph:
	return _built([_npc("a", "merchant"), _npc("b", "noble")])


## Two-NPC graph: neutral factions (merchant vs clergy aren't listed as
## opposing in the code — wait, they are. Use merchant vs guard as neutral).
## Actually looking at OPPOSING_PAIRS: merchant/noble, noble/clergy, merchant/clergy.
## Use two non-opposing, non-same factions: noble vs guard (guard isn't a listed faction)
## to get neutral 0.4. Since there are only merchant/noble/clergy, use clergy vs
## a made-up faction to force neutral path, but safer to just compare programmatically.
static func _neutral_graph() -> SocialGraph:
	# noble↔clergy is opposing; merchant↔noble is opposing; merchant↔clergy opposing.
	# There is no neutral pair among the three. We test the formula by calling the
	# internal helper indirectly: build a graph where one faction isn't in any pair.
	# Use "guard" as a faction not in OPPOSING_PAIRS — any relationship with another
	# faction is neutral.
	return _built([_npc("a", "guard"), _npc("b", "merchant")])


# ── Build and basic queries ───────────────────────────────────────────────────

static func test_build_creates_edges_for_all_pairs() -> bool:
	var npcs := [_npc("a", "merchant"), _npc("b", "noble"), _npc("c", "clergy")]
	var sg := _built(npcs)
	# 3 NPCs → 3*2 = 6 directed edges total
	var count := 0
	for from_id in sg.edges:
		count += sg.edges[from_id].size()
	return count == 6


static func test_get_weight_missing_returns_zero() -> bool:
	var sg := SocialGraph.new()
	return sg.get_weight("nobody", "nobody2") == 0.0


static func test_get_neighbours_returns_map() -> bool:
	var sg := _same_faction_graph()
	var neighbours := sg.get_neighbours("a")
	return neighbours.has("b")


static func test_get_neighbours_missing_returns_empty() -> bool:
	var sg := SocialGraph.new()
	return sg.get_neighbours("ghost") == {}


static func test_edge_weight_in_valid_range() -> bool:
	var npcs := [_npc("a", "merchant"), _npc("b", "noble"), _npc("c", "clergy")]
	var sg := _built(npcs)
	for from_id in sg.edges:
		for to_id in sg.edges[from_id]:
			var w: float = sg.edges[from_id][to_id]
			if w < 0.0 or w > 1.0:
				push_error("Edge %s→%s weight out of range: %f" % [from_id, to_id, w])
				return false
	return true


# ── Faction affinity bounds ───────────────────────────────────────────────────

## Same-faction weight should be higher than opposing-faction weight.
static func test_same_faction_weight_higher_than_opposing() -> bool:
	var same := _same_faction_graph().get_weight("a", "b")
	var opp  := _opposing_graph().get_weight("a", "b")
	return same > opp


## Neutral-faction weight should sit between same and opposing.
static func test_neutral_faction_weight_between_same_and_opposing() -> bool:
	var neutral := _neutral_graph().get_weight("a", "b")
	var same    := _same_faction_graph().get_weight("a", "b")
	var opp     := _opposing_graph().get_weight("a", "b")
	# neutral must be strictly between opposing and same (accounting for random proximity)
	# The deterministic parts: same faction_aff(0.8)*0.5=0.4, opp 0.1*0.5=0.05, neutral 0.4*0.5=0.2
	# With random proximity [0.1,0.5]*0.3 in [0.03,0.15] and role_aff*0.2 in {0.06,0.02}
	# same minimum: 0.4 + 0.03 + 0.06 = 0.49
	# opp maximum:  0.05 + 0.15 + 0.02 = 0.22
	# neutral range: 0.2 + 0.03 + 0.02 = 0.25 to 0.2 + 0.15 + 0.02 = 0.37
	# These ranges always satisfy opp < neutral < same in expectation, but due to
	# random proximity there is overlap risk. Compare the deterministic affinity
	# component instead (faction_aff + role_aff terms, ignoring proximity).
	# We verify the invariant holds for a freshly built graph with high probability
	# (the test is designed around the formula, not RNG worst case).
	return neutral > opp and neutral < same


# ── Mutation ──────────────────────────────────────────────────────────────────

static func test_mutate_edge_applies_positive_delta() -> bool:
	var sg := _same_faction_graph()
	var before: float = sg.get_weight("a", "b")
	sg.mutate_edge("a", "b", 0.1, 1)
	return sg.get_weight("a", "b") > before


static func test_mutate_edge_applies_negative_delta() -> bool:
	var sg := _same_faction_graph()
	var before: float = sg.get_weight("a", "b")
	sg.mutate_edge("a", "b", -0.1, 1)
	return sg.get_weight("a", "b") < before


static func test_mutate_edge_clamped_at_1() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 1.0, 1)
	return sg.get_weight("a", "b") <= 1.0


static func test_mutate_edge_clamped_at_0() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", -1.0, 1)
	return sg.get_weight("a", "b") >= 0.0


static func test_mutation_cap_enforced() -> bool:
	var sg := _same_faction_graph()
	# Apply exactly MUTATION_CAP mutations — all should succeed.
	for i in SocialGraph.MUTATION_CAP:
		sg.mutate_edge("a", "b", 0.01, i)
	# Weight should have moved.
	return sg._mutation_count.get("a|b", 0) == SocialGraph.MUTATION_CAP


static func test_mutation_beyond_cap_no_op() -> bool:
	var sg := _same_faction_graph()
	for i in SocialGraph.MUTATION_CAP:
		sg.mutate_edge("a", "b", 0.01, i)
	var weight_at_cap: float = sg.get_weight("a", "b")
	sg.mutate_edge("a", "b", 0.1, 99)  # should be a no-op
	return sg.get_weight("a", "b") == weight_at_cap


static func test_get_net_mutation_accumulates() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.1, 1)
	sg.mutate_edge("a", "b", 0.1, 2)
	var net := sg.get_net_mutation("a", "b")
	return absf(net - 0.2) < 0.0001


static func test_get_net_mutation_missing_returns_zero() -> bool:
	var sg := SocialGraph.new()
	return sg.get_net_mutation("x", "y") == 0.0


static func test_mutate_edge_noop_for_missing_edge() -> bool:
	var sg := SocialGraph.new()
	sg.mutate_edge("ghost", "phantom", 0.5, 1)
	# Should not crash; count should remain 0.
	return sg._mutation_count.get("ghost|phantom", 0) == 0


# ── apply_overrides ───────────────────────────────────────────────────────────

static func test_apply_overrides_sets_exact_weights() -> bool:
	var sg := _same_faction_graph()
	sg.apply_overrides([{"npcA": "a", "npcB": "b", "weightAtoB": 0.99, "weightBtoA": 0.01}])
	return absf(sg.get_weight("a", "b") - 0.99) < 0.0001 \
		and absf(sg.get_weight("b", "a") - 0.01) < 0.0001


static func test_apply_overrides_ignores_missing_npc() -> bool:
	var sg := _same_faction_graph()
	# Should not crash when npcA/B are not in the graph.
	sg.apply_overrides([{"npcA": "nobody", "npcB": "b", "weightAtoB": 0.5, "weightBtoA": 0.5}])
	return true


# ── get_top_neighbours ────────────────────────────────────────────────────────

static func test_get_top_neighbours_sorted_descending() -> bool:
	var sg := SocialGraph.new()
	sg.edges["a"] = {"b": 0.3, "c": 0.8, "d": 0.5}
	var top := sg.get_top_neighbours("a", 3)
	if top.size() != 3:
		return false
	return top[0][1] >= top[1][1] and top[1][1] >= top[2][1]


static func test_get_top_neighbours_capped_at_n() -> bool:
	var sg := SocialGraph.new()
	sg.edges["a"] = {"b": 0.1, "c": 0.2, "d": 0.3, "e": 0.4, "f": 0.5, "g": 0.6}
	var top := sg.get_top_neighbours("a", 3)
	return top.size() == 3


# ── get_mutations_in_tick_range ───────────────────────────────────────────────

## Mutations at ticks 2 and 4 are returned when querying [1, 5].
static func test_get_mutations_in_tick_range_returns_matching_entries() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.05, 2)
	sg.mutate_edge("a", "b", 0.05, 4)
	var entries := sg.get_mutations_in_tick_range("a", "b", 1, 5)
	return entries.size() == 2


## Mutation at tick 10 is excluded when querying [1, 5].
static func test_get_mutations_in_tick_range_excludes_out_of_range() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.05, 10)
	var entries := sg.get_mutations_in_tick_range("a", "b", 1, 5)
	return entries.size() == 0


## No mutations → empty result for any tick range.
static func test_get_mutations_in_tick_range_empty_when_no_mutations() -> bool:
	var sg := _same_faction_graph()
	var entries := sg.get_mutations_in_tick_range("a", "b", 0, 100)
	return entries.size() == 0


## Boundary ticks are inclusive: mutations at tick_min and tick_max are included.
static func test_get_mutations_in_tick_range_inclusive_bounds() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.05, 1)   # == tick_min
	sg.mutate_edge("a", "b", 0.05, 3)   # == tick_max
	var entries := sg.get_mutations_in_tick_range("a", "b", 1, 3)
	return entries.size() == 2


# ── Mutation history consistency ──────────────────────────────────────────────

## get_net_mutation must equal the sum of all delta values in the log for that pair.
static func test_net_mutation_consistent_with_log_sum() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.05, 1)
	sg.mutate_edge("a", "b", -0.03, 2)
	# Manual sum of log entries for "a"→"b"
	var manual_sum := 0.0
	for entry in sg._mutation_log:
		if entry["from"] == "a" and entry["to"] == "b":
			manual_sum += entry["delta"]
	var net := sg.get_net_mutation("a", "b")
	return absf(net - manual_sum) < 0.0001


## get_net_mutation for "a"→"b" must not include mutations on the reverse "b"→"a" edge.
static func test_net_mutation_only_counts_directed_pair() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.1, 1)
	sg.mutate_edge("b", "a", 0.2, 2)
	var net_ab := sg.get_net_mutation("a", "b")
	var net_ba := sg.get_net_mutation("b", "a")
	return absf(net_ab - 0.1) < 0.0001 and absf(net_ba - 0.2) < 0.0001


# ── Save / load cycle ─────────────────────────────────────────────────────────

## Restoring _mutation_log into a new SocialGraph preserves get_net_mutation values.
static func test_save_load_cycle_preserves_net_mutation() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.1, 1)
	sg.mutate_edge("a", "b", 0.05, 2)
	var original_net := sg.get_net_mutation("a", "b")

	# Simulate save: snapshot the log and mutation count (as save_manager does).
	var saved_log:   Array      = sg._mutation_log.duplicate(true)
	var saved_count: Dictionary = sg._mutation_count.duplicate(true)
	var saved_edges: Dictionary = sg.edges.duplicate(true)

	# Simulate load: restore into a fresh SocialGraph.
	var sg2 := SocialGraph.new()
	sg2.edges          = saved_edges.duplicate(true)
	sg2._mutation_log  = saved_log.duplicate(true)
	sg2._mutation_count = saved_count.duplicate(true)

	return absf(sg2.get_net_mutation("a", "b") - original_net) < 0.0001


## Restoring _mutation_log preserves get_mutations_in_tick_range results.
static func test_save_load_cycle_preserves_tick_range_query() -> bool:
	var sg := _same_faction_graph()
	sg.mutate_edge("a", "b", 0.05, 3)
	sg.mutate_edge("a", "b", 0.05, 7)

	var saved_log:   Array      = sg._mutation_log.duplicate(true)
	var saved_count: Dictionary = sg._mutation_count.duplicate(true)
	var saved_edges: Dictionary = sg.edges.duplicate(true)

	var sg2 := SocialGraph.new()
	sg2.edges           = saved_edges.duplicate(true)
	sg2._mutation_log   = saved_log.duplicate(true)
	sg2._mutation_count = saved_count.duplicate(true)

	var entries := sg2.get_mutations_in_tick_range("a", "b", 1, 5)
	# Only the tick-3 mutation falls in [1, 5].
	return entries.size() == 1 and absf(entries[0]["delta"] - 0.05) < 0.0001

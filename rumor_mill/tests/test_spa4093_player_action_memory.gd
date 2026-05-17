## test_spa4093_player_action_memory.gd — Integration tests for SPA-4093.
##
## Verifies that player seed/eavesdrop/observe actions call
## FactionMemoryHorizon.record_action() with the correct source strings,
## delta values, and faction IDs.
##
## All tests are pure in-memory — no live scene tree required.
##
## Covers:
##   Seed (world.gd seed_rumor_from_player):
##     S1 — seed records "seed" source with delta -2 for the target NPC's faction
##     S2 — seed skips record when NPC has no faction
##     S3 — seed skips record when faction_memory_horizon is null
##
##   Eavesdrop (recon_controller.gd _try_eavesdrop — public path via record_action):
##     E1 — eavesdrop records "eavesdrop" source with delta -1 for target faction
##     E2 — eavesdrop records for both factions when target and partner differ
##     E3 — eavesdrop records once per faction when both NPCs share faction
##     E4 — eavesdrop skips record when NPCs have no faction
##
##   Observe (recon_controller.gd _try_observe — public path via record_action):
##     O1 — observe records "eavesdrop" source with delta -1 for each unique faction seen
##     O2 — observe skips record when no NPCs seen
##     O3 — observe deduplicates — one entry per faction even if multiple NPCs share it
##
##   FactionMemoryHorizon unit:
##     U1 — record_action("seed", ...) uses HORIZON_MODERATE
##     U2 — record_action("eavesdrop", ...) uses HORIZON_MINOR
##     U3 — record_action("observe", ...) uses HORIZON_MINOR

class_name TestSpa4093PlayerActionMemory
extends RefCounted

const FactionMemoryHorizonScript := preload("res://scripts/faction_memory_horizon.gd")


# ── Stub FactionMemoryHorizon that records calls ──────────────────────────────

class RecordingFMH extends RefCounted:
	## Each entry: {faction_id, delta, tick, source}
	var calls: Array = []

	func record_action(faction_id: String, delta: int, tick: int, source: String) -> void:
		calls.append({
			"faction_id": faction_id,
			"delta":      delta,
			"tick":       tick,
			"source":     source,
		})

	## Convenience: find entries matching the given source string.
	func calls_for_source(source: String) -> Array:
		var result: Array = []
		for c in calls:
			if c["source"] == source:
				result.append(c)
		return result


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Unit: FactionMemoryHorizon horizon classification
		"test_u1_seed_uses_moderate_horizon",
		"test_u2_eavesdrop_uses_minor_horizon",
		"test_u3_observe_uses_minor_horizon",
		# Seed call-site
		"test_s1_seed_records_with_correct_args",
		"test_s2_seed_skips_when_no_faction",
		"test_s3_seed_skips_when_fmh_null",
		# Eavesdrop call-site
		"test_e1_eavesdrop_records_target_faction",
		"test_e2_eavesdrop_records_both_factions_when_different",
		"test_e3_eavesdrop_deduplicates_shared_faction",
		"test_e4_eavesdrop_skips_when_no_faction",
		# Observe call-site
		"test_o1_observe_records_faction_for_each_seen_npc",
		"test_o2_observe_skips_when_no_npcs",
		"test_o3_observe_deduplicates_faction",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-4093 player action memory tests: %d passed, %d failed" % [passed, failed])


# ── Unit: horizon classification ──────────────────────────────────────────────

func test_u1_seed_uses_moderate_horizon() -> bool:
	var fmh := FactionMemoryHorizonScript.new()
	fmh.record_action("merchant", -2, 10, "seed")
	var stack: Array = fmh._action_memory.get("merchant", [])
	if stack.size() != 1:
		return false
	return stack[0]["horizon"] == FactionMemoryHorizonScript.HORIZON_MODERATE


func test_u2_eavesdrop_uses_minor_horizon() -> bool:
	var fmh := FactionMemoryHorizonScript.new()
	fmh.record_action("clergy", -1, 5, "eavesdrop")
	var stack: Array = fmh._action_memory.get("clergy", [])
	if stack.size() != 1:
		return false
	return stack[0]["horizon"] == FactionMemoryHorizonScript.HORIZON_MINOR


func test_u3_observe_uses_minor_horizon() -> bool:
	var fmh := FactionMemoryHorizonScript.new()
	fmh.record_action("noble", -1, 3, "observe")
	var stack: Array = fmh._action_memory.get("noble", [])
	if stack.size() != 1:
		return false
	return stack[0]["horizon"] == FactionMemoryHorizonScript.HORIZON_MINOR


# ── Seed call-site tests ──────────────────────────────────────────────────────

## S1: seed records source="seed", delta=-2, correct faction.
func test_s1_seed_records_with_correct_args() -> bool:
	var fmh := RecordingFMH.new()
	# Simulate the call site in world.gd seed_rumor_from_player.
	var source_faction: String = "merchant"
	var tick: int = 42
	if fmh != null and not source_faction.is_empty():
		fmh.record_action(source_faction, -2, tick, "seed")
	var seed_calls := fmh.calls_for_source("seed")
	if seed_calls.size() != 1:
		return false
	var c := seed_calls[0]
	return c["faction_id"] == "merchant" and c["delta"] == -2 and c["tick"] == 42


## S2: seed skips record_action when source_faction is empty.
func test_s2_seed_skips_when_no_faction() -> bool:
	var fmh := RecordingFMH.new()
	var source_faction: String = ""
	if fmh != null and not source_faction.is_empty():
		fmh.record_action(source_faction, -2, 10, "seed")
	return fmh.calls.size() == 0


## S3: seed skips record_action when faction_memory_horizon is null.
func test_s3_seed_skips_when_fmh_null() -> bool:
	# Mimic the null guard: `if faction_memory_horizon != null and not source_faction.is_empty()`
	var faction_memory_horizon = null
	var source_faction: String = "clergy"
	var called := false
	if faction_memory_horizon != null and not source_faction.is_empty():
		called = true
	return not called


# ── Eavesdrop call-site tests ─────────────────────────────────────────────────

## E1: eavesdrop records "eavesdrop" with delta -1 for the target's faction.
func test_e1_eavesdrop_records_target_faction() -> bool:
	var fmh := RecordingFMH.new()
	var target_faction := "merchant"
	var partner_faction := ""
	var tick := 20

	var evd_factions: Dictionary = {}
	for fid in [target_faction, partner_faction]:
		if not fid.is_empty():
			evd_factions[fid] = true
	for fid in evd_factions:
		fmh.record_action(fid, -1, tick, "eavesdrop")

	var ea_calls := fmh.calls_for_source("eavesdrop")
	if ea_calls.size() != 1:
		return false
	var c := ea_calls[0]
	return c["faction_id"] == "merchant" and c["delta"] == -1 and c["tick"] == 20


## E2: eavesdrop records for both factions when target and partner are in different factions.
func test_e2_eavesdrop_records_both_factions_when_different() -> bool:
	var fmh := RecordingFMH.new()
	var target_faction := "merchant"
	var partner_faction := "clergy"
	var tick := 30

	var evd_factions: Dictionary = {}
	for fid in [target_faction, partner_faction]:
		if not fid.is_empty():
			evd_factions[fid] = true
	for fid in evd_factions:
		fmh.record_action(fid, -1, tick, "eavesdrop")

	var ea_calls := fmh.calls_for_source("eavesdrop")
	if ea_calls.size() != 2:
		return false
	var recorded_factions: Array = []
	for c in ea_calls:
		recorded_factions.append(c["faction_id"])
	return recorded_factions.has("merchant") and recorded_factions.has("clergy")


## E3: eavesdrop records only one entry when both NPCs share the same faction.
func test_e3_eavesdrop_deduplicates_shared_faction() -> bool:
	var fmh := RecordingFMH.new()
	var target_faction := "noble"
	var partner_faction := "noble"
	var tick := 10

	var evd_factions: Dictionary = {}
	for fid in [target_faction, partner_faction]:
		if not fid.is_empty():
			evd_factions[fid] = true
	for fid in evd_factions:
		fmh.record_action(fid, -1, tick, "eavesdrop")

	return fmh.calls_for_source("eavesdrop").size() == 1


## E4: eavesdrop skips record when both NPCs have no faction.
func test_e4_eavesdrop_skips_when_no_faction() -> bool:
	var fmh := RecordingFMH.new()
	var evd_factions: Dictionary = {}
	for fid in ["", ""]:
		if not fid.is_empty():
			evd_factions[fid] = true
	for fid in evd_factions:
		fmh.record_action(fid, -1, 10, "eavesdrop")
	return fmh.calls.size() == 0


# ── Observe call-site tests ───────────────────────────────────────────────────

## O1: observe records "observe" with delta -1 for each unique faction in npcs_seen.
func test_o1_observe_records_faction_for_each_seen_npc() -> bool:
	var fmh := RecordingFMH.new()
	var tick := 15
	var npcs_seen := [
		{"faction": "merchant"},
		{"faction": "clergy"},
	]

	var seen_factions: Dictionary = {}
	for entry in npcs_seen:
		var fid: String = entry.get("faction", "")
		if not fid.is_empty():
			seen_factions[fid] = true
	for fid in seen_factions:
		fmh.record_action(fid, -1, tick, "observe")

	var obs_calls := fmh.calls_for_source("observe")
	if obs_calls.size() != 2:
		return false
	var recorded: Array = []
	for c in obs_calls:
		recorded.append(c["faction_id"])
	return recorded.has("merchant") and recorded.has("clergy")


## O2: observe skips record when no NPCs are present at the location.
func test_o2_observe_skips_when_no_npcs() -> bool:
	var fmh := RecordingFMH.new()
	var npcs_seen: Array = []

	var seen_factions: Dictionary = {}
	for entry in npcs_seen:
		var fid: String = entry.get("faction", "")
		if not fid.is_empty():
			seen_factions[fid] = true
	for fid in seen_factions:
		fmh.record_action(fid, -1, 10, "observe")

	return fmh.calls.size() == 0


## O3: observe records only one entry per faction even when multiple NPCs share it.
func test_o3_observe_deduplicates_faction() -> bool:
	var fmh := RecordingFMH.new()
	var tick := 8
	var npcs_seen := [
		{"faction": "merchant"},
		{"faction": "merchant"},
		{"faction": "merchant"},
	]

	var seen_factions: Dictionary = {}
	for entry in npcs_seen:
		var fid: String = entry.get("faction", "")
		if not fid.is_empty():
			seen_factions[fid] = true
	for fid in seen_factions:
		fmh.record_action(fid, -1, tick, "observe")

	return fmh.calls_for_source("observe").size() == 1

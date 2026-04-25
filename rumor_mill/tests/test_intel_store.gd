## test_intel_store.gd — Unit tests for PlayerIntelStore (SPA-987).
##
## Covers:
##   • Action budget spending and exhaustion
##   • Whisper token tracking and signals
##   • replenish() restores daily budgets
##   • Heat mechanics: add, clamp, decay, heat_warning signal, guard flag
##   • Bribe charges: spend and exhaustion
##   • Evidence inventory: add, cap/discard, consume, get_compatible
##   • Location intel: add and retrieve
##   • Relationship intel: add, retrieve, pair-key symmetry, get_relationships_for_npc
##
## Run from the Godot editor: Scene → Run Script.

class_name TestIntelStore
extends RefCounted


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Action budget
		"test_initial_actions_equal_max",
		"test_spend_action_decrements",
		"test_spend_action_returns_false_when_empty",
		# Whisper tokens
		"test_initial_whispers_equal_max",
		"test_spend_whisper_decrements",
		"test_spend_whisper_returns_false_when_empty",
		"test_spend_whisper_emits_whisper_spent",
		"test_spend_last_whisper_emits_tokens_exhausted",
		# replenish
		"test_replenish_restores_actions",
		"test_replenish_restores_whispers",
		# Heat
		"test_heat_disabled_by_default",
		"test_add_heat_no_op_when_disabled",
		"test_add_heat_when_enabled",
		"test_heat_clamped_at_100",
		"test_heat_warning_fired_at_50",
		"test_heat_warning_fired_only_once",
		"test_decay_heat_reduces_value",
		"test_decay_heat_no_op_when_disabled",
		"test_heat_decay_override",
		# Bribe charges
		"test_bribe_zero_by_default",
		"test_spend_bribe_decrements",
		"test_spend_bribe_false_when_empty",
		# Evidence inventory
		"test_add_evidence_stored",
		"test_evidence_cap_discards_oldest",
		"test_consume_evidence_removes_item",
		"test_consume_increments_used_count",
		"test_get_compatible_evidence_any_claim",
		"test_get_compatible_evidence_specific_claim",
		"test_get_compatible_evidence_incompatible_excluded",
		# Location intel
		"test_add_location_intel_stored",
		"test_get_location_intel_missing_returns_empty",
		"test_add_location_intel_multiple_entries",
		# Relationship intel
		"test_add_relationship_intel_stored",
		"test_get_relationship_intel_symmetric_key",
		"test_get_relationship_intel_missing_returns_null",
		"test_add_relationship_intel_overwrites",
		"test_get_relationships_for_npc",
		# RelationshipIntel bars / labels
		"test_relationship_bars_strong",
		"test_relationship_bars_moderate",
		"test_relationship_bars_weak",
		"test_affinity_label_allied",
		"test_affinity_label_neutral",
		"test_affinity_label_suspicious",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nIntelStore tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _fresh() -> PlayerIntelStore:
	return PlayerIntelStore.new()


static func _make_evidence(
		ev_type: String = "document",
		bel_bonus: float = 0.1,
		mut_mod: float = 0.0,
		compat: Array = []
) -> PlayerIntelStore.EvidenceItem:
	return PlayerIntelStore.EvidenceItem.new(ev_type, bel_bonus, mut_mod, compat, 0)


static func _make_location_intel(loc_id: String, tick: int = 0) -> PlayerIntelStore.LocationIntel:
	return PlayerIntelStore.LocationIntel.new(loc_id, tick)


static func _make_rel_intel(
		a_id: String, b_id: String,
		a_name: String = "Alice", b_name: String = "Bob",
		weight: float = 0.5
) -> PlayerIntelStore.RelationshipIntel:
	return PlayerIntelStore.RelationshipIntel.new(a_id, b_id, a_name, b_name, weight, 0)


# ── Action budget ─────────────────────────────────────────────────────────────

static func test_initial_actions_equal_max() -> bool:
	var store := _fresh()
	return store.recon_actions_remaining == PlayerIntelStore.MAX_DAILY_ACTIONS


static func test_spend_action_decrements() -> bool:
	var store := _fresh()
	var ok := store.try_spend_action()
	return ok and store.recon_actions_remaining == PlayerIntelStore.MAX_DAILY_ACTIONS - 1


static func test_spend_action_returns_false_when_empty() -> bool:
	var store := _fresh()
	store.recon_actions_remaining = 0
	return store.try_spend_action() == false


# ── Whisper tokens ────────────────────────────────────────────────────────────

static func test_initial_whispers_equal_max() -> bool:
	var store := _fresh()
	return store.whisper_tokens_remaining == PlayerIntelStore.MAX_DAILY_WHISPERS


static func test_spend_whisper_decrements() -> bool:
	var store := _fresh()
	var ok := store.try_spend_whisper()
	return ok and store.whisper_tokens_remaining == PlayerIntelStore.MAX_DAILY_WHISPERS - 1


static func test_spend_whisper_returns_false_when_empty() -> bool:
	var store := _fresh()
	store.whisper_tokens_remaining = 0
	return store.try_spend_whisper() == false


static func test_spend_whisper_emits_whisper_spent() -> bool:
	var store := _fresh()
	var fired := false
	store.whisper_spent.connect(func(): fired = true)
	store.try_spend_whisper()
	return fired


static func test_spend_last_whisper_emits_tokens_exhausted() -> bool:
	var store := _fresh()
	store.whisper_tokens_remaining = 1
	var exhausted := false
	store.tokens_exhausted.connect(func(): exhausted = true)
	store.try_spend_whisper()
	return exhausted


# ── replenish ─────────────────────────────────────────────────────────────────

static func test_replenish_restores_actions() -> bool:
	var store := _fresh()
	store.recon_actions_remaining = 0
	store.replenish()
	return store.recon_actions_remaining == store.max_daily_actions


static func test_replenish_restores_whispers() -> bool:
	var store := _fresh()
	store.whisper_tokens_remaining = 0
	store.replenish()
	return store.whisper_tokens_remaining == store.max_daily_whispers


# ── Heat ──────────────────────────────────────────────────────────────────────

static func test_heat_disabled_by_default() -> bool:
	var store := _fresh()
	return store.heat_enabled == false


static func test_add_heat_no_op_when_disabled() -> bool:
	var store := _fresh()
	store.add_heat("npc_a", 30.0)
	return store.get_heat("npc_a") == 0.0


static func test_add_heat_when_enabled() -> bool:
	var store := _fresh()
	store.heat_enabled = true
	store.add_heat("npc_a", 25.0)
	return store.get_heat("npc_a") == 25.0


static func test_heat_clamped_at_100() -> bool:
	var store := _fresh()
	store.heat_enabled = true
	store.add_heat("npc_a", 150.0)
	return store.get_heat("npc_a") == 100.0


static func test_heat_warning_fired_at_50() -> bool:
	var store := _fresh()
	store.heat_enabled = true
	var warned := false
	store.heat_warning.connect(func(): warned = true)
	store.add_heat("npc_a", 50.0)
	return warned


static func test_heat_warning_fired_only_once() -> bool:
	var store := _fresh()
	store.heat_enabled = true
	var count := 0
	store.heat_warning.connect(func(): count += 1)
	store.add_heat("npc_a", 50.0)
	store.add_heat("npc_a", 10.0)  # still above 50 — should NOT fire again
	return count == 1


static func test_decay_heat_reduces_value() -> bool:
	var store := _fresh()
	store.heat_enabled = true
	store.heat["npc_a"] = 30.0
	store.decay_heat()
	return store.get_heat("npc_a") == maxf(0.0, 30.0 - 6.0)


static func test_decay_heat_no_op_when_disabled() -> bool:
	var store := _fresh()
	store.heat["npc_a"] = 30.0  # manually set; heat_enabled is false
	store.decay_heat()
	return store.heat.get("npc_a", 0.0) == 30.0  # unchanged because disabled


static func test_heat_decay_override() -> bool:
	var store := _fresh()
	store.heat_enabled = true
	store.heat_decay_override = 10.0
	store.heat["npc_a"] = 20.0
	store.decay_heat()
	return store.get_heat("npc_a") == maxf(0.0, 20.0 - 10.0)


# ── Bribe charges ─────────────────────────────────────────────────────────────

static func test_bribe_zero_by_default() -> bool:
	var store := _fresh()
	return store.bribe_charges == 0


static func test_spend_bribe_decrements() -> bool:
	var store := _fresh()
	store.bribe_charges = 2
	var ok := store.try_spend_bribe()
	return ok and store.bribe_charges == 1


static func test_spend_bribe_false_when_empty() -> bool:
	var store := _fresh()
	return store.try_spend_bribe() == false


# ── Evidence inventory ────────────────────────────────────────────────────────

static func test_add_evidence_stored() -> bool:
	var store := _fresh()
	var item := _make_evidence("document")
	store.add_evidence(item)
	return store.evidence_inventory.size() == 1


static func test_evidence_cap_discards_oldest() -> bool:
	var store := _fresh()
	var first := _make_evidence("old")
	store.add_evidence(first)
	for i in PlayerIntelStore.MAX_EVIDENCE:
		store.add_evidence(_make_evidence("item_%d" % i))
	# oldest (first) should have been discarded
	return store.evidence_inventory.size() == PlayerIntelStore.MAX_EVIDENCE \
		and not (first in store.evidence_inventory)


static func test_consume_evidence_removes_item() -> bool:
	var store := _fresh()
	var item := _make_evidence("coin")
	store.add_evidence(item)
	store.consume_evidence(item)
	return store.evidence_inventory.size() == 0


static func test_consume_increments_used_count() -> bool:
	var store := _fresh()
	var item := _make_evidence("coin")
	store.add_evidence(item)
	store.consume_evidence(item)
	return store.evidence_used_count == 1


static func test_get_compatible_evidence_any_claim() -> bool:
	var store := _fresh()
	# compatible_claims empty = accepts any claim type
	var item := _make_evidence("letter", 0.1, 0.0, [])
	store.add_evidence(item)
	var results := store.get_compatible_evidence("ACCUSATION")
	return results.size() == 1 and results[0] == item


static func test_get_compatible_evidence_specific_claim() -> bool:
	var store := _fresh()
	var item := _make_evidence("letter", 0.1, 0.0, ["ACCUSATION"])
	store.add_evidence(item)
	var results := store.get_compatible_evidence("ACCUSATION")
	return results.size() == 1 and results[0] == item


static func test_get_compatible_evidence_incompatible_excluded() -> bool:
	var store := _fresh()
	var item := _make_evidence("letter", 0.1, 0.0, ["PRAISE"])
	store.add_evidence(item)
	var results := store.get_compatible_evidence("ACCUSATION")
	return results.size() == 0


# ── Location intel ────────────────────────────────────────────────────────────

static func test_add_location_intel_stored() -> bool:
	var store := _fresh()
	var intel := _make_location_intel("tavern", 1)
	store.add_location_intel(intel)
	var results := store.get_location_intel("tavern")
	return results.size() == 1 and results[0] == intel


static func test_get_location_intel_missing_returns_empty() -> bool:
	var store := _fresh()
	return store.get_location_intel("nowhere") == []


static func test_add_location_intel_multiple_entries() -> bool:
	var store := _fresh()
	store.add_location_intel(_make_location_intel("market", 1))
	store.add_location_intel(_make_location_intel("market", 2))
	return store.get_location_intel("market").size() == 2


# ── Relationship intel ────────────────────────────────────────────────────────

static func test_add_relationship_intel_stored() -> bool:
	var store := _fresh()
	var intel := _make_rel_intel("alice", "bob")
	store.add_relationship_intel(intel)
	return store.get_relationship_intel("alice", "bob") == intel


static func test_get_relationship_intel_symmetric_key() -> bool:
	# (A,B) and (B,A) should resolve to the same stored entry.
	var store := _fresh()
	var intel := _make_rel_intel("alice", "bob")
	store.add_relationship_intel(intel)
	return store.get_relationship_intel("bob", "alice") == intel


static func test_get_relationship_intel_missing_returns_null() -> bool:
	var store := _fresh()
	return store.get_relationship_intel("x", "y") == null


static func test_add_relationship_intel_overwrites() -> bool:
	var store := _fresh()
	var old_intel := _make_rel_intel("alice", "bob", "Alice", "Bob", 0.3)
	store.add_relationship_intel(old_intel)
	var new_intel := _make_rel_intel("alice", "bob", "Alice", "Bob", 0.8)
	store.add_relationship_intel(new_intel)
	return store.get_relationship_intel("alice", "bob") == new_intel


static func test_get_relationships_for_npc() -> bool:
	var store := _fresh()
	var ab := _make_rel_intel("alice", "bob")
	var ac := _make_rel_intel("alice", "carol")
	var bc := _make_rel_intel("bob", "carol")
	store.add_relationship_intel(ab)
	store.add_relationship_intel(ac)
	store.add_relationship_intel(bc)
	var results := store.get_relationships_for_npc("alice")
	return results.size() == 2


# ── RelationshipIntel bars and labels ─────────────────────────────────────────

static func test_relationship_bars_strong() -> bool:
	# weight > 0.60 → 3 bars, "allied"
	var intel := _make_rel_intel("a", "b", "A", "B", 0.7)
	return intel.bars() == 3


static func test_relationship_bars_moderate() -> bool:
	# weight 0.34–0.60 → 2 bars, "neutral"
	var intel := _make_rel_intel("a", "b", "A", "B", 0.5)
	return intel.bars() == 2


static func test_relationship_bars_weak() -> bool:
	# weight <= 0.33 → 1 bar, "suspicious"
	var intel := _make_rel_intel("a", "b", "A", "B", 0.2)
	return intel.bars() == 1


static func test_affinity_label_allied() -> bool:
	var intel := _make_rel_intel("a", "b", "A", "B", 0.8)
	return intel.affinity_label == "allied"


static func test_affinity_label_neutral() -> bool:
	var intel := _make_rel_intel("a", "b", "A", "B", 0.5)
	return intel.affinity_label == "neutral"


static func test_affinity_label_suspicious() -> bool:
	var intel := _make_rel_intel("a", "b", "A", "B", 0.2)
	return intel.affinity_label == "suspicious"

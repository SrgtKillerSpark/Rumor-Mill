## test_phase2_slice_e_cooldown_gaps.gd — Regression tests for Phase 2 Slice E cooldown gaps (SPA-1740).
##
## Covers acceptance tests E4 and E5 from docs/phase2-acceptance-tests.md.
## E1/E2/E3/E6 are covered by TestRumorPanelEvidenceCooldown (SPA-1717).
##
##   E4 — On Apprentice difficulty, evidence is always available — cooldown never arms after a
##         seed. Difficulty gating lives in intel_store.gd (_cooldown_days_for_difficulty
##         returns 0 for "apprentice"). Tests assert against _evidence_target_cooldown state
##         directly via get_evidence_cooldown_info(), not via UI side-effects.
##
##   E5 — Seeding a rumor WITHOUT attaching evidence does NOT trigger the cooldown (evidence
##         remains available for any target). Confirms cooldown is gated on evidence_used, not
##         on the rumor seed itself. A seed that skips start_evidence_cooldown must leave the
##         cooldown dict empty.
##
## Feature-flag aware: evidence_economy_v2 ON (set per-test via before_each pattern).
## All tests operate on plain PlayerIntelStore objects. No Godot editor/scene required.
##
## Follow the pattern in test_phase2_slice_c_shelf_life.gd (SPA-1736).
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2SliceECooldownGaps
extends RefCounted


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# E4 — Apprentice difficulty: cooldown days = 0, store stays empty
		"test_e4_apprentice_cooldown_days_is_zero",
		"test_e4_apprentice_start_cooldown_leaves_store_empty",
		"test_e4_apprentice_evidence_not_locked_for_different_target",
		"test_e4_apprentice_evidence_not_locked_for_seed_target",
		# E5 — Seeding without evidence: cooldown never arms
		"test_e5_fresh_store_has_no_cooldown",
		"test_e5_seed_without_evidence_does_not_arm_cooldown",
		"test_e5_evidence_available_for_any_target_after_evidence_free_seed",
	]

	## before_each / after_each: enable the feature flag for the duration of this
	## suite and restore it so sibling suites are not affected.
	var _saved_flag: bool = GameState.evidence_economy_v2

	for method_name in tests:
		GameState.evidence_economy_v2 = true   ## before_each equivalent
		var result: bool = call(method_name)
		GameState.evidence_economy_v2 = _saved_flag  ## after_each equivalent

		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPhase2SliceECooldownGaps tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Return a fresh PlayerIntelStore with no prior state.
static func _make_store() -> PlayerIntelStore:
	return PlayerIntelStore.new()


# ── E4: Apprentice difficulty — cooldown never arms ───────────────────────────

## E4 — _cooldown_days_for_difficulty("apprentice") must return 0 (the no-op sentinel).
## This is the root of the difficulty gate: a 0-day cooldown is a no-op in
## start_evidence_cooldown(), so the _evidence_target_cooldown dict is never written.
static func test_e4_apprentice_cooldown_days_is_zero() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var days: int = PlayerIntelStore._cooldown_days_for_difficulty("apprentice")
	if days != 0:
		push_error(
			"test_e4_apprentice_cooldown_days_is_zero: " +
			"expected 0 days for Apprentice, got %d" % days
		)
		return false
	return true


## E4 — After start_evidence_cooldown on Apprentice difficulty, _evidence_target_cooldown
## must remain empty (get_evidence_cooldown_info returns {}). The 0-day guard in
## start_evidence_cooldown() must prevent any dict entry from being written.
static func test_e4_apprentice_start_cooldown_leaves_store_empty() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "apprentice")
	var info: Dictionary = store.get_evidence_cooldown_info()
	if not info.is_empty():
		push_error(
			"test_e4_apprentice_start_cooldown_leaves_store_empty: " +
			"expected empty cooldown dict after Apprentice seed, got %s" % str(info)
		)
		return false
	return true


## E4 — is_evidence_locked_for_target must return false for a DIFFERENT NPC after an
## Apprentice-difficulty seed. On Normal+ this same call would return true.
static func test_e4_apprentice_evidence_not_locked_for_different_target() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "apprentice")
	if store.is_evidence_locked_for_target("npc_b"):
		push_error(
			"test_e4_apprentice_evidence_not_locked_for_different_target: " +
			"npc_b should NOT be locked on Apprentice difficulty"
		)
		return false
	return true


## E4 — is_evidence_locked_for_target must also return false for the seed target itself
## (npc_a) after an Apprentice seed. Cooldown is a no-op so no entry exists at all.
static func test_e4_apprentice_evidence_not_locked_for_seed_target() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "apprentice")
	if store.is_evidence_locked_for_target("npc_a"):
		push_error(
			"test_e4_apprentice_evidence_not_locked_for_seed_target: " +
			"npc_a (seed target) should NOT be locked on Apprentice difficulty"
		)
		return false
	return true


# ── E5: Seeding without evidence — cooldown never arms ────────────────────────

## E5 baseline — A freshly created PlayerIntelStore must have no active cooldown.
## Confirms that start_evidence_cooldown is never called during construction.
static func test_e5_fresh_store_has_no_cooldown() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var store := _make_store()
	var info: Dictionary = store.get_evidence_cooldown_info()
	if not info.is_empty():
		push_error(
			"test_e5_fresh_store_has_no_cooldown: " +
			"new PlayerIntelStore must start with no active cooldown, got %s" % str(info)
		)
		return false
	return true


## E5 — Simulating a rumor seed WITHOUT evidence (i.e. NOT calling start_evidence_cooldown)
## must leave the cooldown dict empty. This verifies the protocol: the cooldown is gated
## on evidence_used, not on the rumor seed itself.
## Modelled after the world.gd seed path: spend an action, skip start_evidence_cooldown.
static func test_e5_seed_without_evidence_does_not_arm_cooldown() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var store := _make_store()
	## Simulate an evidence-free rumor seed: consume one recon action but do NOT
	## call start_evidence_cooldown (no evidence was attached).
	store.try_spend_action()
	var info: Dictionary = store.get_evidence_cooldown_info()
	if not info.is_empty():
		push_error(
			"test_e5_seed_without_evidence_does_not_arm_cooldown: " +
			"evidence-free seed must not arm a cooldown, got %s" % str(info)
		)
		return false
	return true


## E5 — After an evidence-free seed, evidence remains available for any target:
## is_evidence_locked_for_target returns false for both the implicit seed target
## and an unrelated NPC.
static func test_e5_evidence_available_for_any_target_after_evidence_free_seed() -> bool:
	if not GameState.evidence_economy_v2:
		return true
	var store := _make_store()
	## Evidence-free seed targeting npc_a — no start_evidence_cooldown call.
	store.try_spend_action()
	if store.is_evidence_locked_for_target("npc_a"):
		push_error(
			"test_e5_evidence_available_for_any_target_after_evidence_free_seed: " +
			"npc_a should not be locked after an evidence-free seed"
		)
		return false
	if store.is_evidence_locked_for_target("npc_b"):
		push_error(
			"test_e5_evidence_available_for_any_target_after_evidence_free_seed: " +
			"npc_b should not be locked after an evidence-free seed"
		)
		return false
	return true

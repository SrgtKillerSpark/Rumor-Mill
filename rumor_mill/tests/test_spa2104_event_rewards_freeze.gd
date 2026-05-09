## test_spa2104_event_rewards_freeze.gd — Regression tests for SPA-2104.
##
## Covers the heat-freeze mechanism added to PlayerIntelStore and the three new
## effect keys added to MidGameEventAgent._apply_effects():
##
##   Section 1 — PlayerIntelStore heat freeze (7 tests):
##     F1  apply_heat_freeze(N) sets heat_freeze_days = N
##     F2  add_heat() is a no-op while heat_freeze_days > 0
##     F3  decay_heat() decrements heat_freeze_days when frozen
##     F4  heat values are unchanged by decay_heat() during freeze
##     F5  add_heat() resumes normally once freeze expires
##     F6  decay_heat() resumes normal heat reduction once freeze expires
##     F7  apply_heat_freeze stacks: (2) + (1) → heat_freeze_days == 3
##
##   Section 2 — MidGameEventAgent._apply_effects() new keys (4 tests):
##     E1  suspicionFreezeDays: N → intel_store.apply_heat_freeze(N) called
##     E2  bonusWhisperTokens: N → intel_store.whisper_tokens_remaining += N
##     E3  grantRandomEvidence: N → intel_store.add_evidence called N times
##     E4  all three keys composable in a single effects dict
##
## Mutation sensitivity:
##   Removing the heat_freeze_days guard in add_heat() breaks F2 and E1.
##   Removing the freeze tick in decay_heat() breaks F3/F4/F5/F6.
##   Removing additive stacking in apply_heat_freeze() breaks F7.
##   Removing the suspicionFreezeDays branch in _apply_effects() breaks E1/E4.
##   Removing the bonusWhisperTokens branch breaks E2/E4.
##   Removing the grantRandomEvidence branch breaks E3/E4.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2104EventRewardsFreeze
extends RefCounted


# ── Mock objects (used by Section 2 only) ────────────────────────────────────

class MockIntelStore extends RefCounted:
	var freeze_calls: Array = []          # records days passed to apply_heat_freeze
	var whisper_tokens_remaining: int = 0
	var evidence_calls: Array = []        # records items passed to add_evidence

	func apply_heat_freeze(days: int) -> void:
		freeze_calls.append(days)

	func add_evidence(item) -> void:
		evidence_calls.append(item)


## Extends Node to satisfy MidGameEventAgent.tick(world: Node) type constraint.
class MockWorld extends Node:
	var reputation_system = null
	var intel_store = null
	var npcs: Array = []
	var day_night = null
	var scenario_manager = null
	func inject_rumor(_npc_id, _claim_type, _intensity, _subject_id, _source) -> void:
		pass


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_agent() -> MidGameEventAgent:
	return MidGameEventAgent.new()


## Event dict with probability 1.0 and a single choice bearing the given effects.
static func _make_event_with_effects(ev_id: String, effects: Dictionary) -> Dictionary:
	return {
		"id":             ev_id,
		"dayWindowStart": 1,
		"dayWindowEnd":   20,
		"probability":    1.0,
		"choices": [
			{"outcomeText": "Outcome", "effects": effects},
		],
	}


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Section 1: PlayerIntelStore heat freeze
		"test_f1_apply_heat_freeze_sets_days",
		"test_f2_add_heat_noop_during_freeze",
		"test_f3_decay_heat_decrements_freeze_days",
		"test_f4_heat_unchanged_by_decay_during_freeze",
		"test_f5_add_heat_resumes_after_freeze",
		"test_f6_decay_heat_resumes_after_freeze",
		"test_f7_apply_heat_freeze_stacks",
		# Section 2: MidGameEventAgent._apply_effects() new keys
		"test_e1_suspicion_freeze_days_calls_apply_heat_freeze",
		"test_e2_bonus_whisper_tokens_increments_remaining",
		"test_e3_grant_random_evidence_calls_add_evidence",
		"test_e4_all_three_keys_composable",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Section 1 — PlayerIntelStore heat freeze
# ══════════════════════════════════════════════════════════════════════════════

## F1: apply_heat_freeze(N) sets heat_freeze_days to N.
func test_f1_apply_heat_freeze_sets_days() -> bool:
	var store := PlayerIntelStore.new()
	store.apply_heat_freeze(4)
	return store.heat_freeze_days == 4


## F2: add_heat() is a no-op while heat_freeze_days > 0.
func test_f2_add_heat_noop_during_freeze() -> bool:
	var store := PlayerIntelStore.new()
	store.heat_enabled = true
	store.apply_heat_freeze(2)
	store.add_heat("npc_a", 30.0)
	return store.get_heat("npc_a") == 0.0


## F3: decay_heat() decrements heat_freeze_days by 1 when frozen.
func test_f3_decay_heat_decrements_freeze_days() -> bool:
	var store := PlayerIntelStore.new()
	store.heat_enabled = true
	store.apply_heat_freeze(3)
	store.decay_heat()
	return store.heat_freeze_days == 2


## F4: heat values are not changed by decay_heat() while the freeze is active.
func test_f4_heat_unchanged_by_decay_during_freeze() -> bool:
	var store := PlayerIntelStore.new()
	store.heat_enabled = true
	# Seed heat directly — bypass the freeze guard by setting it in the dict.
	store.heat["npc_b"] = 40.0
	store.apply_heat_freeze(1)
	store.decay_heat()
	return absf(store.get_heat("npc_b") - 40.0) < 0.001


## F5: add_heat() resumes normally once heat_freeze_days reaches 0.
func test_f5_add_heat_resumes_after_freeze() -> bool:
	var store := PlayerIntelStore.new()
	store.heat_enabled = true
	store.apply_heat_freeze(1)
	store.decay_heat()           # freeze_days: 1 → 0
	if store.heat_freeze_days != 0:
		push_error("test_f5: freeze_days should be 0 after one decay, got %d" % store.heat_freeze_days)
		return false
	store.add_heat("npc_c", 20.0)
	return absf(store.get_heat("npc_c") - 20.0) < 0.001


## F6: decay_heat() resumes normal heat reduction once heat_freeze_days reaches 0.
func test_f6_decay_heat_resumes_after_freeze() -> bool:
	var store := PlayerIntelStore.new()
	store.heat_enabled = true
	store.heat["npc_d"] = 50.0
	store.apply_heat_freeze(1)
	store.decay_heat()           # freeze_days: 1 → 0; heat unchanged
	store.decay_heat()           # now applies real decay (default 6.0/day)
	return store.get_heat("npc_d") < 50.0


## F7: apply_heat_freeze stacks additively: (2) + (1) → heat_freeze_days == 3.
func test_f7_apply_heat_freeze_stacks() -> bool:
	var store := PlayerIntelStore.new()
	store.apply_heat_freeze(2)
	store.apply_heat_freeze(1)
	return store.heat_freeze_days == 3


# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — MidGameEventAgent._apply_effects() new keys
# ══════════════════════════════════════════════════════════════════════════════

## E1: suspicionFreezeDays: N calls intel_store.apply_heat_freeze(N).
func test_e1_suspicion_freeze_days_calls_apply_heat_freeze() -> bool:
	var agent := _make_agent()
	agent.activate()
	var mock_intel := MockIntelStore.new()
	var mock_world := MockWorld.new()
	mock_world.intel_store = mock_intel

	var ev := _make_event_with_effects("ev_freeze", {"suspicionFreezeDays": 3})
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_freeze", 0)

	if mock_intel.freeze_calls.size() != 1:
		push_error("test_e1: expected 1 apply_heat_freeze call, got %d" % mock_intel.freeze_calls.size())
		return false
	return mock_intel.freeze_calls[0] == 3


## E2: bonusWhisperTokens: N adds N to intel_store.whisper_tokens_remaining.
func test_e2_bonus_whisper_tokens_increments_remaining() -> bool:
	var agent := _make_agent()
	agent.activate()
	var mock_intel := MockIntelStore.new()
	mock_intel.whisper_tokens_remaining = 1
	var mock_world := MockWorld.new()
	mock_world.intel_store = mock_intel

	var ev := _make_event_with_effects("ev_whisper", {"bonusWhisperTokens": 2})
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_whisper", 0)

	return mock_intel.whisper_tokens_remaining == 3


## E3: grantRandomEvidence: N calls intel_store.add_evidence exactly N times.
func test_e3_grant_random_evidence_calls_add_evidence() -> bool:
	var agent := _make_agent()
	agent.activate()
	var mock_intel := MockIntelStore.new()
	var mock_world := MockWorld.new()
	mock_world.intel_store = mock_intel

	var ev := _make_event_with_effects("ev_evidence", {"grantRandomEvidence": 2})
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_evidence", 0)

	return mock_intel.evidence_calls.size() == 2


## E4: all three new keys are independent and composable in a single effects dict.
func test_e4_all_three_keys_composable() -> bool:
	var agent := _make_agent()
	agent.activate()
	var mock_intel := MockIntelStore.new()
	mock_intel.whisper_tokens_remaining = 0
	var mock_world := MockWorld.new()
	mock_world.intel_store = mock_intel

	var ev := _make_event_with_effects("ev_all", {
		"suspicionFreezeDays": 2,
		"bonusWhisperTokens":  3,
		"grantRandomEvidence": 1,
	})
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_all", 0)

	var freeze_ok: bool = mock_intel.freeze_calls.size() == 1 and mock_intel.freeze_calls[0] == 2
	var whisper_ok: bool = mock_intel.whisper_tokens_remaining == 3
	var evidence_ok: bool = mock_intel.evidence_calls.size() == 1

	if not freeze_ok:
		push_error("test_e4: suspicionFreezeDays: freeze_calls=%s" % str(mock_intel.freeze_calls))
	if not whisper_ok:
		push_error("test_e4: bonusWhisperTokens: expected 3, got %d" % mock_intel.whisper_tokens_remaining)
	if not evidence_ok:
		push_error("test_e4: grantRandomEvidence: expected 1 call, got %d" % mock_intel.evidence_calls.size())

	return freeze_ok and whisper_ok and evidence_ok

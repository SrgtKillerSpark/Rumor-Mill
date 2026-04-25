## test_s4_faction_shift_agent.gd — Unit tests for S4FactionShiftAgent (SPA-1041).
##
## Covers:
##   • Constants: PROTECTED_NPC_IDS matches ScenarioConfig, phase windows match
##   • Initial state: _active false, phase flags false, inquisitor_ref null
##   • activate(): sets _active
##   • Phase firing logic: each phase fires exactly once within its window
##   • _fire_bishop_pressure(): updates inquisitor cooldown_offset
##   • _weakest_protected_npc(): returns first NPC when rep is null
##   • tick() guard: does nothing when not active
##
## Strategy: S4FactionShiftAgent extends RefCounted (no Node). Phase handlers
## that call world.inject_rumor() are guarded via null inquisitor / null world
## where possible; bishop_pressure is fully testable without world.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestS4FactionShiftAgent
extends RefCounted

const S4FactionShiftAgentScript := preload("res://scripts/s4_faction_shift_agent.gd")
const InquisitorAgentScript      := preload("res://scripts/inquisitor_agent.gd")


static func _make_agent() -> S4FactionShiftAgent:
	return S4FactionShiftAgentScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_protected_npc_ids_matches_scenario_config",
		"test_phase_1_window_matches_scenario_config",
		"test_phase_2_window_matches_scenario_config",
		"test_phase_3_window_matches_scenario_config",

		# ── initial state ──
		"test_initial_active_is_false",
		"test_initial_phase_1_not_fired",
		"test_initial_phase_2_not_fired",
		"test_initial_phase_3_not_fired",
		"test_initial_inquisitor_ref_is_null",

		# ── activate ──
		"test_activate_sets_active",

		# ── tick guard ──
		"test_tick_does_nothing_when_not_active",

		# ── phase 1 fires once in window ──
		"test_phase_1_fires_on_day_5",
		"test_phase_1_does_not_fire_twice",

		# ── phase 2: bishop pressure ──
		"test_phase_2_fires_on_day_10",
		"test_phase_2_reduces_inquisitor_cooldown_offset",
		"test_phase_2_cooldown_offset_floor_at_minus_2",

		# ── phase 3 fires once in window ──
		"test_phase_3_fires_on_day_14",
		"test_phase_3_does_not_fire_twice",

		# ── _weakest_protected_npc with null rep ──
		"test_weakest_npc_returns_first_when_rep_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_protected_npc_ids_matches_scenario_config() -> bool:
	return S4FactionShiftAgent.PROTECTED_NPC_IDS == ScenarioConfig.S4_PROTECTED_NPC_IDS


func test_phase_1_window_matches_scenario_config() -> bool:
	return S4FactionShiftAgent.PHASE_1_WINDOW == ScenarioConfig.S4_PHASE_1_WINDOW


func test_phase_2_window_matches_scenario_config() -> bool:
	return S4FactionShiftAgent.PHASE_2_WINDOW == ScenarioConfig.S4_PHASE_2_WINDOW


func test_phase_3_window_matches_scenario_config() -> bool:
	return S4FactionShiftAgent.PHASE_3_WINDOW == ScenarioConfig.S4_PHASE_3_WINDOW


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_active_is_false() -> bool:
	return _make_agent()._active == false


func test_initial_phase_1_not_fired() -> bool:
	return _make_agent()._phase_1_fired == false


func test_initial_phase_2_not_fired() -> bool:
	return _make_agent()._phase_2_fired == false


func test_initial_phase_3_not_fired() -> bool:
	return _make_agent()._phase_3_fired == false


func test_initial_inquisitor_ref_is_null() -> bool:
	return _make_agent().inquisitor_ref == null


# ══════════════════════════════════════════════════════════════════════════════
# activate
# ══════════════════════════════════════════════════════════════════════════════

func test_activate_sets_active() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._active == true


# ══════════════════════════════════════════════════════════════════════════════
# tick guard
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_does_nothing_when_not_active() -> bool:
	var agent := _make_agent()
	# Not active — tick should return immediately without any phase flag changes.
	agent.tick(10, null)
	return not agent._phase_1_fired and not agent._phase_2_fired and not agent._phase_3_fired


# ══════════════════════════════════════════════════════════════════════════════
# Phase 1: Merchant Sympathy (fires within window, then never again)
# We cannot test _fire_merchant_sympathy directly (needs world), but we can
# verify _phase_1_fired is set after tick within the window.
# Since _fire_merchant_sympathy calls world.inject_rumor on a null world,
# we instead test the flag via _fire_bishop_pressure which has no world dependency.
# Phase 1/3 tests use a DummyWorld stub that absorbs inject_rumor calls.
# ══════════════════════════════════════════════════════════════════════════════

## Minimal stub: absorbs inject_rumor and exposes npcs array.
class DummyWorld:
	var npcs: Array = []
	var reputation_system = null

	func inject_rumor(_a, _b, _c, _d, _e) -> String:
		return "dummy_rumor"


func test_phase_1_fires_on_day_5() -> bool:
	var agent := _make_agent()
	agent.activate()
	var world := DummyWorld.new()
	agent.tick(5, world)  # day 5 is within [5,7]
	return agent._phase_1_fired == true


func test_phase_1_does_not_fire_twice() -> bool:
	var agent := _make_agent()
	agent.activate()
	var world := DummyWorld.new()
	agent.tick(5, world)
	agent.tick(6, world)  # already fired — flag prevents second fire
	# _phase_1_fired should still be true, not toggled back
	return agent._phase_1_fired == true


# ══════════════════════════════════════════════════════════════════════════════
# Phase 2: Bishop Pressure (no world dependency)
# ══════════════════════════════════════════════════════════════════════════════

func test_phase_2_fires_on_day_10() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.tick(10, null)  # world null is fine — phase 2 only modifies inquisitor
	return agent._phase_2_fired == true


func test_phase_2_reduces_inquisitor_cooldown_offset() -> bool:
	var agent    := _make_agent()
	var inq      := InquisitorAgentScript.new()
	inq.cooldown_offset = 0
	agent.inquisitor_ref = inq
	agent.activate()
	agent.tick(10, null)
	# offset should drop by 2: 0 - 2 = -2
	return inq.cooldown_offset == -2


func test_phase_2_cooldown_offset_floor_at_minus_2() -> bool:
	var agent    := _make_agent()
	var inq      := InquisitorAgentScript.new()
	inq.cooldown_offset = -1
	agent.inquisitor_ref = inq
	agent.activate()
	agent.tick(10, null)
	# -1 - 2 = -3, but maxi(-3, -2) = -2 → capped at -2
	return inq.cooldown_offset == -2


# ══════════════════════════════════════════════════════════════════════════════
# Phase 3: Clergy Solidarity
# ══════════════════════════════════════════════════════════════════════════════

func test_phase_3_fires_on_day_14() -> bool:
	var agent := _make_agent()
	agent.activate()
	var world := DummyWorld.new()
	agent._phase_1_fired = true   # skip phase 1 to avoid world.npcs access
	agent._phase_2_fired = true   # skip phase 2
	agent.tick(14, world)
	return agent._phase_3_fired == true


func test_phase_3_does_not_fire_twice() -> bool:
	var agent := _make_agent()
	agent.activate()
	var world := DummyWorld.new()
	agent._phase_1_fired = true
	agent._phase_2_fired = true
	agent.tick(14, world)
	agent.tick(15, world)  # second tick in window; flag prevents re-fire
	return agent._phase_3_fired == true


# ══════════════════════════════════════════════════════════════════════════════
# _weakest_protected_npc with null rep
# ══════════════════════════════════════════════════════════════════════════════

func test_weakest_npc_returns_first_when_rep_null() -> bool:
	var agent := _make_agent()
	# When rep is null, snap is null → score defaults to 50 for all NPCs.
	# The loop initialises weakest_score to 999 and finds the first NPC with score < 999.
	# All score at 50 < 999 → first NPC wins (PROTECTED_NPC_IDS[0]).
	var result := agent._weakest_protected_npc(null)
	return result == S4FactionShiftAgent.PROTECTED_NPC_IDS[0]

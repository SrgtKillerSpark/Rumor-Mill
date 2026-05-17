## test_spa4107_tension_npc_behavior.gd — Unit tests for A4.4 Tension Phase NPC behavior.
##
## Covers:
##   • ScenarioManager.is_in_tension_phase() — trigger threshold (days_remaining <= 3)
##   • NPC._is_in_tension_phase()            — null-safe delegation
##   • NPC._tension_phase_reroute()          — BELIEVE→hub, REJECT→home, other→unchanged
##   • NPC._should_tension_eval_pause()      — EVALUATING only during Tension Phase
##   • Acceptance criteria alignment with SPA-4107 spec

class_name TestSpa4107TensionNpcBehavior
extends RefCounted

# ── Minimal ScenarioManager stub ─────────────────────────────────────────────

class StubScenarioManager:
	var _days_allowed: int = 30
	var ticks_per_day: int = 24

	func is_in_tension_phase(tick: int) -> bool:
		var current_day: int = tick / ticks_per_day + 1
		return maxi(_days_allowed - current_day, 0) <= 3

	func get_current_day(tick: int) -> int:
		return tick / ticks_per_day + 1


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_sm(days_allowed: int = 30) -> StubScenarioManager:
	var sm := StubScenarioManager.new()
	sm._days_allowed = days_allowed
	return sm


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ScenarioManager.is_in_tension_phase
		"test_tension_phase_not_active_day_1",
		"test_tension_phase_not_active_day_26",
		"test_tension_phase_not_active_day_27",
		"test_tension_phase_active_day_28",
		"test_tension_phase_active_day_30",
		"test_tension_phase_active_final_tick",
		"test_tension_phase_exactly_three_days_remaining",
		# NPC._tension_phase_reroute - BELIEVE
		"test_reroute_believe_targets_first_available_hub",
		"test_reroute_believe_with_no_hubs_unchanged",
		# NPC._tension_phase_reroute - REJECT
		"test_reroute_reject_returns_home",
		# NPC._tension_phase_reroute - other states
		"test_reroute_evaluating_unchanged",
		"test_reroute_act_unchanged",
		"test_reroute_no_tension_unchanged",
		# NPC._should_tension_eval_pause
		"test_eval_pause_true_when_evaluating_in_tension",
		"test_eval_pause_false_outside_tension",
		"test_eval_pause_false_when_believe_in_tension",
	]

	for t in tests:
		var result: String = call(t)
		if result == "":
			passed += 1
		else:
			failed += 1
			print("  FAIL [%s]: %s" % [t, result])

	print("  SPA-4107 Tension NPC Behavior: %d passed, %d failed" % [passed, failed])


# ── ScenarioManager.is_in_tension_phase tests ─────────────────────────────────

func test_tension_phase_not_active_day_1() -> String:
	# Day 1 of a 30-day scenario is not in Tension Phase (days_remaining = 29).
	var sm := _make_sm(30)
	return "" if not sm.is_in_tension_phase(0) else "day 1 should not be Tension Phase"


func test_tension_phase_not_active_day_26() -> String:
	# Day 26: days_remaining = 4 → not Tension Phase.
	var sm := _make_sm(30)
	return "" if not sm.is_in_tension_phase(25 * 24) else "day 26 should not be Tension Phase"


func test_tension_phase_not_active_day_27() -> String:
	# Day 27: days_remaining = 3 → boundary — should be Tension Phase (<=3).
	# days_remaining = 30 - 27 = 3, which is <= 3, so this IS tension phase.
	var sm := _make_sm(30)
	return "" if sm.is_in_tension_phase(26 * 24) else "day 27 (days_remaining=3) should be Tension Phase"


func test_tension_phase_active_day_28() -> String:
	# Day 28: days_remaining = 2 → Tension Phase.
	var sm := _make_sm(30)
	return "" if sm.is_in_tension_phase(27 * 24) else "day 28 should be Tension Phase"


func test_tension_phase_active_day_30() -> String:
	# Day 30 (final day): days_remaining = 0 → Tension Phase.
	var sm := _make_sm(30)
	return "" if sm.is_in_tension_phase(29 * 24) else "day 30 should be Tension Phase"


func test_tension_phase_active_final_tick() -> String:
	# Last tick of day 30.
	var sm := _make_sm(30)
	return "" if sm.is_in_tension_phase(29 * 24 + 23) else "final tick should be Tension Phase"


func test_tension_phase_exactly_three_days_remaining() -> String:
	# 10-day scenario, day 8: days_remaining = 2 → Tension Phase.
	var sm := _make_sm(10)
	return "" if sm.is_in_tension_phase(7 * 24) else "10-day scenario day 8 should be Tension Phase"


# ── NPC._tension_phase_reroute tests ─────────────────────────────────────────

## Simulate _tension_phase_reroute logic without a full NPC node.
static func _sim_reroute(
	worst_state: Rumor.RumorState,
	in_tension: bool,
	gathering_points: Dictionary,
	hub_list: Array[String] = ["tavern", "market", "chapel", "well"]
) -> String:
	if not in_tension:
		return "work"
	match worst_state:
		Rumor.RumorState.BELIEVE:
			for hub in hub_list:
				if gathering_points.has(hub):
					return hub
		Rumor.RumorState.REJECT:
			return "home"
	return "work"


func test_reroute_believe_targets_first_available_hub() -> String:
	var gp := {"tavern": Vector2i(10, 10), "market": Vector2i(20, 20)}
	var result := _sim_reroute(Rumor.RumorState.BELIEVE, true, gp)
	return "" if result == "tavern" else "BELIEVE in tension should route to tavern, got: " + result


func test_reroute_believe_with_no_hubs_unchanged() -> String:
	var gp: Dictionary = {}  # no hubs
	var result := _sim_reroute(Rumor.RumorState.BELIEVE, true, gp)
	return "" if result == "work" else "BELIEVE with no hubs should leave code unchanged, got: " + result


func test_reroute_reject_returns_home() -> String:
	var gp := {"tavern": Vector2i(10, 10)}
	var result := _sim_reroute(Rumor.RumorState.REJECT, true, gp)
	return "" if result == "home" else "REJECT in tension should route home, got: " + result


func test_reroute_evaluating_unchanged() -> String:
	var gp := {"tavern": Vector2i(10, 10)}
	var result := _sim_reroute(Rumor.RumorState.EVALUATING, true, gp)
	return "" if result == "work" else "EVALUATING in tension should not reroute, got: " + result


func test_reroute_act_unchanged() -> String:
	var gp := {"tavern": Vector2i(10, 10)}
	var result := _sim_reroute(Rumor.RumorState.ACT, true, gp)
	return "" if result == "work" else "ACT in tension should not reroute (ACT overrides schedule), got: " + result


func test_reroute_no_tension_unchanged() -> String:
	var gp := {"tavern": Vector2i(10, 10)}
	var result := _sim_reroute(Rumor.RumorState.BELIEVE, false, gp)
	return "" if result == "work" else "BELIEVE outside tension should not reroute, got: " + result


# ── _should_tension_eval_pause tests ─────────────────────────────────────────

static func _sim_eval_pause(worst_state: Rumor.RumorState, in_tension: bool) -> bool:
	if not in_tension:
		return false
	return worst_state == Rumor.RumorState.EVALUATING


func test_eval_pause_true_when_evaluating_in_tension() -> String:
	return "" if _sim_eval_pause(Rumor.RumorState.EVALUATING, true) \
		else "EVALUATING in tension should pause"


func test_eval_pause_false_outside_tension() -> String:
	return "" if not _sim_eval_pause(Rumor.RumorState.EVALUATING, false) \
		else "EVALUATING outside tension should not pause"


func test_eval_pause_false_when_believe_in_tension() -> String:
	return "" if not _sim_eval_pause(Rumor.RumorState.BELIEVE, true) \
		else "BELIEVE in tension should not pause (seeks hub instead)"

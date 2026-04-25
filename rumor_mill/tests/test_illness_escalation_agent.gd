## test_illness_escalation_agent.gd — Unit tests for IllnessEscalationAgent (SPA-1041).
##
## Covers:
##   • Constants: ALYS_HERBWIFE_ID, MAREN_NUN_ID
##   • Initial state: _active false, _last_seed_day 0, cooldown_offset 0
##   • activate(): sets _active, resets _last_seed_day
##   • _get_cooldown(): early (≤6→6), mid (7-13→3), late (>13→2), cooldown_offset, floor
##   • tick() guard clauses: inactive; within cooldown (null world never reached)
##
## Strategy: IllnessEscalationAgent extends RefCounted (no Node).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestIllnessEscalationAgent
extends RefCounted

const IllnessEscalationAgentScript := preload("res://scripts/illness_escalation_agent.gd")


static func _make_agent() -> IllnessEscalationAgent:
	return IllnessEscalationAgentScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_alys_id_constant",
		"test_maren_id_constant",

		# ── initial state ──
		"test_initial_active_is_false",
		"test_initial_last_seed_day_is_zero",
		"test_initial_cooldown_offset_is_zero",

		# ── activate ──
		"test_activate_sets_active",
		"test_activate_resets_last_seed_day",

		# ── _get_cooldown ──
		"test_cooldown_day1_is_6",
		"test_cooldown_day6_is_6",
		"test_cooldown_day7_is_3",
		"test_cooldown_day13_is_3",
		"test_cooldown_day14_is_2",
		"test_cooldown_day20_is_2",
		"test_cooldown_with_positive_offset",
		"test_cooldown_with_negative_offset",
		"test_cooldown_minimum_is_1",

		# ── tick guard clauses ──
		"test_tick_does_nothing_when_not_active",
		"test_tick_does_nothing_within_cooldown",
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

func test_alys_id_constant() -> bool:
	return IllnessEscalationAgent.ALYS_HERBWIFE_ID == "alys_herbwife"


func test_maren_id_constant() -> bool:
	return IllnessEscalationAgent.MAREN_NUN_ID == "maren_nun"


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_active_is_false() -> bool:
	var agent := _make_agent()
	return agent._active == false


func test_initial_last_seed_day_is_zero() -> bool:
	var agent := _make_agent()
	return agent._last_seed_day == 0


func test_initial_cooldown_offset_is_zero() -> bool:
	var agent := _make_agent()
	return agent.cooldown_offset == 0


# ══════════════════════════════════════════════════════════════════════════════
# activate
# ══════════════════════════════════════════════════════════════════════════════

func test_activate_sets_active() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._active == true


func test_activate_resets_last_seed_day() -> bool:
	var agent := _make_agent()
	agent._last_seed_day = 7
	agent.activate()
	return agent._last_seed_day == 0


# ══════════════════════════════════════════════════════════════════════════════
# _get_cooldown
# ══════════════════════════════════════════════════════════════════════════════

func test_cooldown_day1_is_6() -> bool:
	var agent := _make_agent()
	return agent._get_cooldown(1) == 6


func test_cooldown_day6_is_6() -> bool:
	var agent := _make_agent()
	return agent._get_cooldown(6) == 6


func test_cooldown_day7_is_3() -> bool:
	var agent := _make_agent()
	return agent._get_cooldown(7) == 3


func test_cooldown_day13_is_3() -> bool:
	var agent := _make_agent()
	return agent._get_cooldown(13) == 3


func test_cooldown_day14_is_2() -> bool:
	var agent := _make_agent()
	return agent._get_cooldown(14) == 2


func test_cooldown_day20_is_2() -> bool:
	var agent := _make_agent()
	return agent._get_cooldown(20) == 2


func test_cooldown_with_positive_offset() -> bool:
	var agent := _make_agent()
	agent.cooldown_offset = 2
	# early: 6+2 = 8
	return agent._get_cooldown(1) == 8


func test_cooldown_with_negative_offset() -> bool:
	var agent := _make_agent()
	agent.cooldown_offset = -1
	# mid: 3-1 = 2
	return agent._get_cooldown(7) == 2


func test_cooldown_minimum_is_1() -> bool:
	var agent := _make_agent()
	agent.cooldown_offset = -99
	return agent._get_cooldown(14) >= 1


# ══════════════════════════════════════════════════════════════════════════════
# tick guard clauses
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_does_nothing_when_not_active() -> bool:
	var agent := _make_agent()
	# _active false → returns immediately, _last_seed_day unchanged
	agent.tick(1, null)
	return agent._last_seed_day == 0


func test_tick_does_nothing_within_cooldown() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 1   # seeded on day 1
	# day 5: gap=4 < cooldown(5)=6 → guard fires before _seed_illness_rumor
	agent.tick(5, null)
	return agent._last_seed_day == 1   # unchanged

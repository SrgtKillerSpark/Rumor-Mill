## test_rival_agent.gd — Unit tests for RivalAgent pure state and cooldown logic (SPA-1041).
##
## Covers:
##   • Initial state: _active false, charges at max, degrade target empty
##   • activate(): resets all fields
##   • Constants: MAX_DISRUPT_CHARGES, DISRUPTION_COOLDOWN_BONUS, _DEGRADE_MAP size
##   • _get_cooldown(): correct values for day ranges 1-7, 8-17, 18+
##   • _get_cooldown(): cooldown_offset applied; disruption bonus applied; floor at 1
##   • can_be_disrupted(): all four blocking conditions
##   • apply_disruption(): refuses when cannot; sets days; consumes charge
##   • scout_next_target(): returns "" when not active
##   • get_scouted_target(): returns _next_degrade_target_id
##   • _DEGRADE_MAP entries
##
## Strategy: RivalAgent extends RefCounted (no Node). All methods tested without world.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRivalAgent
extends RefCounted

const RivalAgentScript := preload("res://scripts/rival_agent.gd")


static func _make_agent() -> RivalAgent:
	return RivalAgentScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── initial state ──
		"test_initial_active_is_false",
		"test_initial_last_seed_day_is_zero",
		"test_initial_charges_at_max",
		"test_initial_disruption_days_zero",
		"test_initial_next_degrade_target_empty",
		"test_initial_last_action_description_empty",

		# ── constants ──
		"test_max_disrupt_charges_is_3",
		"test_disruption_cooldown_bonus_is_3",
		"test_degrade_map_has_3_entries",
		"test_degrade_map_act_to_spread",
		"test_degrade_map_spread_to_believe",
		"test_degrade_map_believe_to_evaluating",

		# ── activate ──
		"test_activate_sets_active",
		"test_activate_resets_last_seed_day",
		"test_activate_resets_charges_to_max",
		"test_activate_clears_disruption_days",
		"test_activate_clears_next_degrade_target",

		# ── _get_cooldown ──
		"test_cooldown_early_game_day1_is_4",
		"test_cooldown_early_game_day7_is_4",
		"test_cooldown_mid_game_day8_is_2",
		"test_cooldown_mid_game_day17_is_2",
		"test_cooldown_late_game_day18_is_1",
		"test_cooldown_late_game_day25_is_1",
		"test_cooldown_offset_slows_rival",
		"test_cooldown_offset_speeds_rival",
		"test_cooldown_disruption_adds_bonus",
		"test_cooldown_minimum_is_1",

		# ── can_be_disrupted ──
		"test_cannot_disrupt_when_not_active",
		"test_cannot_disrupt_before_first_seed",
		"test_cannot_disrupt_when_disruption_already_active",
		"test_cannot_disrupt_when_no_charges_remain",
		"test_can_disrupt_when_all_conditions_met",

		# ── apply_disruption ──
		"test_apply_disruption_returns_false_when_cannot",
		"test_apply_disruption_returns_true_on_success",
		"test_apply_disruption_sets_remaining_days",
		"test_apply_disruption_decrements_charges",

		# ── scouting ──
		"test_scout_next_target_returns_empty_when_inactive",
		"test_get_scouted_target_reflects_degrade_target",
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
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_active_is_false() -> bool:
	var agent := _make_agent()
	return agent._active == false


func test_initial_last_seed_day_is_zero() -> bool:
	var agent := _make_agent()
	return agent._last_seed_day == 0


func test_initial_charges_at_max() -> bool:
	var agent := _make_agent()
	return agent.disrupt_charges_remaining == RivalAgent.MAX_DISRUPT_CHARGES


func test_initial_disruption_days_zero() -> bool:
	var agent := _make_agent()
	return agent._disruption_days_remaining == 0


func test_initial_next_degrade_target_empty() -> bool:
	var agent := _make_agent()
	return agent._next_degrade_target_id == ""


func test_initial_last_action_description_empty() -> bool:
	var agent := _make_agent()
	return agent.last_action_description == ""


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_max_disrupt_charges_is_3() -> bool:
	return RivalAgent.MAX_DISRUPT_CHARGES == 3


func test_disruption_cooldown_bonus_is_3() -> bool:
	return RivalAgent.DISRUPTION_COOLDOWN_BONUS == 3


func test_degrade_map_has_3_entries() -> bool:
	return RivalAgent._DEGRADE_MAP.size() == 3


func test_degrade_map_act_to_spread() -> bool:
	return RivalAgent._DEGRADE_MAP.get(Rumor.RumorState.ACT) == Rumor.RumorState.SPREAD


func test_degrade_map_spread_to_believe() -> bool:
	return RivalAgent._DEGRADE_MAP.get(Rumor.RumorState.SPREAD) == Rumor.RumorState.BELIEVE


func test_degrade_map_believe_to_evaluating() -> bool:
	return RivalAgent._DEGRADE_MAP.get(Rumor.RumorState.BELIEVE) == Rumor.RumorState.EVALUATING


# ══════════════════════════════════════════════════════════════════════════════
# activate
# ══════════════════════════════════════════════════════════════════════════════

func test_activate_sets_active() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._active == true


func test_activate_resets_last_seed_day() -> bool:
	var agent := _make_agent()
	agent._last_seed_day = 10
	agent.activate()
	return agent._last_seed_day == 0


func test_activate_resets_charges_to_max() -> bool:
	var agent := _make_agent()
	agent.disrupt_charges_remaining = 0
	agent.activate()
	return agent.disrupt_charges_remaining == RivalAgent.MAX_DISRUPT_CHARGES


func test_activate_clears_disruption_days() -> bool:
	var agent := _make_agent()
	agent._disruption_days_remaining = 5
	agent.activate()
	return agent._disruption_days_remaining == 0


func test_activate_clears_next_degrade_target() -> bool:
	var agent := _make_agent()
	agent._next_degrade_target_id = "some_npc"
	agent.activate()
	return agent._next_degrade_target_id == ""


# ══════════════════════════════════════════════════════════════════════════════
# _get_cooldown
# ══════════════════════════════════════════════════════════════════════════════

func test_cooldown_early_game_day1_is_4() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._get_cooldown(1) == 4


func test_cooldown_early_game_day7_is_4() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._get_cooldown(7) == 4


func test_cooldown_mid_game_day8_is_2() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._get_cooldown(8) == 2


func test_cooldown_mid_game_day17_is_2() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._get_cooldown(17) == 2


func test_cooldown_late_game_day18_is_1() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._get_cooldown(18) == 1


func test_cooldown_late_game_day25_is_1() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._get_cooldown(25) == 1


func test_cooldown_offset_slows_rival() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.cooldown_offset = 2
	return agent._get_cooldown(1) == 6  # base 4 + offset 2


func test_cooldown_offset_speeds_rival() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.cooldown_offset = -1
	return agent._get_cooldown(8) == 1  # base 2 - 1 = 1


func test_cooldown_disruption_adds_bonus() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._disruption_days_remaining = 2
	# base 4 + disruption bonus 3 = 7
	return agent._get_cooldown(1) == 4 + RivalAgent.DISRUPTION_COOLDOWN_BONUS


func test_cooldown_minimum_is_1() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.cooldown_offset = -99  # would make it very negative
	return agent._get_cooldown(25) >= 1  # floor at 1


# ══════════════════════════════════════════════════════════════════════════════
# can_be_disrupted
# ══════════════════════════════════════════════════════════════════════════════

func test_cannot_disrupt_when_not_active() -> bool:
	var agent := _make_agent()
	# Not activated — _active is false
	return agent.can_be_disrupted() == false


func test_cannot_disrupt_before_first_seed() -> bool:
	var agent := _make_agent()
	agent.activate()
	# _last_seed_day is still 0 after activate
	return agent.can_be_disrupted() == false


func test_cannot_disrupt_when_disruption_already_active() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 5       # has seeded before
	agent._disruption_days_remaining = 2  # disruption already running
	return agent.can_be_disrupted() == false


func test_cannot_disrupt_when_no_charges_remain() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 5
	agent.disrupt_charges_remaining = 0
	return agent.can_be_disrupted() == false


func test_can_disrupt_when_all_conditions_met() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 5              # has seeded before
	agent._disruption_days_remaining = 0  # no active disruption
	agent.disrupt_charges_remaining = 2   # charges available
	return agent.can_be_disrupted() == true


# ══════════════════════════════════════════════════════════════════════════════
# apply_disruption
# ══════════════════════════════════════════════════════════════════════════════

func test_apply_disruption_returns_false_when_cannot() -> bool:
	var agent := _make_agent()
	# Not activated — cannot disrupt
	return agent.apply_disruption(1) == false


func test_apply_disruption_returns_true_on_success() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 5
	return agent.apply_disruption(5) == true


func test_apply_disruption_sets_remaining_days() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 5
	agent.apply_disruption(5)
	return agent._disruption_days_remaining == RivalAgent.DISRUPTION_COOLDOWN_BONUS


func test_apply_disruption_decrements_charges() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 5
	var before := agent.disrupt_charges_remaining
	agent.apply_disruption(5)
	return agent.disrupt_charges_remaining == before - 1


# ══════════════════════════════════════════════════════════════════════════════
# Scouting
# ══════════════════════════════════════════════════════════════════════════════

func test_scout_next_target_returns_empty_when_inactive() -> bool:
	var agent := _make_agent()
	return agent.scout_next_target(1) == ""


func test_get_scouted_target_reflects_degrade_target() -> bool:
	var agent := _make_agent()
	agent._next_degrade_target_id = "npc_target"
	return agent.get_scouted_target() == "npc_target"

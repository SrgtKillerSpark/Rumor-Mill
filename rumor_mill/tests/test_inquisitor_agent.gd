## test_inquisitor_agent.gd — Unit tests for InquisitorAgent pure logic (SPA-1041).
##
## Covers:
##   • PROTECTED_NPC_IDS array
##   • Initial state: _active false, _last_seed_day 0, _target_index 0, shielded empty
##   • activate(): sets _active, resets fields, clears shields
##   • apply_anonymous_tip() + is_shielded()
##   • _get_cooldown(): early (≤5→4), mid (6-14→2), late (>14→1), offset, floor
##   • _pick_claim_type(): day≤5→heresy, day%5→scandal, day%3→accusation, else heresy
##   • tick guard clauses: inactive; within cooldown (null world guard)
##
## Strategy: InquisitorAgent extends RefCounted (no Node).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestInquisitorAgent
extends RefCounted

const InquisitorAgentScript := preload("res://scripts/inquisitor_agent.gd")


static func _make_agent() -> InquisitorAgent:
	return InquisitorAgentScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_protected_npc_ids_has_3_entries",
		"test_protected_contains_aldous_prior",
		"test_protected_contains_vera_midwife",
		"test_protected_contains_finn_monk",

		# ── initial state ──
		"test_initial_active_is_false",
		"test_initial_last_seed_day_is_zero",
		"test_initial_target_index_is_zero",
		"test_initial_shielded_is_empty",
		"test_initial_cooldown_offset_is_zero",

		# ── activate ──
		"test_activate_sets_active",
		"test_activate_resets_last_seed_day",
		"test_activate_resets_target_index",
		"test_activate_clears_shields",

		# ── apply_anonymous_tip / is_shielded ──
		"test_tip_shields_npc",
		"test_tip_refreshes_existing_shield",
		"test_is_shielded_false_for_unknown_npc",
		"test_is_shielded_true_after_tip",

		# ── _get_cooldown ──
		"test_cooldown_day1_is_4",
		"test_cooldown_day5_is_4",
		"test_cooldown_day6_is_2",
		"test_cooldown_day14_is_2",
		"test_cooldown_day15_is_1",
		"test_cooldown_day20_is_1",
		"test_cooldown_with_positive_offset",
		"test_cooldown_with_negative_offset",
		"test_cooldown_minimum_is_1",

		# ── _pick_claim_type ──
		"test_claim_type_day1_is_heresy",
		"test_claim_type_day5_is_heresy",
		"test_claim_type_day10_is_scandal",   # 10%5 == 0
		"test_claim_type_day15_is_scandal",   # 15%5 == 0
		"test_claim_type_day9_is_accusation", # 9%3 == 0, not %5
		"test_claim_type_day6_is_heresy",     # 6%5!=0, 6%3!=0

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

func test_protected_npc_ids_has_3_entries() -> bool:
	return InquisitorAgent.PROTECTED_NPC_IDS.size() == 3


func test_protected_contains_aldous_prior() -> bool:
	return "aldous_prior" in InquisitorAgent.PROTECTED_NPC_IDS


func test_protected_contains_vera_midwife() -> bool:
	return "vera_midwife" in InquisitorAgent.PROTECTED_NPC_IDS


func test_protected_contains_finn_monk() -> bool:
	return "finn_monk" in InquisitorAgent.PROTECTED_NPC_IDS


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_active_is_false() -> bool:
	return _make_agent()._active == false


func test_initial_last_seed_day_is_zero() -> bool:
	return _make_agent()._last_seed_day == 0


func test_initial_target_index_is_zero() -> bool:
	return _make_agent()._target_index == 0


func test_initial_shielded_is_empty() -> bool:
	return _make_agent()._shielded_npc_ids.is_empty()


func test_initial_cooldown_offset_is_zero() -> bool:
	return _make_agent().cooldown_offset == 0


# ══════════════════════════════════════════════════════════════════════════════
# activate
# ══════════════════════════════════════════════════════════════════════════════

func test_activate_sets_active() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._active == true


func test_activate_resets_last_seed_day() -> bool:
	var agent := _make_agent()
	agent._last_seed_day = 8
	agent.activate()
	return agent._last_seed_day == 0


func test_activate_resets_target_index() -> bool:
	var agent := _make_agent()
	agent._target_index = 2
	agent.activate()
	return agent._target_index == 0


func test_activate_clears_shields() -> bool:
	var agent := _make_agent()
	agent._shielded_npc_ids["aldous_prior"] = true
	agent.activate()
	return agent._shielded_npc_ids.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# apply_anonymous_tip / is_shielded
# ══════════════════════════════════════════════════════════════════════════════

func test_tip_shields_npc() -> bool:
	var agent := _make_agent()
	agent.apply_anonymous_tip("aldous_prior")
	return agent._shielded_npc_ids.has("aldous_prior")


func test_tip_refreshes_existing_shield() -> bool:
	var agent := _make_agent()
	agent.apply_anonymous_tip("finn_monk")
	agent.apply_anonymous_tip("finn_monk")  # second call should not error
	return agent._shielded_npc_ids.has("finn_monk")


func test_is_shielded_false_for_unknown_npc() -> bool:
	var agent := _make_agent()
	return agent.is_shielded("no_such_npc") == false


func test_is_shielded_true_after_tip() -> bool:
	var agent := _make_agent()
	agent.apply_anonymous_tip("vera_midwife")
	return agent.is_shielded("vera_midwife") == true


# ══════════════════════════════════════════════════════════════════════════════
# _get_cooldown
# ══════════════════════════════════════════════════════════════════════════════

func test_cooldown_day1_is_4() -> bool:
	return _make_agent()._get_cooldown(1) == 4


func test_cooldown_day5_is_4() -> bool:
	return _make_agent()._get_cooldown(5) == 4


func test_cooldown_day6_is_2() -> bool:
	return _make_agent()._get_cooldown(6) == 2


func test_cooldown_day14_is_2() -> bool:
	return _make_agent()._get_cooldown(14) == 2


func test_cooldown_day15_is_1() -> bool:
	return _make_agent()._get_cooldown(15) == 1


func test_cooldown_day20_is_1() -> bool:
	return _make_agent()._get_cooldown(20) == 1


func test_cooldown_with_positive_offset() -> bool:
	var agent := _make_agent()
	agent.cooldown_offset = 3
	return agent._get_cooldown(1) == 7  # 4 + 3


func test_cooldown_with_negative_offset() -> bool:
	var agent := _make_agent()
	agent.cooldown_offset = -1
	return agent._get_cooldown(6) == 1  # 2 - 1 = 1


func test_cooldown_minimum_is_1() -> bool:
	var agent := _make_agent()
	agent.cooldown_offset = -99
	return agent._get_cooldown(20) >= 1


# ══════════════════════════════════════════════════════════════════════════════
# _pick_claim_type
# ══════════════════════════════════════════════════════════════════════════════

func test_claim_type_day1_is_heresy() -> bool:
	return _make_agent()._pick_claim_type(1) == "heresy"


func test_claim_type_day5_is_heresy() -> bool:
	# day 5: ≤5 branch → heresy
	return _make_agent()._pick_claim_type(5) == "heresy"


func test_claim_type_day10_is_scandal() -> bool:
	# day 10: 10%5 == 0 → scandal
	return _make_agent()._pick_claim_type(10) == "scandal"


func test_claim_type_day15_is_scandal() -> bool:
	# day 15: 15%5 == 0 → scandal
	return _make_agent()._pick_claim_type(15) == "scandal"


func test_claim_type_day9_is_accusation() -> bool:
	# day 9: 9%5!=0, 9%3==0 → accusation
	return _make_agent()._pick_claim_type(9) == "accusation"


func test_claim_type_day6_is_heresy() -> bool:
	# day 6: 6%5!=0, 6%3!=0 → heresy (else branch)
	return _make_agent()._pick_claim_type(6) == "heresy"


# ══════════════════════════════════════════════════════════════════════════════
# tick guard clauses
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_does_nothing_when_not_active() -> bool:
	var agent := _make_agent()
	agent.tick(1, null, null)
	return agent._last_seed_day == 0


func test_tick_does_nothing_within_cooldown() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._last_seed_day = 1
	# day 3: gap=2 < cooldown(3)=4 → guard fires before world access
	agent.tick(3, null, null)
	return agent._last_seed_day == 1  # unchanged

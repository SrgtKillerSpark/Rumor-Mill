## test_scenario_config.gd — Unit tests for ScenarioConfig balance constants (SPA-1041).
##
## Covers:
##   • NPC identifier strings for all key NPCs
##   • All scenario win/fail thresholds (S1–S6)
##   • Protected NPC arrays (S4) and candidate arrays (S5)
##   • Timing constants: phase windows, cooldowns, endorsement days
##   • Action costs and multipliers
##
## Strategy: ScenarioConfig is a pure constants class (no Node, no state).
## Every test simply reads a constant and compares it to the expected value.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenarioConfig
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── NPC identifiers ──
		"test_edric_fenn_id",
		"test_alys_herbwife_id",
		"test_maren_nun_id",
		"test_calder_fenn_id",
		"test_tomas_reeve_id",
		"test_aldric_vane_id",
		"test_marta_coin_id",
		"test_aldous_prior_id",

		# ── Scenario 1 ──
		"test_s1_win_edric_below_is_30",
		"test_s1_edric_start_score_is_50",
		"test_s1_exposed_heat_is_80",
		"test_s1_first_blood_threshold_is_48",

		# ── Scenario 2 ──
		"test_s2_win_illness_min_is_7",
		"test_s2_maren_grace_days_is_2",

		# ── Scenario 3 ──
		"test_s3_win_calder_min_is_75",
		"test_s3_win_tomas_max_is_35",
		"test_s3_fail_calder_below_is_35",

		# ── Scenario 4 ──
		"test_s4_protected_npc_ids_has_3_entries",
		"test_s4_protected_npc_ids_contains_aldous",
		"test_s4_protected_npc_ids_contains_vera",
		"test_s4_protected_npc_ids_contains_finn",
		"test_s4_win_rep_min_is_48",
		"test_s4_fail_rep_below_is_40",
		"test_s4_caution_rep_is_52",
		"test_s4_phase_1_window_days_5_to_7",
		"test_s4_phase_2_window_days_10_to_13",
		"test_s4_phase_3_window_days_14_to_17",
		"test_s4_phases_are_non_overlapping",

		# ── Scenario 5 ──
		"test_s5_candidate_ids_has_3_entries",
		"test_s5_win_aldric_min_is_65",
		"test_s5_win_rivals_max_is_45",
		"test_s5_fail_aldric_below_is_30",
		"test_s5_endorsement_day_is_13",
		"test_s5_endorsement_bonus_is_8",
		"test_s5_campaign_rep_boost_is_4",
		"test_s5_campaign_cooldown_is_3",

		# ── Scenario 6 ──
		"test_s6_win_aldric_max_is_30",
		"test_s6_win_marta_min_is_62",
		"test_s6_fail_marta_below_is_30",
		"test_s6_exposed_heat_is_55",
		"test_s6_blackmail_whisper_cost_is_2",
		"test_s6_blackmail_rep_hit_is_negative",
		"test_s6_blackmail_heat_add_is_22",
		"test_s6_blackmail_max_uses_is_2",
		"test_s6_blackmail_heat_npcs_has_2_entries",
		"test_s6_blackmail_heat_npcs_contains_sybil",
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
# NPC identifiers
# ══════════════════════════════════════════════════════════════════════════════

func test_edric_fenn_id() -> bool:
	return ScenarioConfig.EDRIC_FENN_ID == "edric_fenn"


func test_alys_herbwife_id() -> bool:
	return ScenarioConfig.ALYS_HERBWIFE_ID == "alys_herbwife"


func test_maren_nun_id() -> bool:
	return ScenarioConfig.MAREN_NUN_ID == "maren_nun"


func test_calder_fenn_id() -> bool:
	return ScenarioConfig.CALDER_FENN_ID == "calder_fenn"


func test_tomas_reeve_id() -> bool:
	return ScenarioConfig.TOMAS_REEVE_ID == "tomas_reeve"


func test_aldric_vane_id() -> bool:
	return ScenarioConfig.ALDRIC_VANE_ID == "aldric_vane"


func test_marta_coin_id() -> bool:
	return ScenarioConfig.MARTA_COIN_ID == "marta_coin"


func test_aldous_prior_id() -> bool:
	return ScenarioConfig.ALDOUS_PRIOR_ID == "aldous_prior"


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 1
# ══════════════════════════════════════════════════════════════════════════════

func test_s1_win_edric_below_is_30() -> bool:
	return ScenarioConfig.S1_WIN_EDRIC_BELOW == 30


func test_s1_edric_start_score_is_50() -> bool:
	return ScenarioConfig.S1_EDRIC_START_SCORE == 50


func test_s1_exposed_heat_is_80() -> bool:
	return absf(ScenarioConfig.S1_EXPOSED_HEAT - 80.0) < 0.001


func test_s1_first_blood_threshold_is_48() -> bool:
	return ScenarioConfig.S1_FIRST_BLOOD_THRESHOLD == 48


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 2
# ══════════════════════════════════════════════════════════════════════════════

func test_s2_win_illness_min_is_7() -> bool:
	return ScenarioConfig.S2_WIN_ILLNESS_MIN == 7


func test_s2_maren_grace_days_is_2() -> bool:
	return ScenarioConfig.S2_MAREN_GRACE_DAYS == 2


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 3
# ══════════════════════════════════════════════════════════════════════════════

func test_s3_win_calder_min_is_75() -> bool:
	return ScenarioConfig.S3_WIN_CALDER_MIN == 75


func test_s3_win_tomas_max_is_35() -> bool:
	return ScenarioConfig.S3_WIN_TOMAS_MAX == 35


func test_s3_fail_calder_below_is_35() -> bool:
	return ScenarioConfig.S3_FAIL_CALDER_BELOW == 35


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 4
# ══════════════════════════════════════════════════════════════════════════════

func test_s4_protected_npc_ids_has_3_entries() -> bool:
	return ScenarioConfig.S4_PROTECTED_NPC_IDS.size() == 3


func test_s4_protected_npc_ids_contains_aldous() -> bool:
	return "aldous_prior" in ScenarioConfig.S4_PROTECTED_NPC_IDS


func test_s4_protected_npc_ids_contains_vera() -> bool:
	return "vera_midwife" in ScenarioConfig.S4_PROTECTED_NPC_IDS


func test_s4_protected_npc_ids_contains_finn() -> bool:
	return "finn_monk" in ScenarioConfig.S4_PROTECTED_NPC_IDS


func test_s4_win_rep_min_is_48() -> bool:
	return ScenarioConfig.S4_WIN_REP_MIN == 48


func test_s4_fail_rep_below_is_40() -> bool:
	return ScenarioConfig.S4_FAIL_REP_BELOW == 40


func test_s4_caution_rep_is_52() -> bool:
	return ScenarioConfig.S4_CAUTION_REP == 52


func test_s4_phase_1_window_days_5_to_7() -> bool:
	return ScenarioConfig.S4_PHASE_1_WINDOW[0] == 5 and ScenarioConfig.S4_PHASE_1_WINDOW[1] == 7


func test_s4_phase_2_window_days_10_to_13() -> bool:
	return ScenarioConfig.S4_PHASE_2_WINDOW[0] == 10 and ScenarioConfig.S4_PHASE_2_WINDOW[1] == 13


func test_s4_phase_3_window_days_14_to_17() -> bool:
	return ScenarioConfig.S4_PHASE_3_WINDOW[0] == 14 and ScenarioConfig.S4_PHASE_3_WINDOW[1] == 17


func test_s4_phases_are_non_overlapping() -> bool:
	# Phase 1 ends before Phase 2 starts; Phase 2 ends before Phase 3 starts.
	return ScenarioConfig.S4_PHASE_1_WINDOW[1] < ScenarioConfig.S4_PHASE_2_WINDOW[0] \
		and ScenarioConfig.S4_PHASE_2_WINDOW[1] < ScenarioConfig.S4_PHASE_3_WINDOW[0]


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 5
# ══════════════════════════════════════════════════════════════════════════════

func test_s5_candidate_ids_has_3_entries() -> bool:
	return ScenarioConfig.S5_CANDIDATE_IDS.size() == 3


func test_s5_win_aldric_min_is_65() -> bool:
	return ScenarioConfig.S5_WIN_ALDRIC_MIN == 65


func test_s5_win_rivals_max_is_45() -> bool:
	return ScenarioConfig.S5_WIN_RIVALS_MAX == 45


func test_s5_fail_aldric_below_is_30() -> bool:
	return ScenarioConfig.S5_FAIL_ALDRIC_BELOW == 30


func test_s5_endorsement_day_is_13() -> bool:
	return ScenarioConfig.S5_ENDORSEMENT_DAY == 13


func test_s5_endorsement_bonus_is_8() -> bool:
	return ScenarioConfig.S5_ENDORSEMENT_BONUS == 8


func test_s5_campaign_rep_boost_is_4() -> bool:
	return ScenarioConfig.S5_CAMPAIGN_REP_BOOST == 4


func test_s5_campaign_cooldown_is_3() -> bool:
	return ScenarioConfig.S5_CAMPAIGN_COOLDOWN == 3


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 6
# ══════════════════════════════════════════════════════════════════════════════

func test_s6_win_aldric_max_is_30() -> bool:
	return ScenarioConfig.S6_WIN_ALDRIC_MAX == 30


func test_s6_win_marta_min_is_62() -> bool:
	return ScenarioConfig.S6_WIN_MARTA_MIN == 62


func test_s6_fail_marta_below_is_30() -> bool:
	return ScenarioConfig.S6_FAIL_MARTA_BELOW == 30


func test_s6_exposed_heat_is_55() -> bool:
	return absf(ScenarioConfig.S6_EXPOSED_HEAT - 55.0) < 0.001


func test_s6_blackmail_whisper_cost_is_2() -> bool:
	return ScenarioConfig.S6_BLACKMAIL_WHISPER_COST == 2


func test_s6_blackmail_rep_hit_is_negative() -> bool:
	return ScenarioConfig.S6_BLACKMAIL_REP_HIT < 0


func test_s6_blackmail_heat_add_is_22() -> bool:
	return absf(ScenarioConfig.S6_BLACKMAIL_HEAT_ADD - 22.0) < 0.001


func test_s6_blackmail_max_uses_is_2() -> bool:
	return ScenarioConfig.S6_BLACKMAIL_MAX_USES == 2


func test_s6_blackmail_heat_npcs_has_2_entries() -> bool:
	return ScenarioConfig.S6_BLACKMAIL_HEAT_NPCS.size() == 2


func test_s6_blackmail_heat_npcs_contains_sybil() -> bool:
	return "sybil_oats" in ScenarioConfig.S6_BLACKMAIL_HEAT_NPCS

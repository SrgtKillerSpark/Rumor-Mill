## test_npc_schedule.gd — Unit tests for NpcSchedule archetype tables and location lookup (SPA-1041).
##
## Covers:
##   • archetype_from_string: all known names, case-insensitive, unknown fallback
##   • SLOTS_PER_DAY constant
##   • ARCHETYPE_TABLES: all archetypes have exactly 6 slots
##   • get_location: base archetype, "work" substitution, tick overrides,
##     day_mod overrides, specific-day overrides, priority ordering
##
## Strategy: NpcSchedule is a pure static utility class (no Node inheritance).
## All methods and constants are tested without any scene-tree involvement.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcSchedule
extends RefCounted


# ── helpers ───────────────────────────────────────────────────────────────────

static func _loc(
		archetype: NpcSchedule.ScheduleArchetype,
		slot: int,
		work: String = "",
		tick_ov: Dictionary = {},
		day_ov: Array = [],
		day: int = 1
) -> String:
	return NpcSchedule.get_location(archetype, slot, work, tick_ov, day_ov, day)


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── archetype_from_string ──
		"test_archetype_merchant_worker",
		"test_archetype_tavern_staff",
		"test_archetype_noble_household",
		"test_archetype_guard_civic",
		"test_archetype_clergy",
		"test_archetype_scholar",
		"test_archetype_unknown_is_independent",
		"test_archetype_empty_is_independent",
		"test_archetype_case_insensitive",

		# ── SLOTS_PER_DAY ──
		"test_slots_per_day_is_6",

		# ── ARCHETYPE_TABLES ──
		"test_all_archetype_tables_have_6_slots",

		# ── get_location: base archetype ──
		"test_merchant_slot0_is_home",
		"test_merchant_slot2_is_work",
		"test_merchant_slot5_is_tavern",
		"test_clergy_slot0_is_chapel",
		"test_clergy_slot3_is_market",
		"test_guard_slot1_is_patrol",
		"test_noble_slot3_is_town_hall",
		"test_scholar_slot4_is_market",

		# ── get_location: "work" token substitution ──
		"test_work_token_substituted_with_provided_work",
		"test_work_token_falls_back_to_market_when_empty",

		# ── get_location: tick overrides ──
		"test_tick_override_replaces_base",
		"test_tick_override_for_other_slot_not_applied",

		# ── get_location: day_mod overrides ──
		"test_day_mod_override_fires_on_matching_day",
		"test_day_mod_override_skipped_when_not_matching",
		"test_day_mod_zero_does_not_fire",

		# ── get_location: specific-day overrides ──
		"test_specific_day_override_fires_on_exact_day",
		"test_specific_day_override_skipped_on_other_day",

		# ── get_location: priority ordering ──
		"test_day_pattern_beats_tick_override",
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
# archetype_from_string
# ══════════════════════════════════════════════════════════════════════════════

func test_archetype_merchant_worker() -> bool:
	return NpcSchedule.archetype_from_string("merchant_worker") == NpcSchedule.ScheduleArchetype.MERCHANT_WORKER


func test_archetype_tavern_staff() -> bool:
	return NpcSchedule.archetype_from_string("tavern_staff") == NpcSchedule.ScheduleArchetype.TAVERN_STAFF


func test_archetype_noble_household() -> bool:
	return NpcSchedule.archetype_from_string("noble_household") == NpcSchedule.ScheduleArchetype.NOBLE_HOUSEHOLD


func test_archetype_guard_civic() -> bool:
	return NpcSchedule.archetype_from_string("guard_civic") == NpcSchedule.ScheduleArchetype.GUARD_CIVIC


func test_archetype_clergy() -> bool:
	return NpcSchedule.archetype_from_string("clergy") == NpcSchedule.ScheduleArchetype.CLERGY


func test_archetype_scholar() -> bool:
	return NpcSchedule.archetype_from_string("scholar") == NpcSchedule.ScheduleArchetype.SCHOLAR


func test_archetype_unknown_is_independent() -> bool:
	return NpcSchedule.archetype_from_string("totally_unknown") == NpcSchedule.ScheduleArchetype.INDEPENDENT


func test_archetype_empty_is_independent() -> bool:
	return NpcSchedule.archetype_from_string("") == NpcSchedule.ScheduleArchetype.INDEPENDENT


func test_archetype_case_insensitive() -> bool:
	return NpcSchedule.archetype_from_string("CLERGY") == NpcSchedule.ScheduleArchetype.CLERGY


# ══════════════════════════════════════════════════════════════════════════════
# SLOTS_PER_DAY
# ══════════════════════════════════════════════════════════════════════════════

func test_slots_per_day_is_6() -> bool:
	return NpcSchedule.SLOTS_PER_DAY == 6


# ══════════════════════════════════════════════════════════════════════════════
# ARCHETYPE_TABLES integrity
# ══════════════════════════════════════════════════════════════════════════════

func test_all_archetype_tables_have_6_slots() -> bool:
	for arch in NpcSchedule.ARCHETYPE_TABLES:
		var tbl: Array = NpcSchedule.ARCHETYPE_TABLES[arch]
		if tbl.size() != NpcSchedule.SLOTS_PER_DAY:
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# get_location: base archetype
# ══════════════════════════════════════════════════════════════════════════════

func test_merchant_slot0_is_home() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0) == "home"


func test_merchant_slot2_is_work() -> bool:
	# "work" token with no work_location → substituted with "market"
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 2) == "market"


func test_merchant_slot5_is_tavern() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 5) == "tavern"


func test_clergy_slot0_is_chapel() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.CLERGY, 0) == "chapel"


func test_clergy_slot3_is_market() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.CLERGY, 3) == "market"


func test_guard_slot1_is_patrol() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.GUARD_CIVIC, 1) == "patrol"


func test_noble_slot3_is_town_hall() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.NOBLE_HOUSEHOLD, 3) == "town_hall"


func test_scholar_slot4_is_market() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.SCHOLAR, 4) == "market"


# ══════════════════════════════════════════════════════════════════════════════
# get_location: "work" token substitution
# ══════════════════════════════════════════════════════════════════════════════

func test_work_token_substituted_with_provided_work() -> bool:
	# MERCHANT_WORKER slot 2 = "work" → should return the given work_location
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 2, "smithy") == "smithy"


func test_work_token_falls_back_to_market_when_empty() -> bool:
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 2, "") == "market"


# ══════════════════════════════════════════════════════════════════════════════
# get_location: tick overrides
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_override_replaces_base() -> bool:
	var ov := {"0": "festival_grounds"}
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", ov) == "festival_grounds"


func test_tick_override_for_other_slot_not_applied() -> bool:
	var ov := {"1": "festival_grounds"}
	# slot 0 is "home" for merchant; override is for slot 1, not applied here
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", ov) == "home"


# ══════════════════════════════════════════════════════════════════════════════
# get_location: day_mod overrides
# ══════════════════════════════════════════════════════════════════════════════

func test_day_mod_override_fires_on_matching_day() -> bool:
	# day=6, day_mod=3 → 6%3 == 0 → fires
	var day_ov := [{"day_mod": 3, "tick": 0, "location": "temple"}]
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", {}, day_ov, 6) == "temple"


func test_day_mod_override_skipped_when_not_matching() -> bool:
	# day=7, day_mod=3 → 7%3 != 0 → skipped
	var day_ov := [{"day_mod": 3, "tick": 0, "location": "temple"}]
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", {}, day_ov, 7) == "home"


func test_day_mod_zero_does_not_fire() -> bool:
	# day_mod=0 → division by zero guard → skipped
	var day_ov := [{"day_mod": 0, "tick": 0, "location": "temple"}]
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", {}, day_ov, 6) == "home"


# ══════════════════════════════════════════════════════════════════════════════
# get_location: specific-day overrides
# ══════════════════════════════════════════════════════════════════════════════

func test_specific_day_override_fires_on_exact_day() -> bool:
	var day_ov := [{"day": 5, "tick": 0, "location": "fair"}]
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", {}, day_ov, 5) == "fair"


func test_specific_day_override_skipped_on_other_day() -> bool:
	var day_ov := [{"day": 5, "tick": 0, "location": "fair"}]
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", {}, day_ov, 4) == "home"


# ══════════════════════════════════════════════════════════════════════════════
# get_location: priority ordering
# ══════════════════════════════════════════════════════════════════════════════

func test_day_pattern_beats_tick_override() -> bool:
	# day_mod override and tick override both match — day_pattern should win (highest priority)
	var tick_ov := {"0": "from_tick_override"}
	var day_ov  := [{"day_mod": 1, "tick": 0, "location": "from_day_pattern"}]
	# day_mod=1 means every day matches
	return _loc(NpcSchedule.ScheduleArchetype.MERCHANT_WORKER, 0, "", tick_ov, day_ov, 1) == "from_day_pattern"

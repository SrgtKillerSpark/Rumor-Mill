## test_journal_intel_section.gd — Unit tests for JournalIntelSection (SPA-1027).
##
## Covers:
##   • Palette constants: C_HEADING, C_LOCKED
##   • Initial state: _filter_text is empty, _world_ref/_intel_store_ref/_day_night_ref null
##   • setup() — assigns all three refs
##   • _build_npc_name_lookup() — returns {} when world_ref is null
##   • _build_npc_faction_lookup() — returns {} when world_ref is null
##   • _tick_to_day_str() — tick 0 with null day_night_ref → "Day 1, 12:00 AM"
##   • _tick_to_day_str() — tick 12 → "Day 1, 12:00 PM"
##   • _tick_to_day_str() — tick 24 → "Day 2, 12:00 AM"
##   • _tick_to_day_str() — tick 25 → "Day 2, 01:00 AM"
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalIntelSection
extends RefCounted

const _Klass := preload("res://scripts/journal_intel_section.gd")


static func _make() -> JournalIntelSection:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_heading_gold",
		"test_c_locked_muted",

		# Initial state
		"test_initial_filter_text_empty",
		"test_initial_world_ref_null",
		"test_initial_intel_store_ref_null",
		"test_initial_day_night_ref_null",

		# setup()
		"test_setup_assigns_refs",

		# _build_npc_name_lookup()
		"test_name_lookup_empty_without_world",

		# _build_npc_faction_lookup()
		"test_faction_lookup_empty_without_world",

		# _tick_to_day_str()
		"test_tick_to_day_str_tick_0",
		"test_tick_to_day_str_tick_12",
		"test_tick_to_day_str_tick_24",
		"test_tick_to_day_str_tick_25",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournalIntelSection tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Palette
# ══════════════════════════════════════════════════════════════════════════════

func test_c_heading_gold() -> bool:
	var s := _make()
	return s.C_HEADING.r > 0.85 and s.C_HEADING.b < 0.2


func test_c_locked_muted() -> bool:
	var s := _make()
	# Locked colour should be low-saturation brownish
	return s.C_LOCKED.r < 0.6 and s.C_LOCKED.g < 0.5 and s.C_LOCKED.b < 0.4


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_filter_text_empty() -> bool:
	var s := _make()
	return s._filter_text == ""


func test_initial_world_ref_null() -> bool:
	var s := _make()
	return s._world_ref == null


func test_initial_intel_store_ref_null() -> bool:
	var s := _make()
	return s._intel_store_ref == null


func test_initial_day_night_ref_null() -> bool:
	var s := _make()
	return s._day_night_ref == null


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_refs() -> bool:
	var s          := _make()
	var world      := Node2D.new()
	var intel      := PlayerIntelStore.new()
	var day_night  := Node.new()
	s.setup(world, intel, day_night)
	var ok := s._world_ref == world \
		  and s._intel_store_ref == intel \
		  and s._day_night_ref == day_night
	world.free()
	day_night.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _build_npc_name_lookup / _build_npc_faction_lookup
# ══════════════════════════════════════════════════════════════════════════════

func test_name_lookup_empty_without_world() -> bool:
	var s := _make()
	return s._build_npc_name_lookup().is_empty()


func test_faction_lookup_empty_without_world() -> bool:
	var s := _make()
	return s._build_npc_faction_lookup().is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# _tick_to_day_str (ticks_per_day defaults to 24 when day_night_ref is null)
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_to_day_str_tick_0() -> bool:
	var s := _make()
	# tick 0: day=1, hour=0 (AM), display_hour=12 → "Day 1, 12:00 AM"
	return s._tick_to_day_str(0) == "Day 1, 12:00 AM"


func test_tick_to_day_str_tick_12() -> bool:
	var s := _make()
	# tick 12: day=1, hour=12 (PM), display_hour=12 → "Day 1, 12:00 PM"
	return s._tick_to_day_str(12) == "Day 1, 12:00 PM"


func test_tick_to_day_str_tick_24() -> bool:
	var s := _make()
	# tick 24: day=2, hour=0 (AM), display_hour=12 → "Day 2, 12:00 AM"
	return s._tick_to_day_str(24) == "Day 2, 12:00 AM"


func test_tick_to_day_str_tick_25() -> bool:
	var s := _make()
	# tick 25: day=2, hour=1 (AM), display_hour=1 → "Day 2, 01:00 AM"
	return s._tick_to_day_str(25) == "Day 2, 01:00 AM"

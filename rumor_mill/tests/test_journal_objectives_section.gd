## test_journal_objectives_section.gd — Unit tests for JournalObjectivesSection (SPA-1027).
##
## Covers:
##   • Scenario day-limit constants: S1_DAYS through S6_DAYS
##   • Palette constants: C_HEADING, C_SPREADING, C_CONTRADICTED
##   • Initial state: _world_ref and _day_night_ref are null
##   • setup() — assigns both refs
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalObjectivesSection
extends RefCounted

const _Klass := preload("res://scripts/journal_objectives_section.gd")


static func _make() -> JournalObjectivesSection:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Day-limit constants
		"test_s1_days",
		"test_s2_days",
		"test_s3_days",
		"test_s4_days",
		"test_s5_days",
		"test_s6_days",

		# Palette constants
		"test_c_heading_gold",
		"test_c_spreading_green",
		"test_c_contradicted_red",

		# Initial state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",

		# setup()
		"test_setup_assigns_refs",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournalObjectivesSection tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Scenario day-limit constants
# ══════════════════════════════════════════════════════════════════════════════

func test_s1_days() -> bool:
	var s := _make()
	return s.S1_DAYS == 30


func test_s2_days() -> bool:
	var s := _make()
	return s.S2_DAYS == 20


func test_s3_days() -> bool:
	var s := _make()
	return s.S3_DAYS == 25


func test_s4_days() -> bool:
	var s := _make()
	return s.S4_DAYS == 20


func test_s5_days() -> bool:
	var s := _make()
	return s.S5_DAYS == 25


func test_s6_days() -> bool:
	var s := _make()
	return s.S6_DAYS == 22


# ══════════════════════════════════════════════════════════════════════════════
# Palette constants
# ══════════════════════════════════════════════════════════════════════════════

func test_c_heading_gold() -> bool:
	var s := _make()
	return s.C_HEADING.r > 0.85 and s.C_HEADING.b < 0.2


func test_c_spreading_green() -> bool:
	var s := _make()
	return s.C_SPREADING.g > s.C_SPREADING.r and s.C_SPREADING.g > s.C_SPREADING.b


func test_c_contradicted_red() -> bool:
	var s := _make()
	return s.C_CONTRADICTED.r > s.C_CONTRADICTED.g and s.C_CONTRADICTED.r > s.C_CONTRADICTED.b


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_world_ref_null() -> bool:
	var s := _make()
	return s._world_ref == null


func test_initial_day_night_ref_null() -> bool:
	var s := _make()
	return s._day_night_ref == null


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_refs() -> bool:
	var s         := _make()
	var world     := Node2D.new()
	var day_night := Node.new()
	s.setup(world, day_night)
	var ok := s._world_ref == world and s._day_night_ref == day_night
	world.free()
	day_night.free()
	return ok

## test_journal_factions_section.gd — Unit tests for JournalFactionsSection (SPA-1027).
##
## Covers:
##   • Palette constants: C_HEADING, C_BODY, C_KEY, C_SUBKEY, C_SPREADING,
##                        C_STALLING, C_CONTRADICTED
##   • Initial state: _world_ref is null
##   • setup() — assigns _world_ref
##   • _get_rumor_by_id() — returns null when _world_ref is null
##
## Strategy: instantiate JournalFactionsSection directly (extends RefCounted —
## no scene tree required). build() calls create Label nodes so it is not exercised
## here; only pure-data methods and constants are tested.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalFactionsSection
extends RefCounted

const _Klass := preload("res://scripts/journal_factions_section.gd")


static func _make() -> JournalFactionsSection:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants — spot checks on representative colours
		"test_c_heading_is_gold",
		"test_c_body_defined",
		"test_c_spreading_is_green",
		"test_c_contradicted_is_red",
		"test_c_stalling_defined",

		# Initial state
		"test_initial_world_ref_null",

		# setup()
		"test_setup_assigns_world_ref",

		# _get_rumor_by_id()
		"test_get_rumor_by_id_null_when_no_world",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournalFactionsSection tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Palette constants
# ══════════════════════════════════════════════════════════════════════════════

func test_c_heading_is_gold() -> bool:
	var s := _make()
	# Gold hue — red channel should be highest and > 0.85
	return s.C_HEADING.r > 0.85 and s.C_HEADING.g > 0.7 and s.C_HEADING.b < 0.2


func test_c_body_defined() -> bool:
	var s := _make()
	return s.C_BODY.a > 0.0


func test_c_spreading_is_green() -> bool:
	var s := _make()
	# Green channel dominant
	return s.C_SPREADING.g > s.C_SPREADING.r and s.C_SPREADING.g > s.C_SPREADING.b


func test_c_contradicted_is_red() -> bool:
	var s := _make()
	# Red channel dominant
	return s.C_CONTRADICTED.r > s.C_CONTRADICTED.g and s.C_CONTRADICTED.r > s.C_CONTRADICTED.b


func test_c_stalling_defined() -> bool:
	var s := _make()
	return s.C_STALLING.a > 0.0


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_world_ref_null() -> bool:
	var s := _make()
	return s._world_ref == null


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_world_ref() -> bool:
	var s    := _make()
	var node := Node2D.new()
	s.setup(node)
	var ok := s._world_ref == node
	node.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _get_rumor_by_id()
# ══════════════════════════════════════════════════════════════════════════════

func test_get_rumor_by_id_null_when_no_world() -> bool:
	var s := _make()
	# _world_ref is null — should return null without error.
	return s._get_rumor_by_id("any_id") == null

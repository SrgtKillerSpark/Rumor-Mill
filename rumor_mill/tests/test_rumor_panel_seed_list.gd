## test_rumor_panel_seed_list.gd — Unit tests for RumorPanelSeedList (SPA-1027).
##
## Covers:
##   • Faction colour constants: C_FACTION_MERCHANT, C_FACTION_NOBLE, C_FACTION_CLERGY
##   • _faction_color() — static; merchant/noble/clergy/unknown
##   • Initial state: seed_recommended_shown false; evidence_tutorial_fired false
##   • setup() — assigns _world_ref, _intel_store_ref, _estimates refs
##
## build() is not tested here — it creates many scene-tree nodes and depends on
## live world data. Focus is on pure-data methods and initial/setup state.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanelSeedList
extends RefCounted

const _Klass := preload("res://scripts/rumor_panel_seed_list.gd")
const EstimatesScript := preload("res://scripts/rumor_panel_estimates.gd")


static func _make() -> RumorPanelSeedList:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Faction colour constants
		"test_faction_merchant_gold",
		"test_faction_noble_blue",
		"test_faction_clergy_light",

		# _faction_color()
		"test_faction_color_merchant",
		"test_faction_color_noble",
		"test_faction_color_clergy",
		"test_faction_color_unknown_is_white",

		# Initial state
		"test_initial_seed_recommended_shown_false",
		"test_initial_evidence_tutorial_fired_false",
		"test_initial_world_ref_null",
		"test_initial_intel_store_ref_null",
		"test_initial_estimates_null",

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

	print("\nRumorPanelSeedList tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Faction colour constants
# ══════════════════════════════════════════════════════════════════════════════

func test_faction_merchant_gold() -> bool:
	var s := _make()
	# Gold: high red, moderate-high green, low blue
	return s.C_FACTION_MERCHANT.r > 0.8 and s.C_FACTION_MERCHANT.g > 0.6 and s.C_FACTION_MERCHANT.b < 0.4


func test_faction_noble_blue() -> bool:
	var s := _make()
	# Blue-dominant
	return s.C_FACTION_NOBLE.b > s.C_FACTION_NOBLE.r


func test_faction_clergy_light() -> bool:
	var s := _make()
	# All channels relatively high (near white)
	return s.C_FACTION_CLERGY.r > 0.7 and s.C_FACTION_CLERGY.g > 0.7 and s.C_FACTION_CLERGY.b > 0.7


# ══════════════════════════════════════════════════════════════════════════════
# _faction_color()
# ══════════════════════════════════════════════════════════════════════════════

func test_faction_color_merchant() -> bool:
	var s := _make()
	return s._faction_color("merchant") == s.C_FACTION_MERCHANT


func test_faction_color_noble() -> bool:
	var s := _make()
	return s._faction_color("noble") == s.C_FACTION_NOBLE


func test_faction_color_clergy() -> bool:
	var s := _make()
	return s._faction_color("clergy") == s.C_FACTION_CLERGY


func test_faction_color_unknown_is_white() -> bool:
	var s := _make()
	return s._faction_color("pirate") == Color.WHITE


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_seed_recommended_shown_false() -> bool:
	var s := _make()
	return s.seed_recommended_shown == false


func test_initial_evidence_tutorial_fired_false() -> bool:
	var s := _make()
	return s.evidence_tutorial_fired == false


func test_initial_world_ref_null() -> bool:
	var s := _make()
	return s._world_ref == null


func test_initial_intel_store_ref_null() -> bool:
	var s := _make()
	return s._intel_store_ref == null


func test_initial_estimates_null() -> bool:
	var s := _make()
	return s._estimates == null


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_refs() -> bool:
	var s         := _make()
	var world     := Node2D.new()
	var store     := PlayerIntelStore.new()
	var estimates := Estimates_Klass.new()
	s.setup(world, store, estimates)
	var ok: bool = s._world_ref == world and s._intel_store_ref == store and s._estimates == estimates
	world.free()
	return ok

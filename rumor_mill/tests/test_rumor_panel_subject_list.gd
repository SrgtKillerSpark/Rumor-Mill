## test_rumor_panel_subject_list.gd — Unit tests for RumorPanelSubjectList (SPA-1027).
##
## Covers:
##   • Portrait atlas constants: PORTRAIT_W, PORTRAIT_H, PORTRAIT_COLS
##   • Palette constants: C_NPC_NAME, C_LOCKED, C_SELECTED_SUBJECT_BG,
##                        C_RELATION_SUSPICIOUS, C_RELATION_ALLIED, C_RELATION_NEUTRAL
##   • Faction colour constants: C_FACTION_MERCHANT, C_FACTION_NOBLE, C_FACTION_CLERGY
##   • _faction_color() — static; merchant/noble/clergy/unknown
##   • Initial state: _world_ref, _intel_store_ref, _portrait_tex all null
##   • setup() — assigns all three refs
##
## build() is not tested here — it creates scene-tree nodes and depends on live
## world + intel-store data. Focus is on pure-data methods and initial/setup state.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanelSubjectList
extends RefCounted

const _Klass := preload("res://scripts/rumor_panel_subject_list.gd")


static func _make() -> RumorPanelSubjectList:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Portrait atlas constants
		"test_portrait_w",
		"test_portrait_h",
		"test_portrait_cols",

		# Palette constants — spot-check key channels
		"test_c_npc_name_warm_tint",
		"test_c_locked_dark_neutral",
		"test_c_selected_subject_bg_alpha",
		"test_c_relation_suspicious_red_dominant",
		"test_c_relation_allied_green_dominant",
		"test_c_relation_neutral_yellow_tint",

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
		"test_initial_world_ref_null",
		"test_initial_intel_store_ref_null",
		"test_initial_portrait_tex_null",

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

	print("\nRumorPanelSubjectList tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Portrait atlas constants
# ══════════════════════════════════════════════════════════════════════════════

func test_portrait_w() -> bool:
	var s := _make()
	return s.PORTRAIT_W == 64


func test_portrait_h() -> bool:
	var s := _make()
	return s.PORTRAIT_H == 80


func test_portrait_cols() -> bool:
	var s := _make()
	return s.PORTRAIT_COLS == 6


# ══════════════════════════════════════════════════════════════════════════════
# Palette constants
# ══════════════════════════════════════════════════════════════════════════════

func test_c_npc_name_warm_tint() -> bool:
	var s := _make()
	# Warm parchment: high red, medium green, low-ish blue
	return s.C_NPC_NAME.r > 0.8 and s.C_NPC_NAME.g > 0.7 and s.C_NPC_NAME.b < 0.7


func test_c_locked_dark_neutral() -> bool:
	var s := _make()
	# Dark muted brown: all channels below 0.5
	return s.C_LOCKED.r < 0.5 and s.C_LOCKED.g < 0.5 and s.C_LOCKED.b < 0.5


func test_c_selected_subject_bg_alpha() -> bool:
	var s := _make()
	# Semi-transparent green background: alpha < 1.0
	return s.C_SELECTED_SUBJECT_BG.a < 1.0 and s.C_SELECTED_SUBJECT_BG.a > 0.0


func test_c_relation_suspicious_red_dominant() -> bool:
	var s := _make()
	return s.C_RELATION_SUSPICIOUS.r > s.C_RELATION_SUSPICIOUS.g \
		and s.C_RELATION_SUSPICIOUS.r > s.C_RELATION_SUSPICIOUS.b


func test_c_relation_allied_green_dominant() -> bool:
	var s := _make()
	return s.C_RELATION_ALLIED.g > s.C_RELATION_ALLIED.r \
		and s.C_RELATION_ALLIED.g > s.C_RELATION_ALLIED.b


func test_c_relation_neutral_yellow_tint() -> bool:
	var s := _make()
	# Yellow: high red and green, lower blue
	return s.C_RELATION_NEUTRAL.r > 0.8 and s.C_RELATION_NEUTRAL.g > 0.8 \
		and s.C_RELATION_NEUTRAL.b < s.C_RELATION_NEUTRAL.r


# ══════════════════════════════════════════════════════════════════════════════
# Faction colour constants
# ══════════════════════════════════════════════════════════════════════════════

func test_faction_merchant_gold() -> bool:
	var s := _make()
	# Gold: high red, moderate-high green, low blue
	return s.C_FACTION_MERCHANT.r > 0.8 and s.C_FACTION_MERCHANT.g > 0.6 \
		and s.C_FACTION_MERCHANT.b < 0.4


func test_faction_noble_blue() -> bool:
	var s := _make()
	# Blue-dominant
	return s.C_FACTION_NOBLE.b > s.C_FACTION_NOBLE.r


func test_faction_clergy_light() -> bool:
	var s := _make()
	# All channels relatively high (near white)
	return s.C_FACTION_CLERGY.r > 0.7 and s.C_FACTION_CLERGY.g > 0.7 \
		and s.C_FACTION_CLERGY.b > 0.7


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
	return s._faction_color("peasant") == Color.WHITE


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_world_ref_null() -> bool:
	var s := _make()
	return s._world_ref == null


func test_initial_intel_store_ref_null() -> bool:
	var s := _make()
	return s._intel_store_ref == null


func test_initial_portrait_tex_null() -> bool:
	var s := _make()
	return s._portrait_tex == null


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_refs() -> bool:
	var s     := _make()
	var world := Node2D.new()
	var store := PlayerIntelStore.new()
	s.setup(world, store, null)
	var ok := s._world_ref == world \
		  and s._intel_store_ref == store \
		  and s._portrait_tex == null
	world.free()
	return ok

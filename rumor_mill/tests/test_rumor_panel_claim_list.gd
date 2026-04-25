## test_rumor_panel_claim_list.gd — Unit tests for RumorPanelClaimList (SPA-1027).
##
## Covers:
##   • CLAIM_ICON_INDEX — known claim types mapped to expected columns
##   • Palette constants: C_INTENSITY_LOW/MED/HIGH, C_CLAIM_* colours
##   • _claim_type_color() — static; accusation/scandal/illness/heresy/praise/death/unknown
##   • _intensity_color() — static; 1–5 and out-of-range 0
##   • Initial state: _world_ref and _claim_icon_tex are null
##   • setup() — assigns refs
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanelClaimList
extends RefCounted

const _Klass := preload("res://scripts/rumor_panel_claim_list.gd")


static func _make() -> RumorPanelClaimList:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# CLAIM_ICON_INDEX
		"test_claim_icon_accusation",
		"test_claim_icon_death",
		"test_claim_icon_scandal",
		"test_claim_icon_heresy",
		"test_claim_icon_illness",
		"test_claim_icon_prophecy",
		"test_claim_icon_praise",
		"test_claim_icon_unknown_absent",

		# _claim_type_color()
		"test_claim_color_accusation",
		"test_claim_color_scandal",
		"test_claim_color_illness",
		"test_claim_color_heresy",
		"test_claim_color_praise",
		"test_claim_color_death",
		"test_claim_color_unknown_is_white",

		# _intensity_color()
		"test_intensity_color_one_is_low",
		"test_intensity_color_two_is_low",
		"test_intensity_color_three_is_med",
		"test_intensity_color_four_is_high",
		"test_intensity_color_five_is_high",
		"test_intensity_color_zero_is_white",

		# Initial state
		"test_initial_world_ref_null",
		"test_initial_claim_icon_tex_null",

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

	print("\nRumorPanelClaimList tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# CLAIM_ICON_INDEX
# ══════════════════════════════════════════════════════════════════════════════

func test_claim_icon_accusation() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("accusation", -1) == 0


func test_claim_icon_death() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("death", -1) == 0


func test_claim_icon_scandal() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("scandal", -1) == 2


func test_claim_icon_heresy() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("heresy", -1) == 2


func test_claim_icon_illness() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("illness", -1) == 3


func test_claim_icon_prophecy() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("prophecy", -1) == 3


func test_claim_icon_praise() -> bool:
	var s := _make()
	return s.CLAIM_ICON_INDEX.get("praise", -1) == 4


func test_claim_icon_unknown_absent() -> bool:
	var s := _make()
	return not s.CLAIM_ICON_INDEX.has("completely_unknown_claim")


# ══════════════════════════════════════════════════════════════════════════════
# _claim_type_color()
# ══════════════════════════════════════════════════════════════════════════════

func test_claim_color_accusation() -> bool:
	var s := _make()
	return s._claim_type_color("accusation") == s.C_CLAIM_ACCUSATION


func test_claim_color_scandal() -> bool:
	var s := _make()
	return s._claim_type_color("scandal") == s.C_CLAIM_SCANDAL


func test_claim_color_illness() -> bool:
	var s := _make()
	return s._claim_type_color("illness") == s.C_CLAIM_ILLNESS


func test_claim_color_heresy() -> bool:
	var s := _make()
	return s._claim_type_color("heresy") == s.C_CLAIM_HERESY


func test_claim_color_praise() -> bool:
	var s := _make()
	return s._claim_type_color("praise") == s.C_CLAIM_PRAISE


func test_claim_color_death() -> bool:
	var s := _make()
	return s._claim_type_color("death") == s.C_CLAIM_DEATH


func test_claim_color_unknown_is_white() -> bool:
	var s := _make()
	return s._claim_type_color("totally_unknown") == Color.WHITE


# ══════════════════════════════════════════════════════════════════════════════
# _intensity_color()
# ══════════════════════════════════════════════════════════════════════════════

func test_intensity_color_one_is_low() -> bool:
	var s := _make()
	return s._intensity_color(1) == s.C_INTENSITY_LOW


func test_intensity_color_two_is_low() -> bool:
	var s := _make()
	return s._intensity_color(2) == s.C_INTENSITY_LOW


func test_intensity_color_three_is_med() -> bool:
	var s := _make()
	return s._intensity_color(3) == s.C_INTENSITY_MED


func test_intensity_color_four_is_high() -> bool:
	var s := _make()
	return s._intensity_color(4) == s.C_INTENSITY_HIGH


func test_intensity_color_five_is_high() -> bool:
	var s := _make()
	return s._intensity_color(5) == s.C_INTENSITY_HIGH


func test_intensity_color_zero_is_white() -> bool:
	var s := _make()
	return s._intensity_color(0) == Color.WHITE


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_world_ref_null() -> bool:
	var s := _make()
	return s._world_ref == null


func test_initial_claim_icon_tex_null() -> bool:
	var s := _make()
	return s._claim_icon_tex == null


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_refs() -> bool:
	var s     := _make()
	var world := Node2D.new()
	s.setup(world, null)
	var ok := s._world_ref == world and s._claim_icon_tex == null
	world.free()
	return ok

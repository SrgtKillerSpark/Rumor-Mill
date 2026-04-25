## test_scenario_environment_palette.gd — Unit tests for ScenarioEnvironmentPalette
## palette constants and static accessors (SPA-1065).
##
## Covers:
##   • SCENARIO_MOODS    — six entries (scenario_1 … scenario_6), scenario_1 neutral white
##   • DISTRICT_PALETTES — five entries, each has fill + border colors
##   • scenario_canvas_tint() — known id returns expected color; unknown returns white
##   • scenario_mood_name()   — known id returns label; unknown returns "Unknown"
##   • district_fill()        — known district; unknown returns grey fallback
##   • district_border()      — known district; unknown returns grey fallback
##   • all_scenario_ids()     — six entries
##   • all_district_labels()  — five entries
##
## Strategy: ScenarioEnvironmentPalette is a pure-static class_name.
## All tests call the preloaded script directly — no instantiation needed.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenarioEnvironmentPalette
extends RefCounted

const SEPScript := preload("res://scripts/scenario_environment_palette.gd")


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── SCENARIO_MOODS ──
		"test_scenario_moods_has_six_entries",
		"test_scenario_1_canvas_tint_is_white",
		"test_all_moods_have_canvas_tint_key",

		# ── DISTRICT_PALETTES ──
		"test_district_palettes_has_five_entries",
		"test_all_districts_have_fill_and_border",
		"test_district_fill_alphas_are_low",

		# ── scenario_canvas_tint() ──
		"test_scenario_canvas_tint_scenario1_neutral",
		"test_scenario_canvas_tint_unknown_returns_white",

		# ── scenario_mood_name() ──
		"test_scenario_mood_name_known",
		"test_scenario_mood_name_unknown_returns_unknown",

		# ── district_fill() / district_border() ──
		"test_district_fill_known",
		"test_district_fill_unknown_fallback",
		"test_district_border_known",
		"test_district_border_unknown_fallback",

		# ── all_scenario_ids() / all_district_labels() ──
		"test_all_scenario_ids_count",
		"test_all_district_labels_count",
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
# SCENARIO_MOODS
# ══════════════════════════════════════════════════════════════════════════════

func test_scenario_moods_has_six_entries() -> bool:
	return SEPScript.SCENARIO_MOODS.size() == 6


func test_scenario_1_canvas_tint_is_white() -> bool:
	var tint: Color = SEPScript.SCENARIO_MOODS["scenario_1"]["canvas_tint"]
	return tint == Color(1.0, 1.0, 1.0, 1.0)


func test_all_moods_have_canvas_tint_key() -> bool:
	for key in SEPScript.SCENARIO_MOODS:
		if not SEPScript.SCENARIO_MOODS[key].has("canvas_tint"):
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# DISTRICT_PALETTES
# ══════════════════════════════════════════════════════════════════════════════

func test_district_palettes_has_five_entries() -> bool:
	return SEPScript.DISTRICT_PALETTES.size() == 5


func test_all_districts_have_fill_and_border() -> bool:
	for key in SEPScript.DISTRICT_PALETTES:
		var pal: Dictionary = SEPScript.DISTRICT_PALETTES[key]
		if not pal.has("fill") or not pal.has("border"):
			return false
	return true


func test_district_fill_alphas_are_low() -> bool:
	# Fill colors should be semi-transparent (alpha ≈ 0.09)
	for key in SEPScript.DISTRICT_PALETTES:
		var col: Color = SEPScript.DISTRICT_PALETTES[key]["fill"]
		if col.a >= 0.5:
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# scenario_canvas_tint()
# ══════════════════════════════════════════════════════════════════════════════

func test_scenario_canvas_tint_scenario1_neutral() -> bool:
	var tint := SEPScript.scenario_canvas_tint("scenario_1")
	return tint == Color(1.0, 1.0, 1.0, 1.0)


func test_scenario_canvas_tint_unknown_returns_white() -> bool:
	var tint := SEPScript.scenario_canvas_tint("scenario_99")
	return tint == Color(1.0, 1.0, 1.0, 1.0)


# ══════════════════════════════════════════════════════════════════════════════
# scenario_mood_name()
# ══════════════════════════════════════════════════════════════════════════════

func test_scenario_mood_name_known() -> bool:
	return SEPScript.scenario_mood_name("scenario_2") == "Plague"


func test_scenario_mood_name_unknown_returns_unknown() -> bool:
	return SEPScript.scenario_mood_name("scenario_99") == "Unknown"


# ══════════════════════════════════════════════════════════════════════════════
# district_fill() / district_border()
# ══════════════════════════════════════════════════════════════════════════════

func test_district_fill_known() -> bool:
	var col := SEPScript.district_fill("Noble Quarter")
	return col == SEPScript.DISTRICT_PALETTES["Noble Quarter"]["fill"]


func test_district_fill_unknown_fallback() -> bool:
	var col := SEPScript.district_fill("Unknown Place")
	# Fallback is grey with alpha ≈ 0.07
	return absf(col.r - 0.5) < 0.01 and absf(col.a - 0.07) < 0.01


func test_district_border_known() -> bool:
	var col := SEPScript.district_border("Market Square")
	return col == SEPScript.DISTRICT_PALETTES["Market Square"]["border"]


func test_district_border_unknown_fallback() -> bool:
	var col := SEPScript.district_border("Nowhere")
	# Fallback is grey with alpha ≈ 0.24
	return absf(col.r - 0.5) < 0.01 and absf(col.a - 0.24) < 0.01


# ══════════════════════════════════════════════════════════════════════════════
# all_scenario_ids() / all_district_labels()
# ══════════════════════════════════════════════════════════════════════════════

func test_all_scenario_ids_count() -> bool:
	return SEPScript.all_scenario_ids().size() == 6


func test_all_district_labels_count() -> bool:
	return SEPScript.all_district_labels().size() == 5

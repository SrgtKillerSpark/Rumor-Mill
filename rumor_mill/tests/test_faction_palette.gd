## test_faction_palette.gd — Unit tests for FactionPalette palette constants and
## static accessors (SPA-1065).
##
## Covers:
##   • ZONE_COLORS   — six entries, all semi-transparent (alpha ≈ 0.38)
##   • BADGE_COLORS  — six entries, all fully opaque (alpha == 1.0)
##   • DISPLAY_NAMES — six entries
##   • zone_color()  — known faction returns correct color; unknown returns grey fallback
##   • badge_color() — known faction returns correct color; unknown returns grey fallback
##   • display_name()— known faction returns label; unknown returns capitalized id
##   • all_ids()     — returns six entries matching ZONE_COLORS keys
##
## Strategy: FactionPalette is a pure-static class_name with no Node dependency.
## All tests exercise the preloaded script directly — no instantiation needed.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestFactionPalette
extends RefCounted

const FactionPaletteScript := preload("res://scripts/faction_palette.gd")


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── ZONE_COLORS ──
		"test_zone_colors_has_six_entries",
		"test_zone_colors_clergy_alpha",
		"test_zone_colors_all_semi_transparent",

		# ── BADGE_COLORS ──
		"test_badge_colors_has_six_entries",
		"test_badge_colors_all_opaque",

		# ── DISPLAY_NAMES ──
		"test_display_names_has_six_entries",
		"test_display_names_clergy_label",

		# ── zone_color() ──
		"test_zone_color_known_faction",
		"test_zone_color_unknown_returns_fallback",

		# ── badge_color() ──
		"test_badge_color_known_faction",
		"test_badge_color_unknown_returns_fallback",

		# ── display_name() ──
		"test_display_name_known_faction",
		"test_display_name_unknown_capitalizes",

		# ── all_ids() ──
		"test_all_ids_count",
		"test_all_ids_contains_gameplay_factions",
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
# ZONE_COLORS
# ══════════════════════════════════════════════════════════════════════════════

func test_zone_colors_has_six_entries() -> bool:
	return FactionPaletteScript.ZONE_COLORS.size() == 6


func test_zone_colors_clergy_alpha() -> bool:
	var col: Color = FactionPaletteScript.ZONE_COLORS["clergy"]
	return absf(col.a - 0.38) < 0.01


func test_zone_colors_all_semi_transparent() -> bool:
	for key in FactionPaletteScript.ZONE_COLORS:
		var col: Color = FactionPaletteScript.ZONE_COLORS[key]
		if col.a >= 1.0:
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# BADGE_COLORS
# ══════════════════════════════════════════════════════════════════════════════

func test_badge_colors_has_six_entries() -> bool:
	return FactionPaletteScript.BADGE_COLORS.size() == 6


func test_badge_colors_all_opaque() -> bool:
	for key in FactionPaletteScript.BADGE_COLORS:
		var col: Color = FactionPaletteScript.BADGE_COLORS[key]
		if absf(col.a - 1.0) > 0.001:
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# DISPLAY_NAMES
# ══════════════════════════════════════════════════════════════════════════════

func test_display_names_has_six_entries() -> bool:
	return FactionPaletteScript.DISPLAY_NAMES.size() == 6


func test_display_names_clergy_label() -> bool:
	return FactionPaletteScript.DISPLAY_NAMES["clergy"] == "The Church"


# ══════════════════════════════════════════════════════════════════════════════
# zone_color()
# ══════════════════════════════════════════════════════════════════════════════

func test_zone_color_known_faction() -> bool:
	var col := FactionPaletteScript.zone_color("merchant")
	return col == FactionPaletteScript.ZONE_COLORS["merchant"]


func test_zone_color_unknown_returns_fallback() -> bool:
	var col := FactionPaletteScript.zone_color("nonexistent_faction")
	# Fallback is neutral grey with alpha ≈ 0.35
	return absf(col.r - 0.5) < 0.01 and absf(col.a - 0.35) < 0.01


# ══════════════════════════════════════════════════════════════════════════════
# badge_color()
# ══════════════════════════════════════════════════════════════════════════════

func test_badge_color_known_faction() -> bool:
	var col := FactionPaletteScript.badge_color("noble")
	return col == FactionPaletteScript.BADGE_COLORS["noble"]


func test_badge_color_unknown_returns_fallback() -> bool:
	var col := FactionPaletteScript.badge_color("ghost")
	# Fallback is neutral grey, fully opaque
	return absf(col.r - 0.5) < 0.01 and absf(col.a - 1.0) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# display_name()
# ══════════════════════════════════════════════════════════════════════════════

func test_display_name_known_faction() -> bool:
	return FactionPaletteScript.display_name("merchant") == "Merchant Guild"


func test_display_name_unknown_capitalizes() -> bool:
	# Falls back to String.capitalize() of the id
	var result := FactionPaletteScript.display_name("some_faction")
	return result == "some_faction".capitalize()


# ══════════════════════════════════════════════════════════════════════════════
# all_ids()
# ══════════════════════════════════════════════════════════════════════════════

func test_all_ids_count() -> bool:
	return FactionPaletteScript.all_ids().size() == 6


func test_all_ids_contains_gameplay_factions() -> bool:
	var ids := FactionPaletteScript.all_ids()
	return "clergy" in ids and "merchant" in ids and "noble" in ids

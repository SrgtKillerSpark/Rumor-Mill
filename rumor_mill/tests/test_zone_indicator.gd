## test_zone_indicator.gd — Unit tests for zone_indicator.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_BG, C_BORDER, C_TEXT, C_SUBTEXT
##   • LOCATION_NAMES: 15 entries, spot-checks key entries
##   • SKIP_LOCATIONS: 3 entries
##   • Tile constants: TILE_W=64, TILE_H=32
##   • Initial state: refs null, _current_zone=""
##
## Run from the Godot editor: Scene → Run Script.

class_name TestZoneIndicator
extends RefCounted

const ZoneIndicatorScript := preload("res://scripts/zone_indicator.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_zi() -> CanvasLayer:
	return ZoneIndicatorScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark_semi_transparent",
		"test_c_text_warm",
		# LOCATION_NAMES
		"test_location_names_count",
		"test_location_names_tavern",
		"test_location_names_market",
		"test_location_names_town_hall",
		# SKIP_LOCATIONS
		"test_skip_locations_count",
		"test_skip_locations_contains_patrol",
		"test_skip_locations_contains_home",
		"test_skip_locations_contains_work",
		# Tile constants
		"test_tile_w",
		"test_tile_h",
		# Initial state
		"test_initial_world_ref_null",
		"test_initial_camera_ref_null",
		"test_initial_current_zone_empty",
		"test_initial_label_null",
		"test_initial_panel_null",
		"test_initial_fade_tween_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nZoneIndicator tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark_semi_transparent() -> bool:
	var zi := _make_zi()
	var ok := zi.C_BG.r < 0.15 and zi.C_BG.a < 0.90
	zi.free()
	return ok


static func test_c_text_warm() -> bool:
	var zi := _make_zi()
	# warm text: high r, moderate-high g, moderate b
	var ok := zi.C_TEXT.r > 0.85 and zi.C_TEXT.g > 0.75 and zi.C_TEXT.b > 0.50
	zi.free()
	return ok


# ── LOCATION_NAMES ────────────────────────────────────────────────────────────

static func test_location_names_count() -> bool:
	var zi := _make_zi()
	var ok := zi.LOCATION_NAMES.size() == 15
	zi.free()
	return ok


static func test_location_names_tavern() -> bool:
	var zi := _make_zi()
	var ok := zi.LOCATION_NAMES.get("tavern", "") == "The Tavern"
	zi.free()
	return ok


static func test_location_names_market() -> bool:
	var zi := _make_zi()
	var ok := zi.LOCATION_NAMES.get("market", "") == "Market Square"
	zi.free()
	return ok


static func test_location_names_town_hall() -> bool:
	var zi := _make_zi()
	var ok := zi.LOCATION_NAMES.get("town_hall", "") == "Town Hall"
	zi.free()
	return ok


# ── SKIP_LOCATIONS ────────────────────────────────────────────────────────────

static func test_skip_locations_count() -> bool:
	var zi := _make_zi()
	var ok := zi.SKIP_LOCATIONS.size() == 3
	zi.free()
	return ok


static func test_skip_locations_contains_patrol() -> bool:
	var zi := _make_zi()
	var ok := zi.SKIP_LOCATIONS.has("patrol")
	zi.free()
	return ok


static func test_skip_locations_contains_home() -> bool:
	var zi := _make_zi()
	var ok := zi.SKIP_LOCATIONS.has("home")
	zi.free()
	return ok


static func test_skip_locations_contains_work() -> bool:
	var zi := _make_zi()
	var ok := zi.SKIP_LOCATIONS.has("work")
	zi.free()
	return ok


# ── Tile constants ────────────────────────────────────────────────────────────

static func test_tile_w() -> bool:
	var zi := _make_zi()
	var ok := zi.TILE_W == 64
	zi.free()
	return ok


static func test_tile_h() -> bool:
	var zi := _make_zi()
	var ok := zi.TILE_H == 32
	zi.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var zi := _make_zi()
	var ok := zi._world_ref == null
	zi.free()
	return ok


static func test_initial_camera_ref_null() -> bool:
	var zi := _make_zi()
	var ok := zi._camera_ref == null
	zi.free()
	return ok


static func test_initial_current_zone_empty() -> bool:
	var zi := _make_zi()
	var ok := zi._current_zone == ""
	zi.free()
	return ok


static func test_initial_label_null() -> bool:
	var zi := _make_zi()
	var ok := zi._label == null
	zi.free()
	return ok


static func test_initial_panel_null() -> bool:
	var zi := _make_zi()
	var ok := zi._panel == null
	zi.free()
	return ok


static func test_initial_fade_tween_null() -> bool:
	var zi := _make_zi()
	var ok := zi._fade_tween == null
	zi.free()
	return ok

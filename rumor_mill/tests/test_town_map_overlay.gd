## test_town_map_overlay.gd — Unit tests for town_map_overlay.gd (SPA-1042).
##
## Covers:
##   • Tile constants: TILE_W=64, TILE_H=32
##   • REFRESH_INTERVAL, MAX_COUNT_FOR_SCALE, GATHER_RADIUS
##   • FACTION_COLORS: 3 entries (merchant, noble, clergy)
##   • Initial state: _npcs=[], _gathering_points={}, _npc_counts={},
##                    _pulse=0.0, _refresh_timer=0.0
##
## Run from the Godot editor: Scene → Run Script.

class_name TestTownMapOverlay
extends RefCounted

const TownMapOverlayScript := preload("res://scripts/town_map_overlay.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_tmo() -> Node2D:
	return TownMapOverlayScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Tile constants
		"test_tile_w",
		"test_tile_h",
		# Behaviour constants
		"test_refresh_interval",
		"test_max_count_for_scale",
		"test_gather_radius",
		# FACTION_COLORS
		"test_faction_colors_count",
		"test_faction_colors_merchant_blue",
		"test_faction_colors_noble_red",
		"test_faction_colors_clergy_yellow",
		# Initial state
		"test_initial_npcs_empty",
		"test_initial_gathering_points_empty",
		"test_initial_npc_counts_empty",
		"test_initial_pulse_zero",
		"test_initial_refresh_timer_zero",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTownMapOverlay tests: %d passed, %d failed" % [passed, failed])


# ── Tile constants ────────────────────────────────────────────────────────────

static func test_tile_w() -> bool:
	var t := _make_tmo()
	var ok := t.TILE_W == 64
	t.free()
	return ok


static func test_tile_h() -> bool:
	var t := _make_tmo()
	var ok := t.TILE_H == 32
	t.free()
	return ok


# ── Behaviour constants ───────────────────────────────────────────────────────

static func test_refresh_interval() -> bool:
	var t := _make_tmo()
	var ok := t.REFRESH_INTERVAL == 2.5
	t.free()
	return ok


static func test_max_count_for_scale() -> bool:
	var t := _make_tmo()
	var ok := t.MAX_COUNT_FOR_SCALE == 8
	t.free()
	return ok


static func test_gather_radius() -> bool:
	var t := _make_tmo()
	var ok := t.GATHER_RADIUS == 3
	t.free()
	return ok


# ── FACTION_COLORS ────────────────────────────────────────────────────────────

static func test_faction_colors_count() -> bool:
	var t := _make_tmo()
	var ok := t.FACTION_COLORS.size() == 3
	t.free()
	return ok


static func test_faction_colors_merchant_blue() -> bool:
	var t := _make_tmo()
	var c: Color = t.FACTION_COLORS.get("merchant", Color.BLACK)
	var ok := c.b > 0.70 and c.r < 0.30
	t.free()
	return ok


static func test_faction_colors_noble_red() -> bool:
	var t := _make_tmo()
	var c: Color = t.FACTION_COLORS.get("noble", Color.BLACK)
	var ok := c.r > 0.65 and c.b < 0.25
	t.free()
	return ok


static func test_faction_colors_clergy_yellow() -> bool:
	var t := _make_tmo()
	var c: Color = t.FACTION_COLORS.get("clergy", Color.BLACK)
	var ok := c.r > 0.70 and c.g > 0.60 and c.b < 0.15
	t.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_npcs_empty() -> bool:
	var t := _make_tmo()
	var ok := t._npcs.is_empty()
	t.free()
	return ok


static func test_initial_gathering_points_empty() -> bool:
	var t := _make_tmo()
	var ok := t._gathering_points.is_empty()
	t.free()
	return ok


static func test_initial_npc_counts_empty() -> bool:
	var t := _make_tmo()
	var ok := t._npc_counts.is_empty()
	t.free()
	return ok


static func test_initial_pulse_zero() -> bool:
	var t := _make_tmo()
	var ok := t._pulse == 0.0
	t.free()
	return ok


static func test_initial_refresh_timer_zero() -> bool:
	var t := _make_tmo()
	var ok := t._refresh_timer == 0.0
	t.free()
	return ok

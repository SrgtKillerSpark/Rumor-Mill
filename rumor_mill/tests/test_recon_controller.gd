## test_recon_controller.gd — Unit tests for ReconController (SPA-1012).
##
## Covers:
##   • Constants: EAVESDROP_RANGE_TILES, EAVESDROP_FAIL_CHANCE, NPC_HIT_RADIUS_PX, BUILDING_HIT_TILES
##   • Constants: OVERHEAR_RADIUS_TILES, OVERHEAR_COOLDOWN_TICKS, OVERHEAR_MAX_PER_TICK
##   • Constants: BLDG_HALF_W, BLDG_HALF_H, TOOLTIP_OFFSET, NPC_NORMAL_MODULATE
##   • OVERHEAR_SNIPPETS — non-empty pool
##   • Initial state: _world_ref, _intel_store, _building_hover_fired, _eavesdrop_hover_fired,
##                    _overhear_cooldowns, _follow_npc
##   • _current_tick() returns 0 when _world_ref is null
##   • _world_to_cell(): origin, known positive cell, negative world coordinates
##   • _cell_to_world(): origin, known positive cell, asymmetric cell
##   • Round-trip inverses: cell→world→cell and world→cell→world
##   • _belief_trend(): rising (≤3), stable (4–8), fading (>8), boundary values
##
## ReconController extends Node. _ready() is never called (not added to a scene tree),
## so all UI node refs remain null. Only data-field and pure-logic methods are tested.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestReconController
extends RefCounted

const ReconControllerScript := preload("res://scripts/recon_controller.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Return a fresh ReconController instance (not in scene tree, setup() never called).
static func _make_rc() -> Node:
	return ReconControllerScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_eavesdrop_range_tiles_constant",
		"test_eavesdrop_fail_chance_constant",
		"test_npc_hit_radius_constant",
		"test_building_hit_tiles_constant",
		"test_overhear_radius_constant",
		"test_overhear_cooldown_constant",
		"test_overhear_max_per_tick_constant",
		"test_bldg_half_w_constant",
		"test_bldg_half_h_constant",
		"test_tooltip_offset_constant",
		"test_npc_normal_modulate_is_white",
		"test_overhear_snippets_nonempty",
		# Initial state
		"test_initial_world_ref_null",
		"test_initial_intel_store_null",
		"test_initial_building_hover_guard_false",
		"test_initial_eavesdrop_hover_guard_false",
		"test_initial_overhear_cooldowns_empty",
		"test_initial_follow_npc_null",
		# _current_tick
		"test_current_tick_no_world_returns_zero",
		# _world_to_cell
		"test_world_to_cell_origin",
		"test_world_to_cell_known_positive",
		"test_world_to_cell_negative_x",
		# _cell_to_world
		"test_cell_to_world_origin",
		"test_cell_to_world_known_positive",
		"test_cell_to_world_asymmetric",
		# Round-trip inverses
		"test_cell_world_cell_roundtrip",
		"test_world_cell_world_roundtrip",
		# _belief_trend
		"test_belief_trend_zero_is_rising",
		"test_belief_trend_three_is_rising",
		"test_belief_trend_four_is_stable",
		"test_belief_trend_eight_is_stable",
		"test_belief_trend_nine_is_fading",
		"test_belief_trend_large_value_is_fading",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nReconController tests: %d passed, %d failed" % [passed, failed])


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_eavesdrop_range_tiles_constant() -> bool:
	var rc := _make_rc()
	return rc.EAVESDROP_RANGE_TILES == 3


static func test_eavesdrop_fail_chance_constant() -> bool:
	var rc := _make_rc()
	return is_equal_approx(rc.EAVESDROP_FAIL_CHANCE, 0.20)


static func test_npc_hit_radius_constant() -> bool:
	var rc := _make_rc()
	return is_equal_approx(rc.NPC_HIT_RADIUS_PX, 52.0)


static func test_building_hit_tiles_constant() -> bool:
	var rc := _make_rc()
	return rc.BUILDING_HIT_TILES == 2


static func test_overhear_radius_constant() -> bool:
	var rc := _make_rc()
	return rc.OVERHEAR_RADIUS_TILES == 2


static func test_overhear_cooldown_constant() -> bool:
	var rc := _make_rc()
	return rc.OVERHEAR_COOLDOWN_TICKS == 8


static func test_overhear_max_per_tick_constant() -> bool:
	var rc := _make_rc()
	return rc.OVERHEAR_MAX_PER_TICK == 2


static func test_bldg_half_w_constant() -> bool:
	var rc := _make_rc()
	return is_equal_approx(rc.BLDG_HALF_W, 36.0)


static func test_bldg_half_h_constant() -> bool:
	var rc := _make_rc()
	return is_equal_approx(rc.BLDG_HALF_H, 20.0)


static func test_tooltip_offset_constant() -> bool:
	var rc := _make_rc()
	return rc.TOOLTIP_OFFSET == Vector2(14.0, -32.0)


static func test_npc_normal_modulate_is_white() -> bool:
	var rc := _make_rc()
	return rc.NPC_NORMAL_MODULATE == Color(1.0, 1.0, 1.0, 1.0)


static func test_overhear_snippets_nonempty() -> bool:
	var rc := _make_rc()
	return rc.OVERHEAR_SNIPPETS.size() > 0


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var rc := _make_rc()
	return rc._world_ref == null


static func test_initial_intel_store_null() -> bool:
	var rc := _make_rc()
	return rc._intel_store == null


static func test_initial_building_hover_guard_false() -> bool:
	var rc := _make_rc()
	return rc._building_hover_fired == false


static func test_initial_eavesdrop_hover_guard_false() -> bool:
	var rc := _make_rc()
	return rc._eavesdrop_hover_fired == false


static func test_initial_overhear_cooldowns_empty() -> bool:
	var rc := _make_rc()
	return rc._overhear_cooldowns.is_empty()


static func test_initial_follow_npc_null() -> bool:
	var rc := _make_rc()
	return rc._follow_npc == null


# ── _current_tick ─────────────────────────────────────────────────────────────

static func test_current_tick_no_world_returns_zero() -> bool:
	var rc := _make_rc()
	return rc._current_tick() == 0


# ── _world_to_cell ────────────────────────────────────────────────────────────

## world_to_cell(Vector2(0, 0)) == Vector2i(0, 0)
static func test_world_to_cell_origin() -> bool:
	var rc := _make_rc()
	return rc._world_to_cell(Vector2(0.0, 0.0)) == Vector2i(0, 0)


## Cell (2, 1): world_x = (2-1)*32 = 32, world_y = (2+1)*16 = 48
## Inverse: cx = 32/64 + 48/32 = 0.5 + 1.5 = 2  →  round → 2
##          cy = 48/32 - 32/64 = 1.5 - 0.5 = 1  →  round → 1
static func test_world_to_cell_known_positive() -> bool:
	var rc := _make_rc()
	return rc._world_to_cell(Vector2(32.0, 48.0)) == Vector2i(2, 1)


## Cell (-1, 2): world_x = (-1-2)*32 = -96, world_y = (-1+2)*16 = 16
## Inverse: cx = -96/64 + 16/32 = -1.5 + 0.5 = -1.0  → round → -1
##          cy =  16/32 + 96/64 =  0.5 + 1.5 =  2.0   → round →  2
static func test_world_to_cell_negative_x() -> bool:
	var rc := _make_rc()
	return rc._world_to_cell(Vector2(-96.0, 16.0)) == Vector2i(-1, 2)


# ── _cell_to_world ────────────────────────────────────────────────────────────

static func test_cell_to_world_origin() -> bool:
	var rc := _make_rc()
	return rc._cell_to_world(Vector2i(0, 0)) == Vector2.ZERO


## Cell (3, 1): world_x = (3-1)*32 = 64, world_y = (3+1)*16 = 64
static func test_cell_to_world_known_positive() -> bool:
	var rc := _make_rc()
	return rc._cell_to_world(Vector2i(3, 1)) == Vector2(64.0, 64.0)


## Cell (1, 3): world_x = (1-3)*32 = -64, world_y = (1+3)*16 = 64
static func test_cell_to_world_asymmetric() -> bool:
	var rc := _make_rc()
	return rc._cell_to_world(Vector2i(1, 3)) == Vector2(-64.0, 64.0)


# ── Round-trip inverses ───────────────────────────────────────────────────────

## Ensure world_to_cell(cell_to_world(cell)) == cell for a non-trivial cell.
static func test_cell_world_cell_roundtrip() -> bool:
	var rc := _make_rc()
	var cell := Vector2i(5, 3)
	return rc._world_to_cell(rc._cell_to_world(cell)) == cell


## Ensure cell_to_world(world_to_cell(world)) == world for a clean integer cell.
## Uses cell (2, 1) → world (32, 48) as the reference point.
static func test_world_cell_world_roundtrip() -> bool:
	var rc := _make_rc()
	var world := Vector2(32.0, 48.0)
	return rc._cell_to_world(rc._world_to_cell(world)) == world


# ── _belief_trend ─────────────────────────────────────────────────────────────

static func test_belief_trend_zero_is_rising() -> bool:
	var rc := _make_rc()
	return rc._belief_trend(0) == "↑ rising"


## Boundary: ticks_in_state == 3 is still rising (condition is <= 3).
static func test_belief_trend_three_is_rising() -> bool:
	var rc := _make_rc()
	return rc._belief_trend(3) == "↑ rising"


## Boundary: ticks_in_state == 4 crosses into stable.
static func test_belief_trend_four_is_stable() -> bool:
	var rc := _make_rc()
	return rc._belief_trend(4) == "→ stable"


## Boundary: ticks_in_state == 8 is still stable (condition is <= 8).
static func test_belief_trend_eight_is_stable() -> bool:
	var rc := _make_rc()
	return rc._belief_trend(8) == "→ stable"


## Boundary: ticks_in_state == 9 crosses into fading.
static func test_belief_trend_nine_is_fading() -> bool:
	var rc := _make_rc()
	return rc._belief_trend(9) == "↓ fading"


static func test_belief_trend_large_value_is_fading() -> bool:
	var rc := _make_rc()
	return rc._belief_trend(999) == "↓ fading"

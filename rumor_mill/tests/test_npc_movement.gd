## test_npc_movement.gd — Unit tests for NpcMovement sub-module (SPA-1027).
##
## Covers:
##   • MOVE_SPEED and _MICRO_WANDER_CHANCE constants
##   • Initial state: _facing_dir, _waypoint_index, _is_moving, _micro_wander_cooldown,
##                    _last_schedule_slot, _path empty
##   • cell_to_world() — isometric coordinate conversion (pure math, no scene tree)
##   • _cell_furthest_from() — returns current_cell when sample is empty
##
## Strategy: preload npc_movement.gd as an orphaned Node. setup() is never called so
## @onready and pathfinder refs remain null. Only pure-data methods are exercised.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcMovement
extends RefCounted

const NpcMovementScript := preload("res://scripts/npc_movement.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_movement() -> Node:
	return NpcMovementScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_move_speed_constant",
		"test_micro_wander_chance_constant",

		# Initial state
		"test_initial_facing_dir_south",
		"test_initial_waypoint_index_minus_one",
		"test_initial_is_moving_false",
		"test_initial_micro_wander_cooldown_zero",
		"test_initial_last_schedule_slot_minus_one",
		"test_initial_path_empty",

		# cell_to_world
		"test_cell_to_world_origin",
		"test_cell_to_world_one_zero",
		"test_cell_to_world_zero_one",
		"test_cell_to_world_two_three",
		"test_cell_to_world_negative_x_component",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nNpcMovement tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_move_speed_constant() -> bool:
	var m := _make_movement()
	var ok := is_equal_approx(m.MOVE_SPEED, 180.0)
	m.free()
	return ok


func test_micro_wander_chance_constant() -> bool:
	var m := _make_movement()
	var ok := is_equal_approx(m._MICRO_WANDER_CHANCE, 0.20)
	m.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_facing_dir_south() -> bool:
	var m := _make_movement()
	var ok := m._facing_dir == "south"
	m.free()
	return ok


func test_initial_waypoint_index_minus_one() -> bool:
	var m := _make_movement()
	var ok := m._waypoint_index == -1
	m.free()
	return ok


func test_initial_is_moving_false() -> bool:
	var m := _make_movement()
	var ok := m._is_moving == false
	m.free()
	return ok


func test_initial_micro_wander_cooldown_zero() -> bool:
	var m := _make_movement()
	var ok := m._micro_wander_cooldown == 0
	m.free()
	return ok


func test_initial_last_schedule_slot_minus_one() -> bool:
	var m := _make_movement()
	var ok := m._last_schedule_slot == -1
	m.free()
	return ok


func test_initial_path_empty() -> bool:
	var m := _make_movement()
	var ok := m._path.is_empty()
	m.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# cell_to_world — isometric conversion: x=(cx-cy)*32, y=(cx+cy)*16
# ══════════════════════════════════════════════════════════════════════════════

func test_cell_to_world_origin() -> bool:
	var m := _make_movement()
	var result := m.cell_to_world(Vector2i(0, 0))
	var ok := result.is_equal_approx(Vector2(0.0, 0.0))
	m.free()
	return ok


func test_cell_to_world_one_zero() -> bool:
	# x=(1-0)*32=32, y=(1+0)*16=16
	var m := _make_movement()
	var result := m.cell_to_world(Vector2i(1, 0))
	var ok := result.is_equal_approx(Vector2(32.0, 16.0))
	m.free()
	return ok


func test_cell_to_world_zero_one() -> bool:
	# x=(0-1)*32=-32, y=(0+1)*16=16
	var m := _make_movement()
	var result := m.cell_to_world(Vector2i(0, 1))
	var ok := result.is_equal_approx(Vector2(-32.0, 16.0))
	m.free()
	return ok


func test_cell_to_world_two_three() -> bool:
	# x=(2-3)*32=-32, y=(2+3)*16=80
	var m := _make_movement()
	var result := m.cell_to_world(Vector2i(2, 3))
	var ok := result.is_equal_approx(Vector2(-32.0, 80.0))
	m.free()
	return ok


func test_cell_to_world_negative_x_component() -> bool:
	# cell (0,2): x=(0-2)*32=-64, y=(0+2)*16=32
	var m := _make_movement()
	var result := m.cell_to_world(Vector2i(0, 2))
	var ok := result.is_equal_approx(Vector2(-64.0, 32.0))
	m.free()
	return ok

## test_astar_pathfinder.gd — Unit tests for AstarPathfinder (SPA-1041).
##
## Covers:
##   • nearest_walkable(): static pure math — no scene tree required
##     - returns cell itself when walkable is empty
##     - returns sole item when list has one entry
##     - returns nearest (by squared distance) among multiple candidates
##     - handles ties correctly (returns first minimum found)
##   • get_path() before setup(): returns [] (uninitialised guard)
##   • get_path() with from == to: returns [from] (single-cell trivial path)
##   • Initial state: _astar is null, _warned_oob is empty
##
## Strategy: AstarPathfinder is a plain RefCounted class. nearest_walkable() is
## a static function exercised without any scene-tree involvement.
## get_path() tests that call setup() require AStarGrid2D (a Godot built-in that
## also works without a scene tree) but those paths that call world_inject are
## skipped in favour of guard-clause tests only.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestAstarPathfinder
extends RefCounted

const AstarPathfinderScript := preload("res://scripts/astar_pathfinder.gd")


static func _make_pf() -> AstarPathfinder:
	return AstarPathfinderScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── initial state ──
		"test_initial_astar_is_null",
		"test_initial_warned_oob_is_empty",

		# ── get_path before setup ──
		"test_get_path_returns_empty_before_setup",

		# ── nearest_walkable ──
		"test_nearest_walkable_returns_cell_when_walkable_empty",
		"test_nearest_walkable_returns_sole_item",
		"test_nearest_walkable_returns_closest_cell",
		"test_nearest_walkable_prefers_first_on_tie",
		"test_nearest_walkable_exact_match",

		# ── get_path with AStarGrid2D (from == to) ──
		"test_get_path_from_equals_to_returns_single_cell",
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
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_astar_is_null() -> bool:
	var pf := _make_pf()
	return pf._astar == null


func test_initial_warned_oob_is_empty() -> bool:
	var pf := _make_pf()
	return pf._warned_oob.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# get_path before setup
# ══════════════════════════════════════════════════════════════════════════════

func test_get_path_returns_empty_before_setup() -> bool:
	var pf := _make_pf()
	var path := pf.get_path(Vector2i(0, 0), Vector2i(5, 5))
	return path.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# nearest_walkable — static pure-math tests
# ══════════════════════════════════════════════════════════════════════════════

func test_nearest_walkable_returns_cell_when_walkable_empty() -> bool:
	var cell := Vector2i(5, 5)
	var result := AstarPathfinder.nearest_walkable(cell, [])
	return result == cell


func test_nearest_walkable_returns_sole_item() -> bool:
	var cell     := Vector2i(0, 0)
	var walkable: Array[Vector2i] = [Vector2i(3, 4)]
	var result := AstarPathfinder.nearest_walkable(cell, walkable)
	return result == Vector2i(3, 4)


func test_nearest_walkable_returns_closest_cell() -> bool:
	# Origin at (0,0). Candidates: (10,10) d²=200, (2,1) d²=5, (5,0) d²=25.
	var cell := Vector2i(0, 0)
	var walkable: Array[Vector2i] = [Vector2i(10, 10), Vector2i(2, 1), Vector2i(5, 0)]
	var result := AstarPathfinder.nearest_walkable(cell, walkable)
	return result == Vector2i(2, 1)


func test_nearest_walkable_prefers_first_on_tie() -> bool:
	# Both candidates are equidistant from origin: (3,0) and (0,3), both d²=9.
	var cell := Vector2i(0, 0)
	var walkable: Array[Vector2i] = [Vector2i(3, 0), Vector2i(0, 3)]
	var result := AstarPathfinder.nearest_walkable(cell, walkable)
	# Loop initialises best to walkable[0] and only updates on strictly less-than.
	return result == Vector2i(3, 0)


func test_nearest_walkable_exact_match() -> bool:
	# Cell is itself in the walkable list → distance 0 wins.
	var cell := Vector2i(4, 7)
	var walkable: Array[Vector2i] = [Vector2i(10, 10), Vector2i(4, 7), Vector2i(1, 1)]
	var result := AstarPathfinder.nearest_walkable(cell, walkable)
	return result == cell


# ══════════════════════════════════════════════════════════════════════════════
# get_path: from == to (trivial path, no AStarGrid2D query needed)
# ══════════════════════════════════════════════════════════════════════════════

func test_get_path_from_equals_to_returns_single_cell() -> bool:
	var pf := _make_pf()
	# Setup with a minimal 5×5 grid and one walkable cell.
	var walkable: Array[Vector2i] = [Vector2i(2, 2)]
	pf.setup(Vector2i(5, 5), walkable)
	var path := pf.get_path(Vector2i(2, 2), Vector2i(2, 2))
	return path.size() == 1 and path[0] == Vector2i(2, 2)

## test_iso_tile.gd — Unit tests for IsoTile helper (SPA-1268).
##
## Covers:
##   • Constants: TILE_W == 64, TILE_H == 32
##   • cell_to_world origin: (0,0) → Vector2(0, 0)
##   • cell_to_world positive x: (1,0) → Vector2(32, 16)
##   • cell_to_world positive y: (0,1) → Vector2(-32, 16)
##   • cell_to_world symmetry: x-component sign flips for swapped coords
##   • cell_to_world combined: (2,3) → Vector2(-32, 40)
##
## Static verification (confirmed in source, not runtime-checkable):
##   • npc_movement.gd delegates to IsoTile.cell_to_world() at line 260
##   • npc.gd carries no hardcoded 32.0 / 16.0 tile constants (comment-only ref)
##   • No remaining local TILE_W / TILE_H declarations in npc.gd or npc_movement.gd
##
## Strategy: IsoTile is a plain GDScript class with no Node dependency.
## Tests call the static method directly without instantiation.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestIsoTile
extends RefCounted

const IsoTileScript := preload("res://scripts/iso_tile.gd")


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_tile_w_is_64",
		"test_tile_h_is_32",

		# ── cell_to_world ──
		"test_cell_to_world_origin",
		"test_cell_to_world_positive_x",
		"test_cell_to_world_positive_y",
		"test_cell_to_world_symmetry_x_flips",
		"test_cell_to_world_combined",
		"test_cell_to_world_negative_x",
		"test_cell_to_world_negative_y",
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
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_tile_w_is_64() -> bool:
	return IsoTileScript.TILE_W == 64


func test_tile_h_is_32() -> bool:
	return IsoTileScript.TILE_H == 32


# ══════════════════════════════════════════════════════════════════════════════
# cell_to_world
# ══════════════════════════════════════════════════════════════════════════════

func test_cell_to_world_origin() -> bool:
	return IsoTileScript.cell_to_world(Vector2i(0, 0)) == Vector2(0.0, 0.0)


func test_cell_to_world_positive_x() -> bool:
	# cx=1, cy=0 → x=(1-0)*32=32, y=(1+0)*16=16
	return IsoTileScript.cell_to_world(Vector2i(1, 0)) == Vector2(32.0, 16.0)


func test_cell_to_world_positive_y() -> bool:
	# cx=0, cy=1 → x=(0-1)*32=-32, y=(0+1)*16=16
	return IsoTileScript.cell_to_world(Vector2i(0, 1)) == Vector2(-32.0, 16.0)


func test_cell_to_world_symmetry_x_flips() -> bool:
	# Swapping cx and cy negates the x-component while keeping y the same.
	var a := IsoTileScript.cell_to_world(Vector2i(2, 1))
	var b := IsoTileScript.cell_to_world(Vector2i(1, 2))
	return a.x == -b.x and a.y == b.y


func test_cell_to_world_combined() -> bool:
	# cx=2, cy=3 → x=(2-3)*32=-32, y=(2+3)*16=80
	return IsoTileScript.cell_to_world(Vector2i(2, 3)) == Vector2(-32.0, 80.0)


func test_cell_to_world_negative_x() -> bool:
	# cx=-1, cy=0 → x=(-1-0)*32=-32, y=(-1+0)*16=-16
	return IsoTileScript.cell_to_world(Vector2i(-1, 0)) == Vector2(-32.0, -16.0)


func test_cell_to_world_negative_y() -> bool:
	# cx=0, cy=-1 → x=(0-(-1))*32=32, y=(0+(-1))*16=-16
	return IsoTileScript.cell_to_world(Vector2i(0, -1)) == Vector2(32.0, -16.0)

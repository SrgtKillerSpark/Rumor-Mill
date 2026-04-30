## iso_tile.gd — Shared isometric tile conversion constants and helpers.
## Single source of truth for TILE_W / TILE_H and the cell ↔ world formula
## used by npc.gd, npc_movement.gd, and related overlay scripts.
##
## SPA-1218: Extracted from npc.gd / npc_movement.gd to eliminate duplicated
## magic numbers (32.0 / 16.0) and local TILE_W / TILE_H redeclarations.

class_name IsoTile

## Full tile width in pixels (horizontal diamond span).
const TILE_W := 64
## Full tile height in pixels (vertical diamond span).
const TILE_H := 32


## Convert an isometric grid cell to its world-space position.
## Formula: world_x = (cx - cy) * TILE_W/2,  world_y = (cx + cy) * TILE_H/2
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0)
	)

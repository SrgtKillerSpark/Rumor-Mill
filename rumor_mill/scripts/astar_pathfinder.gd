## astar_pathfinder.gd — Thin wrapper around AStarGrid2D for the 48×48 town grid.

class_name AstarPathfinder

var _astar: AStarGrid2D
var _grid_size: Vector2i


func setup(grid_size: Vector2i, walkable_cells: Array[Vector2i]) -> void:
	_grid_size = grid_size
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, grid_size.x, grid_size.y)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	# Mark every cell solid first, then carve out walkable ones.
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			_astar.set_point_solid(Vector2i(x, y), true)

	for cell in walkable_cells:
		_astar.set_point_solid(cell, false)


## Returns an Array[Vector2i] path from `from` to `to`, inclusive of both ends.
## Returns an empty array if no path exists or the pathfinder is uninitialised.
func get_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if _astar == null:
		return []
	if from == to:
		return [from]
	# Clamp to region so we never request out-of-bounds points.
	var safe_from := Vector2i(
		clamp(from.x, 0, _grid_size.x - 1),
		clamp(from.y, 0, _grid_size.y - 1)
	)
	var safe_to := Vector2i(
		clamp(to.x, 0, _grid_size.x - 1),
		clamp(to.y, 0, _grid_size.y - 1)
	)
	if _astar.is_point_solid(safe_from) or _astar.is_point_solid(safe_to):
		return []
	var id_path: Array[Vector2i] = _astar.get_id_path(safe_from, safe_to)
	var result: Array[Vector2i] = []
	for p in id_path:
		result.append(Vector2i(p.x, p.y))
	return result


## Convenience: find the nearest walkable cell to `cell` from a provided list.
static func nearest_walkable(cell: Vector2i, walkable: Array[Vector2i]) -> Vector2i:
	var best := walkable[0]
	var best_dist := cell.distance_squared_to(best)
	for w in walkable:
		var d := cell.distance_squared_to(w)
		if d < best_dist:
			best_dist = d
			best = w
	return best

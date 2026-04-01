extends Node2D

## npc.gd — NPC entity: spawns at a grid cell, walks a random path on each
## game tick, and renders as a coloured square placeholder sprite.

const TILE_W := 64
const TILE_H := 32
const MOVE_SPEED := 120.0  # pixels per second (visual tween speed)

var npc_id: int = 0
var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var walkable_cells: Array[Vector2i] = []
var tile_map_layer: TileMapLayer = null

var _is_moving: bool = false
var _tween: Tween = null

# NPC colours for easy visual distinction
const NPC_COLORS := [
	Color.RED, Color.BLUE, Color.GREEN,
	Color.YELLOW, Color.MAGENTA, Color.CYAN,
	Color.ORANGE, Color.PURPLE, Color.LIME_GREEN
]

@onready var sprite: ColorRect = $Sprite
@onready var name_label: Label = $NameLabel


func _ready() -> void:
	# Placeholder: coloured square 16x16 px, centred
	sprite.size = Vector2(16, 16)
	sprite.position = Vector2(-8, -16)
	sprite.color = NPC_COLORS[npc_id % NPC_COLORS.size()]
	name_label.text = "NPC %d" % npc_id
	name_label.position = Vector2(-16, -28)


func init(id: int, start_cell: Vector2i, walkable: Array[Vector2i], tilemap: TileMapLayer) -> void:
	npc_id = id
	current_cell = start_cell
	target_cell = start_cell
	walkable_cells = walkable
	tile_map_layer = tilemap
	position = _cell_to_world(start_cell)


## Called each game tick by World.on_game_tick().
func on_tick(_tick: int) -> void:
	if _is_moving:
		return  # still travelling from last tick
	_pick_next_cell()
	_walk_to(target_cell)


func _pick_next_cell() -> void:
	# Simple random walk: pick a random neighbour that is walkable.
	var neighbours := _get_walkable_neighbours(current_cell)
	if neighbours.is_empty():
		return
	target_cell = neighbours[randi() % neighbours.size()]


func _get_walkable_neighbours(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets := [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
	for offset in offsets:
		var neighbour := cell + offset
		if neighbour in walkable_cells:
			result.append(neighbour)
	return result


func _walk_to(cell: Vector2i) -> void:
	if cell == current_cell:
		return
	_is_moving = true
	var world_pos := _cell_to_world(cell)
	var duration := position.distance_to(world_pos) / MOVE_SPEED
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", world_pos, duration).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_move_finished.bind(cell), CONNECT_ONE_SHOT)


func _on_move_finished(arrived_cell: Vector2i) -> void:
	current_cell = arrived_cell
	_is_moving = false


## Convert isometric grid coordinates to world (screen) position.
## Formula for 2:1 isometric (tile size 64×32):
##   screen_x = (x - y) * (TILE_W / 2)
##   screen_y = (x + y) * (TILE_H / 2)
func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0)
	)

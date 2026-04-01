extends Node2D

## World.gd — loads the 48x48 town grid, places buildings, spawns NPCs,
## and owns the game-tick loop that drives NPC movement and day/night.

const TILE_SIZE := Vector2i(64, 32)   # isometric bounding box (2:1 ratio)
const GRID_W := 48
const GRID_H := 48

# Source IDs in the TileSet (one atlas per tile category)
const SRC_GROUND := 0
const SRC_ROAD_DIRT := 1
const SRC_ROAD_STONE := 2
const SRC_BUILDING := 3

# Atlas coords per tile type within SRC_GROUND
const ATLAS_VOID := Vector2i(0, 0)
const ATLAS_GRASS := Vector2i(1, 0)
const ATLAS_ROAD_DIRT := Vector2i(0, 0)
const ATLAS_ROAD_STONE := Vector2i(1, 0)

# Building atlas coords (one row per building type)
const ATLAS_MANOR := Vector2i(0, 0)
const ATLAS_TAVERN := Vector2i(1, 0)
const ATLAS_CHAPEL := Vector2i(2, 0)
const ATLAS_MARKET := Vector2i(3, 0)
const ATLAS_WELL := Vector2i(4, 0)

@export var npc_scene: PackedScene
@export var npc_count: int = 6

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
@onready var npc_container: Node2D = $NPCContainer
@onready var day_night: Node = $DayNightCycle

var grid_data: Dictionary = {}
var buildings: Array = []
var npcs: Array = []
var walkable_cells: Array[Vector2i] = []

func _ready() -> void:
	_load_grid()
	_paint_terrain()
	_place_buildings()
	_collect_walkable_cells()
	_spawn_npcs()


func _load_grid() -> void:
	var path := "res://data/town_grid.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("World: cannot open %s" % path)
		return
	var text := file.get_as_text()
	file.close()
	var result := JSON.parse_string(text)
	if result == null:
		push_error("World: failed to parse town_grid.json")
		return
	grid_data = result
	buildings = grid_data.get("buildings", [])


func _paint_terrain() -> void:
	if grid_data.is_empty():
		return
	var rows: Array = grid_data["grid"]
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell_type: int = rows[y][x]
			var coords := Vector2i(x, y)
			match cell_type:
				0:  # void — skip, leave empty
					pass
				1:  # grass ground
					terrain_layer.set_cell(coords, SRC_GROUND, ATLAS_GRASS)
				2:  # dirt road
					terrain_layer.set_cell(coords, SRC_ROAD_DIRT, ATLAS_ROAD_DIRT)
				3:  # stone road
					terrain_layer.set_cell(coords, SRC_ROAD_STONE, ATLAS_ROAD_STONE)
				8:  # well (terrain layer)
					terrain_layer.set_cell(coords, SRC_GROUND, ATLAS_GRASS)
					building_layer.set_cell(coords, SRC_BUILDING, ATLAS_WELL)
				_:  # building footprint — terrain underneath is grass
					terrain_layer.set_cell(coords, SRC_GROUND, ATLAS_GRASS)


func _place_buildings() -> void:
	for b in buildings:
		var atlas_coord: Vector2i
		match b["name"]:
			"manor":   atlas_coord = ATLAS_MANOR
			"tavern":  atlas_coord = ATLAS_TAVERN
			"chapel":  atlas_coord = ATLAS_CHAPEL
			"market":  atlas_coord = ATLAS_MARKET
			_:         continue
		# Place the top-left anchor tile; the sprite size covers the footprint visually.
		var anchor := Vector2i(b["x"], b["y"])
		building_layer.set_cell(anchor, SRC_BUILDING, atlas_coord)


func _collect_walkable_cells() -> void:
	if grid_data.is_empty():
		return
	var rows: Array = grid_data["grid"]
	var walkable_types: Array = grid_data.get("walkable_types", [1, 2, 3, 8])
	for y in range(GRID_H):
		for x in range(GRID_W):
			if rows[y][x] in walkable_types:
				walkable_cells.append(Vector2i(x, y))


func _spawn_npcs() -> void:
	if npc_scene == null:
		push_warning("World: npc_scene not set, skipping NPC spawn")
		return
	for i in range(npc_count):
		var npc: Node2D = npc_scene.instantiate()
		npc_container.add_child(npc)
		var start_cell := walkable_cells[randi() % walkable_cells.size()]
		npc.init(i, start_cell, walkable_cells, terrain_layer)
		npcs.append(npc)


## Called by DayNightCycle each game tick.
func on_game_tick(tick: int) -> void:
	for npc in npcs:
		npc.on_tick(tick)

extends Node2D

## world.gd — Sprint 2 rewrite.
## Loads 30 NPCs from data/npcs.json, builds AstarPathfinder and SocialGraph,
## assigns faction-based schedules, and hosts inject_rumor for the debug console.

const TILE_SIZE := Vector2i(64, 32)
const GRID_W    := 48
const GRID_H    := 48

# Source IDs in the TileSet (one atlas per tile category)
const SRC_GROUND    := 0
const SRC_ROAD_DIRT := 1
const SRC_ROAD_STONE := 2
const SRC_BUILDING  := 3

const ATLAS_VOID       := Vector2i(0, 0)
const ATLAS_GRASS      := Vector2i(1, 0)
const ATLAS_ROAD_DIRT  := Vector2i(0, 0)
const ATLAS_ROAD_STONE := Vector2i(1, 0)
const ATLAS_MANOR      := Vector2i(0, 0)
const ATLAS_TAVERN     := Vector2i(1, 0)
const ATLAS_CHAPEL     := Vector2i(2, 0)
const ATLAS_MARKET     := Vector2i(3, 0)
const ATLAS_WELL       := Vector2i(4, 0)

@export var npc_scene: PackedScene

@onready var terrain_layer:  TileMapLayer = $TerrainLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
@onready var npc_container:  Node2D       = $NPCContainer
@onready var day_night:      Node         = $DayNightCycle

var grid_data:     Dictionary = {}
var buildings:     Array      = []
var npcs:          Array      = []
var walkable_cells: Array[Vector2i] = []

var social_graph:  SocialGraph     = null
var _pathfinder:   AstarPathfinder = null

# Building entry-point cells derived from grid data (populated in _load_grid).
# Keys: "manor", "tavern", "chapel", "market", "well"
var _building_entries: Dictionary = {}

# Faction schedule templates (building name lists).
const FACTION_SCHEDULES := {
	"merchant": ["tavern", "market", "market", "tavern"],
	"noble":    ["manor",  "manor",  "market", "chapel"],
	"clergy":   ["chapel", "chapel", "market", "tavern"],
}


func _ready() -> void:
	_load_grid()
	_paint_terrain()
	_place_buildings()
	_collect_walkable_cells()
	_extract_building_entries()
	_init_pathfinder()
	_spawn_npcs()
	_init_social_graph()
	_wire_debug_nodes()


# ── Grid loading ─────────────────────────────────────────────────────────────

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
	buildings  = grid_data.get("buildings", [])


# ── Terrain / building painting (unchanged from Sprint 1) ───────────────────

func _paint_terrain() -> void:
	if grid_data.is_empty():
		return
	var rows: Array = grid_data["grid"]
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell_type: int = rows[y][x]
			var coords := Vector2i(x, y)
			match cell_type:
				0:
					pass
				1:
					terrain_layer.set_cell(coords, SRC_GROUND, ATLAS_GRASS)
				2:
					terrain_layer.set_cell(coords, SRC_ROAD_DIRT, ATLAS_ROAD_DIRT)
				3:
					terrain_layer.set_cell(coords, SRC_ROAD_STONE, ATLAS_ROAD_STONE)
				8:
					terrain_layer.set_cell(coords, SRC_GROUND, ATLAS_GRASS)
					building_layer.set_cell(coords, SRC_BUILDING, ATLAS_WELL)
				_:
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


# ── Building entry points ────────────────────────────────────────────────────

func _extract_building_entries() -> void:
	# For each building, find the nearest walkable cell just outside its bounding box.
	for b in buildings:
		var bx:  int = b["x"]
		var by:  int = b["y"]
		var bw:  int = b.get("width",  1)
		var bh_: int = b.get("height", 1)
		# Try cells along the bottom edge (y = by + bh_) and left edge.
		var candidates: Array[Vector2i] = []
		for dx in range(bw):
			candidates.append(Vector2i(bx + dx, by + bh_))       # bottom row
			candidates.append(Vector2i(bx + dx, by - 1))          # top row
		for dy in range(bh_):
			candidates.append(Vector2i(bx - 1,      by + dy))     # left col
			candidates.append(Vector2i(bx + bw,     by + dy))     # right col
		for c in candidates:
			if c in walkable_cells:
				_building_entries[b["name"]] = c
				break
		# Fallback: nearest walkable cell to building centre.
		if not _building_entries.has(b["name"]):
			var centre := Vector2i(bx + bw / 2, by + bh_ / 2)
			_building_entries[b["name"]] = AstarPathfinder.nearest_walkable(centre, walkable_cells)

	# Also add "well" entry from the grid (tile type 8) — use first found.
	if not _building_entries.has("well"):
		var rows: Array = grid_data.get("grid", [])
		for y in range(GRID_H):
			for x in range(GRID_W):
				if rows[y][x] == 8:
					_building_entries["well"] = Vector2i(x, y)
					break
			if _building_entries.has("well"):
				break

	# "graveyard" — not explicitly in the JSON; place it near the bottom-right area.
	if not _building_entries.has("graveyard"):
		_building_entries["graveyard"] = Vector2i(38, 38) if Vector2i(38, 38) in walkable_cells \
			else AstarPathfinder.nearest_walkable(Vector2i(38, 38), walkable_cells)


# ── A* pathfinder ────────────────────────────────────────────────────────────

func _init_pathfinder() -> void:
	_pathfinder = AstarPathfinder.new()
	_pathfinder.setup(Vector2i(GRID_W, GRID_H), walkable_cells)
	print("World: AstarPathfinder initialised (%d walkable cells)" % walkable_cells.size())


# ── NPC spawning ─────────────────────────────────────────────────────────────

func _spawn_npcs() -> void:
	if npc_scene == null:
		push_warning("World: npc_scene not set — skipping NPC spawn")
		return

	var npc_json_path := "res://data/npcs.json"
	var file := FileAccess.open(npc_json_path, FileAccess.READ)
	if file == null:
		push_error("World: cannot open %s" % npc_json_path)
		return
	var text := file.get_as_text()
	file.close()
	var npc_list = JSON.parse_string(text)
	if npc_list == null or not (npc_list is Array):
		push_error("World: failed to parse npcs.json")
		return

	for data in npc_list:
		var npc: Node2D = npc_scene.instantiate()
		npc_container.add_child(npc)

		# Random start cell on a walkable tile.
		var start_cell: Vector2i = walkable_cells[randi() % walkable_cells.size()]

		npc.init_from_data(data, start_cell, walkable_cells, _pathfinder)
		npc.schedule_waypoints = _build_schedule(data.get("faction", "merchant"), start_cell)
		npcs.append(npc)

	# Give every NPC a reference to the full NPC list (for spread targeting).
	for npc in npcs:
		npc.all_npcs_ref = npcs

	print("World: spawned %d NPCs" % npcs.size())


func _build_schedule(faction: String, start_cell: Vector2i) -> Array[Vector2i]:
	var template: Array = FACTION_SCHEDULES.get(faction, FACTION_SCHEDULES["merchant"])
	var waypoints: Array[Vector2i] = []
	waypoints.append(start_cell)
	for loc_name in template:
		if _building_entries.has(loc_name):
			var entry: Vector2i = _building_entries[loc_name]
			# Add small random jitter (±2 tiles) so NPCs don't all pile at the exact same spot.
			var jitter := Vector2i(randi_range(-2, 2), randi_range(-2, 2))
			var jittered: Vector2i = entry + jitter
			if jittered in walkable_cells:
				waypoints.append(jittered)
			else:
				waypoints.append(entry)
		else:
			# Fallback: random walkable cell.
			waypoints.append(walkable_cells[randi() % walkable_cells.size()])
	return waypoints


# ── Social graph ─────────────────────────────────────────────────────────────

func _init_social_graph() -> void:
	social_graph = SocialGraph.new()
	var npc_data_list: Array = []
	for npc in npcs:
		npc_data_list.append(npc.npc_data)
	social_graph.build(npc_data_list)

	# Pass graph reference to each NPC.
	for npc in npcs:
		npc.social_graph_ref = social_graph

	print("World: SocialGraph built for %d NPCs" % npcs.size())


# ── Debug node wiring ────────────────────────────────────────────────────────

func _wire_debug_nodes() -> void:
	# DebugOverlay and DebugConsole are expected as siblings under Main,
	# or as children of World. We search both.
	var overlay  := _find_node_by_class("DebugOverlay")
	var console_ := _find_node_by_class("DebugConsole")

	if overlay != null and overlay.has_method("set_world"):
		overlay.set_world(self)
		print("World: wired DebugOverlay")

	if console_ != null:
		if console_.has_method("set_world"):
			console_.set_world(self)
		if console_.has_method("set_overlay") and overlay != null:
			console_.set_overlay(overlay)
		print("World: wired DebugConsole")


func _find_node_by_class(class_tag: String) -> Node:
	# Search children of the scene root.
	var root := get_tree().root
	return _recursive_find(root, class_tag)


func _recursive_find(node: Node, class_tag: String) -> Node:
	if node.get_script() != null:
		var path: String = node.get_script().resource_path
		if path.get_file().get_basename().to_lower().replace("_", "") == class_tag.to_lower().replace("_", ""):
			return node
	for child in node.get_children():
		var found := _recursive_find(child, class_tag)
		if found != null:
			return found
	return null


# ── Tick ─────────────────────────────────────────────────────────────────────

func on_game_tick(tick: int) -> void:
	for npc in npcs:
		npc.on_tick(tick)


# ── Public API: inject_rumor ─────────────────────────────────────────────────

## Called by DebugConsole. Returns the rumor id string on success, "" on failure.
func inject_rumor(target_npc_id: String, claim_type_str: String, intensity: int) -> String:
	# Find target NPC.
	var target_npc: Node2D = null
	for npc in npcs:
		if npc.npc_data.get("id", "") == target_npc_id:
			target_npc = npc
			break

	if target_npc == null:
		push_warning("World.inject_rumor: NPC '%s' not found" % target_npc_id)
		return ""

	var claim_type := Rumor.claim_type_from_string(claim_type_str)

	# Pick a random subject (not the target).
	var subject_npc: Node2D = null
	var candidates := npcs.filter(func(n): return n != target_npc)
	if not candidates.is_empty():
		subject_npc = candidates[randi() % candidates.size()]

	var subject_id := subject_npc.npc_data.get("id", "unknown") if subject_npc != null else "unknown"
	var rumor_id   := "r_%s_%d" % [claim_type_str.to_lower(), Time.get_ticks_msec()]

	var tick := 0
	if day_night != null and day_night.has_method("_on_tick_timer_timeout"):
		tick = day_night.current_tick

	var rumor := Rumor.create(
		rumor_id,
		subject_id,
		claim_type,
		clamp(intensity, 1, 5),
		0.4,   # default mutability
		tick
	)

	var source_faction: String = target_npc.npc_data.get("faction", "")
	target_npc.hear_rumor(rumor, source_faction)

	print("[World] inject_rumor '%s' (type=%s, intensity=%d) → %s about %s" % [
		rumor_id, claim_type_str, intensity,
		target_npc.npc_data.get("name", "?"),
		subject_id
	])
	return rumor_id

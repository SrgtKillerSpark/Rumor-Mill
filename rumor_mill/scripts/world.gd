extends Node2D

## world.gd — Sprint 5 update (Art Pass 1: 10 building types, animated NPCs).
## Sprint 9: rumor_event signal aggregates NPC state-change and transmission
## events so the Journal and Social Graph Overlay can react in real-time.

## Emitted whenever a noteworthy rumor event occurs (spread, state change).
## message: human-readable log string.  tick: current game tick.
signal rumor_event(message: String, tick: int)
## Emitted once per NPC the first tick their SOCIALLY_DEAD flag becomes true.
signal socially_dead_triggered(npc_id: String, npc_name: String, tick: int)
## Loads 30 NPCs from data/npcs.json, builds AstarPathfinder and SocialGraph,
## assigns faction-based schedules, and hosts inject_rumor for the debug console.

const TILE_SIZE := Vector2i(64, 32)
const GRID_W    := 48
const GRID_H    := 48

# Source IDs in the TileSet (one atlas per tile category)
const SRC_GROUND     := 0
const SRC_ROAD_DIRT  := 1
const SRC_ROAD_STONE := 2
const SRC_BUILDING   := 3
const SRC_PROPS      := 4

const ATLAS_VOID             := Vector2i(0, 0)
const ATLAS_GRASS            := Vector2i(1, 0)
const ATLAS_GRASS_DARK       := Vector2i(2, 0)  # shadow / building footprint variant
const ATLAS_GRASS_SPARSE     := Vector2i(3, 0)  # sparse dots, lighter (SPA-526)
const ATLAS_GRASS_DENSE      := Vector2i(4, 0)  # denser, darker (SPA-526)
const ATLAS_GRASS_FLORAL     := Vector2i(5, 0)  # flower dot variant (SPA-526)
const ATLAS_DIRT_MUDDY       := Vector2i(6, 0)  # DIRT_D + puddles (SPA-526)
const ATLAS_DIRT_PACKED      := Vector2i(7, 0)  # DIRT_L, smooth (SPA-526)
const ATLAS_GRASS_DIRT_BLEND := Vector2i(8, 0)  # edge blend grass→dirt (SPA-526)
const ATLAS_ROAD_DIRT        := Vector2i(0, 0)
const ATLAS_ROAD_STONE       := Vector2i(0, 0)  # fixed: road_stone source uses (0,0)
# Building atlas columns — matches tiles_buildings.png tile order (SPA-41)
const ATLAS_MANOR       := Vector2i(0, 0)
const ATLAS_TAVERN      := Vector2i(1, 0)
const ATLAS_CHAPEL      := Vector2i(2, 0)
const ATLAS_MARKET      := Vector2i(3, 0)
const ATLAS_WELL        := Vector2i(4, 0)
const ATLAS_BLACKSMITH  := Vector2i(5, 0)
const ATLAS_MILL        := Vector2i(6, 0)
const ATLAS_STORAGE     := Vector2i(7, 0)
const ATLAS_GUARDPOST   := Vector2i(8, 0)
const ATLAS_TOWN_HALL   := Vector2i(9, 0)
# Ground atlas coords — matches tiles_ground.png tile order (SPA-526 / SPA-551)
const ATLAS_STONE_SMOOTH  := Vector2i(9, 0)   # SPA-551: smooth grey stone courtyard
const ATLAS_STONE_CRACKED := Vector2i(10, 0)  # SPA-551: cracked/weathered stone
const ATLAS_STONE_COBBLE  := Vector2i(11, 0)  # SPA-551: cobblestone pattern

## Stone tile pool for random variant selection in stone-paved areas.
const STONE_VARIANTS: Array[Vector2i] = [
	ATLAS_STONE_SMOOTH, ATLAS_STONE_CRACKED, ATLAS_STONE_COBBLE
]

# Prop atlas coords — matches tiles_props.png tile order (SPA-434 / SPA-526 / SPA-551)
const ATLAS_CRATE        := Vector2i(0, 0)
const ATLAS_BARREL       := Vector2i(1, 0)
const ATLAS_SIGN         := Vector2i(2, 0)
const ATLAS_FENCE        := Vector2i(3, 0)
const ATLAS_CART         := Vector2i(4, 0)
const ATLAS_HAY_BALE     := Vector2i(5, 0)
const ATLAS_FLOWER_POT   := Vector2i(6, 0)
const ATLAS_WELL_BUCKET  := Vector2i(7, 0)
const ATLAS_OAK_TREE     := Vector2i(8, 0)   # SPA-526
const ATLAS_LANTERN_POST := Vector2i(9, 0)   # SPA-526
const ATLAS_GARDEN_BED   := Vector2i(10, 0)  # SPA-526
const ATLAS_MARKET_STALL  := Vector2i(11, 0)  # SPA-551: market stall with awning
const ATLAS_BENCH         := Vector2i(12, 0)  # SPA-551: wooden bench
const ATLAS_STONE_WELL    := Vector2i(13, 0)  # SPA-551: stone well with crossbar
const ATLAS_CHAPEL_CANDLE := Vector2i(14, 0)  # SPA-595: ivory pillar candle with forge flame
const ATLAS_WOODPILE      := Vector2i(15, 0)  # SPA-602: stacked log pile
const ATLAS_NOTICE_BOARD  := Vector2i(16, 0)  # SPA-602: post-mounted parchment notice board
const ATLAS_IRON_TORCH    := Vector2i(17, 0)  # SPA-602: iron bracket torch with forge flame

## Grass tile pool for random variant selection in _paint_terrain() (SPA-526).
const GRASS_VARIANTS: Array[Vector2i] = [
	ATLAS_GRASS, ATLAS_GRASS_SPARSE, ATLAS_GRASS_DENSE, ATLAS_GRASS_FLORAL
]

@export var npc_scene: PackedScene

@onready var terrain_layer:  TileMapLayer = $TerrainLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
@onready var props_layer:    TileMapLayer = $PropsLayer
@onready var npc_container:  Node2D       = $NPCContainer
@onready var day_night:      Node         = $DayNightCycle

var grid_data:     Dictionary = {}
var buildings:     Array      = []
var npcs:          Array      = []
var walkable_cells: Array[Vector2i] = []

var social_graph:  SocialGraph     = null
var _pathfinder:   AstarPathfinder = null

## Sprint 3: player intelligence store (shared with ReconController + UI).
var intel_store: PlayerIntelStore = null

## Sprint 6: reputation system and scenario evaluator.
var reputation_system: ReputationSystem = null
var scenario_manager:  ScenarioManager  = null

## NPC ids for which socially_dead_triggered has already been emitted this session.
var _socially_dead_ids: Dictionary = {}

## SPA-592: cached display name of the Sister Maren NPC for carrier tracking.
var _maren_display_name: String = ""

## Sprint 4: SIR propagation engine (β/γ formulas, mutations, lineage registry).
var propagation_engine: PropagationEngine = null

## Rival agent — only active in Scenario 3.
var rival_agent: RivalAgent = null

## Inquisitor agent — only active in Scenario 4.
var inquisitor_agent: InquisitorAgent = null

## Illness escalation agent — only active in Scenario 2.
var illness_escalation_agent: IllnessEscalationAgent = null

## S4 faction shift agent — only active in Scenario 4.
var s4_faction_shift_agent: S4FactionShiftAgent = null

## Guild defense agent — only active in Scenario 6.
var guild_defense_agent: GuildDefenseAgent = null

## Mid-game narrative event agent — data-driven branching events (all scenarios).
var mid_game_event_agent: MidGameEventAgent = null

## Milestone tracker — fires one-shot narrative notifications (SPA-479).
## Callback must be set from main.gd after recon_hud is ready.
var milestone_tracker: MilestoneTracker = null

## Faction event system — fires 1-2 random events per scenario run (SPA-199).
var faction_event_system: FactionEventSystem = null

## VFX: screen-edge vignette pulse for suspicion danger (SPA-495).
var _vignette_layer: CanvasLayer = null
var _vignette_rect:  ColorRect   = null
var _vignette_tween: Tween       = null

## VFX: atmospheric depth vignette — dark border frames the town (SPA-523).
var _atmo_vignette_layer: CanvasLayer = null
var _atmo_vignette_rect:  ColorRect   = null

## Night buildings: texture swap for lit windows (SPA-523).
var _building_day_tex:  Texture2D = null
var _building_night_tex: Texture2D = null
var _is_night: bool = false

## Visual polish systems (SPA-586).
var _ambient_particles: Node = null
var _weather_system:    Node = null

## Reputation change indicators (SPA-599): npc_id → last emitted score.
## Compared each tick against the new snapshot; shows floating +/- when delta ≥ threshold.
var _prev_rep_scores: Dictionary = {}
const _REP_CHANGE_THRESHOLD := 3  # minimum score change to show a floating indicator

## Active scenario id — change before _ready() to load a different scenario.
## Valid values: "scenario_1", "scenario_2", "scenario_3", "scenario_4"
var active_scenario_id: String = "scenario_1"

# Building entry-point cells derived from grid data (populated in _load_grid).
# Keys: "manor", "tavern", "chapel", "market", "well", etc.
var _building_entries: Dictionary = {}

# Gathering points for all NPC schedule location codes.
# Populated in _build_gathering_points() after _extract_building_entries().
# Keys match NpcSchedule location code strings.
var _gathering_points: Dictionary = {}

# Number of schedule slots per game day (matches NpcSchedule.SLOTS_PER_DAY).
const SCHEDULE_SLOTS := 6

# Faction schedule templates (building name lists) — kept for legacy reference.
const FACTION_SCHEDULES := {
	"merchant": ["tavern", "market", "market", "tavern"],
	"noble":    ["manor",  "manor",  "market", "chapel"],
	"clergy":   ["chapel", "chapel", "market", "tavern"],
}


func _ready() -> void:
	# Read scenario selected in the main menu (falls back to "scenario_1").
	active_scenario_id = GameState.selected_scenario_id
	_load_grid()
	_paint_terrain()
	_place_buildings()
	_place_props()
	_collect_walkable_cells()
	_extract_building_entries()
	_build_gathering_points()
	_init_pathfinder()
	_spawn_npcs()
	_init_social_graph()
	_init_propagation_engine()
	_init_intel_store()
	_init_reputation_system()
	_wire_debug_nodes()
	_init_vignette_overlay()
	_init_atmo_vignette()
	_init_night_buildings()
	_init_ambient_particles()
	_init_weather_system()


func _exit_tree() -> void:
	for npc in npcs:
		if npc.rumor_state_changed.is_connected(_on_npc_rumor_state_changed):
			npc.rumor_state_changed.disconnect(_on_npc_rumor_state_changed)
		if npc.rumor_transmitted.is_connected(_on_npc_rumor_transmitted):
			npc.rumor_transmitted.disconnect(_on_npc_rumor_transmitted)
		if npc.graph_edge_mutated.is_connected(_on_npc_graph_edge_mutated):
			npc.graph_edge_mutated.disconnect(_on_npc_graph_edge_mutated)
		if npc.suspicion_danger.is_connected(_on_npc_suspicion_danger):
			npc.suspicion_danger.disconnect(_on_npc_suspicion_danger)
	if day_night != null and day_night.day_changed.is_connected(_on_day_changed):
		day_night.day_changed.disconnect(_on_day_changed)


# ── Grid loading ─────────────────────────────────────────────────────────────

func _load_grid() -> void:
	var path := "res://data/town_grid.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("World: cannot open %s" % path)
		return
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("World: failed to parse town_grid.json")
		return
	grid_data = result
	buildings  = grid_data.get("buildings", [])


# ── Terrain / building painting ──────────────────────────────────────────────

func _paint_terrain() -> void:
	if grid_data.is_empty():
		return
	var rows: Array = grid_data["grid"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 526  # deterministic; unique to terrain pass (SPA-526)
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell_type: int = rows[y][x]
			var coords := Vector2i(x, y)
			match cell_type:
				0:
					pass
				1:
					# Use edge-blend tile for grass cells adjacent to dirt road.
					var adj_dirt := false
					for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var nx: int = x + offset.x
						var ny: int = y + offset.y
						if nx >= 0 and nx < GRID_W and ny >= 0 and ny < GRID_H:
							if rows[ny][nx] == 2:
								adj_dirt = true
								break
					if adj_dirt:
						terrain_layer.set_cell(coords, SRC_GROUND, ATLAS_GRASS_DIRT_BLEND)
					else:
						var idx: int = rng.randi_range(0, GRASS_VARIANTS.size() - 1)
						terrain_layer.set_cell(coords, SRC_GROUND, GRASS_VARIANTS[idx])
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
			"manor":       atlas_coord = ATLAS_MANOR
			"tavern":      atlas_coord = ATLAS_TAVERN
			"chapel":      atlas_coord = ATLAS_CHAPEL
			"market":      atlas_coord = ATLAS_MARKET
			"blacksmith":  atlas_coord = ATLAS_BLACKSMITH
			"mill":        atlas_coord = ATLAS_MILL
			"storage":     atlas_coord = ATLAS_STORAGE
			"guardpost":   atlas_coord = ATLAS_GUARDPOST
			"town_hall":   atlas_coord = ATLAS_TOWN_HALL
			_:             continue
		var anchor := Vector2i(b["x"], b["y"])
		building_layer.set_cell(anchor, SRC_BUILDING, atlas_coord)

		# Floating building name label above the tile.
		var label := Label.new()
		label.text = b["name"].replace("_", " ").capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		label.size = Vector2(80, 16)
		var wx: float = (anchor.x - anchor.y) * (TILE_SIZE.x / 2.0)
		var wy: float = (anchor.x + anchor.y) * (TILE_SIZE.y / 2.0)
		label.position = Vector2(wx - 40.0, wy - 72.0)
		label.z_index = -1   # render behind NPC sprites to prevent label overlap
		add_child(label)


# Prop placement rules per building type — which props appear nearby (SPA-434 / SPA-526).
const BUILDING_PROPS := {
	"tavern":     [ATLAS_BARREL, ATLAS_BARREL, ATLAS_CRATE, ATLAS_SIGN, ATLAS_LANTERN_POST, ATLAS_WOODPILE],
	"market":     [ATLAS_CRATE, ATLAS_CRATE, ATLAS_BARREL, ATLAS_CART, ATLAS_NOTICE_BOARD],
	"manor":      [ATLAS_FLOWER_POT, ATLAS_FLOWER_POT, ATLAS_FENCE, ATLAS_OAK_TREE, ATLAS_GARDEN_BED, ATLAS_IRON_TORCH],
	"chapel":     [ATLAS_FLOWER_POT, ATLAS_CHAPEL_CANDLE, ATLAS_GARDEN_BED, ATLAS_NOTICE_BOARD],
	"blacksmith": [ATLAS_BARREL, ATLAS_CRATE, ATLAS_CART, ATLAS_WOODPILE],
	"mill":       [ATLAS_HAY_BALE, ATLAS_HAY_BALE, ATLAS_BARREL, ATLAS_CART],
	"storage":    [ATLAS_CRATE, ATLAS_CRATE, ATLAS_BARREL, ATLAS_BARREL],
	"guardpost":  [ATLAS_BARREL, ATLAS_FENCE, ATLAS_CRATE, ATLAS_LANTERN_POST, ATLAS_IRON_TORCH],
	"town_hall":  [ATLAS_FLOWER_POT, ATLAS_NOTICE_BOARD, ATLAS_FENCE, ATLAS_OAK_TREE, ATLAS_IRON_TORCH],
	"well":       [ATLAS_WELL_BUCKET, ATLAS_LANTERN_POST],
}


func _place_props() -> void:
	if grid_data.is_empty():
		return
	var rows: Array = grid_data["grid"]
	var occupied: Dictionary = {}  # track cells already holding a prop
	var rng := RandomNumberGenerator.new()
	rng.seed = 434  # deterministic layout

	for b in buildings:
		var bname: String = b["name"]
		if not BUILDING_PROPS.has(bname):
			continue
		var bx: int = b["x"]
		var by: int = b["y"]
		var bw: int = b.get("width", 1)
		var bh: int = b.get("height", 1)

		# Collect candidate cells just outside the building footprint.
		var candidates: Array[Vector2i] = []
		for dx in range(-1, bw + 1):
			for dy in range(-1, bh + 1):
				# Skip interior cells
				if dx >= 0 and dx < bw and dy >= 0 and dy < bh:
					continue
				var cx: int = bx + dx
				var cy: int = by + dy
				if cx < 0 or cx >= GRID_W or cy < 0 or cy >= GRID_H:
					continue
				var cell_type: int = rows[cy][cx]
				# Only place on walkable ground
				if cell_type in [1, 2, 3]:
					candidates.append(Vector2i(cx, cy))

		# Place a subset of the building's prop palette.
		var prop_list: Array = BUILDING_PROPS[bname]
		var placed := 0
		for prop_atlas in prop_list:
			if candidates.is_empty():
				break
			var idx: int = rng.randi_range(0, candidates.size() - 1)
			var cell: Vector2i = candidates[idx]
			if occupied.has(cell):
				candidates.remove_at(idx)
				continue
			props_layer.set_cell(cell, SRC_PROPS, prop_atlas)
			occupied[cell] = true
			candidates.remove_at(idx)
			placed += 1


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


# ── Gathering points (NPC schedule targets) ──────────────────────────────────

func _build_gathering_points() -> void:
	# Seed with the building entries extracted from the grid.
	for key in _building_entries:
		_gathering_points[key] = _building_entries[key]

	# Placeholder positions for buildings not yet placed in the grid.
	# Each is the desired grid cell; we resolve to the nearest walkable cell.
	var placeholders := {
		"town_hall":       Vector2i(21, 10),
		"alderman_house":  Vector2i(10, 15),
		"courthouse":      Vector2i(24, 15),
		"guardhouse":      Vector2i(22, 22),
		"blacksmith":      Vector2i(15, 30),
		"tanner":          Vector2i(20, 35),
		"trader_stall":    Vector2i(8,  30),
		"mill":            Vector2i(35, 20),
		"storage":         Vector2i(35, 30),
		"patrol":          Vector2i(24, 24),
	}
	for loc in placeholders:
		if not _gathering_points.has(loc):
			var desired: Vector2i = placeholders[loc]
			_gathering_points[loc] = AstarPathfinder.nearest_walkable(desired, walkable_cells)



# ── A* pathfinder ────────────────────────────────────────────────────────────

func _init_pathfinder() -> void:
	_pathfinder = AstarPathfinder.new()
	_pathfinder.setup(Vector2i(GRID_W, GRID_H), walkable_cells)


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
		if walkable_cells.is_empty():
			push_error("World: No walkable cells — cannot spawn NPC")
			return
		var start_cell: Vector2i = walkable_cells[randi() % walkable_cells.size()]

		npc.init_from_data(data, start_cell, walkable_cells, _pathfinder)
		npc.schedule_waypoints = _build_schedule(data.get("faction", "merchant"), start_cell)
		npcs.append(npc)
		# SPA-592: cache Maren's display name for rumor carrier attribution.
		if data.get("id", "") == ScenarioManager.MAREN_NUN_ID:
			_maren_display_name = data.get("name", "")

	# Give every NPC a reference to the full NPC list (for spread targeting).
	for npc in npcs:
		npc.all_npcs_ref = npcs

	# Wire NPC events → world rumor_event signal so UI layers can subscribe.
	for npc in npcs:
		npc.rumor_state_changed.connect(_on_npc_rumor_state_changed)
		npc.rumor_transmitted.connect(_on_npc_rumor_transmitted)
		npc.graph_edge_mutated.connect(_on_npc_graph_edge_mutated)
		npc.suspicion_danger.connect(_on_npc_suspicion_danger)



# ── Propagation engine ────────────────────────────────────────────────────────

func _init_propagation_engine() -> void:
	propagation_engine = PropagationEngine.new()
	for npc in npcs:
		npc.propagation_engine_ref = propagation_engine


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
			if not walkable_cells.is_empty():
				waypoints.append(walkable_cells[randi() % walkable_cells.size()])
			else:
				push_error("World: No walkable cells — NPC schedule fallback failed")
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



# ── Recon intel store ────────────────────────────────────────────────────────

func _init_intel_store() -> void:
	intel_store = PlayerIntelStore.new()
	# Wire intel store to propagation engine for heat tracking.
	if propagation_engine != null:
		propagation_engine.intel_store_ref = intel_store
	# Replenish the daily recon budget at dawn (when the day counter increments).
	if day_night != null:
		day_night.day_changed.connect(_on_day_changed)


# ── Reputation system ────────────────────────────────────────────────────────

func _init_reputation_system() -> void:
	reputation_system = ReputationSystem.new()
	scenario_manager  = ScenarioManager.new()
	# recalculate_all is called by _apply_active_scenario() after loading
	# starting reputation overrides so that the initial cache reflects them.


func _on_day_changed(_day: int) -> void:
	if intel_store != null:
		intel_store.replenish()
	if rival_agent != null and scenario_manager != null:
		rival_agent.tick(_day, self, scenario_manager)
	if inquisitor_agent != null and scenario_manager != null:
		inquisitor_agent.tick(_day, self, scenario_manager)
	if illness_escalation_agent != null:
		illness_escalation_agent.tick(_day, self)
	if s4_faction_shift_agent != null:
		s4_faction_shift_agent.tick(_day, self)
	if guild_defense_agent != null:
		guild_defense_agent.tick(_day, self)
	if mid_game_event_agent != null:
		mid_game_event_agent.tick(_day, self)
	if faction_event_system != null:
		faction_event_system.on_day_changed(_day)


# ── Scenario data loader ─────────────────────────────────────────────────────

## Loads scenarios.json, finds the entry matching active_scenario_id, and applies:
##   1. Edge weight overrides to the social graph.
##   2. Personality overrides to individual NPC data dictionaries.
##   3. Starting reputation overrides to the reputation system.
##   4. Narrative text to the scenario manager.
## Then seeds the reputation cache so the UI has correct values at frame 0.
func _apply_active_scenario() -> void:
	var file := FileAccess.open("res://data/scenarios.json", FileAccess.READ)
	if file == null:
		push_warning("World: scenarios.json not found — using default graph weights")
		reputation_system.recalculate_all(npcs, 0)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Array):
		push_error("World: failed to parse scenarios.json")
		reputation_system.recalculate_all(npcs, 0)
		return

	var scenario_data: Dictionary = {}
	for entry in parsed:
		if entry.get("scenarioId", "") == active_scenario_id:
			scenario_data = entry
			break

	if scenario_data.is_empty():
		push_warning("World: scenario '%s' not found in scenarios.json" % active_scenario_id)
		reputation_system.recalculate_all(npcs, 0)
		return

	# 1. Social graph edge overrides.
	var edge_overrides: Array = scenario_data.get("edgeOverrides", [])
	if social_graph != null and not edge_overrides.is_empty():
		social_graph.apply_overrides(edge_overrides)

	# 2. Personality overrides (patch individual NPC data dicts).
	var personality_overrides: Array = scenario_data.get("personalityOverrides", [])
	for po in personality_overrides:
		var npc_id: String = po.get("npcId", "")
		for npc in npcs:
			if npc.npc_data.get("id", "") == npc_id:
				for key in po:
					if key == "npcId":
						continue
					npc.npc_data[key] = po[key]
				npc._credulity   = float(npc.npc_data.get("credulity",   0.5))
				npc._sociability = float(npc.npc_data.get("sociability",  0.5))
				npc._loyalty     = float(npc.npc_data.get("loyalty",      0.5))
				npc._temperament = float(npc.npc_data.get("temperament",  0.5))
				break

	# 3. Starting reputations (override base_score per NPC in reputation system).
	var starting_reps: Dictionary = scenario_data.get("startingReputations", {})
	if reputation_system != null:
		reputation_system.clear_base_overrides()
		for npc_id in starting_reps:
			reputation_system.set_base_override(npc_id, int(starting_reps[npc_id]))

	# 4. Narrative text into scenario manager.
	if scenario_manager != null:
		scenario_manager.load_scenario_data(scenario_data)
		# SPA-684: feed objective text into the day-change cinematic.
		if day_night != null:
			day_night.objective_text_provider = func() -> String:
				return scenario_manager.get_objective_one_liner()

	# 5. Propagation engine mutation filters.
	if propagation_engine != null:
		var excluded: Array = scenario_data.get("targetShiftExcluded", [])
		propagation_engine.target_shift_excluded_ids.assign(excluded)

	# 6. Heat + Bribery: heat disabled only in Scenario 4 (pure defense);
	#    enabled in S1 so the exposed fail condition can fire (SPA-502).
	if intel_store != null:
		var non_tutorial := (active_scenario_id != "scenario_1")
		var bribery_allowed := non_tutorial and (active_scenario_id != "scenario_4")
		intel_store.heat_enabled   = (active_scenario_id != "scenario_4")
		intel_store.bribe_charges  = 2 if bribery_allowed else 0

	# 7. Difficulty modifiers — adjust action budgets, heat decay, time limit, rival speed.
	var diff_mods: Dictionary = GameState.get_difficulty_modifiers(GameState.selected_difficulty)
	if intel_store != null:
		var non_tutorial := (active_scenario_id != "scenario_1")
		# Whispers and recon actions: clamp to at least 1 so the player can always act.
		intel_store.max_daily_whispers = maxi(1,
			PlayerIntelStore.MAX_DAILY_WHISPERS + int(diff_mods.get("whisper_bonus", 0)))
		intel_store.max_daily_actions  = maxi(1,
			PlayerIntelStore.MAX_DAILY_ACTIONS  + int(diff_mods.get("action_bonus",  0)))
		intel_store.whisper_tokens_remaining = intel_store.max_daily_whispers
		intel_store.recon_actions_remaining  = intel_store.max_daily_actions
		# Heat decay override (skip for S4 where heat is disabled).
		if active_scenario_id != "scenario_4":
			intel_store.heat_decay_override = float(diff_mods.get("heat_decay", 6.0))
	if scenario_manager != null:
		scenario_manager.set_intel_store(intel_store)
		var days_bonus: int = int(diff_mods.get("days_bonus", 0))
		if days_bonus != 0:
			var adjusted: int = maxi(1, scenario_manager.get_days_allowed() + days_bonus)
			scenario_manager.override_days_allowed(adjusted)

	# 7b. Scenario-specific difficulty overrides from scenarios.json.
	var _diff_key_map := {"apprentice": "easy", "master": "normal", "spymaster": "hard"}
	var _scen_diff_key: String = _diff_key_map.get(GameState.selected_difficulty, "normal")
	var _scen_diff_mods: Dictionary = scenario_data.get("difficultyModifiers", {}).get(_scen_diff_key, {})
	if scenario_manager != null and _scen_diff_mods.has("winBelieversOverride"):
		scenario_manager.s2_win_illness_min = int(_scen_diff_mods["winBelieversOverride"])

	# 7c. Scenario 5 difficulty overrides (SPA-676).
	if scenario_manager != null and active_scenario_id == "scenario_5":
		if _scen_diff_mods.has("winAldricMin"):
			scenario_manager.S5_WIN_ALDRIC_MIN = int(_scen_diff_mods["winAldricMin"])
		if _scen_diff_mods.has("winRivalsMax"):
			scenario_manager.S5_WIN_RIVALS_MAX = int(_scen_diff_mods["winRivalsMax"])
		if _scen_diff_mods.has("failAldricBelow"):
			scenario_manager.S5_FAIL_ALDRIC_BELOW = int(_scen_diff_mods["failAldricBelow"])
		if _scen_diff_mods.has("endorsementBonusOverride"):
			scenario_manager.S5_ENDORSEMENT_BONUS = int(_scen_diff_mods["endorsementBonusOverride"])
		if _scen_diff_mods.has("daysAllowedOverride"):
			scenario_manager.override_days_allowed(int(_scen_diff_mods["daysAllowedOverride"]))

	# 7d. Scenario 6 difficulty overrides (SPA-676).
	if scenario_manager != null and active_scenario_id == "scenario_6":
		if _scen_diff_mods.has("winAldricMax"):
			scenario_manager.S6_WIN_ALDRIC_MAX = int(_scen_diff_mods["winAldricMax"])
		if _scen_diff_mods.has("winMartaMin"):
			scenario_manager.S6_WIN_MARTA_MIN = int(_scen_diff_mods["winMartaMin"])
		if _scen_diff_mods.has("failMartaBelow"):
			scenario_manager.S6_FAIL_MARTA_BELOW = int(_scen_diff_mods["failMartaBelow"])
		if _scen_diff_mods.has("exposedHeatOverride"):
			scenario_manager.S6_EXPOSED_HEAT = float(_scen_diff_mods["exposedHeatOverride"])
		if _scen_diff_mods.has("daysAllowedOverride"):
			scenario_manager.override_days_allowed(int(_scen_diff_mods["daysAllowedOverride"]))
		# Apply hard-mode starting reputation overrides (e.g. Aldric 60, Marta 48).
		if _scen_diff_mods.has("startingReputationOverrides"):
			var s6_rep_overrides: Dictionary = _scen_diff_mods["startingReputationOverrides"]
			for npc_id in s6_rep_overrides:
				reputation_system.set_base_override(npc_id, int(s6_rep_overrides[npc_id]))
		# Apply hard-mode personality overrides.
		if _scen_diff_mods.has("personalityOverrides"):
			var s6_pers: Array = _scen_diff_mods["personalityOverrides"]
			for entry in s6_pers:
				var npc_id: String = entry.get("npcId", "")
				for npc in npcs:
					if npc.npc_data.get("id", "") == npc_id:
						if entry.has("loyalty"):
							npc.npc_data["loyalty"] = float(entry["loyalty"])
						if entry.has("credulity"):
							npc.npc_data["credulity"] = float(entry["credulity"])
						break

	# 8. Rival agent — only active in Scenario 3.
	rival_agent = RivalAgent.new()
	rival_agent.cooldown_offset = int(diff_mods.get("rival_cooldown_offset", 0))
	if active_scenario_id == "scenario_3":
		rival_agent.activate()

	# 9. Inquisitor agent — only active in Scenario 4.
	inquisitor_agent = InquisitorAgent.new()
	inquisitor_agent.cooldown_offset = int(diff_mods.get("inquisitor_cooldown_offset", 0))
	if active_scenario_id == "scenario_4":
		inquisitor_agent.activate()

	# 10. Illness escalation agent — only active in Scenario 2.
	illness_escalation_agent = IllnessEscalationAgent.new()
	illness_escalation_agent.cooldown_offset = int(diff_mods.get("illness_escalation_offset", 0))
	if active_scenario_id == "scenario_2":
		illness_escalation_agent.activate()

	# 11. S4 faction shift agent — only active in Scenario 4.
	s4_faction_shift_agent = S4FactionShiftAgent.new()
	s4_faction_shift_agent.inquisitor_ref = inquisitor_agent
	if active_scenario_id == "scenario_4":
		s4_faction_shift_agent.activate()

	# 11b. Guild defense agent — only active in Scenario 6 (SPA-676).
	guild_defense_agent = GuildDefenseAgent.new()
	if active_scenario_id == "scenario_6":
		var gd_config: Dictionary = scenario_data.get("guildDefenseConfig", {})
		if not gd_config.is_empty():
			var defender_ids: Array = gd_config.get("defenderNpcIds", [])
			if not defender_ids.is_empty():
				guild_defense_agent.defender_npc_ids.assign(defender_ids)
			guild_defense_agent.defense_target_id = gd_config.get("defenseTarget", "aldric_vane")
			guild_defense_agent.praise_intensity = int(gd_config.get("praiseIntensity", 2))
			guild_defense_agent.cooldown_days = int(gd_config.get("cooldownDays", 3))
			guild_defense_agent.start_day = int(gd_config.get("startDay", 5))
		# Apply difficulty cooldown override.
		if _scen_diff_mods.has("guildDefenseCooldownOverride"):
			guild_defense_agent.cooldown_days = int(_scen_diff_mods["guildDefenseCooldownOverride"])
		guild_defense_agent.activate()

	# 12. Milestone tracker — created here; callback wired from main.gd after recon_hud is ready.
	milestone_tracker = MilestoneTracker.new()

	# 13. Faction event system — initialise after all subsystems are ready.
	faction_event_system = FactionEventSystem.new()
	faction_event_system.initialize(self)

	# 14. Mid-game event agent — data-driven branching events from scenarios.json.
	mid_game_event_agent = MidGameEventAgent.new()
	var mid_events: Array = scenario_data.get("midGameEvents", [])
	mid_game_event_agent.load_events(mid_events)
	mid_game_event_agent.rival_agent_ref = rival_agent
	mid_game_event_agent.inquisitor_agent_ref = inquisitor_agent
	mid_game_event_agent.illness_agent_ref = illness_escalation_agent
	mid_game_event_agent.activate()

	# Seed the reputation cache now that all overrides are in place.
	reputation_system.recalculate_all(npcs, 0)


# ── Debug node wiring ────────────────────────────────────────────────────────

func _wire_debug_nodes() -> void:
	# DebugOverlay and DebugConsole are expected as siblings under Main,
	# or as children of World. We search both.
	var overlay  := _find_node_by_class("DebugOverlay")
	var console_ := _find_node_by_class("DebugConsole")

	if overlay != null and overlay.has_method("set_world"):
		overlay.set_world(self)

	if console_ != null:
		if console_.has_method("set_world"):
			console_.set_world(self)
		if console_.has_method("set_overlay") and overlay != null:
			console_.set_overlay(overlay)


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
	# ── Lit windows: swap building texture between day and night variants. ──
	var tpd: int = day_night.ticks_per_day if day_night != null else 24
	var hour: int = tick % tpd
	var night_now: bool = (hour >= 20 or hour < 6)
	if night_now != _is_night:
		_is_night = night_now
		_update_building_night(_is_night)

	# ── Visual polish: particles + weather (SPA-586). ──
	if _ambient_particles != null:
		_ambient_particles.on_game_tick(tick, tpd)
	if _weather_system != null:
		_weather_system.on_game_tick(tick, tpd)

	# ── Reputation: recalculate all snapshots BEFORE state transitions fire. ──
	if reputation_system != null:
		reputation_system.recalculate_all(npcs, tick)

		# ── SOCIALLY_DEAD edge detection — emit once per NPC on first trigger. ──
		# ── Reputation change indicator — show floating +/- for significant shifts. ──
		for npc in npcs:
			var npc_id: String = npc.npc_data.get("id", "")
			if npc_id.is_empty() or _socially_dead_ids.has(npc_id):
				continue
			var snap: ReputationSystem.ReputationSnapshot = reputation_system.get_snapshot(npc_id)
			if snap == null:
				continue
			if snap.is_socially_dead:
				_socially_dead_ids[npc_id] = true
				var npc_name: String = npc.npc_data.get("name", npc_id)
				emit_signal("socially_dead_triggered", npc_id, npc_name, tick)
				emit_signal("rumor_event",
					"[SOCIALLY DEAD] %s — death rumor believed by 5+ townspeople. Reputation permanently frozen." % npc_name,
					tick)
			# Floating +/- indicator: compare against last emitted score (not raw pre_scores)
			# to avoid showing the same delta every tick during stable believers.
			var prev_emitted: int = _prev_rep_scores.get(npc_id, -1)
			if prev_emitted < 0:
				_prev_rep_scores[npc_id] = snap.score
			else:
				var delta: int = snap.score - prev_emitted
				if abs(delta) >= _REP_CHANGE_THRESHOLD:
					_prev_rep_scores[npc_id] = snap.score
					npc.show_reputation_change(delta)
	if scenario_manager != null and reputation_system != null:
		scenario_manager.evaluate(reputation_system, tick)
	if milestone_tracker != null:
		milestone_tracker.evaluate(tick)

	# ── Time pressure: boost spread probability in the final 25% of the scenario. ──
	if propagation_engine != null and scenario_manager != null:
		propagation_engine.time_pressure_bonus = 0.20 if scenario_manager.is_final_quarter(tick) else 0.0

	# ── Shelf-life decay: run before NPC state transitions so EXPIRED is visible. ──
	if propagation_engine != null:
		propagation_engine.tick_decay()

	# Map continuous tick to a 0–5 schedule slot.
	tpd = day_night.ticks_per_day if day_night != null else 24
	var hour_of_day: int = tick % tpd
	var schedule_slot: int = (hour_of_day * SCHEDULE_SLOTS) / tpd
	var current_day: int   = day_night.current_day if day_night != null else (tick / tpd + 1)

	for npc in npcs:
		npc.update_tick_schedule(schedule_slot, current_day, _gathering_points)
		npc.on_tick(tick)


# ── Claims data ─────────────────────────────────────────────────────────────

## Cached claims list loaded once from data/claims.json.
var _claims_data: Array = []

## Returns the full claims array, loading it on first call.
func get_claims() -> Array:
	if _claims_data.is_empty():
		var file := FileAccess.open("res://data/claims.json", FileAccess.READ)
		if file == null:
			push_error("World: cannot open claims.json")
			return []
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Array:
			_claims_data = parsed
	return _claims_data


# ── Public API: seed_rumor_from_player ───────────────────────────────────────

## Called by the Rumor Crafting UI. Consumes one Whisper Token.
## subject_npc_id:    the NPC the rumor is about.
## claim_id:          claims.json id string (e.g. "ACC-01").
## seed_target_npc_id: the NPC the player whispers the rumor to.
## evidence_item:     optional PlayerIntelStore.EvidenceItem to boost the rumor at creation.
## Returns the new rumor id on success, "" on failure.
func seed_rumor_from_player(
		subject_npc_id:     String,
		claim_id:           String,
		seed_target_npc_id: String,
		evidence_item                = null
) -> String:
	if intel_store == null or not intel_store.try_spend_whisper():
		push_error("World.seed_rumor_from_player: no Whisper Tokens remaining")
		return ""

	# Resolve NPCs.
	var subject_npc:     Node2D = null
	var seed_target_npc: Node2D = null
	for npc in npcs:
		var nid: String = npc.npc_data.get("id", "")
		if nid == subject_npc_id:
			subject_npc = npc
		if nid == seed_target_npc_id:
			seed_target_npc = npc

	if subject_npc == null or seed_target_npc == null:
		push_error("World.seed_rumor_from_player: NPC not found (subject=%s seed=%s)" % [
			subject_npc_id, seed_target_npc_id])
		# Refund token if we can't proceed.
		intel_store.whisper_tokens_remaining = mini(
			intel_store.whisper_tokens_remaining + 1,
			intel_store.max_daily_whispers)
		return ""

	# Find the claim template.
	var claim_template: Dictionary = {}
	for c in get_claims():
		if c.get("id", "") == claim_id:
			claim_template = c
			break

	if claim_template.is_empty():
		push_error("World.seed_rumor_from_player: claim '%s' not found" % claim_id)
		intel_store.whisper_tokens_remaining = mini(
			intel_store.whisper_tokens_remaining + 1,
			intel_store.max_daily_whispers)
		return ""

	var claim_type: Rumor.ClaimType = Rumor.claim_type_from_string(claim_template.get("type", "accusation"))
	var intensity:   int   = int(claim_template.get("intensity",  3))
	var mutability:  float = float(claim_template.get("mutability", 3)) / 5.0

	var tick: int = 0
	if day_night != null:
		tick = day_night.current_tick

	var rumor_id := "rp_%s_%d" % [claim_id.to_lower(), Time.get_ticks_msec()]
	var rumor    := Rumor.create(rumor_id, subject_npc_id, claim_type, intensity, mutability, tick)

	# Apply evidence bonuses at creation time (not recalculated on subsequent ticks).
	if evidence_item != null:
		rumor.current_believability = minf(1.0, rumor.current_believability + evidence_item.believability_bonus)
		rumor.mutability = clampf(rumor.mutability + evidence_item.mutability_modifier, 0.0, 1.0)
		rumor.bolstered_by_evidence = true

	# Chain detection: check if this subject already has an active rumor that
	# creates a same-type, escalation, or contradiction chain.
	var chain_type: PropagationEngine.ChainType = PropagationEngine.ChainType.NONE
	if propagation_engine != null:
		var chain_info := propagation_engine.detect_chain(subject_npc_id, claim_type)
		chain_type = propagation_engine.apply_chain_bonus(rumor, chain_info)

	var source_faction: String = seed_target_npc.npc_data.get("faction", "")

	# Register in the propagation engine before seeding so shelf-life decay starts.
	if propagation_engine != null:
		propagation_engine.register_rumor(rumor)

	seed_target_npc.hear_rumor(rumor, source_faction)

	# Contradiction chains accelerate the CONTRADICTED transition on NPCs that
	# already hold the opposing rumor.  Force any NPC currently in SPREAD/ACT
	# for the existing opposing rumor to transition to CONTRADICTED immediately.
	if chain_type == PropagationEngine.ChainType.CONTRADICTION:
		for npc in npcs:
			for slot in npc.rumor_slots.values():
				if slot.rumor.subject_npc_id == subject_npc_id \
						and Rumor.is_positive_claim(slot.rumor.claim_type) != Rumor.is_positive_claim(claim_type) \
						and slot.state in [Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
					slot.state = Rumor.RumorState.CONTRADICTED
					slot.ticks_in_state = 0

	# Heat: +12 to the seed NPC (player has used them as a known relay).
	if intel_store != null:
		intel_store.add_heat(seed_target_npc_id, 12.0)

	return rumor_id


# ── Public API: vouch_for_npc (Scenario 4 mechanic) ────────────────────────

## Vouch action: spend 1 whisper to force a nearby NPC into DEFENDING state for
## the specified subject.  Adds +12 heat to the vouching NPC.
## Returns true on success.
func vouch_for_npc(voucher_npc_id: String, subject_npc_id: String) -> bool:
	if intel_store == null or not intel_store.try_spend_whisper():
		push_error("World.vouch_for_npc: no Whisper Tokens remaining")
		return false

	var voucher_npc: Node2D = null
	for npc in npcs:
		if npc.npc_data.get("id", "") == voucher_npc_id:
			voucher_npc = npc
			break

	if voucher_npc == null:
		push_error("World.vouch_for_npc: NPC '%s' not found" % voucher_npc_id)
		intel_store.whisper_tokens_remaining = mini(
			intel_store.whisper_tokens_remaining + 1,
			intel_store.max_daily_whispers)
		return false

	# Force the voucher NPC into DEFENDING state for the subject.
	voucher_npc._is_defending = true
	voucher_npc._defender_target_npc_id = subject_npc_id
	voucher_npc._defender_ticks_remaining = voucher_npc._DEFENDER_DURATION

	# Heat: +12 to the voucher NPC (player has used them publicly).
	if intel_store != null:
		intel_store.add_heat(voucher_npc_id, 12.0)

	var voucher_name: String = voucher_npc.npc_data.get("name", voucher_npc_id)
	emit_signal("rumor_event",
		"[VOUCH] %s is now defending %s against the inquisitor's claims." % [voucher_name, subject_npc_id],
		day_night.current_tick if day_night != null else 0)
	return true


# ── NPC event → rumor_event aggregation ─────────────────────────────────────

func _on_npc_rumor_state_changed(npc_name: String, state_name: String, rumor_id: String) -> void:
	var tick: int = day_night.current_tick if day_night != null else 0
	var msg := "%s → %s" % [npc_name, state_name]
	if not rumor_id.is_empty():
		msg += " (%s)" % rumor_id
	emit_signal("rumor_event", msg, tick)


func _on_npc_rumor_transmitted(from_name: String, to_name: String, rumor_id: String) -> void:
	AudioManager.play_sfx("whisper")
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake_screen"):
		cam.shake_screen(4.0, 0.3)
	var tick: int = day_night.current_tick if day_night != null else 0
	var msg := "%s whispered to %s" % [from_name, to_name]
	if not rumor_id.is_empty():
		msg += " [%s]" % rumor_id
	emit_signal("rumor_event", msg, tick)
	# SPA-592: record first NPC to carry a rumor to Maren for fail-screen attribution.
	if scenario_manager != null \
			and not _maren_display_name.is_empty() \
			and to_name == _maren_display_name \
			and scenario_manager.s2_maren_carrier_name.is_empty():
		scenario_manager.s2_maren_carrier_name = from_name


func _on_npc_suspicion_danger(_npc_name: String) -> void:
	if _vignette_rect == null:
		return
	if _vignette_tween != null:
		_vignette_tween.kill()
	_vignette_rect.modulate.a = 0.0
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette_rect, "modulate:a", 0.15, 0.2)
	_vignette_tween.tween_property(_vignette_rect, "modulate:a", 0.0, 0.4)


func _on_npc_graph_edge_mutated(actor_name: String, subject_name: String, delta: float) -> void:
	var tick: int = day_night.current_tick if day_night != null else 0
	var msg: String
	if delta < 0.0:
		msg = "%s now distrusts %s" % [actor_name, subject_name]
	else:
		msg = "%s holds %s in higher regard" % [actor_name, subject_name]
	emit_signal("rumor_event", msg, tick)


# ── Public API: inject_rumor ─────────────────────────────────────────────────

## Called by DebugConsole and RivalAgent. Returns the rumor id string on success, "" on failure.
## subject_npc_id: if provided, use this NPC as the subject; otherwise picks a random NPC.
## lineage_parent_id: passed through to Rumor.create() — use "rival" sentinel for rival rumors.
func inject_rumor(
		target_npc_id: String,
		claim_type_str: String,
		intensity: int,
		subject_npc_id: String = "",
		lineage_parent_id: String = ""
) -> String:
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

	# Resolve subject: use provided id if given, else pick a random NPC (not the target).
	var subject_id: String
	if not subject_npc_id.is_empty():
		subject_id = subject_npc_id
	else:
		var candidates: Array = npcs.filter(func(n): return n != target_npc)
		var subject_npc: Node2D = candidates[randi() % candidates.size()] if not candidates.is_empty() else null
		subject_id = subject_npc.npc_data.get("id", "unknown") if subject_npc != null else "unknown"

	var rumor_id := "r_%s_%d" % [claim_type_str.to_lower(), Time.get_ticks_msec()]

	var tick := 0
	if day_night != null and "current_tick" in day_night:
		tick = day_night.current_tick

	var rumor := Rumor.create(
		rumor_id,
		subject_id,
		claim_type,
		clamp(intensity, 1, 5),
		0.4,   # default mutability
		tick,
		330,   # default shelf life
		lineage_parent_id
	)

	var source_faction: String = target_npc.npc_data.get("faction", "")

	# Register in the propagation engine before injecting.
	if propagation_engine != null:
		propagation_engine.register_rumor(rumor)

	target_npc.hear_rumor(rumor, source_faction)

	return rumor_id


# ── VFX: suspicion danger vignette (SPA-495) ─────────────────────────────────

## Builds a screen-edge vignette overlay using a radial gradient shader.
## Alpha is driven to 0 at startup; _on_npc_suspicion_danger() pulses it.
func _init_vignette_overlay() -> void:
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.layer = 20
	add_child(_vignette_layer)

	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.modulate.a = 0.0

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5));
	float vignette = smoothstep(0.35, 0.75, dist);
	COLOR = vec4(0.85, 0.15, 0.05, vignette);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_vignette_rect.material = mat
	_vignette_layer.add_child(_vignette_rect)


# ── VFX: atmospheric depth vignette — permanent dark border (SPA-523) ────────

## Builds a permanent screen-edge vignette that frames the town with depth.
## Dark outer ring fades to transparent at centre.  Layer 1 keeps it below HUD.
func _init_atmo_vignette() -> void:
	_atmo_vignette_layer = CanvasLayer.new()
	_atmo_vignette_layer.layer = 1
	add_child(_atmo_vignette_layer)

	_atmo_vignette_rect = ColorRect.new()
	_atmo_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_atmo_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5));
	float vignette = smoothstep(0.30, 0.75, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * 0.60);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_atmo_vignette_rect.material = mat
	_atmo_vignette_layer.add_child(_atmo_vignette_rect)


# ── Night buildings: lit-window texture swap (SPA-523) ───────────────────────

## Loads day and night building atlas textures.  Called once from _ready().
func _init_night_buildings() -> void:
	_building_day_tex   = load("res://assets/textures/tiles_buildings.png")
	_building_night_tex = load("res://assets/textures/tiles_buildings_night.png")


## Swaps the building TileSet atlas to the day or night texture variant.
func _update_building_night(is_night: bool) -> void:
	if _building_day_tex == null or _building_night_tex == null:
		return
	if building_layer == null or building_layer.tile_set == null:
		return
	var src := building_layer.tile_set.get_source(SRC_BUILDING) as TileSetAtlasSource
	if src == null:
		return
	src.texture = _building_night_tex if is_night else _building_day_tex


# ── Visual polish: ambient particles (SPA-586) ───────────────────────────────

func _init_ambient_particles() -> void:
	var script: GDScript = load("res://scripts/ambient_particles.gd")
	if script == null:
		push_error("World: could not load ambient_particles.gd")
		return
	_ambient_particles = Node.new()
	_ambient_particles.set_script(script)
	_ambient_particles.name = "AmbientParticles"
	add_child(_ambient_particles)


# ── Visual polish: weather system (SPA-586) ──────────────────────────────────

func _init_weather_system() -> void:
	var script: GDScript = load("res://scripts/weather_system.gd")
	if script == null:
		push_error("World: could not load weather_system.gd")
		return
	_weather_system = Node.new()
	_weather_system.set_script(script)
	_weather_system.name = "WeatherSystem"
	add_child(_weather_system)
	# Wire the weather_changed signal so AudioManager can respond when it adds rain SFX.
	_weather_system.weather_changed.connect(_on_weather_changed)


func _on_weather_changed(type: String) -> void:
	# Audio hook: forward to AudioManager when rain SFX track is available.
	# AudioManager.set_weather_ambient(type)  ← uncomment once track is added.
	pass

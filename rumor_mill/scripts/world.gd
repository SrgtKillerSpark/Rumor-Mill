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

const ATLAS_VOID        := Vector2i(0, 0)
const ATLAS_GRASS       := Vector2i(1, 0)
const ATLAS_GRASS_DARK  := Vector2i(2, 0)  # shadow / building footprint variant
const ATLAS_ROAD_DIRT   := Vector2i(0, 0)
const ATLAS_ROAD_STONE  := Vector2i(0, 0)  # fixed: road_stone source uses (0,0)
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

## Sprint 3: player intelligence store (shared with ReconController + UI).
var intel_store: PlayerIntelStore = null

## Sprint 6: reputation system and scenario evaluator.
var reputation_system: ReputationSystem = null
var scenario_manager:  ScenarioManager  = null

## NPC ids for which socially_dead_triggered has already been emitted this session.
var _socially_dead_ids: Dictionary = {}

## Sprint 4: SIR propagation engine (β/γ formulas, mutations, lineage registry).
var propagation_engine: PropagationEngine = null

## Rival agent — only active in Scenario 3.
var rival_agent: RivalAgent = null

## Inquisitor agent — only active in Scenario 4.
var inquisitor_agent: InquisitorAgent = null

## Faction event system — fires 1-2 random events per scenario run (SPA-199).
var faction_event_system: FactionEventSystem = null

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
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		label.size = Vector2(80, 16)
		var wx: float = (anchor.x - anchor.y) * (TILE_SIZE.x / 2.0)
		var wy: float = (anchor.x + anchor.y) * (TILE_SIZE.y / 2.0)
		label.position = Vector2(wx - 40.0, wy - 72.0)
		label.z_index = -1   # render behind NPC sprites to prevent label overlap
		add_child(label)


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
		var start_cell: Vector2i = walkable_cells[randi() % walkable_cells.size()]

		npc.init_from_data(data, start_cell, walkable_cells, _pathfinder)
		npc.schedule_waypoints = _build_schedule(data.get("faction", "merchant"), start_cell)
		npcs.append(npc)

	# Give every NPC a reference to the full NPC list (for spread targeting).
	for npc in npcs:
		npc.all_npcs_ref = npcs

	# Wire NPC events → world rumor_event signal so UI layers can subscribe.
	for npc in npcs:
		npc.rumor_state_changed.connect(_on_npc_rumor_state_changed)
		npc.rumor_transmitted.connect(_on_npc_rumor_transmitted)
		npc.graph_edge_mutated.connect(_on_npc_graph_edge_mutated)



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
	if not personality_overrides.is_empty():

	# 3. Starting reputations (override base_score per NPC in reputation system).
	var starting_reps: Dictionary = scenario_data.get("startingReputations", {})
	if reputation_system != null:
		reputation_system.clear_base_overrides()
		for npc_id in starting_reps:
			reputation_system.set_base_override(npc_id, int(starting_reps[npc_id]))
		if not starting_reps.is_empty():

	# 4. Narrative text into scenario manager.
	if scenario_manager != null:
		scenario_manager.load_scenario_data(scenario_data)

	# 5. Propagation engine mutation filters.
	if propagation_engine != null:
		var excluded: Array = scenario_data.get("targetShiftExcluded", [])
		propagation_engine.target_shift_excluded_ids.assign(excluded)
		if not excluded.is_empty():

	# 6. Heat + Bribery: disabled in Scenario 1 (tutorial) and Scenario 4 (pure defense).
	if intel_store != null:
		var non_tutorial := (active_scenario_id != "scenario_1")
		var bribery_allowed := non_tutorial and (active_scenario_id != "scenario_4")
		intel_store.heat_enabled   = non_tutorial
		intel_store.bribe_charges  = 2 if bribery_allowed else 0

	# 7. Difficulty modifiers — adjust action budgets, heat decay, time limit, rival speed.
	var diff_mods: Dictionary = GameState.get_difficulty_modifiers(GameState.selected_difficulty)
	if intel_store != null:
		var non_tutorial: bool = (active_scenario_id != "scenario_1")
		# Whispers and recon actions: clamp to at least 1 so the player can always act.
		intel_store.max_daily_whispers = maxi(1,
			PlayerIntelStore.MAX_DAILY_WHISPERS + int(diff_mods.get("whisper_bonus", 0)))
		intel_store.max_daily_actions  = maxi(1,
			PlayerIntelStore.MAX_DAILY_ACTIONS  + int(diff_mods.get("action_bonus",  0)))
		intel_store.whisper_tokens_remaining = intel_store.max_daily_whispers
		intel_store.recon_actions_remaining  = intel_store.max_daily_actions
		# Heat decay override (skip for tutorial where heat is disabled).
		if non_tutorial:
			intel_store.heat_decay_override = float(diff_mods.get("heat_decay", 6.0))
			GameState.selected_difficulty,
			intel_store.max_daily_whispers,
			intel_store.max_daily_actions,
			intel_store.heat_decay_override if non_tutorial else 6.0])
	if scenario_manager != null:
		var days_bonus: int = int(diff_mods.get("days_bonus", 0))
		if days_bonus != 0:
			var adjusted: int = maxi(1, scenario_manager.get_days_allowed() + days_bonus)
			scenario_manager.override_days_allowed(adjusted)
				GameState.selected_difficulty, adjusted])

	# 8. Rival agent — only active in Scenario 3.
	rival_agent = RivalAgent.new()
	rival_agent.cooldown_offset = int(diff_mods.get("rival_cooldown_offset", 0))
	if active_scenario_id == "scenario_3":
		rival_agent.activate()
	else:

	# 8. Inquisitor agent — only active in Scenario 4.
	inquisitor_agent = InquisitorAgent.new()
	if active_scenario_id == "scenario_4":
		inquisitor_agent.activate()
	else:

	# 8. Faction event system — initialise after all subsystems are ready.
	faction_event_system = FactionEventSystem.new()
	faction_event_system.initialize(self)

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
	# ── Reputation: recalculate all snapshots BEFORE state transitions fire. ──
	if reputation_system != null:
		reputation_system.recalculate_all(npcs, tick)
		# ── SOCIALLY_DEAD edge detection — emit once per NPC on first trigger. ──
		for npc in npcs:
			var npc_id: String = npc.npc_data.get("id", "")
			if npc_id.is_empty() or _socially_dead_ids.has(npc_id):
				continue
			var snap: ReputationSystem.ReputationSnapshot = reputation_system.get_snapshot(npc_id)
			if snap != null and snap.is_socially_dead:
				_socially_dead_ids[npc_id] = true
				var npc_name: String = npc.npc_data.get("name", npc_id)
				emit_signal("socially_dead_triggered", npc_id, npc_name, tick)
				emit_signal("rumor_event",
					"[SOCIALLY DEAD] %s — death rumor believed by 5+ townspeople. Reputation permanently frozen." % npc_name,
					tick)
	if scenario_manager != null and reputation_system != null:
		scenario_manager.evaluate(reputation_system, tick)

	# ── Time pressure: boost spread probability in the final 25% of the scenario. ──
	if propagation_engine != null and scenario_manager != null:
		propagation_engine.time_pressure_bonus = 0.20 if scenario_manager.is_final_quarter(tick) else 0.0

	# ── Shelf-life decay: run before NPC state transitions so EXPIRED is visible. ──
	if propagation_engine != null:
		propagation_engine.tick_decay()

	# Map continuous tick to a 0–5 schedule slot.
	var tpd: int = day_night.ticks_per_day if day_night != null else 24
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
		push_warning("World.seed_rumor_from_player: no Whisper Tokens remaining")
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
		push_warning("World.seed_rumor_from_player: NPC not found (subject=%s seed=%s)" % [
			subject_npc_id, seed_target_npc_id])
		# Refund token if we can't proceed.
		intel_store.whisper_tokens_remaining = mini(
			intel_store.whisper_tokens_remaining + 1,
			PlayerIntelStore.MAX_DAILY_WHISPERS)
		return ""

	# Find the claim template.
	var claim_template: Dictionary = {}
	for c in get_claims():
		if c.get("id", "") == claim_id:
			claim_template = c
			break

	if claim_template.is_empty():
		push_warning("World.seed_rumor_from_player: claim '%s' not found" % claim_id)
		intel_store.whisper_tokens_remaining = mini(
			intel_store.whisper_tokens_remaining + 1,
			PlayerIntelStore.MAX_DAILY_WHISPERS)
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
			evidence_item.type, rumor_id, rumor.current_believability, rumor.mutability])

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

		rumor_id, claim_id, intensity,
		seed_target_npc.npc_data.get("name", "?"),
		subject_npc.npc_data.get("name", "?")])
	return rumor_id


# ── Public API: vouch_for_npc (Scenario 4 mechanic) ────────────────────────

## Vouch action: spend 1 whisper to force a nearby NPC into DEFENDING state for
## the specified subject.  Adds +12 heat to the vouching NPC.
## Returns true on success.
func vouch_for_npc(voucher_npc_id: String, subject_npc_id: String) -> bool:
	if intel_store == null or not intel_store.try_spend_whisper():
		push_warning("World.vouch_for_npc: no Whisper Tokens remaining")
		return false

	var voucher_npc: Node2D = null
	for npc in npcs:
		if npc.npc_data.get("id", "") == voucher_npc_id:
			voucher_npc = npc
			break

	if voucher_npc == null:
		push_warning("World.vouch_for_npc: NPC '%s' not found" % voucher_npc_id)
		intel_store.whisper_tokens_remaining = mini(
			intel_store.whisper_tokens_remaining + 1,
			PlayerIntelStore.MAX_DAILY_WHISPERS)
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
	var tick: int = day_night.current_tick if day_night != null else 0
	var msg := "%s whispered to %s" % [from_name, to_name]
	if not rumor_id.is_empty():
		msg += " [%s]" % rumor_id
	emit_signal("rumor_event", msg, tick)


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
		var candidates := npcs.filter(func(n): return n != target_npc)
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

		rumor_id, claim_type_str, intensity, lineage_parent_id,
		target_npc.npc_data.get("name", "?"),
		subject_id
	])
	return rumor_id

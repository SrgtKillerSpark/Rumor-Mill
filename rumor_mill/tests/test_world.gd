## test_world.gd — Unit tests for World constants and initial state (SPA-981).
##
## Covers:
##   • Constants         — TILE_SIZE, GRID_W, GRID_H, SCHEDULE_SLOTS
##   • FACTION_SCHEDULES — keys present, schedule array lengths
##   • Initial property  — npcs, buildings, walkable_cells empty; active_scenario_id default;
##     state               _dusk_snapshot, _socially_dead_ids, _daily_believe_counts empty
##   • get_npcs_near_location() — returns [] for unknown location key when npcs is empty
##   • _on_day_changed() — runs without crash on a fresh World (all agents/systems null)
##
## World extends Node2D with @onready vars.  Instantiated with .new() — _ready() is
## intentionally never called, so @onready vars remain null and no scene-tree or file
## I/O is triggered.  Only properties with plain-data default values are validated.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestWorld
extends RefCounted


static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_tile_size",
		"test_grid_dimensions",
		"test_schedule_slots",
		# FACTION_SCHEDULES
		"test_faction_schedules_has_merchant",
		"test_faction_schedules_has_noble",
		"test_faction_schedules_has_clergy",
		"test_merchant_schedule_is_non_empty",
		"test_noble_schedule_is_non_empty",
		"test_clergy_schedule_is_non_empty",
		"test_all_schedule_entries_are_strings",
		# Initial property state
		"test_initial_npcs_empty",
		"test_initial_buildings_empty",
		"test_initial_walkable_cells_empty",
		"test_initial_scenario_id_is_scenario_1",
		"test_initial_dusk_snapshot_empty",
		"test_initial_socially_dead_ids_empty",
		"test_initial_daily_believe_counts_empty",
		"test_initial_key_npc_ids_empty",
		# get_npcs_near_location
		"test_get_npcs_near_unknown_location_returns_empty",
		"test_get_npcs_near_any_location_with_no_npcs_returns_empty",
		# _on_day_changed with null agents
		"test_on_day_changed_no_crash_with_null_agents",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nWorld tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

## Returns a fresh World node WITHOUT calling _ready().
## @onready vars stay null; plain var declarations keep their defaults.
static func _make_world() -> World:
	return World.new()


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_tile_size() -> bool:
	if World.TILE_SIZE != Vector2i(64, 32):
		push_error("test_tile_size: expected Vector2i(64,32), got %s" % str(World.TILE_SIZE))
		return false
	return true


static func test_grid_dimensions() -> bool:
	if World.GRID_W != 48:
		push_error("test_grid_dimensions: GRID_W expected 48, got %d" % World.GRID_W)
		return false
	if World.GRID_H != 48:
		push_error("test_grid_dimensions: GRID_H expected 48, got %d" % World.GRID_H)
		return false
	return true


static func test_schedule_slots() -> bool:
	if World.SCHEDULE_SLOTS != 6:
		push_error("test_schedule_slots: expected 6, got %d" % World.SCHEDULE_SLOTS)
		return false
	return true


# ── FACTION_SCHEDULES ─────────────────────────────────────────────────────────

static func test_faction_schedules_has_merchant() -> bool:
	return World.FACTION_SCHEDULES.has("merchant")


static func test_faction_schedules_has_noble() -> bool:
	return World.FACTION_SCHEDULES.has("noble")


static func test_faction_schedules_has_clergy() -> bool:
	return World.FACTION_SCHEDULES.has("clergy")


static func test_merchant_schedule_is_non_empty() -> bool:
	var sched: Array = World.FACTION_SCHEDULES["merchant"]
	if sched.is_empty():
		push_error("test_merchant_schedule_is_non_empty: schedule is empty")
		return false
	return true


static func test_noble_schedule_is_non_empty() -> bool:
	var sched: Array = World.FACTION_SCHEDULES["noble"]
	if sched.is_empty():
		push_error("test_noble_schedule_is_non_empty: schedule is empty")
		return false
	return true


static func test_clergy_schedule_is_non_empty() -> bool:
	var sched: Array = World.FACTION_SCHEDULES["clergy"]
	if sched.is_empty():
		push_error("test_clergy_schedule_is_non_empty: schedule is empty")
		return false
	return true


static func test_all_schedule_entries_are_strings() -> bool:
	for faction in World.FACTION_SCHEDULES:
		for entry in World.FACTION_SCHEDULES[faction]:
			if not (entry is String):
				push_error("test_all_schedule_entries_are_strings: '%s' entry is not a String: %s" % [
					faction, str(entry)])
				return false
	return true


# ── Initial property state ────────────────────────────────────────────────────

static func test_initial_npcs_empty() -> bool:
	var world := _make_world()
	if not world.npcs.is_empty():
		push_error("test_initial_npcs_empty: npcs should be empty before _ready()")
		return false
	return true


static func test_initial_buildings_empty() -> bool:
	var world := _make_world()
	if not world.buildings.is_empty():
		push_error("test_initial_buildings_empty: buildings should be empty before _ready()")
		return false
	return true


static func test_initial_walkable_cells_empty() -> bool:
	var world := _make_world()
	if not world.walkable_cells.is_empty():
		push_error("test_initial_walkable_cells_empty: walkable_cells should be empty before _ready()")
		return false
	return true


static func test_initial_scenario_id_is_scenario_1() -> bool:
	var world := _make_world()
	if world.active_scenario_id != "scenario_1":
		push_error("test_initial_scenario_id_is_scenario_1: got '%s'" % world.active_scenario_id)
		return false
	return true


static func test_initial_dusk_snapshot_empty() -> bool:
	var world := _make_world()
	return world._dusk_snapshot.is_empty()


static func test_initial_socially_dead_ids_empty() -> bool:
	var world := _make_world()
	return world._socially_dead_ids.is_empty()


static func test_initial_daily_believe_counts_empty() -> bool:
	var world := _make_world()
	return world._daily_believe_counts.is_empty()


static func test_initial_key_npc_ids_empty() -> bool:
	var world := _make_world()
	return world.key_npc_ids.is_empty()


# ── get_npcs_near_location ────────────────────────────────────────────────────

static func test_get_npcs_near_unknown_location_returns_empty() -> bool:
	var world := _make_world()
	# No gathering points are populated without _ready(); unknown key returns [].
	var result := world.get_npcs_near_location("totally_unknown_location_xyz")
	if not result.is_empty():
		push_error("test_get_npcs_near_unknown_location_returns_empty: expected [], got %s" % str(result))
		return false
	return true


static func test_get_npcs_near_any_location_with_no_npcs_returns_empty() -> bool:
	# Even with a known gathering point (if we inject one), the npcs array is empty
	# so the radius search returns no results.
	var world := _make_world()
	world._gathering_points["market"] = Vector2i(10, 10)
	var result := world.get_npcs_near_location("market", 100)
	return result.is_empty()


# ── _on_day_changed with null agents ──────────────────────────────────────────

static func test_on_day_changed_no_crash_with_null_agents() -> bool:
	# All agents (rival_agent, inquisitor_agent, etc.) are null by default.
	# _on_day_changed must handle all null refs gracefully.
	# _update_illness_hotspots() iterates npcs (empty) — safe.
	# intel_store is null → replenish() guarded by null check.
	var world := _make_world()
	world._on_day_changed(1)
	# If we reach here without an error/crash, the test passes.
	return true

## test_spa1811_maren_orbit_halos.gd — Regression tests for SPA-1811: Maren
## orbit risk halos on social_graph_overlay.
##
## Covers (per SPA-1815 acceptance criteria):
##   • Orbit membership — _maren_orbit is populated for every Maren neighbour in
##     the social graph when the world is in scenario_2 (positive case).
##   • Negative case — non-scenario_2 worlds, null world, or null social_graph
##     leave _maren_orbit empty; halos are never rendered.
##   • Risk-tier color mapping — _maren_orbit_color() returns the correct constant
##     for each tier: red (weight ≥ 0.6), orange (≥ 0.4), amber (< 0.4),
##     including boundaries at exactly 0.6 and 0.4.
##   • Cleanup / no orphan entries — after an NPC leaves Maren's social-graph
##     edges, a subsequent _refresh_maren_orbit() removes them from the dict.
##   • _draw_risk_halos() early-exit guards — the function returns safely when
##     _risk_halo_on is false or _maren_orbit is empty, without touching the null
##     _draw_node that exists in headless tests.
##
## Uses the same test conventions as test_social_graph_overlay.gd (SPA-1000):
## overlay is created via SocialGraphOverlayScript.new() without being added to
## the scene tree, so _ready() is never called and all UI node refs remain null.

class_name TestSpa1811MarenOrbitHalos
extends RefCounted

const SocialGraphOverlayScript := preload("res://scripts/social_graph_overlay.gd")


# ── Mock helpers ──────────────────────────────────────────────────────────────

## Minimal NPC mock — mirrors the MockNpc in test_social_graph_overlay.gd.
class MockNpc:
	extends Node2D
	var npc_data: Dictionary = {}
	var rumor_slots: Dictionary = {}


## World mock extended with the properties _refresh_maren_orbit() reads:
## active_scenario_id and social_graph.
class MockWorld2:
	extends Node2D
	var npcs: Array = []
	var active_scenario_id: String = ""
	var social_graph: SocialGraph = null


## Returns a fresh SocialGraphOverlay without adding it to the scene tree.
static func _make_overlay() -> CanvasLayer:
	return SocialGraphOverlayScript.new()


## Returns a SocialGraph whose edges for MAREN_NUN_ID are set to neighbour_weights.
static func _make_sg_with_maren_edges(neighbour_weights: Dictionary) -> SocialGraph:
	var sg := SocialGraph.new()
	sg.edges[ScenarioConfig.MAREN_NUN_ID] = neighbour_weights
	return sg


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Orbit membership — positive cases
		"test_refresh_orbit_populates_in_scenario_2",
		"test_refresh_orbit_populates_all_neighbours",
		# Orbit membership — negative cases
		"test_refresh_orbit_empty_when_not_scenario_2",
		"test_refresh_orbit_empty_when_world_null",
		"test_refresh_orbit_empty_when_no_social_graph",
		# Risk-tier color mapping
		"test_orbit_color_red_at_exact_threshold",
		"test_orbit_color_red_above_threshold",
		"test_orbit_color_orange_at_exact_threshold",
		"test_orbit_color_orange_between_thresholds",
		"test_orbit_color_amber_below_orange_threshold",
		# Cleanup / no orphan entries
		"test_refresh_orbit_removes_departed_npc",
		"test_refresh_orbit_full_clear_when_edges_gone",
		# _draw_risk_halos early-exit guards (null _draw_node safe)
		"test_draw_halos_no_crash_when_halo_off",
		"test_draw_halos_no_crash_when_orbit_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1811 MarenOrbitHalos tests: %d passed, %d failed" % [passed, failed])


# ── Orbit membership — positive cases ────────────────────────────────────────

## In scenario_2, _refresh_maren_orbit() must populate _maren_orbit with every
## NPC that is a social-graph neighbour of Maren, preserving their edge weights.
static func test_refresh_orbit_populates_in_scenario_2() -> bool:
	var ov := _make_overlay()
	var world := MockWorld2.new()
	world.active_scenario_id = "scenario_2"
	world.social_graph = _make_sg_with_maren_edges({"priest_alan": 0.72})
	ov._world_ref = world
	ov._refresh_maren_orbit()
	if not ov._maren_orbit.has("priest_alan"):
		push_error("test_refresh_orbit_populates_in_scenario_2: 'priest_alan' missing from _maren_orbit")
		return false
	if absf(float(ov._maren_orbit["priest_alan"]) - 0.72) > 0.0001:
		push_error("test_refresh_orbit_populates_in_scenario_2: weight mismatch, got %s" % str(ov._maren_orbit["priest_alan"]))
		return false
	return true


## All Maren neighbours must appear in the orbit dict — not just the first one.
static func test_refresh_orbit_populates_all_neighbours() -> bool:
	var ov := _make_overlay()
	var world := MockWorld2.new()
	world.active_scenario_id = "scenario_2"
	world.social_graph = _make_sg_with_maren_edges({
		"npc_alpha": 0.65,
		"npc_beta":  0.45,
		"npc_gamma": 0.30,
	})
	ov._world_ref = world
	ov._refresh_maren_orbit()
	for npc_id in ["npc_alpha", "npc_beta", "npc_gamma"]:
		if not ov._maren_orbit.has(npc_id):
			push_error("test_refresh_orbit_populates_all_neighbours: '%s' missing from _maren_orbit" % npc_id)
			return false
	if ov._maren_orbit.size() != 3:
		push_error("test_refresh_orbit_populates_all_neighbours: expected 3 entries, got %d" % ov._maren_orbit.size())
		return false
	return true


# ── Orbit membership — negative cases ────────────────────────────────────────

## Non-scenario_2 world must leave _maren_orbit empty — halos must not appear
## in scenarios other than Scenario 2.
static func test_refresh_orbit_empty_when_not_scenario_2() -> bool:
	var ov := _make_overlay()
	var world := MockWorld2.new()
	world.active_scenario_id = "scenario_1"
	world.social_graph = _make_sg_with_maren_edges({"priest_alan": 0.72})
	ov._world_ref = world
	ov._refresh_maren_orbit()
	if not ov._maren_orbit.is_empty():
		push_error("test_refresh_orbit_empty_when_not_scenario_2: expected empty, got %s" % str(ov._maren_orbit))
		return false
	return true


## Null _world_ref must leave _maren_orbit empty and must not crash.
static func test_refresh_orbit_empty_when_world_null() -> bool:
	var ov := _make_overlay()
	# _world_ref defaults to null — no assignment needed.
	ov._refresh_maren_orbit()
	if not ov._maren_orbit.is_empty():
		push_error("test_refresh_orbit_empty_when_world_null: expected empty, got %s" % str(ov._maren_orbit))
		return false
	return true


## A null social_graph must leave _maren_orbit empty and must not crash.
static func test_refresh_orbit_empty_when_no_social_graph() -> bool:
	var ov := _make_overlay()
	var world := MockWorld2.new()
	world.active_scenario_id = "scenario_2"
	world.social_graph = null
	ov._world_ref = world
	ov._refresh_maren_orbit()
	if not ov._maren_orbit.is_empty():
		push_error("test_refresh_orbit_empty_when_no_social_graph: expected empty, got %s" % str(ov._maren_orbit))
		return false
	return true


# ── Risk-tier color mapping ───────────────────────────────────────────────────

## Weight at exactly the red threshold (0.6) → MAREN_ORBIT_COLOR_RED.
static func test_orbit_color_red_at_exact_threshold() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._maren_orbit_color(ScenarioConfig.MAREN_ORBIT_RISK_THRESHOLDS["red"])
	if not c.is_equal_approx(ScenarioConfig.MAREN_ORBIT_COLOR_RED):
		push_error("test_orbit_color_red_at_exact_threshold: expected RED (%s), got %s" % [
			ScenarioConfig.MAREN_ORBIT_COLOR_RED, c])
		return false
	return true


## Weight clearly above 0.6 → MAREN_ORBIT_COLOR_RED.
static func test_orbit_color_red_above_threshold() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._maren_orbit_color(0.9)
	if not c.is_equal_approx(ScenarioConfig.MAREN_ORBIT_COLOR_RED):
		push_error("test_orbit_color_red_above_threshold: expected RED (%s), got %s" % [
			ScenarioConfig.MAREN_ORBIT_COLOR_RED, c])
		return false
	return true


## Weight at exactly the orange threshold (0.4) → MAREN_ORBIT_COLOR_ORANGE.
static func test_orbit_color_orange_at_exact_threshold() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._maren_orbit_color(ScenarioConfig.MAREN_ORBIT_RISK_THRESHOLDS["orange"])
	if not c.is_equal_approx(ScenarioConfig.MAREN_ORBIT_COLOR_ORANGE):
		push_error("test_orbit_color_orange_at_exact_threshold: expected ORANGE (%s), got %s" % [
			ScenarioConfig.MAREN_ORBIT_COLOR_ORANGE, c])
		return false
	return true


## Weight between 0.4 and 0.6 → MAREN_ORBIT_COLOR_ORANGE (medium risk).
static func test_orbit_color_orange_between_thresholds() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._maren_orbit_color(0.5)
	if not c.is_equal_approx(ScenarioConfig.MAREN_ORBIT_COLOR_ORANGE):
		push_error("test_orbit_color_orange_between_thresholds: expected ORANGE (%s), got %s" % [
			ScenarioConfig.MAREN_ORBIT_COLOR_ORANGE, c])
		return false
	return true


## Weight below 0.4 → MAREN_ORBIT_COLOR_AMBER (lowest risk tier).
static func test_orbit_color_amber_below_orange_threshold() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._maren_orbit_color(0.25)
	if not c.is_equal_approx(ScenarioConfig.MAREN_ORBIT_COLOR_AMBER):
		push_error("test_orbit_color_amber_below_orange_threshold: expected AMBER (%s), got %s" % [
			ScenarioConfig.MAREN_ORBIT_COLOR_AMBER, c])
		return false
	return true


# ── Cleanup / no orphan entries ───────────────────────────────────────────────

## After an NPC leaves Maren's social-graph edges, a subsequent call to
## _refresh_maren_orbit() must remove that NPC from _maren_orbit.
## The remaining orbit member must not be disturbed.
static func test_refresh_orbit_removes_departed_npc() -> bool:
	var ov := _make_overlay()
	var world := MockWorld2.new()
	world.active_scenario_id = "scenario_2"
	var sg := _make_sg_with_maren_edges({"npc_stays": 0.65, "npc_leaves": 0.5})
	world.social_graph = sg
	ov._world_ref = world

	# First refresh — both NPCs enter the orbit.
	ov._refresh_maren_orbit()
	if not ov._maren_orbit.has("npc_leaves"):
		push_error("test_refresh_orbit_removes_departed_npc: pre-condition failed — 'npc_leaves' not in orbit after first refresh")
		return false

	# Simulate NPC leaving Maren's social-graph neighbourhood.
	sg.edges[ScenarioConfig.MAREN_NUN_ID].erase("npc_leaves")

	# Second refresh — orphan entry must be purged.
	ov._refresh_maren_orbit()
	if ov._maren_orbit.has("npc_leaves"):
		push_error("test_refresh_orbit_removes_departed_npc: 'npc_leaves' still in _maren_orbit after departure")
		return false
	if not ov._maren_orbit.has("npc_stays"):
		push_error("test_refresh_orbit_removes_departed_npc: 'npc_stays' was incorrectly removed")
		return false
	return true


## When all Maren edges are removed, _refresh_maren_orbit() must fully clear
## the orbit dict — no entries survive from the previous refresh.
static func test_refresh_orbit_full_clear_when_edges_gone() -> bool:
	var ov := _make_overlay()
	var world := MockWorld2.new()
	world.active_scenario_id = "scenario_2"
	var sg := _make_sg_with_maren_edges({"npc_x": 0.55})
	world.social_graph = sg
	ov._world_ref = world

	# Seed the orbit.
	ov._refresh_maren_orbit()
	if ov._maren_orbit.is_empty():
		push_error("test_refresh_orbit_full_clear_when_edges_gone: pre-condition failed — orbit empty after first refresh")
		return false

	# Remove all Maren edges from the graph.
	sg.edges.erase(ScenarioConfig.MAREN_NUN_ID)

	# Orbit must be fully cleared after the next refresh.
	ov._refresh_maren_orbit()
	if not ov._maren_orbit.is_empty():
		push_error("test_refresh_orbit_full_clear_when_edges_gone: orbit not cleared, got %s" % str(ov._maren_orbit))
		return false
	return true


# ── _draw_risk_halos early-exit guards ───────────────────────────────────────

## With _risk_halo_on = false, _draw_risk_halos() must exit before touching
## _draw_node (which is null in headless tests).
static func test_draw_halos_no_crash_when_halo_off() -> bool:
	var ov := _make_overlay()
	ov._risk_halo_on = false
	ov._maren_orbit = {"some_npc": 0.7}
	# _draw_node is null — any draw call would crash here.
	ov._draw_risk_halos([])
	return true


## With an empty orbit, _draw_risk_halos() must exit before any draw call
## (the or _maren_orbit.is_empty() branch in the guard).
static func test_draw_halos_no_crash_when_orbit_empty() -> bool:
	var ov := _make_overlay()
	ov._risk_halo_on = true
	# _maren_orbit is empty by default — no draw calls should be reached.
	ov._draw_risk_halos([])
	return true

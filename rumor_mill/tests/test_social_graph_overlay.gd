## test_social_graph_overlay.gd — Unit tests for SocialGraphOverlay (SPA-1000).
##
## Covers:
##   • FACTION_FILL constant — has entries for all three factions
##   • STATE_RING_COLOR constant — covers all nine RumorState values
##   • ZOOM_MIN / ZOOM_MAX constants — correct boundary values
##   • EDGE_THRESHOLD constant — 0.30
##   • HEATMAP_LOCATIONS constant — four named locations
##   • Initial state — visible_overlay, _heatmap_mode, _zoom_level, _pan_offset,
##                     _factions_hidden, _states_highlighted all start at defaults
##   • set_world()              — assigns _world_ref reference
##   • _edge_strength_color()   — weak / medium / strong colour selection and clamping
##   • _avg_trust()             — zero for empty graph; correct average for neighbours
##   • _trust_bar_color()       — green/yellow/red thresholds, including boundary values
##   • _npc_has_active_rumor()  — false when all slots UNAWARE or EXPIRED, true otherwise
##   • _count_active_rumor_slots() — counts non-UNAWARE, non-EXPIRED slots only
##   • on_rumor_event()         — null-world early-exit, non-whisper ignore, edge key insertion
##   • _compute_heatmap_targets() — empty NPCs, single faction, two-faction split
##   • _pie_slice_points()      — centre-first invariant, default and custom segment counts
##   • _find_npc_by_id()        — null for missing key, correct node for known key
##
## SocialGraphOverlay extends CanvasLayer. _ready() is NOT triggered in these tests
## (the instance is never added to a scene tree), so all UI node refs (_draw_node,
## _legend_panel, _search_input, etc.) remain null. Only pure-logic methods that do
## not access those refs are exercised here.
##
## Run from the Godot editor: Scene → Run Script (or call run() directly).

class_name TestSocialGraphOverlay
extends RefCounted

const SocialGraphOverlayScript := preload("res://scripts/social_graph_overlay.gd")


# ── Mock helpers ──────────────────────────────────────────────────────────────

## Minimal NPC mock extending Node2D to satisfy the Node2D type hint in the
## overlay methods.  rumor_slots holds actual Rumor.NpcRumorSlot instances.
class MockNpc:
	extends Node2D
	var npc_data: Dictionary = {}
	var rumor_slots: Dictionary = {}
	var current_location_code: String = ""


## Minimal world mock extending Node2D to satisfy set_world(world: Node2D).
class MockWorld:
	extends Node2D
	var npcs: Array = []


## Returns a fresh SocialGraphOverlay that has NOT been added to the scene tree.
## _ready() is skipped — all UI node refs are null; pure-logic methods are safe.
static func _make_overlay() -> CanvasLayer:
	return SocialGraphOverlayScript.new()


## Returns a MockNpc whose rumor_slots contains one real Rumor.NpcRumorSlot per
## entry in slot_states.
static func _make_npc_with_slots(npc_id: String, faction: String,
		slot_states: Array) -> MockNpc:
	var npc := MockNpc.new()
	npc.npc_data = {"id": npc_id, "faction": faction, "name": npc_id}
	for i in slot_states.size():
		var slot := Rumor.NpcRumorSlot.new()
		slot.state = slot_states[i]
		npc.rumor_slots["rid_%d" % i] = slot
	return npc


## Returns a SocialGraph with edges[from_id] set manually (no random build needed).
static func _make_sg_with_edges(from_id: String,
		neighbour_weights: Dictionary) -> SocialGraph:
	var sg := SocialGraph.new()
	sg.edges[from_id] = neighbour_weights
	return sg


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_faction_fill_has_all_factions",
		"test_state_ring_color_covers_all_states",
		"test_zoom_min_max_constants",
		"test_edge_threshold_constant",
		"test_heatmap_locations_four_entries",
		# Initial state
		"test_initial_overlay_hidden",
		"test_initial_not_heatmap_mode",
		"test_initial_zoom_level",
		"test_initial_pan_offset",
		"test_initial_factions_hidden_empty",
		"test_initial_states_highlighted_empty",
		# set_world
		"test_set_world_assigns_ref",
		# _edge_strength_color
		"test_edge_strength_color_at_threshold_returns_weak",
		"test_edge_strength_color_at_1_returns_strong",
		"test_edge_strength_color_at_055_returns_medium",
		"test_edge_strength_color_below_threshold_clamps_to_weak",
		# _avg_trust
		"test_avg_trust_no_neighbours_returns_zero",
		"test_avg_trust_single_neighbour",
		"test_avg_trust_multiple_neighbours_averages",
		# _trust_bar_color
		"test_trust_bar_color_high_returns_green",
		"test_trust_bar_color_medium_returns_yellow",
		"test_trust_bar_color_low_returns_red",
		"test_trust_bar_color_boundary_60_green",
		"test_trust_bar_color_boundary_35_yellow",
		# _npc_has_active_rumor
		"test_npc_has_active_rumor_empty_slots_false",
		"test_npc_has_active_rumor_all_unaware_false",
		"test_npc_has_active_rumor_all_expired_false",
		"test_npc_has_active_rumor_one_evaluating_true",
		"test_npc_has_active_rumor_one_spread_true",
		# _count_active_rumor_slots
		"test_count_active_slots_empty_returns_zero",
		"test_count_active_slots_all_unaware_returns_zero",
		"test_count_active_slots_mixed_states_counts_active",
		# on_rumor_event
		"test_on_rumor_event_null_world_safe",
		"test_on_rumor_event_no_whisper_string_ignored",
		"test_on_rumor_event_adds_spread_edge_key",
		# _compute_heatmap_targets
		"test_compute_heatmap_targets_no_npcs_empty_influence",
		"test_compute_heatmap_targets_single_merchant_at_market",
		"test_compute_heatmap_targets_two_factions_split_evenly",
		# _pie_slice_points
		"test_pie_slice_points_first_vertex_is_center",
		"test_pie_slice_points_default_segment_count",
		"test_pie_slice_points_custom_segments",
		# _find_npc_by_id
		"test_find_npc_by_id_returns_null_for_missing",
		"test_find_npc_by_id_returns_npc_for_known_id",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSocialGraphOverlay tests: %d passed, %d failed" % [passed, failed])


# ── Constants ─────────────────────────────────────────────────────────────────

## FACTION_FILL must have entries for all three in-game factions.
static func test_faction_fill_has_all_factions() -> bool:
	var ff: Dictionary = SocialGraphOverlayScript.FACTION_FILL
	for key in ["merchant", "noble", "clergy"]:
		if not ff.has(key):
			push_error("test_faction_fill_has_all_factions: missing key '%s'" % key)
			return false
	return true


## STATE_RING_COLOR must cover every member of the RumorState enum.
static func test_state_ring_color_covers_all_states() -> bool:
	var src: Dictionary = SocialGraphOverlayScript.STATE_RING_COLOR
	var expected_states: Array = [
		Rumor.RumorState.UNAWARE,      Rumor.RumorState.EVALUATING,
		Rumor.RumorState.BELIEVE,      Rumor.RumorState.REJECT,
		Rumor.RumorState.SPREAD,       Rumor.RumorState.ACT,
		Rumor.RumorState.DEFENDING,    Rumor.RumorState.CONTRADICTED,
		Rumor.RumorState.EXPIRED,
	]
	for state in expected_states:
		if not src.has(state):
			push_error("test_state_ring_color_covers_all_states: missing state %d" % int(state))
			return false
	return true


## ZOOM_MIN must be 0.5 and ZOOM_MAX must be 2.0.
static func test_zoom_min_max_constants() -> bool:
	if SocialGraphOverlayScript.ZOOM_MIN != 0.5:
		push_error("test_zoom_min_max_constants: ZOOM_MIN expected 0.5, got %f" % SocialGraphOverlayScript.ZOOM_MIN)
		return false
	if SocialGraphOverlayScript.ZOOM_MAX != 2.0:
		push_error("test_zoom_min_max_constants: ZOOM_MAX expected 2.0, got %f" % SocialGraphOverlayScript.ZOOM_MAX)
		return false
	return true


## EDGE_THRESHOLD must equal 0.30 — edges below this weight are not drawn.
static func test_edge_threshold_constant() -> bool:
	if absf(SocialGraphOverlayScript.EDGE_THRESHOLD - 0.30) > 0.0001:
		push_error("test_edge_threshold_constant: expected 0.30, got %f" % SocialGraphOverlayScript.EDGE_THRESHOLD)
		return false
	return true


## HEATMAP_LOCATIONS must list exactly four location codes.
static func test_heatmap_locations_four_entries() -> bool:
	var locs: Array = SocialGraphOverlayScript.HEATMAP_LOCATIONS
	if locs.size() != 4:
		push_error("test_heatmap_locations_four_entries: expected 4, got %d" % locs.size())
		return false
	return true


# ── Initial state ─────────────────────────────────────────────────────────────

## visible_overlay must be false before the overlay is shown.
static func test_initial_overlay_hidden() -> bool:
	var ov := _make_overlay()
	if ov.visible_overlay != false:
		push_error("test_initial_overlay_hidden: visible_overlay expected false")
		return false
	return true


## _heatmap_mode must default to false (social graph mode).
static func test_initial_not_heatmap_mode() -> bool:
	var ov := _make_overlay()
	if ov._heatmap_mode != false:
		push_error("test_initial_not_heatmap_mode: _heatmap_mode expected false")
		return false
	return true


## _zoom_level must default to 1.0 (no magnification).
static func test_initial_zoom_level() -> bool:
	var ov := _make_overlay()
	if absf(ov._zoom_level - 1.0) > 0.0001:
		push_error("test_initial_zoom_level: expected 1.0, got %f" % ov._zoom_level)
		return false
	return true


## _pan_offset must default to Vector2.ZERO (centred view).
static func test_initial_pan_offset() -> bool:
	var ov := _make_overlay()
	if ov._pan_offset != Vector2.ZERO:
		push_error("test_initial_pan_offset: expected Vector2.ZERO, got %s" % ov._pan_offset)
		return false
	return true


## _factions_hidden must be empty — no faction is hidden at start.
static func test_initial_factions_hidden_empty() -> bool:
	var ov := _make_overlay()
	if not ov._factions_hidden.is_empty():
		push_error("test_initial_factions_hidden_empty: expected empty dict, got %s" % ov._factions_hidden)
		return false
	return true


## _states_highlighted must be empty — no state-highlight filter active at start.
static func test_initial_states_highlighted_empty() -> bool:
	var ov := _make_overlay()
	if not ov._states_highlighted.is_empty():
		push_error("test_initial_states_highlighted_empty: expected empty dict, got %s" % ov._states_highlighted)
		return false
	return true


# ── set_world ─────────────────────────────────────────────────────────────────

## set_world() must store the supplied node in _world_ref.
static func test_set_world_assigns_ref() -> bool:
	var ov := _make_overlay()
	var world := MockWorld.new()
	ov.set_world(world)
	if ov._world_ref != world:
		push_error("test_set_world_assigns_ref: _world_ref was not set")
		return false
	return true


# ── _edge_strength_color ──────────────────────────────────────────────────────

## At exactly EDGE_THRESHOLD, t = 0 → result equals EDGE_WEAK_COLOR.
static func test_edge_strength_color_at_threshold_returns_weak() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._edge_strength_color(SocialGraphOverlayScript.EDGE_THRESHOLD)
	var expected: Color = SocialGraphOverlayScript.EDGE_WEAK_COLOR
	if not c.is_equal_approx(expected):
		push_error("test_edge_strength_color_at_threshold_returns_weak: got %s, expected %s" % [c, expected])
		return false
	return true


## At weight = 1.0, t = 1 in the strong branch → result equals EDGE_STRONG_COLOR.
static func test_edge_strength_color_at_1_returns_strong() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._edge_strength_color(1.0)
	var expected: Color = SocialGraphOverlayScript.EDGE_STRONG_COLOR
	if not c.is_equal_approx(expected):
		push_error("test_edge_strength_color_at_1_returns_strong: got %s, expected %s" % [c, expected])
		return false
	return true


## At weight = 0.55, the strong branch uses t = 0 → result equals EDGE_MEDIUM_COLOR.
static func test_edge_strength_color_at_055_returns_medium() -> bool:
	var ov := _make_overlay()
	# 0.55 is NOT < 0.55 → else branch: t = (0.55 - 0.55) / (1.0 - 0.55) = 0.0
	# lerp(MEDIUM, STRONG, 0) = MEDIUM
	var c: Color = ov._edge_strength_color(0.55)
	var expected: Color = SocialGraphOverlayScript.EDGE_MEDIUM_COLOR
	if not c.is_equal_approx(expected):
		push_error("test_edge_strength_color_at_055_returns_medium: got %s, expected %s" % [c, expected])
		return false
	return true


## Below EDGE_THRESHOLD, t clamps to 0 → result still equals EDGE_WEAK_COLOR.
static func test_edge_strength_color_below_threshold_clamps_to_weak() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._edge_strength_color(0.0)
	var expected: Color = SocialGraphOverlayScript.EDGE_WEAK_COLOR
	if not c.is_equal_approx(expected):
		push_error("test_edge_strength_color_below_threshold_clamps_to_weak: got %s, expected %s" % [c, expected])
		return false
	return true


# ── _avg_trust ────────────────────────────────────────────────────────────────

## A node with no neighbours returns 0.0.
static func test_avg_trust_no_neighbours_returns_zero() -> bool:
	var ov := _make_overlay()
	var sg := SocialGraph.new()
	var result: float = ov._avg_trust(sg, "nobody")
	if result != 0.0:
		push_error("test_avg_trust_no_neighbours_returns_zero: expected 0.0, got %f" % result)
		return false
	return true


## One neighbour with weight 0.6 → average is 0.6.
static func test_avg_trust_single_neighbour() -> bool:
	var ov := _make_overlay()
	var sg := _make_sg_with_edges("a", {"b": 0.6})
	var result: float = ov._avg_trust(sg, "a")
	if absf(result - 0.6) > 0.0001:
		push_error("test_avg_trust_single_neighbour: expected 0.6, got %f" % result)
		return false
	return true


## Two neighbours with weights 0.4 and 0.8 → average is 0.6.
static func test_avg_trust_multiple_neighbours_averages() -> bool:
	var ov := _make_overlay()
	var sg := _make_sg_with_edges("a", {"b": 0.4, "c": 0.8})
	var result: float = ov._avg_trust(sg, "a")
	if absf(result - 0.6) > 0.0001:
		push_error("test_avg_trust_multiple_neighbours_averages: expected 0.6, got %f" % result)
		return false
	return true


# ── _trust_bar_color ──────────────────────────────────────────────────────────

## trust >= 0.6 → green bar.
static func test_trust_bar_color_high_returns_green() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._trust_bar_color(0.8)
	var expected := Color(0.30, 0.90, 0.45, 0.90)
	if not c.is_equal_approx(expected):
		push_error("test_trust_bar_color_high_returns_green: got %s" % c)
		return false
	return true


## 0.35 <= trust < 0.6 → yellow bar.
static func test_trust_bar_color_medium_returns_yellow() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._trust_bar_color(0.5)
	var expected := Color(0.95, 0.80, 0.30, 0.90)
	if not c.is_equal_approx(expected):
		push_error("test_trust_bar_color_medium_returns_yellow: got %s" % c)
		return false
	return true


## trust < 0.35 → red bar.
static func test_trust_bar_color_low_returns_red() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._trust_bar_color(0.2)
	var expected := Color(0.95, 0.40, 0.25, 0.90)
	if not c.is_equal_approx(expected):
		push_error("test_trust_bar_color_low_returns_red: got %s" % c)
		return false
	return true


## Boundary at exactly 0.6 → green (>= 0.6 branch).
static func test_trust_bar_color_boundary_60_green() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._trust_bar_color(0.6)
	var expected := Color(0.30, 0.90, 0.45, 0.90)
	if not c.is_equal_approx(expected):
		push_error("test_trust_bar_color_boundary_60_green: got %s" % c)
		return false
	return true


## Boundary at exactly 0.35 → yellow (>= 0.35 branch).
static func test_trust_bar_color_boundary_35_yellow() -> bool:
	var ov := _make_overlay()
	var c: Color = ov._trust_bar_color(0.35)
	var expected := Color(0.95, 0.80, 0.30, 0.90)
	if not c.is_equal_approx(expected):
		push_error("test_trust_bar_color_boundary_35_yellow: got %s" % c)
		return false
	return true


# ── _npc_has_active_rumor ─────────────────────────────────────────────────────

## An NPC with no rumor slots must return false.
static func test_npc_has_active_rumor_empty_slots_false() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [])
	if ov._npc_has_active_rumor(npc) != false:
		push_error("test_npc_has_active_rumor_empty_slots_false: expected false")
		return false
	return true


## All UNAWARE slots → no active rumor → false.
static func test_npc_has_active_rumor_all_unaware_false() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [
		Rumor.RumorState.UNAWARE, Rumor.RumorState.UNAWARE,
	])
	if ov._npc_has_active_rumor(npc) != false:
		push_error("test_npc_has_active_rumor_all_unaware_false: expected false")
		return false
	return true


## All EXPIRED slots → treated as inactive → false.
static func test_npc_has_active_rumor_all_expired_false() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [
		Rumor.RumorState.EXPIRED, Rumor.RumorState.EXPIRED,
	])
	if ov._npc_has_active_rumor(npc) != false:
		push_error("test_npc_has_active_rumor_all_expired_false: expected false")
		return false
	return true


## One EVALUATING slot among UNAWARE ones → active rumor present → true.
static func test_npc_has_active_rumor_one_evaluating_true() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [
		Rumor.RumorState.UNAWARE, Rumor.RumorState.EVALUATING,
	])
	if ov._npc_has_active_rumor(npc) != true:
		push_error("test_npc_has_active_rumor_one_evaluating_true: expected true")
		return false
	return true


## A single SPREAD slot → active rumor → true.
static func test_npc_has_active_rumor_one_spread_true() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [Rumor.RumorState.SPREAD])
	if ov._npc_has_active_rumor(npc) != true:
		push_error("test_npc_has_active_rumor_one_spread_true: expected true")
		return false
	return true


# ── _count_active_rumor_slots ─────────────────────────────────────────────────

## No slots → count = 0.
static func test_count_active_slots_empty_returns_zero() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [])
	var count: int = ov._count_active_rumor_slots(npc)
	if count != 0:
		push_error("test_count_active_slots_empty_returns_zero: expected 0, got %d" % count)
		return false
	return true


## All UNAWARE slots → count = 0.
static func test_count_active_slots_all_unaware_returns_zero() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [
		Rumor.RumorState.UNAWARE, Rumor.RumorState.UNAWARE,
	])
	var count: int = ov._count_active_rumor_slots(npc)
	if count != 0:
		push_error("test_count_active_slots_all_unaware_returns_zero: expected 0, got %d" % count)
		return false
	return true


## Mixed states: UNAWARE, EVALUATING, BELIEVE, EXPIRED → 2 active (EVALUATING + BELIEVE).
static func test_count_active_slots_mixed_states_counts_active() -> bool:
	var ov := _make_overlay()
	var npc := _make_npc_with_slots("a", "merchant", [
		Rumor.RumorState.UNAWARE,
		Rumor.RumorState.EVALUATING,
		Rumor.RumorState.BELIEVE,
		Rumor.RumorState.EXPIRED,
	])
	var count: int = ov._count_active_rumor_slots(npc)
	if count != 2:
		push_error("test_count_active_slots_mixed_states_counts_active: expected 2, got %d" % count)
		return false
	return true


# ── on_rumor_event ────────────────────────────────────────────────────────────

## With null _world_ref the function must return early without crashing.
static func test_on_rumor_event_null_world_safe() -> bool:
	var ov := _make_overlay()
	# _world_ref is null by default — should exit gracefully.
	ov.on_rumor_event("Alice whispered to Bob [rid_1]")
	return true


## Messages without " whispered to " are silently ignored; _active_spread_edges stays empty.
static func test_on_rumor_event_no_whisper_string_ignored() -> bool:
	var ov := _make_overlay()
	var world := MockWorld.new()
	world.npcs = []
	ov.set_world(world)
	ov.on_rumor_event("Alice told Bob something")
	if not ov._active_spread_edges.is_empty():
		push_error("test_on_rumor_event_no_whisper_string_ignored: expected empty spread edges")
		return false
	return true


## A valid whisper message with matching NPCs populates _active_spread_edges with the
## correctly sorted key ("npc_a|npc_b" because "npc_a" < "npc_b").
static func test_on_rumor_event_adds_spread_edge_key() -> bool:
	var ov := _make_overlay()
	var world := MockWorld.new()
	var npc_a := _make_npc_with_slots("npc_a", "merchant", [])
	npc_a.npc_data["name"] = "Alice"
	var npc_b := _make_npc_with_slots("npc_b", "noble", [])
	npc_b.npc_data["name"] = "Bob"
	world.npcs = [npc_a, npc_b]
	ov.set_world(world)
	ov.on_rumor_event("Alice whispered to Bob [rid_1]")
	var expected_key := "npc_a|npc_b"
	if not ov._active_spread_edges.has(expected_key):
		push_error("test_on_rumor_event_adds_spread_edge_key: key '%s' missing; got %s" % [
			expected_key, ov._active_spread_edges])
		return false
	return true


# ── _compute_heatmap_targets ──────────────────────────────────────────────────

## With an empty NPC list, every location must have an empty influence dict.
static func test_compute_heatmap_targets_no_npcs_empty_influence() -> bool:
	var ov := _make_overlay()
	var world := MockWorld.new()
	world.npcs = []
	ov.set_world(world)
	var targets: Dictionary = ov._compute_heatmap_targets()
	for loc in SocialGraphOverlayScript.HEATMAP_LOCATIONS:
		if not targets.has(loc):
			push_error("test_compute_heatmap_targets_no_npcs_empty_influence: missing key '%s'" % loc)
			return false
		if not (targets[loc] as Dictionary).is_empty():
			push_error("test_compute_heatmap_targets_no_npcs_empty_influence: '%s' not empty" % loc)
			return false
	return true


## One merchant NPC at "market" → merchant influence = 1.0, other factions absent.
static func test_compute_heatmap_targets_single_merchant_at_market() -> bool:
	var ov := _make_overlay()
	var world := MockWorld.new()
	var npc := _make_npc_with_slots("m1", "merchant", [])
	npc.current_location_code = "market"
	world.npcs = [npc]
	ov.set_world(world)
	var targets: Dictionary = ov._compute_heatmap_targets()
	var market_inf: Dictionary = targets.get("market", {})
	var merchant_share: float = market_inf.get("merchant", 0.0)
	if absf(merchant_share - 1.0) > 0.0001:
		push_error("test_compute_heatmap_targets_single_merchant_at_market: expected 1.0, got %f" % merchant_share)
		return false
	return true


## One merchant + one noble at "tavern" → each has 0.5 share.
static func test_compute_heatmap_targets_two_factions_split_evenly() -> bool:
	var ov := _make_overlay()
	var world := MockWorld.new()
	var npc1 := _make_npc_with_slots("m1", "merchant", [])
	npc1.current_location_code = "tavern"
	var npc2 := _make_npc_with_slots("n1", "noble", [])
	npc2.current_location_code = "tavern"
	world.npcs = [npc1, npc2]
	ov.set_world(world)
	var targets: Dictionary = ov._compute_heatmap_targets()
	var tavern_inf: Dictionary = targets.get("tavern", {})
	var merch: float = tavern_inf.get("merchant", 0.0)
	var noble: float = tavern_inf.get("noble", 0.0)
	if absf(merch - 0.5) > 0.0001 or absf(noble - 0.5) > 0.0001:
		push_error("test_compute_heatmap_targets_two_factions_split_evenly: merchant=%f noble=%f" % [merch, noble])
		return false
	return true


# ── _pie_slice_points ─────────────────────────────────────────────────────────

## The very first vertex in the returned array must be the centre point.
static func test_pie_slice_points_first_vertex_is_center() -> bool:
	var ov := _make_overlay()
	var center := Vector2(100.0, 200.0)
	var pts: PackedVector2Array = ov._pie_slice_points(center, 50.0, 0.0, PI)
	if pts.is_empty() or pts[0] != center:
		push_error("test_pie_slice_points_first_vertex_is_center: first point is not center")
		return false
	return true


## Default segments = 24 → total points = 1 (centre) + 25 (arc) = 26.
static func test_pie_slice_points_default_segment_count() -> bool:
	var ov := _make_overlay()
	var pts: PackedVector2Array = ov._pie_slice_points(Vector2.ZERO, 50.0, 0.0, PI)
	var expected_count := 24 + 2
	if pts.size() != expected_count:
		push_error("test_pie_slice_points_default_segment_count: expected %d, got %d" % [expected_count, pts.size()])
		return false
	return true


## Custom segments = 8 → total points = 1 + 9 = 10.
static func test_pie_slice_points_custom_segments() -> bool:
	var ov := _make_overlay()
	var pts: PackedVector2Array = ov._pie_slice_points(Vector2.ZERO, 30.0, 0.0, TAU, 8)
	var expected_count := 8 + 2
	if pts.size() != expected_count:
		push_error("test_pie_slice_points_custom_segments: expected %d, got %d" % [expected_count, pts.size()])
		return false
	return true


# ── _find_npc_by_id ───────────────────────────────────────────────────────────

## Returns null when _npc_lookup is empty (no draw pass has occurred).
static func test_find_npc_by_id_returns_null_for_missing() -> bool:
	var ov := _make_overlay()
	var result = ov._find_npc_by_id([], "nobody")
	if result != null:
		push_error("test_find_npc_by_id_returns_null_for_missing: expected null, got %s" % result)
		return false
	return true


## Returns the stored node when the id is present in _npc_lookup.
static func test_find_npc_by_id_returns_npc_for_known_id() -> bool:
	var ov := _make_overlay()
	var node := MockNpc.new()
	ov._npc_lookup["alpha"] = node
	var result = ov._find_npc_by_id([], "alpha")
	if result != node:
		push_error("test_find_npc_by_id_returns_npc_for_known_id: returned wrong node")
		return false
	return true

## test_debug_overlay.gd — Unit tests for debug_overlay.gd (SPA-2747).
##
## Covers:
##   • Initial state   — show_states / show_social / show_lineage all false
##   • Null refs       — _world_ref, _draw_node, _lineage_panel, _lineage_label null
##   • set_world()     — assigns _world_ref to the provided Node2D
##   • STATE_COLORS    — dict has entries for all 9 RumorState values
##   • _find_npc_by_id — returns null for empty array; returns null when no match
##
## debug_overlay.gd creates child nodes in _ready(); tests instantiate without a
## scene tree so those nodes are never built.  All paths exercised here are
## pure-state checks or helpers with no scene-tree dependency.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestDebugOverlay
extends RefCounted

const DebugOverlayScript := preload("res://scripts/debug_overlay.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a fresh DebugOverlay that has NOT been added to the scene tree.
## _ready() is NOT called, so _draw_node / _lineage_panel remain null.
static func _make_do() -> Node:
	return DebugOverlayScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial boolean state
		"test_show_states_initial_false",
		"test_show_social_initial_false",
		"test_show_lineage_initial_false",
		# Null refs before _ready()
		"test_world_ref_initial_null",
		"test_draw_node_initial_null",
		"test_lineage_panel_initial_null",
		# set_world() setter
		"test_set_world_assigns_ref",
		# STATE_COLORS completeness
		"test_state_colors_has_nine_entries",
		# _find_npc_by_id pure logic
		"test_find_npc_by_id_empty_array_returns_null",
		"test_find_npc_by_id_no_match_returns_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nDebugOverlay tests: %d passed, %d failed" % [passed, failed])


# ── Initial boolean state ─────────────────────────────────────────────────────

## State badges are hidden by default.
static func test_show_states_initial_false() -> bool:
	var d := _make_do()
	var ok: bool = d.show_states == false
	d.free()
	return ok


## Social graph is hidden by default.
static func test_show_social_initial_false() -> bool:
	var d := _make_do()
	var ok: bool = d.show_social == false
	d.free()
	return ok


## Lineage panel is hidden by default.
static func test_show_lineage_initial_false() -> bool:
	var d := _make_do()
	var ok: bool = d.show_lineage == false
	d.free()
	return ok


# ── Null refs before _ready() ────────────────────────────────────────────────

## _world_ref starts null — no world connected on construction.
static func test_world_ref_initial_null() -> bool:
	var d := _make_do()
	var ok: bool = d._world_ref == null
	d.free()
	return ok


## _draw_node starts null — created in _ready(), not yet connected.
static func test_draw_node_initial_null() -> bool:
	var d := _make_do()
	var ok: bool = d._draw_node == null
	d.free()
	return ok


## _lineage_panel starts null — built on demand in _ready().
static func test_lineage_panel_initial_null() -> bool:
	var d := _make_do()
	var ok: bool = d._lineage_panel == null
	d.free()
	return ok


# ── set_world() setter ────────────────────────────────────────────────────────

## set_world() must store the provided Node2D in _world_ref.
static func test_set_world_assigns_ref() -> bool:
	var d := _make_do()
	var dummy := Node2D.new()
	d.set_world(dummy)
	var ok: bool = d._world_ref == dummy
	d.free()
	dummy.free()
	return ok


# ── STATE_COLORS completeness ─────────────────────────────────────────────────

## STATE_COLORS must have one entry per RumorState value.
## Rumor.RumorState has 9 members:
##   UNAWARE, EVALUATING, BELIEVE, REJECT, SPREAD, ACT, EXPIRED, DEFENDING, CONTRADICTED
static func test_state_colors_has_nine_entries() -> bool:
	var d := _make_do()
	var ok: bool = d.STATE_COLORS.size() == 9
	if not ok:
		push_error("test_state_colors_has_nine_entries: expected 9 entries, got %d" % d.STATE_COLORS.size())
	d.free()
	return ok


# ── _find_npc_by_id pure logic ────────────────────────────────────────────────

## Searching an empty NPC array must return null without crashing.
static func test_find_npc_by_id_empty_array_returns_null() -> bool:
	var d := _make_do()
	var result = d._find_npc_by_id([], "aria")
	var ok: bool = result == null
	d.free()
	return ok


## Searching an array with no matching id must return null.
## Uses a lightweight inner-class mock with a npc_data Dictionary.
static func test_find_npc_by_id_no_match_returns_null() -> bool:
	var d := _make_do()
	# Build a plain Node2D mock and attach npc_data via set().
	# _find_npc_by_id only reads npc_data.get("id", "") — no other NPC API needed.
	var mock := Node2D.new()
	mock.set_meta("npc_data_dict", {"id": "bryn"})
	# Re-wrap: _find_npc_by_id calls npc.npc_data.get(), so we need a real property.
	# Since Node2D does not declare npc_data, use a GDScript object with the property.
	mock.free()

	# Create a minimal script object that exposes npc_data.
	var src := GDScript.new()
	src.source_code = "extends RefCounted\nvar npc_data: Dictionary = {}"
	src.reload()
	var npc_obj = src.new()
	npc_obj.npc_data = {"id": "bryn"}

	var result = d._find_npc_by_id([npc_obj], "aria")  # "aria" != "bryn" → null
	var ok: bool = result == null
	d.free()
	return ok

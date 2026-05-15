## test_debug_console.gd — Unit tests for debug_console.gd (SPA-2747).
##
## Covers:
##   • Initial state  — _world_ref and _overlay_ref are null on construction
##   • set_world()    — assigns _world_ref to the provided Node2D
##   • set_overlay()  — assigns _overlay_ref to the provided CanvasLayer
##
## debug_console.gd uses @onready for its scene-tree UI nodes (panel, log_label,
## input_box), so tests avoid any method that reaches those.  All testable
## behaviours here are pure-state setters that do not touch the scene tree.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestDebugConsole
extends RefCounted

const DebugConsoleScript := preload("res://scripts/debug_console.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a fresh DebugConsole that has NOT been added to the scene tree.
## _ready() is NOT called, so @onready vars remain null.
static func _make_dc() -> Node:
	return DebugConsoleScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state
		"test_world_ref_initial_null",
		"test_overlay_ref_initial_null",
		# Setters
		"test_set_world_assigns_ref",
		"test_set_overlay_assigns_ref",
		# Null-safe setter calls
		"test_set_world_null_safe",
		"test_set_overlay_null_safe",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nDebugConsole tests: %d passed, %d failed" % [passed, failed])


# ── Initial state ─────────────────────────────────────────────────────────────

## _world_ref starts null — no world connected on construction.
static func test_world_ref_initial_null() -> bool:
	var dc := _make_dc()
	var ok: bool = dc._world_ref == null
	dc.free()
	return ok


## _overlay_ref starts null — no overlay connected on construction.
static func test_overlay_ref_initial_null() -> bool:
	var dc := _make_dc()
	var ok: bool = dc._overlay_ref == null
	dc.free()
	return ok


# ── Setters ───────────────────────────────────────────────────────────────────

## set_world() must store the provided Node2D in _world_ref.
static func test_set_world_assigns_ref() -> bool:
	var dc := _make_dc()
	var dummy := Node2D.new()
	dc.set_world(dummy)
	var ok: bool = dc._world_ref == dummy
	dc.free()
	dummy.free()
	return ok


## set_overlay() must store the provided CanvasLayer in _overlay_ref.
static func test_set_overlay_assigns_ref() -> bool:
	var dc := _make_dc()
	var dummy := CanvasLayer.new()
	dc.set_overlay(dummy)
	var ok: bool = dc._overlay_ref == dummy
	dc.free()
	dummy.free()
	return ok


## set_world(null) must not crash — guard against disconnection calls.
static func test_set_world_null_safe() -> bool:
	var dc := _make_dc()
	dc.set_world(null)      # must not raise; just stores null
	var ok: bool = dc._world_ref == null
	dc.free()
	return ok


## set_overlay(null) must not crash — guard against disconnection calls.
static func test_set_overlay_null_safe() -> bool:
	var dc := _make_dc()
	dc.set_overlay(null)    # must not raise; just stores null
	var ok: bool = dc._overlay_ref == null
	dc.free()
	return ok

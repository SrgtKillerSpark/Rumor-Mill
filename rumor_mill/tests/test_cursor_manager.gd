## test_cursor_manager.gd — Unit tests for CursorManager priority-based cursor system (SPA-2619).
##
## Covers:
##   • Priority constants (PRIORITY_WORLD/NPC/RECON/HUD)
##   • Initial state: _requests empty, _current_shape = CURSOR_ARROW
##   • request_cursor() populates _requests and updates _current_shape
##   • Higher-priority request wins; lower-priority does not override
##   • Updating an existing owner replaces its entry
##   • Equal-priority requests: first-inserted wins (> not >=)
##   • release_cursor() removes entry and falls back to next highest priority
##   • release_cursor() with no remaining requests resets to CURSOR_ARROW
##   • release_cursor() on non-existent owner is a no-op
##   • Multi-release cascade and full-release reset
##
## Strategy: CursorManager extends Node — instantiated via .new() without adding
## to the scene tree.  DisplayServer.cursor_set_shape() is called internally by
## _apply() but does not crash in the editor/headless test runner.  We validate
## _current_shape and _requests state directly rather than the DisplayServer call.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestCursorManager
extends RefCounted

const CursorManagerScript := preload("res://scripts/cursor_manager.gd")


static func _make_cm() -> Node:
	return CursorManagerScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_priority_world_value",
		"test_priority_npc_value",
		"test_priority_recon_value",
		"test_priority_hud_value",

		# ── initial state ──
		"test_initial_requests_empty",
		"test_initial_current_shape_arrow",

		# ── request_cursor() ──
		"test_request_cursor_populates_requests",
		"test_request_cursor_updates_current_shape",
		"test_request_cursor_higher_priority_wins",
		"test_request_cursor_lower_priority_does_not_override",
		"test_request_cursor_update_existing_owner",
		"test_request_cursor_equal_priority_first_inserted_wins",

		# ── release_cursor() ──
		"test_release_cursor_removes_entry",
		"test_release_cursor_falls_back_to_next_priority",
		"test_release_cursor_with_no_remaining_resets_to_arrow",
		"test_release_cursor_nonexistent_owner_is_noop",

		# ── edge cases ──
		"test_multiple_releases_cascade_to_single_remaining",
		"test_release_all_clears_requests_and_resets_shape",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_priority_world_value() -> bool:
	return CursorManagerScript.PRIORITY_WORLD == 0

func test_priority_npc_value() -> bool:
	return CursorManagerScript.PRIORITY_NPC == 1

func test_priority_recon_value() -> bool:
	return CursorManagerScript.PRIORITY_RECON == 2

func test_priority_hud_value() -> bool:
	return CursorManagerScript.PRIORITY_HUD == 3


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_requests_empty() -> bool:
	var cm := _make_cm()
	return cm._requests.is_empty()

func test_initial_current_shape_arrow() -> bool:
	var cm := _make_cm()
	return cm._current_shape == DisplayServer.CURSOR_ARROW


# ══════════════════════════════════════════════════════════════════════════════
# request_cursor()
# ══════════════════════════════════════════════════════════════════════════════

func test_request_cursor_populates_requests() -> bool:
	var cm := _make_cm()
	cm.request_cursor("tooltip", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_WORLD)
	return cm._requests.has("tooltip")

func test_request_cursor_updates_current_shape() -> bool:
	var cm := _make_cm()
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	return cm._current_shape == DisplayServer.CURSOR_POINTING_HAND

func test_request_cursor_higher_priority_wins() -> bool:
	var cm := _make_cm()
	# Register low-priority first, then high-priority — high must win.
	cm.request_cursor("world", DisplayServer.CURSOR_CROSS, CursorManagerScript.PRIORITY_WORLD)
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	return cm._current_shape == DisplayServer.CURSOR_POINTING_HAND

func test_request_cursor_lower_priority_does_not_override() -> bool:
	var cm := _make_cm()
	# Recon (priority 2) registered first; then world (priority 0) must NOT override.
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	cm.request_cursor("world", DisplayServer.CURSOR_CROSS, CursorManagerScript.PRIORITY_WORLD)
	return cm._current_shape == DisplayServer.CURSOR_POINTING_HAND

func test_request_cursor_update_existing_owner() -> bool:
	var cm := _make_cm()
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	cm.request_cursor("recon", DisplayServer.CURSOR_CROSS, CursorManagerScript.PRIORITY_RECON)
	return cm._requests["recon"]["shape"] == DisplayServer.CURSOR_CROSS

func test_request_cursor_equal_priority_first_inserted_wins() -> bool:
	# _apply() uses > (strict), so among equal-priority requests the first
	# iterated entry wins.  Dictionary preserves insertion order in GDScript 4.
	var cm := _make_cm()
	cm.request_cursor("owner_a", DisplayServer.CURSOR_POINTING_HAND, 1)
	cm.request_cursor("owner_b", DisplayServer.CURSOR_CROSS, 1)
	return cm._current_shape == DisplayServer.CURSOR_POINTING_HAND


# ══════════════════════════════════════════════════════════════════════════════
# release_cursor()
# ══════════════════════════════════════════════════════════════════════════════

func test_release_cursor_removes_entry() -> bool:
	var cm := _make_cm()
	cm.request_cursor("npc", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_NPC)
	cm.release_cursor("npc")
	return not cm._requests.has("npc")

func test_release_cursor_falls_back_to_next_priority() -> bool:
	var cm := _make_cm()
	cm.request_cursor("world", DisplayServer.CURSOR_CROSS, CursorManagerScript.PRIORITY_WORLD)
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	# Releasing the highest-priority request must restore the next best shape.
	cm.release_cursor("recon")
	return cm._current_shape == DisplayServer.CURSOR_CROSS

func test_release_cursor_with_no_remaining_resets_to_arrow() -> bool:
	var cm := _make_cm()
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	cm.release_cursor("recon")
	return cm._current_shape == DisplayServer.CURSOR_ARROW

func test_release_cursor_nonexistent_owner_is_noop() -> bool:
	# Releasing an owner that was never registered must not disturb existing state.
	var cm := _make_cm()
	cm.request_cursor("recon", DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_RECON)
	cm.release_cursor("ghost")
	return cm._requests.has("recon") and cm._current_shape == DisplayServer.CURSOR_POINTING_HAND


# ══════════════════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════════════════

func test_multiple_releases_cascade_to_single_remaining() -> bool:
	var cm := _make_cm()
	cm.request_cursor("world", DisplayServer.CURSOR_CROSS, CursorManagerScript.PRIORITY_WORLD)
	cm.request_cursor("npc",   DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_NPC)
	cm.request_cursor("recon", DisplayServer.CURSOR_WAIT, CursorManagerScript.PRIORITY_RECON)
	cm.release_cursor("recon")
	cm.release_cursor("npc")
	return cm._current_shape == DisplayServer.CURSOR_CROSS and cm._requests.size() == 1

func test_release_all_clears_requests_and_resets_shape() -> bool:
	var cm := _make_cm()
	cm.request_cursor("world", DisplayServer.CURSOR_CROSS, CursorManagerScript.PRIORITY_WORLD)
	cm.request_cursor("npc",   DisplayServer.CURSOR_POINTING_HAND, CursorManagerScript.PRIORITY_NPC)
	cm.release_cursor("npc")
	cm.release_cursor("world")
	return cm._current_shape == DisplayServer.CURSOR_ARROW and cm._requests.is_empty()

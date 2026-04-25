## test_npc_rumor_processing.gd — Unit tests for NpcRumorProcessing sub-module (SPA-1027).
##
## Covers:
##   • _MIN_EVAL_TICKS constant
##   • Initial state: _npc is null before setup()
##   • setup() — assigns _npc reference correctly
##   • get_spread_preview() — returns [] when social_graph_ref is null
##   • get_spread_preview() — returns [] when all_npcs_ref is empty
##
## Strategy: preload npc_rumor_processing.gd as an orphaned Node. A minimal MockNpc
## inner class provides only the properties accessed in get_spread_preview().
## All methods that actually run the rumor state machine are skipped — they mutate
## _npc state and trigger dialogue/movement callbacks which require a scene tree.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcRumorProcessing
extends RefCounted

const NpcRumorProcessingScript := preload("res://scripts/npc_rumor_processing.gd")


# ── Mock helpers ──────────────────────────────────────────────────────────────

## Minimal NPC stub with only the fields get_spread_preview() inspects.
class MockNpc:
	extends Node2D
	var social_graph_ref = null
	var all_npcs_ref: Array = []
	var npc_data: Dictionary = {}


static func _make_proc() -> Node:
	return NpcRumorProcessingScript.new()


static func _make_mock_npc() -> MockNpc:
	return MockNpc.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constant
		"test_min_eval_ticks_is_three",

		# Initial state
		"test_initial_npc_ref_null",

		# setup()
		"test_setup_assigns_npc_ref",

		# get_spread_preview()
		"test_spread_preview_empty_when_no_social_graph",
		"test_spread_preview_empty_when_no_npcs",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nNpcRumorProcessing tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# _MIN_EVAL_TICKS
# ══════════════════════════════════════════════════════════════════════════════

func test_min_eval_ticks_is_three() -> bool:
	var p := _make_proc()
	var ok := p._MIN_EVAL_TICKS == 3
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_npc_ref_null() -> bool:
	var p := _make_proc()
	var ok := p._npc == null
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_npc_ref() -> bool:
	var p   := _make_proc()
	var npc := _make_mock_npc()
	p.setup(npc)
	var ok := p._npc == npc
	p.free()
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# get_spread_preview()
# ══════════════════════════════════════════════════════════════════════════════

func test_spread_preview_empty_when_no_social_graph() -> bool:
	var p   := _make_proc()
	var npc := _make_mock_npc()
	# social_graph_ref defaults to null; all_npcs_ref is non-empty so we reach the null check.
	npc.all_npcs_ref = [npc]  # one entry so the all_npcs_ref.is_empty() guard does NOT fire
	p.setup(npc)
	var result: Array = p.get_spread_preview(3)
	var ok := result.is_empty()
	p.free()
	npc.free()
	return ok


func test_spread_preview_empty_when_no_npcs() -> bool:
	var p   := _make_proc()
	var npc := _make_mock_npc()
	npc.social_graph_ref = null
	npc.all_npcs_ref     = []
	p.setup(npc)
	var result: Array = p.get_spread_preview(3)
	var ok := result.is_empty()
	p.free()
	npc.free()
	return ok

## test_npc_dialogue.gd — Unit tests for NpcDialogue sub-module (SPA-1027).
##
## Covers:
##   • _MAX_BUBBLES constant
##   • _get_time_phase() — all four phases (morning/day/evening/night)
##   • Initial state fields: _idle_bubble_cooldown, _has_bubble, _gossip_cooldown,
##                           _chatter_cooldown, _defending_icon
##   • on_exit_tree() — decrements _active_bubbles, clears _has_bubble
##   • on_exit_tree() — clamps _active_bubbles to ≥ 0
##
## Strategy: preload npc_dialogue.gd as an orphaned Node. @onready vars remain null.
## Only methods that do not touch the scene tree (no add_child, create_tween) are called.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcDialogue
extends RefCounted

const NpcDialogueScript := preload("res://scripts/npc_dialogue.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_dialogue() -> Node:
	return NpcDialogueScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# _MAX_BUBBLES
		"test_max_bubbles_constant",

		# Initial state
		"test_initial_idle_bubble_cooldown_zero",
		"test_initial_has_bubble_false",
		"test_initial_gossip_cooldown_zero",
		"test_initial_chatter_cooldown_zero",
		"test_initial_defending_icon_null",

		# _get_time_phase
		"test_time_phase_morning_at_5",
		"test_time_phase_morning_at_11",
		"test_time_phase_day_at_12",
		"test_time_phase_day_at_16",
		"test_time_phase_evening_at_17",
		"test_time_phase_evening_at_21",
		"test_time_phase_night_at_22",
		"test_time_phase_night_at_0",
		"test_time_phase_night_at_4",

		# on_exit_tree
		"test_on_exit_tree_decrements_active_bubbles",
		"test_on_exit_tree_clears_has_bubble",
		"test_on_exit_tree_clamps_bubbles_at_zero",
		"test_on_exit_tree_no_op_when_not_has_bubble",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nNpcDialogue tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# _MAX_BUBBLES
# ══════════════════════════════════════════════════════════════════════════════

func test_max_bubbles_constant() -> bool:
	var d := _make_dialogue()
	var ok := d._MAX_BUBBLES == 2
	d.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_idle_bubble_cooldown_zero() -> bool:
	var d := _make_dialogue()
	var ok := d._idle_bubble_cooldown == 0
	d.free()
	return ok


func test_initial_has_bubble_false() -> bool:
	var d := _make_dialogue()
	var ok := d._has_bubble == false
	d.free()
	return ok


func test_initial_gossip_cooldown_zero() -> bool:
	var d := _make_dialogue()
	var ok := d._gossip_cooldown == 0
	d.free()
	return ok


func test_initial_chatter_cooldown_zero() -> bool:
	var d := _make_dialogue()
	var ok := d._chatter_cooldown == 0
	d.free()
	return ok


func test_initial_defending_icon_null() -> bool:
	var d := _make_dialogue()
	var ok := d._defending_icon == null
	d.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _get_time_phase
# ══════════════════════════════════════════════════════════════════════════════

func test_time_phase_morning_at_5() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(5) == "morning"
	d.free()
	return ok


func test_time_phase_morning_at_11() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(11) == "morning"
	d.free()
	return ok


func test_time_phase_day_at_12() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(12) == "day"
	d.free()
	return ok


func test_time_phase_day_at_16() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(16) == "day"
	d.free()
	return ok


func test_time_phase_evening_at_17() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(17) == "evening"
	d.free()
	return ok


func test_time_phase_evening_at_21() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(21) == "evening"
	d.free()
	return ok


func test_time_phase_night_at_22() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(22) == "night"
	d.free()
	return ok


func test_time_phase_night_at_0() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(0) == "night"
	d.free()
	return ok


func test_time_phase_night_at_4() -> bool:
	var d := _make_dialogue()
	var ok := d._get_time_phase(4) == "night"
	d.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# on_exit_tree
# ══════════════════════════════════════════════════════════════════════════════

func test_on_exit_tree_decrements_active_bubbles() -> bool:
	var d := _make_dialogue()
	d._has_bubble = true
	NpcDialogueScript._active_bubbles = 2
	d.on_exit_tree()
	var ok := NpcDialogueScript._active_bubbles == 1
	NpcDialogueScript._active_bubbles = 0  # reset
	d.free()
	return ok


func test_on_exit_tree_clears_has_bubble() -> bool:
	var d := _make_dialogue()
	d._has_bubble = true
	NpcDialogueScript._active_bubbles = 1
	d.on_exit_tree()
	var ok := d._has_bubble == false
	NpcDialogueScript._active_bubbles = 0
	d.free()
	return ok


func test_on_exit_tree_clamps_bubbles_at_zero() -> bool:
	var d := _make_dialogue()
	d._has_bubble = true
	NpcDialogueScript._active_bubbles = 0  # already 0 — should not go negative
	d.on_exit_tree()
	var ok := NpcDialogueScript._active_bubbles == 0
	d.free()
	return ok


func test_on_exit_tree_no_op_when_not_has_bubble() -> bool:
	var d := _make_dialogue()
	d._has_bubble = false
	NpcDialogueScript._active_bubbles = 2
	d.on_exit_tree()
	# Should leave _active_bubbles untouched.
	var ok := NpcDialogueScript._active_bubbles == 2
	NpcDialogueScript._active_bubbles = 0
	d.free()
	return ok

## test_npc_conversation_overlay.gd — Unit tests for NpcConversationOverlay
## constants and initial state (SPA-1065).
##
## Covers:
##   • CONVO_RANGE_MANHATTAN == 3
##   • PULSE_DURATION == 1.5
##   • Color constants: COL_STRONG, COL_MEDIUM, COL_WEAK (alpha ordering),
##     COL_PULSE (bright gold), COL_BUBBLE
##   • Initial state: _world_ref null, _draw_node null,
##     _active_convos empty, _whisper_lines empty
##
## Strategy: NpcConversationOverlay extends CanvasLayer. .new() skips _ready()
## so the child draw node is not created. Constants and initial var state are
## safe to read on a bare instance.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcConversationOverlay
extends RefCounted

const NpcConvoScript := preload("res://scripts/npc_conversation_overlay.gd")


static func _make_nco() -> CanvasLayer:
	return NpcConvoScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_convo_range_manhattan_is_3",
		"test_pulse_duration_is_1p5",
		"test_col_strong_alpha",
		"test_col_medium_alpha",
		"test_col_weak_alpha",
		"test_col_pulse_is_bright",
		"test_col_bubble_alpha",

		# ── initial state ──
		"test_initial_world_ref_null",
		"test_initial_draw_node_null",
		"test_initial_active_convos_empty",
		"test_initial_whisper_lines_empty",
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

func test_convo_range_manhattan_is_3() -> bool:
	return NpcConvoScript.CONVO_RANGE_MANHATTAN == 3


func test_pulse_duration_is_1p5() -> bool:
	return absf(NpcConvoScript.PULSE_DURATION - 1.5) < 0.0001


func test_col_strong_alpha() -> bool:
	# COL_STRONG — warm amber, alpha ≈ 0.40
	return absf(NpcConvoScript.COL_STRONG.a - 0.40) < 0.01


func test_col_medium_alpha() -> bool:
	# COL_MEDIUM — neutral grey, alpha < COL_STRONG.a
	return NpcConvoScript.COL_MEDIUM.a < NpcConvoScript.COL_STRONG.a


func test_col_weak_alpha() -> bool:
	# COL_WEAK — faintest line, alpha < COL_MEDIUM.a
	return NpcConvoScript.COL_WEAK.a < NpcConvoScript.COL_MEDIUM.a


func test_col_pulse_is_bright() -> bool:
	# COL_PULSE — bright gold transmission flash, alpha ≈ 0.90
	return absf(NpcConvoScript.COL_PULSE.a - 0.90) < 0.01


func test_col_bubble_alpha() -> bool:
	# COL_BUBBLE — speech-bubble dots, high alpha
	return NpcConvoScript.COL_BUBBLE.a >= 0.85


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_world_ref_null() -> bool:
	var nco := _make_nco()
	var ok := nco._world_ref == null
	nco.free()
	return ok


func test_initial_draw_node_null() -> bool:
	var nco := _make_nco()
	var ok := nco._draw_node == null
	nco.free()
	return ok


func test_initial_active_convos_empty() -> bool:
	var nco := _make_nco()
	var ok := nco._active_convos.is_empty()
	nco.free()
	return ok


func test_initial_whisper_lines_empty() -> bool:
	var nco := _make_nco()
	var ok := nco._whisper_lines.is_empty()
	nco.free()
	return ok

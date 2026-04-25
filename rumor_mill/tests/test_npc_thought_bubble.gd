## test_npc_thought_bubble.gd — Unit tests for NpcThoughtBubble constants and initial state (SPA-1041).
##
## Covers:
##   • MAX_VISIBLE constant
##   • SYMBOL dictionary: all 9 RumorState entries present, correct symbols for key states
##   • STATE_COLOR dictionary: all 9 RumorState entries present
##   • STATE_HINT dictionary: entries for key states (EVALUATING–DEFENDING), absent for others
##   • Initial state: _is_showing false, _current_state UNAWARE, node refs null
##   • _exit_tree counter: decrements _visible_count when _is_showing
##
## Strategy: NpcThoughtBubble extends Node2D. Instantiating via .new() skips
## _ready() (no scene tree). All static dicts and the initial var values are
## accessible without a scene tree. _exit_tree() is called manually.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcThoughtBubble
extends RefCounted

const NpcThoughtBubbleScript := preload("res://scripts/npc_thought_bubble.gd")


static func _make_bubble() -> Node2D:
	return NpcThoughtBubbleScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── MAX_VISIBLE ──
		"test_max_visible_is_5",

		# ── SYMBOL dictionary ──
		"test_symbol_dict_has_9_entries",
		"test_symbol_unaware_is_empty",
		"test_symbol_evaluating_is_question",
		"test_symbol_believe_is_exclamation",
		"test_symbol_spread_is_ellipsis",
		"test_symbol_act_is_double_exclamation",
		"test_symbol_reject_is_x",
		"test_symbol_contradicted_is_tilde",
		"test_symbol_expired_is_empty",
		"test_symbol_defending_non_empty",

		# ── STATE_COLOR dictionary ──
		"test_state_color_has_9_entries",
		"test_state_color_unaware_is_white",
		"test_state_color_evaluating_is_yellowish",
		"test_state_color_believe_is_greenish",

		# ── STATE_HINT dictionary ──
		"test_state_hint_evaluating_present",
		"test_state_hint_believe_present",
		"test_state_hint_spread_present",
		"test_state_hint_act_present",
		"test_state_hint_reject_present",
		"test_state_hint_contradicted_present",
		"test_state_hint_defending_present",
		"test_state_hint_no_unaware_entry",
		"test_state_hint_no_expired_entry",

		# ── Initial state ──
		"test_initial_is_showing_false",
		"test_initial_current_state_unaware",
		"test_initial_label_null",
		"test_initial_badge_bg_null",

		# ── _exit_tree counter behaviour ──
		"test_exit_tree_decrements_count_when_showing",
		"test_exit_tree_noop_when_not_showing",
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
# MAX_VISIBLE
# ══════════════════════════════════════════════════════════════════════════════

func test_max_visible_is_5() -> bool:
	return NpcThoughtBubble.MAX_VISIBLE == 5


# ══════════════════════════════════════════════════════════════════════════════
# SYMBOL dictionary
# ══════════════════════════════════════════════════════════════════════════════

func test_symbol_dict_has_9_entries() -> bool:
	return NpcThoughtBubble.SYMBOL.size() == 9


func test_symbol_unaware_is_empty() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.UNAWARE, "X") == ""


func test_symbol_evaluating_is_question() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.EVALUATING, "") == "?"


func test_symbol_believe_is_exclamation() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.BELIEVE, "") == "!"


func test_symbol_spread_is_ellipsis() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.SPREAD, "") == "..."


func test_symbol_act_is_double_exclamation() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.ACT, "") == "!!"


func test_symbol_reject_is_x() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.REJECT, "") == "x"


func test_symbol_contradicted_is_tilde() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.CONTRADICTED, "") == "~"


func test_symbol_expired_is_empty() -> bool:
	return NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.EXPIRED, "X") == ""


func test_symbol_defending_non_empty() -> bool:
	var sym: String = NpcThoughtBubble.SYMBOL.get(Rumor.RumorState.DEFENDING, "")
	return not sym.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# STATE_COLOR dictionary
# ══════════════════════════════════════════════════════════════════════════════

func test_state_color_has_9_entries() -> bool:
	return NpcThoughtBubble.STATE_COLOR.size() == 9


func test_state_color_unaware_is_white() -> bool:
	var c: Color = NpcThoughtBubble.STATE_COLOR.get(Rumor.RumorState.UNAWARE, Color.BLACK)
	return c == Color.WHITE


func test_state_color_evaluating_is_yellowish() -> bool:
	var c: Color = NpcThoughtBubble.STATE_COLOR.get(Rumor.RumorState.EVALUATING, Color.BLACK)
	# Yellow-ish: R≈1, G≈1, B≈0.5
	return c.r > 0.8 and c.g > 0.8 and c.b < 0.8


func test_state_color_believe_is_greenish() -> bool:
	var c: Color = NpcThoughtBubble.STATE_COLOR.get(Rumor.RumorState.BELIEVE, Color.BLACK)
	# Green-ish: R < G
	return c.g > c.r


# ══════════════════════════════════════════════════════════════════════════════
# STATE_HINT dictionary
# ══════════════════════════════════════════════════════════════════════════════

func test_state_hint_evaluating_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.EVALUATING)


func test_state_hint_believe_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.BELIEVE)


func test_state_hint_spread_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.SPREAD)


func test_state_hint_act_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.ACT)


func test_state_hint_reject_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.REJECT)


func test_state_hint_contradicted_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.CONTRADICTED)


func test_state_hint_defending_present() -> bool:
	return NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.DEFENDING)


func test_state_hint_no_unaware_entry() -> bool:
	return not NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.UNAWARE)


func test_state_hint_no_expired_entry() -> bool:
	return not NpcThoughtBubble.STATE_HINT.has(Rumor.RumorState.EXPIRED)


# ══════════════════════════════════════════════════════════════════════════════
# Initial state (before _ready)
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_is_showing_false() -> bool:
	var b := _make_bubble()
	var ok := b._is_showing == false
	b.free()
	return ok


func test_initial_current_state_unaware() -> bool:
	var b := _make_bubble()
	var ok := b._current_state == Rumor.RumorState.UNAWARE
	b.free()
	return ok


func test_initial_label_null() -> bool:
	var b := _make_bubble()
	# _label is set in _ready(), which hasn't fired
	var ok := b._label == null
	b.free()
	return ok


func test_initial_badge_bg_null() -> bool:
	var b := _make_bubble()
	var ok := b._badge_bg == null
	b.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _exit_tree counter behaviour
# ══════════════════════════════════════════════════════════════════════════════

func test_exit_tree_decrements_count_when_showing() -> bool:
	var b := _make_bubble()
	# Manually set _is_showing and bump the static count so we can observe decrement.
	NpcThoughtBubble._visible_count += 1
	b._is_showing = true
	var count_before: int = NpcThoughtBubble._visible_count
	b._exit_tree()
	var count_after: int = NpcThoughtBubble._visible_count
	b.free()
	return count_after == count_before - 1 and b._is_showing == false


func test_exit_tree_noop_when_not_showing() -> bool:
	var b := _make_bubble()
	b._is_showing = false
	var count_before: int = NpcThoughtBubble._visible_count
	b._exit_tree()
	var count_after: int = NpcThoughtBubble._visible_count
	b.free()
	return count_after == count_before

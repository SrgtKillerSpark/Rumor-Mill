## test_recon_tooltip_manager.gd — Unit tests for recon_tooltip_manager.gd (SPA-1042).
##
## Covers:
##   • Initial state: all node refs null (setup() not called)
##
## Run from the Godot editor: Scene → Run Script.

class_name TestReconTooltipManager
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_rtm() -> ReconTooltipManager:
	return ReconTooltipManager.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_initial_counter_panel_null",
		"test_initial_heat_row_null",
		"test_initial_feed_panel_null",
		"test_initial_key_hint_row_null",
		"test_initial_action_pips_parent_null",
		"test_initial_whisper_pips_parent_null",
		"test_initial_favors_row_null",
		"test_initial_key_hint_rumor_null",
		"test_initial_key_hint_journal_null",
		"test_initial_key_hint_graph_null",
		"test_initial_key_hint_help_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nReconTooltipManager tests: %d passed, %d failed" % [passed, failed])


# ── Initial state (all refs null before setup()) ──────────────────────────────

static func test_initial_counter_panel_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._counter_panel == null
	rtm.free()
	return ok


static func test_initial_heat_row_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._heat_row == null
	rtm.free()
	return ok


static func test_initial_feed_panel_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._feed_panel == null
	rtm.free()
	return ok


static func test_initial_key_hint_row_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._key_hint_row == null
	rtm.free()
	return ok


static func test_initial_action_pips_parent_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._action_pips_parent == null
	rtm.free()
	return ok


static func test_initial_whisper_pips_parent_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._whisper_pips_parent == null
	rtm.free()
	return ok


static func test_initial_favors_row_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._favors_row == null
	rtm.free()
	return ok


static func test_initial_key_hint_rumor_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._key_hint_rumor == null
	rtm.free()
	return ok


static func test_initial_key_hint_journal_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._key_hint_journal == null
	rtm.free()
	return ok


static func test_initial_key_hint_graph_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._key_hint_graph == null
	rtm.free()
	return ok


static func test_initial_key_hint_help_null() -> bool:
	var rtm := _make_rtm()
	var ok := rtm._key_hint_help == null
	rtm.free()
	return ok

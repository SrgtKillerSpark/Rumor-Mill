## test_ui_layer_manager.gd — Unit tests for ui_layer_manager.gd (SPA-1024).
##
## Covers:
##   • Initial instance state: all scene refs null (_parent, _world, _day_night,
##     _camera, _recon_hud, _rumor_panel, _journal, _social_graph_overlay,
##     _objective_hud, _debug_overlay, _debug_console)
##   • Public overlay refs null before setup_all():
##     tutorial_wiring, input_handler, rumor_event_wiring, milestone_notifier,
##     feedback_seq, event_choice_modal, recon_ctrl_ref
##   • Private overlay refs null: _pause_menu, _end_screen, _event_card,
##     _visual_affordances, _milestone_notifier, _hud_tooltip, _context_controls,
##     _npc_info_panel, _daily_planning, _help_ui, _analytics, _analytics_manager,
##     _achievement_hooks
##   • _on_player_exposed(): null _world guard — must not crash
##   • _on_pause_menu_visibility_changed_flush(): null _pause_menu guard — must not crash
##
## UILayerManager extends Node.  setup_all() requires a fully initialised world
## with live scene-tree nodes; it is not called in unit tests.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestUILayerManager
extends RefCounted

const UILayerManagerScript := preload("res://scripts/ui_layer_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ulm() -> Node:
	return UILayerManagerScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Scene refs null
		"test_initial_parent_null",
		"test_initial_world_null",
		"test_initial_day_night_null",
		"test_initial_camera_null",
		"test_initial_recon_hud_null",
		"test_initial_rumor_panel_null",
		"test_initial_journal_null",
		"test_initial_social_graph_overlay_null",
		"test_initial_objective_hud_null",
		"test_initial_debug_overlay_null",
		"test_initial_debug_console_null",
		# Public overlay refs
		"test_initial_tutorial_wiring_null",
		"test_initial_input_handler_null",
		"test_initial_rumor_event_wiring_null",
		"test_initial_milestone_notifier_null",
		"test_initial_feedback_seq_null",
		"test_initial_event_choice_modal_null",
		"test_initial_recon_ctrl_ref_null",
		# Private overlay refs
		"test_initial_pause_menu_null",
		"test_initial_end_screen_null",
		"test_initial_event_card_null",
		"test_initial_visual_affordances_null",
		"test_initial_hud_tooltip_null",
		"test_initial_context_controls_null",
		"test_initial_npc_info_panel_null",
		"test_initial_daily_planning_null",
		"test_initial_help_ui_null",
		"test_initial_analytics_null",
		"test_initial_analytics_manager_null",
		"test_initial_achievement_hooks_null",
		# Null guards
		"test_on_player_exposed_null_world_no_crash",
		"test_on_pause_menu_flush_null_menu_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nUILayerManager tests: %d passed, %d failed" % [passed, failed])


# ── Scene refs null ───────────────────────────────────────────────────────────

static func test_initial_parent_null() -> bool:
	return _make_ulm()._parent == null


static func test_initial_world_null() -> bool:
	return _make_ulm()._world == null


static func test_initial_day_night_null() -> bool:
	return _make_ulm()._day_night == null


static func test_initial_camera_null() -> bool:
	return _make_ulm()._camera == null


static func test_initial_recon_hud_null() -> bool:
	return _make_ulm()._recon_hud == null


static func test_initial_rumor_panel_null() -> bool:
	return _make_ulm()._rumor_panel == null


static func test_initial_journal_null() -> bool:
	return _make_ulm()._journal == null


static func test_initial_social_graph_overlay_null() -> bool:
	return _make_ulm()._social_graph_overlay == null


static func test_initial_objective_hud_null() -> bool:
	return _make_ulm()._objective_hud == null


static func test_initial_debug_overlay_null() -> bool:
	return _make_ulm()._debug_overlay == null


static func test_initial_debug_console_null() -> bool:
	return _make_ulm()._debug_console == null


# ── Public overlay refs ───────────────────────────────────────────────────────

static func test_initial_tutorial_wiring_null() -> bool:
	return _make_ulm().tutorial_wiring == null


static func test_initial_input_handler_null() -> bool:
	return _make_ulm().input_handler == null


static func test_initial_rumor_event_wiring_null() -> bool:
	return _make_ulm().rumor_event_wiring == null


static func test_initial_milestone_notifier_null() -> bool:
	return _make_ulm().milestone_notifier == null


static func test_initial_feedback_seq_null() -> bool:
	return _make_ulm().feedback_seq == null


static func test_initial_event_choice_modal_null() -> bool:
	return _make_ulm().event_choice_modal == null


static func test_initial_recon_ctrl_ref_null() -> bool:
	return _make_ulm().recon_ctrl_ref == null


# ── Private overlay refs ──────────────────────────────────────────────────────

static func test_initial_pause_menu_null() -> bool:
	return _make_ulm()._pause_menu == null


static func test_initial_end_screen_null() -> bool:
	return _make_ulm()._end_screen == null


static func test_initial_event_card_null() -> bool:
	return _make_ulm()._event_card == null


static func test_initial_visual_affordances_null() -> bool:
	return _make_ulm()._visual_affordances == null


static func test_initial_hud_tooltip_null() -> bool:
	return _make_ulm()._hud_tooltip == null


static func test_initial_context_controls_null() -> bool:
	return _make_ulm()._context_controls == null


static func test_initial_npc_info_panel_null() -> bool:
	return _make_ulm()._npc_info_panel == null


static func test_initial_daily_planning_null() -> bool:
	return _make_ulm()._daily_planning == null


static func test_initial_help_ui_null() -> bool:
	return _make_ulm()._help_ui == null


static func test_initial_analytics_null() -> bool:
	return _make_ulm()._analytics == null


static func test_initial_analytics_manager_null() -> bool:
	return _make_ulm()._analytics_manager == null


static func test_initial_achievement_hooks_null() -> bool:
	return _make_ulm()._achievement_hooks == null


# ── Null guards ───────────────────────────────────────────────────────────────

## _on_player_exposed() checks "if _world != null and _world.scenario_manager != null".
## With null _world the guard fires and the method returns without crashing.
static func test_on_player_exposed_null_world_no_crash() -> bool:
	var ulm := _make_ulm()
	ulm._on_player_exposed()
	return true


## _on_pause_menu_visibility_changed_flush() checks "_pause_menu != null".
## With null _pause_menu the guard fires and the method returns without crashing.
static func test_on_pause_menu_flush_null_menu_no_crash() -> bool:
	var ulm := _make_ulm()
	ulm._on_pause_menu_visibility_changed_flush()
	return true

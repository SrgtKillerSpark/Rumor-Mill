## test_tutorial_wiring.gd — Unit tests for tutorial_wiring.gd (SPA-1024).
##
## Covers:
##   • Initial instance state: tutorial_sys=null, tutorial_banner=null,
##     _tutorial_hud=null, _tutorial_ctrl=null
##   • World/scene refs null before setup(): _world, _day_night, _camera,
##     _recon_hud, _rumor_panel, _journal, _visual_affordances, _recon_ctrl_ref
##   • S1 banner gate booleans all false: _banner_camera_gate, _banner_observe_gate,
##     _banner_eavesdrop_gate, _banner_seed_fired, _banner_hint06_fired,
##     _banner_believe_fired, _banner_journal_hint_fired, _banner_social_graph_fired,
##     _banner_s1_market_cleared
##   • Cross-scenario gate booleans all false: _ctx_spread_fired, _ctx_act_fired,
##     _ctx_reject_fired, _ctx_tokens_fired, _ctx_heat_warn_fired,
##     _ctx_rival_first_act_fired, _ctx_inquisitor_first_act_fired, _ctx_halfway_fired
##   • Idle-detection state: _idle_timer=null, _idle_hint_fired_no_action=false,
##     _idle_hint_fired_no_rumor=false, _has_performed_any_action=false,
##     _has_crafted_any_rumor=false
##   • Counters: _spa724_action_count=0, _banner_eavesdrop_count=0, _waypoint_step=0
##   • Waypoint/manor refs null: _waypoint_node, _waypoint_tween, _s1_manor_highlight,
##     _whats_changed_card, _rumor_panel_tooltip
##   • wire_pause_menu(): null pause_menu guard — must not crash
##
## TutorialWiring extends Node (class_name TutorialWiring).
## setup() requires live world, recon_ctrl, and scene-tree signals — not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestTutorialWiring
extends RefCounted

const TutorialWiringScript := preload("res://scripts/tutorial_wiring.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_tw() -> Node:
	return TutorialWiringScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Core refs null
		"test_initial_tutorial_sys_null",
		"test_initial_tutorial_banner_null",
		"test_initial_tutorial_hud_null",
		"test_initial_tutorial_ctrl_null",
		# World/scene refs null
		"test_initial_world_null",
		"test_initial_day_night_null",
		"test_initial_camera_null",
		"test_initial_recon_hud_null",
		"test_initial_rumor_panel_null",
		"test_initial_journal_null",
		"test_initial_visual_affordances_null",
		"test_initial_recon_ctrl_ref_null",
		# S1 banner gate booleans
		"test_initial_banner_camera_gate_false",
		"test_initial_banner_observe_gate_false",
		"test_initial_banner_eavesdrop_gate_false",
		"test_initial_banner_seed_fired_false",
		"test_initial_banner_hint06_fired_false",
		"test_initial_banner_believe_fired_false",
		"test_initial_banner_journal_hint_fired_false",
		"test_initial_banner_social_graph_fired_false",
		"test_initial_banner_s1_market_cleared_false",
		# Cross-scenario gate booleans
		"test_initial_ctx_spread_fired_false",
		"test_initial_ctx_act_fired_false",
		"test_initial_ctx_reject_fired_false",
		"test_initial_ctx_tokens_fired_false",
		"test_initial_ctx_heat_warn_fired_false",
		"test_initial_ctx_rival_first_act_fired_false",
		"test_initial_ctx_inquisitor_first_act_fired_false",
		"test_initial_ctx_halfway_fired_false",
		# Idle-detection state
		"test_initial_idle_timer_null",
		"test_initial_idle_hint_fired_no_action_false",
		"test_initial_idle_hint_fired_no_rumor_false",
		"test_initial_has_performed_any_action_false",
		"test_initial_has_crafted_any_rumor_false",
		# Counters
		"test_initial_spa724_action_count_zero",
		"test_initial_banner_eavesdrop_count_zero",
		"test_initial_waypoint_step_zero",
		# Node refs
		"test_initial_waypoint_node_null",
		"test_initial_waypoint_tween_null",
		"test_initial_s1_manor_highlight_null",
		"test_initial_whats_changed_card_null",
		"test_initial_rumor_panel_tooltip_null",
		# wire_pause_menu() null guard
		"test_wire_pause_menu_null_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTutorialWiring tests: %d passed, %d failed" % [passed, failed])


# ── Core refs null ────────────────────────────────────────────────────────────

static func test_initial_tutorial_sys_null() -> bool:
	return _make_tw().tutorial_sys == null


static func test_initial_tutorial_banner_null() -> bool:
	return _make_tw().tutorial_banner == null


static func test_initial_tutorial_hud_null() -> bool:
	return _make_tw()._tutorial_hud == null


static func test_initial_tutorial_ctrl_null() -> bool:
	return _make_tw()._tutorial_ctrl == null


# ── World/scene refs null ─────────────────────────────────────────────────────

static func test_initial_world_null() -> bool:
	return _make_tw()._world == null


static func test_initial_day_night_null() -> bool:
	return _make_tw()._day_night == null


static func test_initial_camera_null() -> bool:
	return _make_tw()._camera == null


static func test_initial_recon_hud_null() -> bool:
	return _make_tw()._recon_hud == null


static func test_initial_rumor_panel_null() -> bool:
	return _make_tw()._rumor_panel == null


static func test_initial_journal_null() -> bool:
	return _make_tw()._journal == null


static func test_initial_visual_affordances_null() -> bool:
	return _make_tw()._visual_affordances == null


static func test_initial_recon_ctrl_ref_null() -> bool:
	return _make_tw()._recon_ctrl_ref == null


# ── S1 banner gate booleans ───────────────────────────────────────────────────

static func test_initial_banner_camera_gate_false() -> bool:
	return not _make_tw()._banner_camera_gate


static func test_initial_banner_observe_gate_false() -> bool:
	return not _make_tw()._banner_observe_gate


static func test_initial_banner_eavesdrop_gate_false() -> bool:
	return not _make_tw()._banner_eavesdrop_gate


static func test_initial_banner_seed_fired_false() -> bool:
	return not _make_tw()._banner_seed_fired


static func test_initial_banner_hint06_fired_false() -> bool:
	return not _make_tw()._banner_hint06_fired


static func test_initial_banner_believe_fired_false() -> bool:
	return not _make_tw()._banner_believe_fired


static func test_initial_banner_journal_hint_fired_false() -> bool:
	return not _make_tw()._banner_journal_hint_fired


static func test_initial_banner_social_graph_fired_false() -> bool:
	return not _make_tw()._banner_social_graph_fired


static func test_initial_banner_s1_market_cleared_false() -> bool:
	return not _make_tw()._banner_s1_market_cleared


# ── Cross-scenario gate booleans ──────────────────────────────────────────────

static func test_initial_ctx_spread_fired_false() -> bool:
	return not _make_tw()._ctx_spread_fired


static func test_initial_ctx_act_fired_false() -> bool:
	return not _make_tw()._ctx_act_fired


static func test_initial_ctx_reject_fired_false() -> bool:
	return not _make_tw()._ctx_reject_fired


static func test_initial_ctx_tokens_fired_false() -> bool:
	return not _make_tw()._ctx_tokens_fired


static func test_initial_ctx_heat_warn_fired_false() -> bool:
	return not _make_tw()._ctx_heat_warn_fired


static func test_initial_ctx_rival_first_act_fired_false() -> bool:
	return not _make_tw()._ctx_rival_first_act_fired


static func test_initial_ctx_inquisitor_first_act_fired_false() -> bool:
	return not _make_tw()._ctx_inquisitor_first_act_fired


static func test_initial_ctx_halfway_fired_false() -> bool:
	return not _make_tw()._ctx_halfway_fired


# ── Idle-detection state ──────────────────────────────────────────────────────

static func test_initial_idle_timer_null() -> bool:
	return _make_tw()._idle_timer == null


static func test_initial_idle_hint_fired_no_action_false() -> bool:
	return not _make_tw()._idle_hint_fired_no_action


static func test_initial_idle_hint_fired_no_rumor_false() -> bool:
	return not _make_tw()._idle_hint_fired_no_rumor


static func test_initial_has_performed_any_action_false() -> bool:
	return not _make_tw()._has_performed_any_action


static func test_initial_has_crafted_any_rumor_false() -> bool:
	return not _make_tw()._has_crafted_any_rumor


# ── Counters ──────────────────────────────────────────────────────────────────

static func test_initial_spa724_action_count_zero() -> bool:
	return _make_tw()._spa724_action_count == 0


static func test_initial_banner_eavesdrop_count_zero() -> bool:
	return _make_tw()._banner_eavesdrop_count == 0


static func test_initial_waypoint_step_zero() -> bool:
	return _make_tw()._waypoint_step == 0


# ── Node refs ─────────────────────────────────────────────────────────────────

static func test_initial_waypoint_node_null() -> bool:
	return _make_tw()._waypoint_node == null


static func test_initial_waypoint_tween_null() -> bool:
	return _make_tw()._waypoint_tween == null


static func test_initial_s1_manor_highlight_null() -> bool:
	return _make_tw()._s1_manor_highlight == null


static func test_initial_whats_changed_card_null() -> bool:
	return _make_tw()._whats_changed_card == null


static func test_initial_rumor_panel_tooltip_null() -> bool:
	return _make_tw()._rumor_panel_tooltip == null


# ── wire_pause_menu() null guard ──────────────────────────────────────────────

## wire_pause_menu() checks "if tutorial_banner != null and pause_menu != null".
## With null tutorial_banner the guard fires — must not crash.
static func test_wire_pause_menu_null_no_crash() -> bool:
	var tw := _make_tw()
	tw.wire_pause_menu(null)
	return true

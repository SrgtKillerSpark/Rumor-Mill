## test_rumor_event_wiring.gd — Unit tests for RumorEventWiring initial state
## and reward-moment guards (SPA-1065).
##
## Covers:
##   • Initial state: all ten external node refs null
##   • Reward-moment one-shot guards: _reward_first_spread_fired false,
##     _reward_first_belief_fired false
##   • _on_rumor_seeded_for_planning increments whisper_count when daily_planning
##     is null (no crash — guard clause)
##   • _on_recon_action_for_planning no-ops when daily_planning is null
##   • _on_bribe_for_planning no-ops when daily_planning is null
##
## Strategy: RumorEventWiring extends Node. .new() does not call _ready(),
## so no scene tree is required. Methods that depend on external refs all guard
## on null so they are safe to call on a fresh instance.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorEventWiring
extends RefCounted

const RumorEventWiringScript := preload("res://scripts/rumor_event_wiring.gd")


static func _make_rew() -> RumorEventWiring:
	return RumorEventWiringScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── initial state: external refs ──
		"test_initial_world_null",
		"test_initial_day_night_null",
		"test_initial_camera_null",
		"test_initial_journal_null",
		"test_initial_recon_hud_null",
		"test_initial_rumor_panel_null",
		"test_initial_social_graph_overlay_null",
		"test_initial_objective_hud_null",
		"test_initial_milestone_notifier_null",
		"test_initial_daily_planning_null",

		# ── reward-moment guards ──
		"test_initial_reward_first_spread_false",
		"test_initial_reward_first_belief_false",

		# ── null-guard: planning counter handlers ──
		"test_planning_handlers_no_crash_null_deps",
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
# Initial state — external refs
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_world_null() -> bool:
	var rew := _make_rew()
	var ok := rew._world == null
	rew.free()
	return ok


func test_initial_day_night_null() -> bool:
	var rew := _make_rew()
	var ok := rew._day_night == null
	rew.free()
	return ok


func test_initial_camera_null() -> bool:
	var rew := _make_rew()
	var ok := rew._camera == null
	rew.free()
	return ok


func test_initial_journal_null() -> bool:
	var rew := _make_rew()
	var ok := rew._journal == null
	rew.free()
	return ok


func test_initial_recon_hud_null() -> bool:
	var rew := _make_rew()
	var ok := rew._recon_hud == null
	rew.free()
	return ok


func test_initial_rumor_panel_null() -> bool:
	var rew := _make_rew()
	var ok := rew._rumor_panel == null
	rew.free()
	return ok


func test_initial_social_graph_overlay_null() -> bool:
	var rew := _make_rew()
	var ok := rew._social_graph_overlay == null
	rew.free()
	return ok


func test_initial_objective_hud_null() -> bool:
	var rew := _make_rew()
	var ok := rew._objective_hud == null
	rew.free()
	return ok


func test_initial_milestone_notifier_null() -> bool:
	var rew := _make_rew()
	var ok := rew._milestone_notifier == null
	rew.free()
	return ok


func test_initial_daily_planning_null() -> bool:
	var rew := _make_rew()
	var ok := rew._daily_planning == null
	rew.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Reward-moment guards
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_reward_first_spread_false() -> bool:
	var rew := _make_rew()
	var ok := rew._reward_first_spread_fired == false
	rew.free()
	return ok


func test_initial_reward_first_belief_false() -> bool:
	var rew := _make_rew()
	var ok := rew._reward_first_belief_fired == false
	rew.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Null-guard: planning counter handlers
# ══════════════════════════════════════════════════════════════════════════════

func test_planning_handlers_no_crash_null_deps() -> bool:
	var rew := _make_rew()
	# All deps null — each handler should return early without crashing.
	rew._on_recon_action_for_planning("observe successful", true)
	rew._on_bribe_for_planning("TestNpc", 5)
	rew._on_rumor_seeded_for_planning("r1", "Subject", "claim", "Target")
	rew.free()
	return true  # reaching here means no crash

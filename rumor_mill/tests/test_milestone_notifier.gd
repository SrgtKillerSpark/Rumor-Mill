## test_milestone_notifier.gd — Unit tests for milestone_notifier.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Layout constants: POPUP_W, POPUP_H_BASE, POPUP_H_FULL, POPUP_Y, VW,
##                       PARTICLE_CNT, AUTO_DISMISS
##   • PROGRESS_PARTICLE_MAP entries
##   • Initial state: refs null, _milestones/{}_queue empty, _showing false
##   • setup() stores journal and intel refs
##
## NOTE: show_milestone() calls get_tree().create_timer() — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMilestoneNotifier
extends RefCounted

const MilestoneNotifierScript := preload("res://scripts/milestone_notifier.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_mn() -> CanvasLayer:
	return MilestoneNotifierScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark",
		"test_c_border_gold",
		"test_c_reward_bright_green",
		"test_c_vignette_translucent_gold",
		# Layout constants
		"test_popup_w",
		"test_popup_h_base",
		"test_popup_h_full",
		"test_popup_y",
		"test_vw",
		"test_particle_cnt",
		"test_auto_dismiss",
		# PROGRESS_PARTICLE_MAP
		"test_progress_particle_map_count",
		"test_progress_particle_map_25",
		"test_progress_particle_map_50",
		"test_progress_particle_map_75",
		# Initial state
		"test_initial_journal_ref_null",
		"test_initial_intel_ref_null",
		"test_initial_milestones_empty",
		"test_initial_queue_empty",
		"test_initial_showing_false",
		"test_initial_popup_root_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMilestoneNotifier tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark() -> bool:
	var mn := _make_mn()
	var ok := mn.C_BG.r < 0.15 and mn.C_BG.a > 0.90
	mn.free()
	return ok


static func test_c_border_gold() -> bool:
	var mn := _make_mn()
	var ok := mn.C_BORDER.r > 0.65 and mn.C_BORDER.g > 0.45 and mn.C_BORDER.b < 0.25
	mn.free()
	return ok


static func test_c_reward_bright_green() -> bool:
	var mn := _make_mn()
	var ok := mn.C_REWARD.g > 0.85 and mn.C_REWARD.r < 0.80
	mn.free()
	return ok


static func test_c_vignette_translucent_gold() -> bool:
	var mn := _make_mn()
	# translucent: a < 0.6; gold: high r, high g, low b
	var ok := mn.C_VIGNETTE.a < 0.60 and mn.C_VIGNETTE.r > 0.85
	mn.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_popup_w() -> bool:
	var mn := _make_mn()
	var ok := mn.POPUP_W == 480
	mn.free()
	return ok


static func test_popup_h_base() -> bool:
	var mn := _make_mn()
	var ok := mn.POPUP_H_BASE == 108
	mn.free()
	return ok


static func test_popup_h_full() -> bool:
	var mn := _make_mn()
	var ok := mn.POPUP_H_FULL == 134
	mn.free()
	return ok


static func test_popup_y() -> bool:
	var mn := _make_mn()
	var ok := mn.POPUP_Y == 76
	mn.free()
	return ok


static func test_vw() -> bool:
	var mn := _make_mn()
	var ok := mn.VW == 1280
	mn.free()
	return ok


static func test_particle_cnt() -> bool:
	var mn := _make_mn()
	var ok := mn.PARTICLE_CNT == 28
	mn.free()
	return ok


static func test_auto_dismiss() -> bool:
	var mn := _make_mn()
	var ok := mn.AUTO_DISMISS == 4.0
	mn.free()
	return ok


# ── PROGRESS_PARTICLE_MAP ─────────────────────────────────────────────────────

static func test_progress_particle_map_count() -> bool:
	var mn := _make_mn()
	var ok := mn.PROGRESS_PARTICLE_MAP.size() == 3
	mn.free()
	return ok


static func test_progress_particle_map_25() -> bool:
	var mn := _make_mn()
	var ok := mn.PROGRESS_PARTICLE_MAP.get("progress_toast_25", 0) == 28
	mn.free()
	return ok


static func test_progress_particle_map_50() -> bool:
	var mn := _make_mn()
	var ok := mn.PROGRESS_PARTICLE_MAP.get("progress_toast_50", 0) == 40
	mn.free()
	return ok


static func test_progress_particle_map_75() -> bool:
	var mn := _make_mn()
	var ok := mn.PROGRESS_PARTICLE_MAP.get("progress_toast_75", 0) == 60
	mn.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_journal_ref_null() -> bool:
	var mn := _make_mn()
	var ok := mn._journal_ref == null
	mn.free()
	return ok


static func test_initial_intel_ref_null() -> bool:
	var mn := _make_mn()
	var ok := mn._intel_ref == null
	mn.free()
	return ok


static func test_initial_milestones_empty() -> bool:
	var mn := _make_mn()
	var ok := mn._milestones.is_empty()
	mn.free()
	return ok


static func test_initial_queue_empty() -> bool:
	var mn := _make_mn()
	var ok := mn._queue.is_empty()
	mn.free()
	return ok


static func test_initial_showing_false() -> bool:
	var mn := _make_mn()
	var ok := mn._showing == false
	mn.free()
	return ok


static func test_initial_popup_root_null() -> bool:
	var mn := _make_mn()
	var ok := mn._popup_root == null
	mn.free()
	return ok

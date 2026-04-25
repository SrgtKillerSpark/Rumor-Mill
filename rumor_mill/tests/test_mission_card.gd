## test_mission_card.gd — Unit tests for mission_card.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_BG, C_BORDER, C_BADGE, C_BODY, C_LABEL, C_ACTION
##   • Layout constants: POPUP_W, POPUP_H, POPUP_Y, VW, AUTO_DISMISS, PARTICLE_CNT
##   • Initial state: refs null, _is_dismissed=false
##
## NOTE: setup() builds and adds nodes — requires scene tree, not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMissionCard
extends RefCounted

const MissionCardScript := preload("res://scripts/mission_card.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_mc() -> CanvasLayer:
	return MissionCardScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark",
		"test_c_border_gold",
		"test_c_badge_gold",
		"test_c_action_green",
		# Layout constants
		"test_popup_w",
		"test_popup_h",
		"test_popup_y",
		"test_vw",
		"test_auto_dismiss",
		"test_particle_cnt",
		# Initial state
		"test_initial_popup_root_null",
		"test_initial_dismiss_tween_null",
		"test_initial_is_dismissed_false",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMissionCard tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark() -> bool:
	var mc := _make_mc()
	var ok := mc.C_BG.r < 0.15 and mc.C_BG.a > 0.90
	mc.free()
	return ok


static func test_c_border_gold() -> bool:
	var mc := _make_mc()
	var ok := mc.C_BORDER.r > 0.65 and mc.C_BORDER.g > 0.45 and mc.C_BORDER.b < 0.25
	mc.free()
	return ok


static func test_c_badge_gold() -> bool:
	var mc := _make_mc()
	var ok := mc.C_BADGE.r > 0.85 and mc.C_BADGE.g > 0.70 and mc.C_BADGE.b < 0.20
	mc.free()
	return ok


static func test_c_action_green() -> bool:
	var mc := _make_mc()
	var ok := mc.C_ACTION.g > 0.80 and mc.C_ACTION.r < 0.70
	mc.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_popup_w() -> bool:
	var mc := _make_mc()
	var ok := mc.POPUP_W == 540
	mc.free()
	return ok


static func test_popup_h() -> bool:
	var mc := _make_mc()
	var ok := mc.POPUP_H == 168
	mc.free()
	return ok


static func test_popup_y() -> bool:
	var mc := _make_mc()
	var ok := mc.POPUP_Y == 72.0
	mc.free()
	return ok


static func test_vw() -> bool:
	var mc := _make_mc()
	var ok := mc.VW == 1280
	mc.free()
	return ok


static func test_auto_dismiss() -> bool:
	var mc := _make_mc()
	var ok := mc.AUTO_DISMISS == 8.0
	mc.free()
	return ok


static func test_particle_cnt() -> bool:
	var mc := _make_mc()
	var ok := mc.PARTICLE_CNT == 22
	mc.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_popup_root_null() -> bool:
	var mc := _make_mc()
	var ok := mc._popup_root == null
	mc.free()
	return ok


static func test_initial_dismiss_tween_null() -> bool:
	var mc := _make_mc()
	var ok := mc._dismiss_tween == null
	mc.free()
	return ok


static func test_initial_is_dismissed_false() -> bool:
	var mc := _make_mc()
	var ok := mc._is_dismissed == false
	mc.free()
	return ok

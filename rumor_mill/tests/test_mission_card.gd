## test_mission_card.gd — Unit tests for mission_card.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_BG, C_BORDER, C_BADGE, C_BODY, C_LABEL, C_ACTION
##   • Layout constants: POPUP_W_FRAC, POPUP_H_FRAC, POPUP_Y_FRAC,
##                       AUTO_DISMISS, PARTICLE_CNT
##   • Computed vars initial state: _popup_w/_popup_h/_popup_y == 0.0
##   • Initial state: refs null, _is_dismissed=false
##
## NOTE: The card was refactored from fixed pixel constants (POPUP_W/H/Y, VW)
## to viewport-relative fractions (POPUP_W_FRAC/H_FRAC/Y_FRAC) prior to SPA-1798.
## setup() builds and adds nodes — requires scene tree, not tested here.
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
		# Layout fraction constants (refactored from fixed pixel values pre-SPA-1798)
		"test_popup_w_frac",
		"test_popup_h_frac",
		"test_popup_y_frac",
		"test_auto_dismiss",
		"test_particle_cnt",
		# Computed vars initial state
		"test_popup_y_var_initially_zero",
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
	var ok: bool = mc.C_BG.r < 0.15 and mc.C_BG.a > 0.90
	mc.free()
	return ok


static func test_c_border_gold() -> bool:
	var mc := _make_mc()
	var ok: bool = mc.C_BORDER.r > 0.65 and mc.C_BORDER.g > 0.45 and mc.C_BORDER.b < 0.25
	mc.free()
	return ok


static func test_c_badge_gold() -> bool:
	var mc := _make_mc()
	var ok: bool = mc.C_BADGE.r > 0.85 and mc.C_BADGE.g > 0.70 and mc.C_BADGE.b < 0.20
	mc.free()
	return ok


static func test_c_action_green() -> bool:
	var mc := _make_mc()
	var ok: bool = mc.C_ACTION.g > 0.80 and mc.C_ACTION.r < 0.70
	mc.free()
	return ok


# ── Layout fraction constants ─────────────────────────────────────────────────
# The card was refactored from fixed pixel constants (POPUP_W/H/Y, VW) to
# viewport-relative fractions before SPA-1798.  Tests updated accordingly.

static func test_popup_w_frac() -> bool:
	var mc := _make_mc()
	var ok: bool = is_equal_approx(mc.POPUP_W_FRAC, 0.422)
	mc.free()
	return ok


static func test_popup_h_frac() -> bool:
	var mc := _make_mc()
	var ok: bool = is_equal_approx(mc.POPUP_H_FRAC, 0.233)
	mc.free()
	return ok


static func test_popup_y_frac() -> bool:
	var mc := _make_mc()
	var ok: bool = is_equal_approx(mc.POPUP_Y_FRAC, 0.10)
	mc.free()
	return ok


static func test_auto_dismiss() -> bool:
	var mc := _make_mc()
	var ok: bool = mc.AUTO_DISMISS == 8.0
	mc.free()
	return ok


static func test_particle_cnt() -> bool:
	var mc := _make_mc()
	var ok: bool = mc.PARTICLE_CNT == 22
	mc.free()
	return ok


# ── Computed vars initial state ───────────────────────────────────────────────

static func test_popup_y_var_initially_zero() -> bool:
	## _popup_y is populated by setup() from _vp_h * POPUP_Y_FRAC.  On a bare
	## instance (setup() not yet called) it must be 0.0.  The SPA-1798 fix corrected
	## line 79 to reference this var instead of the undefined name POPUP_Y.
	var mc := _make_mc()
	var ok: bool = mc._popup_y == 0.0
	mc.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_popup_root_null() -> bool:
	var mc := _make_mc()
	var ok: bool = mc._popup_root == null
	mc.free()
	return ok


static func test_initial_dismiss_tween_null() -> bool:
	var mc := _make_mc()
	var ok: bool = mc._dismiss_tween == null
	mc.free()
	return ok


static func test_initial_is_dismissed_false() -> bool:
	var mc := _make_mc()
	var ok: bool = mc._is_dismissed == false
	mc.free()
	return ok

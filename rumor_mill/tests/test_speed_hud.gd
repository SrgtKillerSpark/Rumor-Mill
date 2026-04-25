## test_speed_hud.gd — Unit tests for speed_hud.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_ACTIVE, C_NORMAL, C_BORDER, C_TEXT
##   • Speed enum ordinals: PAUSE=0, NORMAL=1, FAST=2
##   • TICK_DURATION entries
##   • Initial state: _speed=Speed.NORMAL, node refs null
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpeedHud
extends RefCounted

const SpeedHudScript := preload("res://scripts/speed_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return SpeedHudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_active_amber",
		"test_c_normal_very_dark",
		"test_c_text_near_white",
		# Speed enum ordinals
		"test_speed_pause_is_zero",
		"test_speed_normal_is_one",
		"test_speed_fast_is_two",
		# TICK_DURATION
		"test_tick_duration_count",
		"test_tick_duration_normal",
		"test_tick_duration_fast",
		# Initial state
		"test_initial_speed_is_normal",
		"test_initial_day_night_null",
		"test_initial_intel_store_null",
		"test_initial_btn_pause_null",
		"test_initial_btn_normal_null",
		"test_initial_btn_fast_null",
		"test_initial_btn_end_day_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSpeedHud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_active_amber() -> bool:
	var h := _make_hud()
	# amber: moderate-high r, moderate g, low b
	var ok := h.C_ACTIVE.r > 0.60 and h.C_ACTIVE.g > 0.45 and h.C_ACTIVE.b < 0.25
	h.free()
	return ok


static func test_c_normal_very_dark() -> bool:
	var h := _make_hud()
	var ok := h.C_NORMAL.r < 0.25 and h.C_NORMAL.g < 0.20
	h.free()
	return ok


static func test_c_text_near_white() -> bool:
	var h := _make_hud()
	var ok := h.C_TEXT.r > 0.90 and h.C_TEXT.g > 0.85 and h.C_TEXT.b > 0.75
	h.free()
	return ok


# ── Speed enum ordinals ───────────────────────────────────────────────────────

static func test_speed_pause_is_zero() -> bool:
	var ok := SpeedHudScript.Speed.PAUSE == 0
	return ok


static func test_speed_normal_is_one() -> bool:
	var ok := SpeedHudScript.Speed.NORMAL == 1
	return ok


static func test_speed_fast_is_two() -> bool:
	var ok := SpeedHudScript.Speed.FAST == 2
	return ok


# ── TICK_DURATION ─────────────────────────────────────────────────────────────

static func test_tick_duration_count() -> bool:
	var h := _make_hud()
	var ok := h.TICK_DURATION.size() == 2
	h.free()
	return ok


static func test_tick_duration_normal() -> bool:
	var h := _make_hud()
	var ok := h.TICK_DURATION.get(SpeedHudScript.Speed.NORMAL, -1.0) == 1.0
	h.free()
	return ok


static func test_tick_duration_fast() -> bool:
	var h := _make_hud()
	# 0.333 with float tolerance
	var val: float = h.TICK_DURATION.get(SpeedHudScript.Speed.FAST, -1.0)
	var ok := abs(val - 0.333) < 0.001
	h.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_speed_is_normal() -> bool:
	var h := _make_hud()
	var ok := h._speed == SpeedHudScript.Speed.NORMAL
	h.free()
	return ok


static func test_initial_day_night_null() -> bool:
	var h := _make_hud()
	var ok := h._day_night == null
	h.free()
	return ok


static func test_initial_intel_store_null() -> bool:
	var h := _make_hud()
	var ok := h._intel_store == null
	h.free()
	return ok


static func test_initial_btn_pause_null() -> bool:
	var h := _make_hud()
	var ok := h._btn_pause == null
	h.free()
	return ok


static func test_initial_btn_normal_null() -> bool:
	var h := _make_hud()
	var ok := h._btn_normal == null
	h.free()
	return ok


static func test_initial_btn_fast_null() -> bool:
	var h := _make_hud()
	var ok := h._btn_fast == null
	h.free()
	return ok


static func test_initial_btn_end_day_null() -> bool:
	var h := _make_hud()
	var ok := h._btn_end_day == null
	h.free()
	return ok

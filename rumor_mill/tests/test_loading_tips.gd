## test_loading_tips.gd — Unit tests for loading_tips.gd (SPA-1042).
##
## Covers:
##   • MIN_DURATION_SEC constant
##   • TIPS array has 16 entries, all non-empty strings
##   • Palette constants: C_BACKDROP (near-black), C_LABEL, C_TIP
##   • Initial state: _active=false, node refs null
##   • end_transition() is safe to call before start_transition() (no crash)
##
## Run from the Godot editor: Scene → Run Script.

class_name TestLoadingTips
extends RefCounted

const LoadingTipsScript := preload("res://scripts/loading_tips.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_lt() -> CanvasLayer:
	return LoadingTipsScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_min_duration_sec",
		"test_tips_count",
		"test_tips_all_nonempty",
		# Palette
		"test_c_backdrop_near_black",
		"test_c_tip_near_parchment",
		# Initial state
		"test_initial_active_false",
		"test_initial_start_time_zero",
		"test_initial_tip_label_null",
		"test_initial_loading_label_null",
		"test_initial_fade_tween_null",
		"test_initial_wrapper_null",
		# Guard: end_transition() before start_transition() must not crash
		"test_end_transition_before_start_is_safe",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nLoadingTips tests: %d passed, %d failed" % [passed, failed])


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_min_duration_sec() -> bool:
	var lt := _make_lt()
	var ok := lt.MIN_DURATION_SEC == 2.0
	lt.free()
	return ok


static func test_tips_count() -> bool:
	var lt := _make_lt()
	var ok := lt.TIPS.size() == 16
	lt.free()
	return ok


static func test_tips_all_nonempty() -> bool:
	var lt := _make_lt()
	var ok := true
	for tip in lt.TIPS:
		if (tip as String).is_empty():
			ok = false
			break
	lt.free()
	return ok


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var lt := _make_lt()
	var ok := lt.C_BACKDROP.r < 0.10 and lt.C_BACKDROP.g < 0.05 and lt.C_BACKDROP.a > 0.90
	lt.free()
	return ok


static func test_c_tip_near_parchment() -> bool:
	var lt := _make_lt()
	# parchment: high r, high g, moderate b
	var ok := lt.C_TIP.r > 0.85 and lt.C_TIP.g > 0.80 and lt.C_TIP.b > 0.60
	lt.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_active_false() -> bool:
	var lt := _make_lt()
	var ok := lt._active == false
	lt.free()
	return ok


static func test_initial_start_time_zero() -> bool:
	var lt := _make_lt()
	var ok := lt._start_time == 0.0
	lt.free()
	return ok


static func test_initial_tip_label_null() -> bool:
	var lt := _make_lt()
	var ok := lt._tip_label == null
	lt.free()
	return ok


static func test_initial_loading_label_null() -> bool:
	var lt := _make_lt()
	var ok := lt._loading_label == null
	lt.free()
	return ok


static func test_initial_fade_tween_null() -> bool:
	var lt := _make_lt()
	var ok := lt._fade_tween == null
	lt.free()
	return ok


static func test_initial_wrapper_null() -> bool:
	var lt := _make_lt()
	var ok := lt._wrapper == null
	lt.free()
	return ok


# ── end_transition() guard ────────────────────────────────────────────────────

## Calling end_transition() when _active=false must return early without crashing.
static func test_end_transition_before_start_is_safe() -> bool:
	var lt := _make_lt()
	# _active is false by default; end_transition() has an early-return guard.
	lt.end_transition()
	var ok := lt._active == false
	lt.free()
	return ok
